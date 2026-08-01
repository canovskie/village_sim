import 'dart:math';

/// HAREKET FİZİĞİ — NPC'nin ağırlığı, ataleti ve bakış yönü.
///
/// Öncesinde her NPC hedefine doğru her kare "ışınlanıyordu": yön anlık
/// değişiyor, hız 0'dan tam değere tek karede sıçrıyor, bakış yönü ham `dx`
/// işaretinden okunduğu için izoda dikeye yakın yürüyende kare kare
/// titriyordu. Sonuç, oyuncunun gördüğü şey: sürekli ileri geri gidip gelen,
/// yerinde dönen kuklalar.
///
/// Bu sınıf o katmanı bir HIZ VEKTÖRÜ üzerine kurar:
///   - hız hedefe üstel yaklaşır (kalkışta ivme, duruşta fren),
///   - yön değişimi bir açısal hız sınırıyla kısıtlanır → NPC keskin köşe
///     dönmez, kavis çizer; ani 180° yerine gerçek bir U dönüşü yapar,
///   - bakış yönü ham yer değişiminden değil, YUMUŞATILMIŞ hızdan ve bir
///     histerezisle okunur → gürültüyle takla atmaz,
///   - yön değiştiğinde sprite yatayda daralıp genişleyerek döner
///     ([turnScaleX]) → anlık aynalama gider.
///
/// Saf sınıf: dünyayı, Flutter'ı, sahneyi bilmez. Girdi hedef yönü + istenen
/// hız, çıktı bu karede uygulanacak yer değişimi. Testi [test/locomotion_test.dart].
class Locomotion {
  // ── Ayarlar ────────────────────────────────────────────────────────────────
  /// Hızlanma zaman sabiti (sn) — duraktan tam hıza ~3× bu süre.
  static const double kAccelTau = 0.16;

  /// Yavaşlama zaman sabiti (sn) — frenlemek hızlanmaktan çabuk.
  static const double kBrakeTau = 0.10;

  /// Yürürken maksimum dönüş hızı (rad/sn). Küçük değer = geniş kavis.
  static const double kTurnRate = 4.6;

  /// Düşük hızda ek dönüş serbestliği — yerinde/ağır ağır giderken NPC
  /// çabucak yön değiştirebilir, koşarken değiştiremez (atalet okunur).
  static const double kTurnBoost = 5.0;

  /// Hedefe bu mesafeden itibaren fren başlar (tile).
  static const double kArriveRadius = 1.15;

  /// Varış freninin taban çarpanı — hedefe sürünerek değil, yavaşlayarak varır.
  static const double kArriveFloor = 0.28;

  /// |vx| bu eşiğin altındaysa bakış yönü kararı ALINMAZ (gürültü bandı).
  static const double kFaceDeadband = 0.16;

  /// Yeni bakış yönünün onaylanması için gereken kararlılık süresi (sn).
  static const double kFaceHold = 0.28;

  /// Dönüş animasyonu hızı (birim/sn; aralık -1..+1 → tam dönüş ~0.22 sn).
  static const double kFlipRate = 9.0;

  /// Dönüşün ortasında sprite'ın yatayda inebileceği en dar oran — 0 olsaydı
  /// karakter bir kare tamamen kaybolurdu.
  static const double kEdgeOnScale = 0.10;

  // ── Durum ──────────────────────────────────────────────────────────────────
  /// Anlık hız vektörü (tile/sn).
  double vx = 0, vy = 0;

  /// Bakış yönü, animasyonlu: +1 sağ, -1 sol, arası dönüş anı.
  double facingSign = 1.0;

  /// Hedef bakış yönü (+1/-1) — histerezis onayından geçmiş karar.
  double _want = 1.0;

  /// Yeni yönün ne kadardır kararlı olduğu (sn).
  double _hold = 0.0;

  /// KAÇINMA yönlendirmesi — separation buraya yazar, ilk [advance] tüketir.
  /// Pozisyona doğrudan itme DEĞİL: hedef yönü büken bir kuvvet. Böylece NPC
  /// kalabalıkta zıplamaz, etrafından dolanır.
  double avoidX = 0, avoidY = 0;

  double get speedNow => sqrt(vx * vx + vy * vy);

  /// Gövde yönü — renderer sprite'ı buna göre aynalar.
  bool get facingRight => facingSign >= 0;

  /// Dönüş anında sprite'a uygulanacak yatay ölçek (0.10..1.0). Renderer
  /// `canvas.scale(charScale * turnScaleX, …)` ile kullanır: karakter yatayda
  /// daralıp öbür yöne açılır — anlık aynalama yerine görünür bir dönüş.
  double get turnScaleX =>
      facingSign.abs() < kEdgeOnScale ? kEdgeOnScale : facingSign.abs();

  /// Separation (ya da başka bir kaçınma kaynağı) yön bükmesi ekler.
  void addAvoid(double ax, double ay) {
    avoidX += ax;
    avoidY += ay;
  }

  /// BİR KARE HAREKET. [dirX],[dirY] hedefe birim yön; [maxSpeed] o an
  /// istenen hız (0 = dur). Dönüş: bu karede uygulanacak (dx, dy) yer değişimi.
  (double, double) advance(
      double dt, double dirX, double dirY, double maxSpeed) {
    // Kaçınma, hedef yönüne karışır — ayrı bir itme değil, aynı gidişin bükülmüş hâli.
    var dx = dirX, dy = dirY;
    if (avoidX != 0 || avoidY != 0) {
      dx += avoidX;
      dy += avoidY;
      avoidX = 0;
      avoidY = 0;
      final m = sqrt(dx * dx + dy * dy);
      if (m > 1e-6) {
        dx /= m;
        dy /= m;
      }
    }

    // Hız vektörü KUTUPSAL işlenir: yön ve büyüklük ayrı ayrı.
    //
    // TUZAK: ikisi birden kartezyen üstel yumuşatmaya verilirse dönüş hızı
    // artık [kTurnRate] değil, yumuşatma zaman sabiti olur — komut açısı
    // ilerlese de vektör ona yetişemediği için gerçek dönüş ~6 kat yavaşlar
    // ve NPC U dönüşünü saniyeler süren bir kavise çevirir. Yön DOĞRUDAN
    // döndürülür, üstel yumuşatma yalnız BÜYÜKLÜĞE uygulanır.
    final cur = speedNow;
    double ang;
    if (cur > 1e-4) {
      ang = atan2(vy, vx);
      if (maxSpeed > 1e-4) {
        var diff = atan2(dy, dx) - ang;
        while (diff > pi) {
          diff -= 2 * pi;
        }
        while (diff < -pi) {
          diff += 2 * pi;
        }
        // Yavaş giden çabuk döner (neredeyse yerinde), hızlı giden geniş
        // dönüş yapar. "Ağırlığı olan gövde" hissi buradan gelir.
        final maxTurn = (kTurnRate + kTurnBoost / (1.0 + cur * 2.5)) * dt;
        ang += diff.abs() > maxTurn ? (diff > 0 ? maxTurn : -maxTurn) : diff;
      }
    } else {
      // Duruyorsa yön serbestçe kurulur — yerinde dönmek bedava.
      ang = atan2(dy, dx);
    }

    // ── İvme / fren (yalnız büyüklük) ───────────────────────────────────────
    final tau = maxSpeed < cur ? kBrakeTau : kAccelTau;
    final k = 1 - exp(-dt / tau);
    final sp = cur + (maxSpeed - cur) * k;
    vx = cos(ang) * sp;
    vy = sin(ang) * sp;
    if (vx.abs() < 1e-4) vx = 0;
    if (vy.abs() < 1e-4) vy = 0;

    return (vx * dt, vy * dt);
  }

  /// Hedef yok / hareket engellendi — hız sıfıra frenlenir, yer değişimi
  /// üretilmez (oturma/uyku gibi konumu hassas olan hâllerde sürüklenme olmaz).
  void brake(double dt) {
    final k = 1 - exp(-dt / kBrakeTau);
    vx -= vx * k;
    vy -= vy * k;
    if (vx.abs() < 1e-4) vx = 0;
    if (vy.abs() < 1e-4) vy = 0;
    avoidX = 0;
    avoidY = 0;
  }

  /// Bakış yönünü ilerlet — histerezis + dönüş animasyonu. Her karede çağrılır.
  void faceTick(double dt) {
    if (vx.abs() > kFaceDeadband) {
      final w = vx > 0 ? 1.0 : -1.0;
      if (w != _want) {
        _hold += dt;
        if (_hold >= kFaceHold) {
          _want = w;
          _hold = 0;
        }
      } else {
        _hold = 0;
      }
    } else {
      _hold = 0;
    }
    final d = _want - facingSign;
    if (d != 0) {
      final step = kFlipRate * dt;
      facingSign = d.abs() <= step ? _want : facingSign + (d > 0 ? step : -step);
    }
  }

  /// Bakış yönünü DIŞARIDAN kur (ateşe dönme, oturma, uyanma…). Kararı anında
  /// değiştirir ama görsel dönüş yine [faceTick] ile yumuşak akar.
  void faceTo(bool right) {
    _want = right ? 1.0 : -1.0;
    _hold = 0;
  }

  /// Bakış yönünü animasyonsuz kur — spawn / kayıttan yükleme gibi "zaten öyle
  /// duruyordu" anları için.
  void snapFacing(bool right) {
    _want = right ? 1.0 : -1.0;
    facingSign = _want;
    _hold = 0;
  }

  /// Hareketi tamamen sıfırla (ışınlanma, sahne kurulumu).
  void reset() {
    vx = 0;
    vy = 0;
    avoidX = 0;
    avoidY = 0;
    _hold = 0;
  }
}
