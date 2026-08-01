import 'estate_system.dart' show EstateMoodTier;

/// Köyün HANELERİ (soyları) — yönetişimin yeni politik birimi. Eski 4 sabit
/// zümrenin (soyut sınıf) yerini alır: artık politika, DOĞUMUNU İZLEDİĞİN
/// tanıdık kan bağları etrafında döner. "Her soy bir hane" — her köylü
/// [VillagerEntity.surname] ile tek bir haneye aittir; hane büyüdükçe (doğum)
/// güçlenir, soy tükenince (üye kalmayınca) nüfuzuyla birlikte söner.
///
/// Bir hanenin HÂLİ (mood) = onların insanlarına nasıl davrandığın: üyelerinin
/// morali + onları ilgilendiren kararlar (dilekçe/kan davası/evlilik) mood'u
/// besler. NÜFUZ (sway) yavaş birikip yavaş erir → köy zamanla bir hanenin
/// gölgesine kayabilir ([ascendant]).
///
/// SABİT zümre enum'u yerine DİNAMİK bir soyad haritasıdır (haneler oyun boyunca
/// doğar/ölür). Zümre→Hane geçişi TAMAMLANDI: eski EstateSystem motoru kaldırıldı,
/// tüm politik durum artık burada döner (dilekçe/ferman/UI/moral hepsi bunu okur).
class HouseState {
  /// Memnuniyet/sadakat 0..1. Boşlukta üye moraline (yoksa tabana) süzülür.
  double mood;

  /// Ham nüfuz puanı — kararlar biriktirir, çok yavaş erir. Köy içi PAY
  /// [HouseSystem.swayShare] ile hesaplanır.
  double sway;

  /// Canlı üye sayısı — sahne her tick günceller (salience + budama için).
  int members = 0;

  /// Üyelerin ortalama bireysel morali (sahne besler). null = canlı üye yok.
  double? memberMorale;

  HouseState({this.mood = 0.55, this.sway = 1.0});
}

/// Panel/diegetik için tek hanenin salt-okunur özeti.
class HouseSnapshot {
  final String surname;
  final String label; // "Demirhan Hanesi"
  final double mood; // 0..1
  final double swayShare; // 0..1 köy içi pay
  final bool ascendant; // köyün gölgesine kaydığı hane mi
  final int members;
  final EstateMoodTier tier;
  const HouseSnapshot({
    required this.surname,
    required this.label,
    required this.mood,
    required this.swayShare,
    required this.ascendant,
    required this.members,
    required this.tier,
  });
}

/// Köyün hanelerinin durumunu tutar + dengeyi yürütür. Sahne
/// (`scene_estates`) tick'ler ve üye moralini besler; dilekçe/ferman `nudge`
/// ile oynatır; HANELER paneli `snapshot()` ile gösterir.
class HouseSystem {
  static const double _moodBaseline = 0.55;
  static const double _moodTauDays = 3.0;
  static const double _swayTauDays = 26.0;
  static const double _swayFloor = 1.0;

  /// Bir hanenin "köyün gölgesine kaydığı hane" sayılması için nüfuz payı eşiği.
  /// Zümreden (0.34) biraz yüksek — çok hane olabilir, baskınlık daha anlamlı.
  static const double _ascendantShare = 0.40;

  final Map<String, HouseState> _states = {};

  Iterable<String> get surnames => _states.keys;
  int get houseCount => _states.length;

  HouseState _ensure(String surname) =>
      _states.putIfAbsent(surname, () => HouseState());

  /// Sahne her tick besler: `counts` = soyad→canlı üye sayısı, `moraleSum` =
  /// soyad→üye moral toplamı. Yeni hane eklenir; bu turda görünmeyen hane
  /// üyesiz işaretlenir; tükenmiş + nüfuzsuz hane haritadan budanır.
  void rebuild(Map<String, int> counts, Map<String, double> moraleSum) {
    for (final e in counts.entries) {
      final h = _ensure(e.key);
      h.members = e.value;
      h.memberMorale = e.value > 0 ? (moraleSum[e.key] ?? 0) / e.value : null;
    }
    final gone = <String>[];
    for (final entry in _states.entries) {
      if (!counts.containsKey(entry.key)) {
        final h = entry.value;
        h.members = 0;
        h.memberMorale = null;
        // Soy tükendi + nüfuz da tabana indi → hane tamamen silinir.
        if (h.sway <= _swayFloor + 0.02) gone.add(entry.key);
      }
    }
    for (final k in gone) {
      _states.remove(k);
    }
  }

  double moodOf(String surname) => _states[surname]?.mood ?? _moodBaseline;

  double _swayTotal() {
    var t = 0.0;
    for (final h in _states.values) {
      t += h.sway;
    }
    return t;
  }

  /// Köy içi nüfuz payı (0..1).
  double swayShare(String surname) {
    final total = _swayTotal();
    if (total <= 0) return _states.isEmpty ? 0 : 1.0 / _states.length;
    return (_states[surname]?.sway ?? 0) / total;
  }

  /// Köyün gölgesine kaydığı hane — payı eşiği geçen en yüksek. Yoksa null.
  String? get ascendant {
    final total = _swayTotal();
    if (total <= 0) return null;
    String? best;
    var bestShare = _ascendantShare;
    for (final e in _states.entries) {
      final sh = e.value.sway / total;
      if (sh >= bestShare) {
        bestShare = sh;
        best = e.key;
      }
    }
    return best;
  }

  /// Köyün şu anki kimliği — baskın hane yoksa "Dengeli Köy", varsa hane adı.
  String get identityName {
    final a = ascendant;
    return a == null ? 'Dengeli Köy' : '$a Hanesi';
  }

  String? _prevAscendant;

  /// Baskın hane değişti mi — değiştiyse (changed:true, current: yeni ya da
  /// null) döner ve yeni durumu kaydeder. Kimlik kaymasını tetiklemek için
  /// bir kez çağrılır. Kaydedilmez (yüklemede bir kez yeniden tespit edebilir).
  ({bool changed, String? current}) pollAscendantChange() {
    final cur = ascendant;
    final changed = cur != _prevAscendant;
    _prevAscendant = cur;
    return (changed: changed, current: cur);
  }

  EstateMoodTier tierOf(String surname) {
    final m = moodOf(surname);
    if (m >= 0.70) return EstateMoodTier.content;
    if (m >= 0.50) return EstateMoodTier.neutral;
    if (m >= 0.32) return EstateMoodTier.uneasy;
    return EstateMoodTier.sullen;
  }

  /// En küskün (canlı üyeli) hane — diegetik postür için. Hepsi iyiyse null.
  String? get mostAggrieved {
    String? worst;
    var worstMood = 0.50;
    for (final e in _states.entries) {
      if (e.value.members <= 0) continue; // üyesiz hane somurtamaz
      if (e.value.mood < worstMood) {
        worstMood = e.value.mood;
        worst = e.key;
      }
    }
    return worst;
  }

  /// Bir kararın hane üstündeki etkisi. [moodDelta] memnuniyet (±, clamp),
  /// [swayGain] kalıcı nüfuz (≥0). Hane yoksa oluşturulur (yazar hanesi).
  void nudge(String surname, {double moodDelta = 0, double swayGain = 0}) {
    if (surname.isEmpty) return;
    final h = _ensure(surname);
    if (moodDelta != 0) {
      h.mood = (h.mood + moodDelta).clamp(0.0, 1.0);
    }
    if (swayGain > 0) {
      h.sway += swayGain;
    }
  }

  /// Nüfuz KIRMA — [nudge] yalnız nüfuz biriktirir (kararların ödülü); oyuncu
  /// eylemleri (ceza/el koyma/sürgün/entrika) nüfuzu kırabilmeli. Taban
  /// ([_swayFloor]) altına inmez: hane söner ama yok sayılmaz.
  void drainSway(String surname, double amount) {
    final h = _states[surname];
    if (h == null || amount <= 0) return;
    h.sway = (h.sway - amount).clamp(_swayFloor, double.infinity);
  }

  /// Zaman geçişi — hane moralleri üye moraline (yoksa tabana) süzülür; nüfuz
  /// tabana çok yavaş erir (üstel süzülme, sway sönmez).
  void tick(double dt, double gameDaySeconds) {
    if (dt <= 0 || gameDaySeconds <= 0) return;
    final k = (dt / (_moodTauDays * gameDaySeconds)).clamp(0.0, 1.0);
    final sk = (dt / (_swayTauDays * gameDaySeconds)).clamp(0.0, 1.0);
    for (final h in _states.values) {
      final mm = h.memberMorale;
      final baseline =
          mm == null ? _moodBaseline : _moodBaseline * 0.35 + mm * 0.65;
      h.mood += (baseline - h.mood) * k;
      if (h.sway > _swayFloor) {
        h.sway += (_swayFloor - h.sway) * sk;
      }
    }
  }

  /// Panel için salience'a göre sıralı özet (en politik önemli önce): küskünlük
  /// + nüfuz + üye sayısı + baskınlık. Öne çıkan haneler başa gelir.
  List<HouseSnapshot> snapshot() {
    final asc = ascendant;
    final total = _swayTotal();
    final list = [
      for (final e in _states.entries)
        HouseSnapshot(
          surname: e.key,
          label: '${e.key} Hanesi',
          mood: e.value.mood,
          swayShare: total <= 0 ? 0 : e.value.sway / total,
          ascendant: e.key == asc,
          members: e.value.members,
          tier: tierOf(e.key),
        ),
    ];
    double score(HouseSnapshot h) =>
        (0.5 - h.mood).abs() * 2.0 +
        h.swayShare * 3.0 +
        h.members * 0.15 +
        (h.ascendant ? 1.0 : 0.0);
    list.sort((a, b) => score(b).compareTo(score(a)));
    return list;
  }

  /// Kayıt: anlamlı her hanenin mood+sway'i. Üye sayısı/morali türetilir.
  Map<String, dynamic> toJson() => {
        for (final e in _states.entries)
          if (e.value.sway > _swayFloor + 0.001 ||
              (e.value.mood - _moodBaseline).abs() > 0.001 ||
              e.value.members > 0)
            e.key: {'mood': e.value.mood, 'sway': e.value.sway},
      };

  /// Yükleme: kaydedilmiş mood+sway'i geri yaz (haneler soyaddan yeniden doğar).
  void loadJson(Map<String, dynamic> json) {
    for (final e in json.entries) {
      if (e.value is Map) {
        final h = _ensure(e.key);
        final m = e.value as Map;
        h.mood = (m['mood'] as num?)?.toDouble() ?? h.mood;
        h.sway = (m['sway'] as num?)?.toDouble() ?? h.sway;
      }
    }
  }
}
