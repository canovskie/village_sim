import 'estate_system.dart';

/// POLİTİK PUSULA — Kanunname'nin kimliğe dönüşen yüzü.
///
/// Kanunname'nin başında yazan söz şudur: "Köyün kimliği bir çatal seçiminden
/// değil, HANGİ yasaları çıkardığından doğar." Bu modül o sözü gerçek bir
/// mekaniğe çevirir: her mühür bir VEKTÖR'dür, mühürlerin toplamı köyün politik
/// KONUMU'dur, konum da REJİM'dir.
///
/// Kimlik SEÇİLMEZ, mühürlerle KAZANILIR — organik, evre yok. Oyuncu "tiranım"
/// demeden köy tiranlaşmaya başlar (sinsi kayma); istediğinde bunu bir yeminle
/// ilan eder (opt-in radikal commitment). Bu dosya yalnız KONUMU ve REJİMİ
/// hesaplar; yeminin/gating'in/UI'ın omurgası buradan okur.
///
/// İki eksen + bir overlay:
///   • OTORİTE  : Hür (−)      ↔  Baskı (+)   — dilekçe/meclis açık mı, tek söz mü?
///   • İKTİSAT  : Ortakçı (−)  ↔  Mülkçü (+)  — paylaşım mı, mülk/pazar mı?
///   • İMAN     : Dünyevi (0)  →  Dinî (+)    — rejimin üstüne binen boya (overlay,
///                                              ayrı sert eksen DEĞİL).

/// Bir yasanın pusuladaki itiş kuvveti. Değerler kabaca −5..+5 bandında; büyük
/// olanlar (nizam.sole, dergah.oneFaith) tek başına köyü bir kutba yaklaştırır.
class LawVector {
  /// − Hür … + Baskı
  final double authority;

  /// − Ortakçı … + Mülkçü
  final double economy;

  /// 0 Dünyevi … + Dinî (yalnız pozitif — iman bir overlay).
  final double faith;

  const LawVector({this.authority = 0, this.economy = 0, this.faith = 0});
}

/// YASA → VEKTÖR HARİTASI. Her mühürün köyü nereye ittiği. Haritada olmayan
/// yasa nötr (pusulayı oynatmaz) sayılır — yeni yasa eklerken buraya bir satır.
///
/// TASARIM NOTU (ilk taslak, denge kullanıcı onayına açık):
///   • GEÇİM çoğunlukla Ortakçı'ya hafif iter (köy imecesi doğal hâli); birkaçı
///     mülk/pazar (hospitality, apprenticeship) ya da otorite (oneChild,
///     slowMaturity, tradeGuidance) tarafına.
///   • NİZAM kolu saf Baskı; registry ayrıca Mülkçü (mülk sayımı+vergi).
///   • DERGÂH kolu ağır Dinî + değişken otorite; oneFaith en uç dinî-baskı.
const Map<String, LawVector> kLawVectors = {
  // ── GEÇİM ──────────────────────────────────────────────────────────────────
  'neighborliness': LawVector(economy: -1), // komşuluk = imece bağı
  'winterFodder': LawVector(economy: -1), // ortak ihtiyat
  'sharedHarvest': LawVector(economy: -3), // müşterek harman = kolektifleştirme
  'irrigation': LawVector(economy: -1), // ortak emek seferi
  'farmLabor': LawVector(authority: 1, economy: -2), // seferberlik + zorlama
  'hospitality': LawVector(authority: -1, economy: 1), // açık kapı = özgür + pazar/emek
  'familyReunion': LawVector(economy: -1), // ocak dayanışması
  'herdGrowth': LawVector(economy: -1), // ortak sürü büyütme
  'cropRotation': LawVector(economy: -1), // ortak toprak gözetimi
  'apprenticeship': LawVector(authority: 1, economy: 2), // zanaat mülkü + soy zorlaması
  'oneChild': LawVector(authority: 2, economy: -1), // beşiğe devlet eli (sert)
  'twoChild': LawVector(authority: 1), // beşiğe devlet eli (yumuşak)
  'familyEncouragement': LawVector(economy: -1), // ortak beşik teşviki
  'tradeGuidance': LawVector(authority: 1, economy: -1), // merkezî emek dağıtımı
  'freeRange': LawVector(authority: -1, economy: 1), // bırakınız otlasınlar
  'treePlanting': LawVector(authority: 1, economy: -1, faith: 1), // regülasyon+commons+saygı
  'peacefulEnd': LawVector(economy: -1, faith: 1), // tören onuru
  'slowMaturity': LawVector(authority: 1), // paternalist çocukluk
  'eldersExemptFromFood': LawVector(economy: -2), // yeniden dağıtım (yaşlıya)
  'greenVillage': LawVector(economy: -1, faith: 1), // ortak güzellik + hafif ruh

  // ── NİZAM (⚔ saf Baskı) ─────────────────────────────────────────────────────
  'nizam.watch': LawVector(authority: 2), // gece nöbeti = düzen
  'nizam.registry': LawVector(authority: 2, economy: 2), // sicil = sayım + mülk vergisi
  'nizam.labor': LawVector(authority: 3, economy: 1), // kürek cezası = zor + emek sömürüsü
  'nizam.exile': LawVector(authority: 3), // sürgün
  'nizam.sole': LawVector(authority: 5), // tek söz = mutlak otorite (dilekçe susar)

  // ── DERGÂH (☾ ağır Dinî) ────────────────────────────────────────────────────
  'dergah.holyDay': LawVector(authority: 1, economy: -1, faith: 3), // dayatılan istirahat
  'dergah.lodge': LawVector(economy: -1, faith: 3), // dergâh = commons/sığınak
  'dergah.tithe': LawVector(authority: 1, economy: -2, faith: 3), // öşür = yeniden dağıtım
  'dergah.penance': LawVector(authority: 2, faith: 3), // aleni tövbe = sosyal denetim
  'dergah.oneFaith': LawVector(authority: 4, faith: 5), // tek inanç = dinî mutlakiyet
};

/// Köyün pusuladaki KONUMU — mühür setinin özeti. Eksenler ölçekli ([-1,1]),
/// iman [0,1]. `lawCount` "teşekkül etti mi" (Merkez'den çıktı mı) için ipucu.
class CompassPosition {
  /// − Hür … + Baskı, [-1, 1].
  final double authority;

  /// − Ortakçı … + Mülkçü, [-1, 1].
  final double economy;

  /// 0 Dünyevi … 1 Dinî.
  final double faith;

  /// Mühürlü yasa sayısı (kimliğin ne kadar "yazıldığı").
  final int lawCount;

  const CompassPosition({
    required this.authority,
    required this.economy,
    required this.faith,
    required this.lawCount,
  });

  /// Merkezden ne kadar uzakta (eksen büyüklüğü) — ton (eğilim/köklü) buradan.
  double get intensity =>
      authority.abs() > economy.abs() ? authority.abs() : economy.abs();
}

/// Dört rejim + teşekkül etmemiş merkez. İman overlay olduğu için ayrı enum
/// değil — [RegimeIdentity.religious] ile taşınır.
enum VillageRegime {
  moderate, //  Ilımlı Köy (henüz bir şey olmadı)
  commune, //   🤝 Hür + Ortakçı
  market, //    🏪 Hür + Mülkçü
  ironTable, // ⚖ Baskı + Ortakçı
  sealedHand, //👑 Baskı + Mülkçü
}

/// Rejimin ne olduğunun okunur karşılığı — UI kartı ve olay sistemi buradan
/// besler. İsim, iman boyasına göre değişir (Mühürlü El → dinî → Şeyh Beyliği).
class RegimeIdentity {
  final VillageRegime regime;
  final String icon;
  final String title;

  /// Tek cümle his — köyün ne tür bir yer olduğu.
  final String tagline;

  /// OYUNCUYU nasıl bağladığı — sistemin kalbi. Tiran mutlak, demokrat kısıtlı.
  final String agencyNote;

  /// Rejimin dayandığı zümre (tabanı) ve ezdiği zümre (muhalefeti). null = yok.
  final Estate? base;
  final Estate? dissent;

  /// İman boyası bindi mi (dinî kimlik).
  final bool religious;

  /// Köklü mü (ilan/yemin eşiğine yakın) yoksa yalnız eğilimli mi?
  final bool committed;

  const RegimeIdentity({
    required this.regime,
    required this.icon,
    required this.title,
    required this.tagline,
    required this.agencyNote,
    required this.base,
    required this.dissent,
    required this.religious,
    required this.committed,
  });
}

/// Pusula sorguları — konum hesabı ve rejim çözümü tek yerde (UI + sahne aynı
/// kurallardan okusun). Ölçek sabitleri tasarım kararıdır; denge için burada.
abstract final class LawCompass {
  /// Eksen ölçeği — ham vektör toplamı bu sayıya bölünüp [-1,1]'e sıkışır.
  /// 8 → tek uç yasa (sole=5) köyü ~0.63'e taşır (belirgin ama maksed değil);
  /// köşeye ancak birkaç hizalı yasa (sole+registry+exile) ulaştırır.
  static const double kAxisScale = 8.0;

  /// İman ölçeği — dergâh yasaları faith 3, oneFaith 5. 7 → iki dergâh yasası
  /// köyü dinî kimliğe taşır.
  static const double kFaithScale = 7.0;

  /// Ölü bant — bir eksende |konum| bunun altındaysa o eksen "belirsiz".
  /// İki eksen de belirsiz + iman zayıfsa köy henüz MERKEZ (ılımlı, cezasız).
  static const double kBand = 0.30;

  /// İman bu eşiği geçince rejime dinî boya biner.
  static const double kFaithBand = 0.45;

  /// Köklü/eğilimli sınırı — bu yoğunluğun üstü "belirgin", altı "eğilimli".
  static const double kConvictionBand = 0.60;

  /// Mühür setinden köyün konumunu hesapla. Toplam-ve-sıkıştır: aynı yöne
  /// biriken mühürler köyü kutba SÜRÜKLER (ortalama değil — sinsi kayma budur).
  static CompassPosition positionOf(Set<String> sealed) {
    double a = 0, e = 0, f = 0;
    for (final id in sealed) {
      final v = kLawVectors[id];
      if (v == null) continue;
      a += v.authority;
      e += v.economy;
      f += v.faith;
    }
    return CompassPosition(
      authority: (a / kAxisScale).clamp(-1.0, 1.0),
      economy: (e / kAxisScale).clamp(-1.0, 1.0),
      faith: (f / kFaithScale).clamp(0.0, 1.0),
      lawCount: sealed.length,
    );
  }

  /// Bir yasa daha mühürlense konum NE olurdu — UI "sonraki mühür seni ...'e
  /// iter" ipucu ve önizleme için.
  static CompassPosition preview(Set<String> sealed, String addId) =>
      positionOf({...sealed, addId});

  /// Bir fermanın ibreyi HANGİ YÖNE ittiği, insan diliyle. Nötr (pusulayı
  /// oynatmayan) ferman için null — oyuncuyu boş bilgiyle meşgul etme.
  ///
  /// Kuvvete göre fiil seçilir: 1 birim "hafifçe", 3+ "sert". Yön kelimeleri
  /// eksen uçlarının adıdır (Hür/Baskı, Ortakçı/Mülkçü) — kadranla aynı dil.
  static String? nudgeOf(String lawId) {
    final v = kLawVectors[lawId];
    if (v == null) return null;

    final parts = <String>[];
    if (v.authority.abs() >= 1) {
      parts.add(v.authority > 0 ? 'BASKI' : 'HÜR');
    }
    if (v.economy.abs() >= 1) {
      parts.add(v.economy > 0 ? 'MÜLKÇÜ' : 'ORTAKÇI');
    }
    if (v.faith >= 1) parts.add('DİNÎ');
    if (parts.isEmpty) return null;

    final force = [v.authority.abs(), v.economy.abs(), v.faith]
        .reduce((a, b) => a > b ? a : b);
    final verb = force >= 3
        ? 'sert biçimde iter'
        : force >= 2
            ? 'iter'
            : 'hafifçe iter';
    final dirs = parts.length == 1
        ? '${parts.first} tarafa'
        : '${parts.sublist(0, parts.length - 1).join(', ')} ve ${parts.last} tarafa';
    return 'Bu ferman köyü $dirs $verb.';
  }

  /// Bu mühür köyün KİMLİĞİNİ değiştirir mi? Değiştiriyorsa (eski ad, yeni ad);
  /// aynı kalıyorsa null. Ritüelin "geri dönüşü olmayan an" uyarısı buradan.
  static (String, String)? regimeShift(Set<String> sealed, String addId) {
    final before = identify(positionOf(sealed));
    final after = identify(preview(sealed, addId));
    if (before.title == after.title) return null;
    return (before.title, after.title);
  }

  /// Konumdan rejim kimliği. Ölü bant mantığı: otorite yalnız BİLE İSTEYE
  /// (band'ı geçince) Baskı olur — köy kazara tiranlaşmaz; iktisat band altında
  /// köyün doğal hâli Ortakçı (imece) sayılır.
  static RegimeIdentity identify(CompassPosition p) {
    final religious = p.faith >= kFaithBand;

    // MERKEZ — iki eksen de belirsiz ve iman zayıf: köy henüz teşekkül etmedi.
    if (p.authority.abs() < kBand &&
        p.economy.abs() < kBand &&
        !religious) {
      return const RegimeIdentity(
        regime: VillageRegime.moderate,
        icon: '⚖',
        title: 'Ilımlı Köy',
        tagline: 'Henüz bir yöne yatmadı; kimliği açık, defteri ince.',
        agencyNote: 'Sözün geçer, kimse çok memnun ya da çok küs değil. '
            'Uçların gücüne de erişemezsin.',
        base: null,
        dissent: null,
        religious: false,
        committed: false,
      );
    }

    // Kutuplar — otorite band'ı geçmediyse Hür varsayılır; iktisat band'ı
    // pozitif geçmediyse Ortakçı (imece) varsayılır.
    final baski = p.authority >= kBand;
    final mulk = p.economy >= kBand;
    final committed = p.intensity >= kConvictionBand;

    final VillageRegime regime;
    if (baski) {
      regime = mulk ? VillageRegime.sealedHand : VillageRegime.ironTable;
    } else {
      regime = mulk ? VillageRegime.market : VillageRegime.commune;
    }
    return _describe(regime, religious: religious, committed: committed);
  }

  /// Rejim + boya → okunur kimlik. İsimler dinî overlay'de değişir.
  static RegimeIdentity _describe(
    VillageRegime regime, {
    required bool religious,
    required bool committed,
  }) {
    switch (regime) {
      case VillageRegime.commune:
        return RegimeIdentity(
          regime: regime,
          icon: '🤝',
          title: religious ? 'Tarikat-Köyü' : 'Ortak Ocak',
          tagline: religious
              ? 'Herkes aynı sofrada, aynı kandilin altında; mülk de gönül de ortak.'
              : 'Kimse aç kalmaz, kimse öne geçmez; söz meydanda toplanır.',
          agencyNote: 'Meclis gerçek oy verir — bir dilekçe sen istemesen de '
              'geçebilir. Yavaşsın ama meşrusun.',
          base: Estate.laborers,
          dissent: Estate.artisans,
          religious: religious,
          committed: committed,
        );
      case VillageRegime.market:
        return RegimeIdentity(
          regime: regime,
          icon: '🏪',
          title: religious ? 'Vakıf Kasabası' : 'Açık Pazar',
          tagline: religious
              ? 'Kervan da hayrat da akar; kese açık, kapı açık, dergâh vakıflı.'
              : 'Kapı yabancıya, yol tüccara açık; herkes kendi kısmetinin peşinde.',
          agencyNote: 'Az müdahale edersin; refah akar ama para konuşur, '
              'zengin-fakir arası açılır.',
          base: Estate.artisans,
          dissent: Estate.hearth,
          religious: religious,
          committed: committed,
        );
      case VillageRegime.ironTable:
        return RegimeIdentity(
          regime: regime,
          icon: '⚖',
          title: religious ? 'Dergâh Düzeni' : 'Demir Sofra',
          tagline: religious
              ? 'Cemaat tek beden: herkes eşit pay alır, eşit baş eğer.'
              : 'Herkes eşit — ama eşitliği dağıtan el senin, ve o el sıkıdır.',
          agencyNote: 'Yüksek yetkin var, "eşitlik adına" kullanırsın. Zorla '
              'paylaşımın bedeli sinsi bir tembellik, düşen verim.',
          base: Estate.laborers,
          dissent: Estate.hearth,
          religious: religious,
          committed: committed,
        );
      case VillageRegime.sealedHand:
        return RegimeIdentity(
          regime: regime,
          icon: '👑',
          title: religious ? 'Şeyh Beyliği' : 'Mühürlü El',
          tagline: religious
              ? 'Tek inanç, tek söz, tek el: köy şeyhin avucunda döner.'
              : 'Dilekçe susar, sicil tutulur, kılıç keskindir; son söz senin.',
          agencyNote: 'Mutlak yetki senin — ama korku moral yer, altta isyan '
              'kaynar, favorilerin bile güvende değil.',
          base: Estate.artisans,
          dissent: Estate.hearth,
          religious: religious,
          committed: committed,
        );
      case VillageRegime.moderate:
        // Merkez identify()'da erken döner; burası ulaşılmaz ama tip için.
        return const RegimeIdentity(
          regime: VillageRegime.moderate,
          icon: '⚖',
          title: 'Ilımlı Köy',
          tagline: 'Henüz bir yöne yatmadı.',
          agencyNote: 'Sözün geçer.',
          base: null,
          dissent: null,
          religious: false,
          committed: false,
        );
    }
  }
}
