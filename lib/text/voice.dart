import 'dart:math';

import '../world/season.dart';

/// Köyün SESİ — oyuncunun okuduğu her cümle buradan geçer.
///
/// İki iş yapar:
///  1. **Varyasyon**: her metin bir HAVUZDUR (birkaç farklı yazım). Seed'e göre
///     biri seçilir — aynı olay ikinci kez geldiğinde başka kelimelerle okunur.
///     Sabit tek metin = ezber = "makine yazmış" hissi; havuz onu kırar.
///  2. **Dokuma**: metne köyün o anki gerçekleri işlenir — konuşanın adı,
///     mesleği, hanesi, mevsim, gün. Şablon yer tutucularla yazılır: `{ad}`,
///     `{ad-in}`, `{meslek}`, `{hane}`, `{mevsim}`, `{gün}`.
///
/// Yer tutucuya EK istenirse tire ile yazılır ve ek Türkçe ünlü uyumuna göre
/// üretilir: `{ad-in}` → "İlyas'ın" / "Ayşe'nin", `{ad-e}` → "Mehmet'e".
/// Naif `${v.name}'in` yapıştırması yanlış ek üretir; metnin en ucuz göründüğü
/// yer orasıdır — o yüzden ek işi tek elden buradan yürür.

// ── Türkçe ek motoru ────────────────────────────────────────────────────────

/// Ad çekim durumu — özel isme apostroflu eklenir.
enum Suffix {
  /// -ın / -in / -un / -ün  ("İlyas'ın oğlu")
  genitive,
  /// -a / -e               ("Mehmet'e söyledi")
  dative,
  /// -ı / -i / -u / -ü      ("Ayşe'yi gördü")
  accusative,
  /// -da / -de / -ta / -te  ("Zeynep'te kaldı")
  locative,
  /// -dan / -den / …        ("Hasan'dan aldı")
  ablative,
  /// -la / -le             ("Ayşe'yle konuştu")
  instrumental,
}

const _vowels = 'aeıioöuüâîû';
const _backUnrounded = 'aıâ';   // a, ı  → kalın düz
const _backRounded = 'ou';      // o, u  → kalın yuvarlak
const _frontUnrounded = 'eiî';  // e, i  → ince düz
// (ö/ü = ince yuvarlak: aşağıdaki daraltmada 'else' dalına düşer)

/// Sert ünsüzler — locative/ablative eki sertleşir (Zeynep'TE, Mehmet'TEN).
const _hardConsonants = 'pçtkfhsş';

/// Kelimenin son ünlüsü (yoksa null).
String? _lastVowel(String w) {
  for (var i = w.length - 1; i >= 0; i--) {
    final c = w[i].toLowerCase();
    if (_vowels.contains(c)) return c;
  }
  return null;
}

/// Türkçe özel isme [s] durum ekini ünlü uyumuyla ekler (apostroflu).
/// Bilinmeyen/ünlüsüz girdide ismi olduğu gibi döner — asla çökmez.
String withSuffix(String name, Suffix s) {
  if (name.isEmpty) return name;
  final v = _lastVowel(name);
  if (v == null) return name;

  final lastChar = name[name.length - 1].toLowerCase();
  final endsWithVowel = _vowels.contains(lastChar);
  final hard = _hardConsonants.contains(lastChar);

  // Dar ünlü (ı/i/u/ü) — genitive/accusative için.
  final narrow = _backUnrounded.contains(v)
      ? 'ı'
      : _backRounded.contains(v)
          ? 'u'
          : _frontUnrounded.contains(v)
              ? 'i'
              : 'ü';
  // Geniş ünlü (a/e) — dative/locative/ablative/instrumental için.
  final wide =
      (_backUnrounded.contains(v) || _backRounded.contains(v)) ? 'a' : 'e';

  final tail = switch (s) {
    // Ünlüyle biterse araya kaynaştırma ünsüzü girer: Ayşe'NİN, Ayşe'Yİ, Ayşe'YE.
    Suffix.genitive => endsWithVowel ? 'n${narrow}n' : '${narrow}n',
    Suffix.accusative => endsWithVowel ? 'y$narrow' : narrow,
    Suffix.dative => endsWithVowel ? 'y$wide' : wide,
    Suffix.locative => '${hard ? 't' : 'd'}$wide',
    Suffix.ablative => '${hard ? 't' : 'd'}${wide}n',
    Suffix.instrumental => endsWithVowel ? 'yl$wide' : 'l$wide',
  };
  return "$name'$tail";
}

// ── Bağlam ──────────────────────────────────────────────────────────────────

/// Bir cümlenin dokunacağı köy gerçekleri. Alanların hepsi opsiyonel — metin
/// hangi yer tutucuyu kullanıyorsa o dolar; eksik olan yer tutucu sessizce
/// nötr bir karşılığa düşer (asla "null" yazmaz).
class VoiceCtx {
  /// Varyant seçimini belirleyen tohum — aynı tohum aynı cümleyi verir
  /// (kayıt/yükleme sonrası metin değişmesin diye).
  final int seed;

  /// Konuşan / öznesi olan köylü.
  final String? name;
  /// İkinci kişi (eş, rakip, kavga karşıtı, bebek…).
  final String? other;
  /// Konuşanın mesleği ("Demirci", "Çoban"…).
  final String? profession;
  /// Konuşanın hanesi ("Karaoğlan").
  final String? house;
  /// Konuşanın zümresi/topluluk adı ("Emekçiler").
  final String? estate;
  /// Köyün adı.
  final String? village;

  final Season? season;
  final int? day;

  /// Metne özel ek yer tutucular — `{miktar}`, `{bina}` gibi.
  final Map<String, String> extra;

  const VoiceCtx({
    required this.seed,
    this.name,
    this.other,
    this.profession,
    this.house,
    this.estate,
    this.village,
    this.season,
    this.day,
    this.extra = const {},
  });

  VoiceCtx copyWith({int? seed, String? name, String? other}) => VoiceCtx(
        seed: seed ?? this.seed,
        name: name ?? this.name,
        other: other ?? this.other,
        profession: profession,
        house: house,
        estate: estate,
        village: village,
        season: season,
        day: day,
        extra: extra,
      );
}

/// Mevsimin metinde geçen adı.
String seasonWord(Season s) => switch (s) {
      Season.spring => 'ilkbahar',
      Season.summer => 'yaz',
      Season.autumn => 'sonbahar',
      Season.winter => 'kış',
    };

// ── Sesin kendisi ───────────────────────────────────────────────────────────

abstract final class Voice {
  /// Havuzdan seed'e göre bir varyant seçer. Havuz boşsa boş string.
  static String pick(List<String> pool, int seed) {
    if (pool.isEmpty) return '';
    if (pool.length == 1) return pool.first;
    return pool[Random(seed).nextInt(pool.length)];
  }

  /// Havuzdan seç + bağlamı doku. Oyuncunun gördüğü cümle bu.
  static String say(List<String> pool, VoiceCtx c) => weave(pick(pool, c.seed), c);

  /// Yer tutucuları doldurur. `{ad}`, `{ad-in}`, `{öteki-e}`, `{meslek}`,
  /// `{hane}`, `{zümre}`, `{köy}`, `{mevsim}`, `{gün}` + ctx.extra anahtarları.
  static String weave(String s, VoiceCtx c) {
    if (!s.contains('{')) return s;
    return s.replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (m) {
      final token = m[1]!;
      final dash = token.indexOf('-');
      final key = dash < 0 ? token : token.substring(0, dash);
      final suffixTag = dash < 0 ? null : token.substring(dash + 1);

      final base = _valueOf(key, c);
      if (base == null || base.isEmpty) return _fallbackFor(key);
      if (suffixTag == null) return base;

      final s = switch (suffixTag) {
        'in' => Suffix.genitive,
        'e' => Suffix.dative,
        'i' => Suffix.accusative,
        'de' => Suffix.locative,
        'den' => Suffix.ablative,
        'le' => Suffix.instrumental,
        _ => null,
      };
      return s == null ? base : withSuffix(base, s);
    });
  }

  static String? _valueOf(String key, VoiceCtx c) => switch (key) {
        'ad' => c.name,
        'öteki' => c.other,
        'meslek' => c.profession,
        'hane' => c.house,
        'zümre' => c.estate,
        'köy' => c.village,
        'mevsim' => c.season == null ? null : seasonWord(c.season!),
        'gün' => c.day?.toString(),
        _ => c.extra[key],
      };

  /// Bağlam eksikse cümle yine de Türkçe okunsun — "null" ya da boşluk değil.
  static String _fallbackFor(String key) => switch (key) {
        'ad' || 'öteki' => 'köylünün biri',
        'meslek' => 'köylü',
        'hane' => 'bir hane',
        'zümre' => 'köy',
        'köy' => 'köy',
        _ => '',
      };
}
