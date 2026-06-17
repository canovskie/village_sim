import '../characters/villager_type.dart';
import '../characters/life_stage.dart';

/// Köyün zümreleri (hizipleri) — yönetişimin kalbi. Oyuncu "politik dengeci":
/// her kararı zümrelerin MORALİNİ (memnun↔küskün) ve NÜFUZUNU (köy ona ne kadar
/// kaydı) oynatır. Kimseyi tam memnun edemezsin — birini sevindirmek çoğu kez
/// diğerini gücendirir. Kaybetmek yok (cozy): küskün zümre köyde GÖRÜNÜR olur
/// (somurtan köylüler, sönük etkinlik), oyunu bitirmez.
///
/// Nüfuz zamanla birikir ve sönmez → köy yavaşça bir KİMLİĞE kayar (bkz.
/// [EstateSystem.ascendant]). Tek "doğru" yok; kimlik kazanmak ödüldür.
enum Estate {
  /// 🌾 Çiftçi + oduncu + madenci + balıkçı — toprağın ve emeğin sesi.
  laborers('Emekçiler', '🌾', 'Bereketli Köy'),

  /// 🔨 Tüccar + demirci — pazarın, zanaatın, keseyi dolduranların sesi.
  artisans('Zanaatkârlar', '🔨', 'Zanaat Kasabası'),

  /// 🕯️ Büyücü + inananlar (cult/kilise) — inancın, ayinin, mananın sesi.
  faithful('İnananlar', '🕯️', 'Kutsal Köy'),

  /// 🏡 Yaşlılar + aileler + ocağı bekleyenler — gelenek ve yuva sesi.
  hearth('Ocak', '🏡', 'Köklü Yuva');

  final String label;
  final String icon;

  /// Bu zümre baskın olursa köyün kayacağı kimlik adı.
  final String identity;
  const Estate(this.label, this.icon, this.identity);
}

/// Bir köylünün hangi zümreye ait olduğunu mesleğe + yaşam evresine göre verir.
/// Diegetik geri bildirimde (küskün zümre postürü) ve sözcü seçiminde kullanılır.
/// Yaşlı her meslekten olsa da önce OCAK'ın sesidir (gelenek/yuva).
Estate estateOfVillager(VillagerType type, LifeStage stage) {
  if (stage == LifeStage.elder) return Estate.hearth;
  switch (type) {
    case VillagerType.farmer:
    case VillagerType.miner:
    case VillagerType.fisher:
      return Estate.laborers;
    case VillagerType.merchant:
    case VillagerType.blacksmith:
      return Estate.artisans;
    case VillagerType.mage:
      return Estate.faithful;
    case VillagerType.guard:
      return Estate.hearth; // yuvanın bekçisi
  }
}

/// Bir zümrenin morali hangi kademede — yüz ikonu + diegetik tepki bunun üstünden.
enum EstateMoodTier {
  content('😊'),  // memnun
  neutral('😐'),  // kayıtsız
  uneasy('😟'),   // tedirgin
  sullen('😠');   // küskün

  final String face;
  const EstateMoodTier(this.face);
}

/// Tek bir zümrenin anlık durumu — mood (0..1) + ham nüfuz puanı (sway).
class EstateState {
  /// Memnuniyet 0..1. Tabana ([EstateSystem._moodBaseline]) doğru yavaş süzülür.
  double mood;

  /// Ham nüfuz puanı — kararlar biriktirir, sönmez. Normalize edilmemiş;
  /// köy içi PAY [EstateSystem.swayShare] ile hesaplanır.
  double sway;

  EstateState({this.mood = 0.55, this.sway = 1.0});
}

/// Panel/diegetik için tek zümrenin salt-okunur özeti.
class EstateSnapshot {
  final Estate estate;
  final double mood;       // 0..1
  final double swayShare;  // 0..1 (köy içi pay)
  final bool ascendant;    // köyün baskın/önde zümresi mi
  final EstateMoodTier tier;
  const EstateSnapshot({
    required this.estate,
    required this.mood,
    required this.swayShare,
    required this.ascendant,
    required this.tier,
  });
}

/// Köyün dört zümresinin durumunu tutar + dengeyi yürütür.
/// Sahne (`scene_estates`) tick'ler, dilekçeler `nudge` ile oynatır, belediye
/// paneli `snapshot()` ile gösterir.
class EstateSystem {
  /// Moralin tabanı — boşlukta her zümre buraya doğru süzülür (ne mutlu ne küs).
  static const double _moodBaseline = 0.55;

  /// Moral tabanına dönüş zaman sabiti (oyun günü cinsinden). Büyük = yavaş
  /// unutuş → kararlar günlerce hissedilir ama sonsuza kalmaz.
  static const double _moodTauDays = 3.0;

  /// Bir zümrenin "açıkça önde" sayılması için gereken nüfuz payı eşiği.
  static const double _ascendantShare = 0.34;

  final Map<Estate, EstateState> _states = {
    for (final e in Estate.values) e: EstateState(),
  };

  EstateState _s(Estate e) => _states[e]!;

  double moodOf(Estate e) => _s(e).mood;

  /// Köy içi nüfuz payı (0..1) — tüm sway'lerin toplamına normalize.
  double swayShare(Estate e) {
    final total = Estate.values.fold<double>(0, (s, x) => s + _s(x).sway);
    if (total <= 0) return 1.0 / Estate.values.length;
    return _s(e).sway / total;
  }

  /// Köyün baskın zümresi — payı [_ascendantShare]'i geçen en yüksek. Hiçbiri
  /// yeterince önde değilse null (köy henüz bir kimliğe kaymamış: "dengeli").
  Estate? get ascendant {
    Estate? best;
    double bestShare = _ascendantShare;
    for (final e in Estate.values) {
      final sh = swayShare(e);
      if (sh >= bestShare) {
        bestShare = sh;
        best = e;
      }
    }
    return best;
  }

  /// Köyün şu anki kimlik adı — baskın zümre yoksa "Dengeli Köy".
  String get identityName => ascendant?.identity ?? 'Dengeli Köy';

  EstateMoodTier tierOf(Estate e) {
    final m = _s(e).mood;
    if (m >= 0.70) return EstateMoodTier.content;
    if (m >= 0.50) return EstateMoodTier.neutral;
    if (m >= 0.32) return EstateMoodTier.uneasy;
    return EstateMoodTier.sullen;
  }

  /// En küskün zümre (diegetik postür için) — morali tedirgin eşiğin altındaysa.
  /// Hepsi iyiyse null.
  Estate? get mostAggrieved {
    Estate? worst;
    double worstMood = 0.50; // sadece neutral altı "küskün" sayılır
    for (final e in Estate.values) {
      final m = _s(e).mood;
      if (m < worstMood) {
        worstMood = m;
        worst = e;
      }
    }
    return worst;
  }

  /// Bir kararın zümre üstündeki etkisi. [moodDelta] memnuniyeti oynatır
  /// (±, clamp 0..1). [swayGain] o zümrenin köydeki nüfuzunu kalıcı artırır
  /// (≥0; köy o yöne kayar). Dilekçe/ferman çözümünde çağrılır.
  void nudge(Estate e, {double moodDelta = 0, double swayGain = 0}) {
    final s = _s(e);
    if (moodDelta != 0) {
      s.mood = (s.mood + moodDelta).clamp(0.0, 1.0);
    }
    if (swayGain > 0) {
      s.sway += swayGain;
    }
  }

  /// Zaman geçişi — tüm zümre moralleri tabana doğru üstel süzülür (sway sönmez).
  /// [dt] sim saniyesi, [gameDaySeconds] bir oyun gününün saniye uzunluğu.
  void tick(double dt, double gameDaySeconds) {
    if (dt <= 0 || gameDaySeconds <= 0) return;
    final tau = _moodTauDays * gameDaySeconds;
    final k = (dt / tau).clamp(0.0, 1.0);
    for (final e in Estate.values) {
      final s = _s(e);
      s.mood += (_moodBaseline - s.mood) * k;
    }
  }

  /// Panel/diegetik için salt-okunur özet — sabit zümre sırasında.
  List<EstateSnapshot> snapshot() {
    final asc = ascendant;
    return [
      for (final e in Estate.values)
        EstateSnapshot(
          estate: e,
          mood: _s(e).mood,
          swayShare: swayShare(e),
          ascendant: e == asc,
          tier: tierOf(e),
        ),
    ];
  }
}
