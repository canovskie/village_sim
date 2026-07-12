import 'dart:math';
import 'package:flutter/material.dart';

/// Bir NPC'nin değişmez görsel kimliği — ten/saç/göz/kıyafet varyasyonu.
/// Seed'den deterministik üretilir; aynı seed → aynı görünüm.
/// Aynı tipteki NPC'lerin tıpatıp aynı görünmemesi için kritik.
class NpcVisual {
  final Color skin;
  final Color hair;
  final HairStyle hairStyle;
  final Color eyes;
  final bool hasBeard;
  final BeardStyle beardStyle;
  /// Kıyafet için ince ton kayması (-1..+1).  Renderer baz kıyafet renginin
  /// üzerine bu kadar ton oynatır → her NPC kıyafeti hafif farklı.
  final double clothingShift;
  /// Blink fazı (0..2π) — göz kapama animasyonu için per-NPC offset.
  final double blinkPhase;
  /// Cinsiyete bağlı saç stili kararı için saklanır (sakal kararı, vb).
  final bool isMale;

  const NpcVisual({
    required this.skin,
    required this.hair,
    required this.hairStyle,
    required this.eyes,
    required this.hasBeard,
    required this.beardStyle,
    required this.clothingShift,
    required this.blinkPhase,
    required this.isMale,
  });

  NpcVisual copyWith({
    Color? skin,
    Color? hair,
    HairStyle? hairStyle,
    Color? eyes,
    bool? hasBeard,
    BeardStyle? beardStyle,
    double? clothingShift,
    double? blinkPhase,
    bool? isMale,
  }) =>
      NpcVisual(
        skin: skin ?? this.skin,
        hair: hair ?? this.hair,
        hairStyle: hairStyle ?? this.hairStyle,
        eyes: eyes ?? this.eyes,
        hasBeard: hasBeard ?? this.hasBeard,
        beardStyle: beardStyle ?? this.beardStyle,
        clothingShift: clothingShift ?? this.clothingShift,
        blinkPhase: blinkPhase ?? this.blinkPhase,
        isMale: isMale ?? this.isMale,
      );

  /// Yaşlı varyantı — saç/sakal kıra döner. Sprite ölçeği [LifeStage] ile
  /// ayrıca küçültülür; bu yalnızca renk değişimi.
  NpcVisual elderly() =>
      copyWith(hair: Color.lerp(hair, const Color(0xFFDAD8D0), 0.72)!);

  /// [forceMale] verilirse cinsiyet rastgele atanmaz, dışarıdan dayatılır.
  /// İsim ile visual'ın uyumlu olması için spawn akışı bunu kullanır.
  factory NpcVisual.fromSeed(int seed, {bool? forceMale}) {
    final r       = Random(seed);
    final isMale  = forceMale ?? r.nextBool();
    final skin    = _skinTones[r.nextInt(_skinTones.length)];
    final hair    = _hairColors[r.nextInt(_hairColors.length)];

    // Saç stili — erkek/kadın için farklı dağılım
    final HairStyle hairStyle;
    if (isMale) {
      // Erkeklerde kel/kısa/orta daha sık; uzun nadir
      final roll = r.nextInt(10);
      hairStyle = roll < 2 ? HairStyle.bald
                 : roll < 6 ? HairStyle.short
                 : roll < 8 ? HairStyle.messy
                 : roll < 9 ? HairStyle.medium
                 : HairStyle.long;
    } else {
      // Kadınlarda uzun ve orta daha sık
      final roll = r.nextInt(10);
      hairStyle = roll < 4 ? HairStyle.long
                 : roll < 7 ? HairStyle.medium
                 : roll < 9 ? HairStyle.short
                 : HairStyle.messy;
    }

    final eyes = _eyeColors[r.nextInt(_eyeColors.length)];

    // Sakal: %40 erkek, kadında yok
    final hasBeard = isMale && r.nextDouble() < 0.40;
    final beardStyle = hasBeard
        ? BeardStyle.values[r.nextInt(BeardStyle.values.length)]
        : BeardStyle.none;

    return NpcVisual(
      skin:          skin,
      hair:          hair,
      hairStyle:     hairStyle,
      eyes:          eyes,
      hasBeard:      hasBeard,
      beardStyle:    beardStyle,
      clothingShift: (r.nextDouble() * 2 - 1) * 0.18,
      blinkPhase:    r.nextDouble() * 2 * pi,
      isMale:        isMale,
    );
  }
}

enum HairStyle { bald, short, medium, long, messy }
enum BeardStyle { none, stubble, full, goatee }

/// Bir NPC'nin mesleğinden bağımsız ÖZEL kostümü — karakter çizici tip yerine
/// bunu önceler. `none` = normal meslek/köylü görünümü. `imperial` = dış güç
/// askeri (koyu çelik zırh + kızıl tabard + miğfer), köyde net "yabancı".
enum NpcCostume { none, imperial }

// ─── Renk havuzları ──────────────────────────────────────────────────────────

const List<Color> _skinTones = [
  Color(0xFFFFD8B0), // çok açık
  Color(0xFFFFCB9A), // açık (mevcut _skin1)
  Color(0xFFE8B888), // ten orta
  Color(0xFFD4956A), // koyu (mevcut _skin2)
  Color(0xFFB07848), // daha koyu
  Color(0xFF8A5530), // en koyu
];

const List<Color> _hairColors = [
  Color(0xFF2A1A0A), // siyah
  Color(0xFF3E2A14), // koyu kahve
  Color(0xFF6A4828), // kahve
  Color(0xFF8A6A38), // açık kahve
  Color(0xFFB89858), // koyu sarı
  Color(0xFFE8C868), // sarı/saman
  Color(0xFFD8D8D0), // kır
  Color(0xFF8C2818), // kızıl
];

const List<Color> _eyeColors = [
  Color(0xFF2A1A08), // siyah/koyu kahve
  Color(0xFF4A381E), // kahve
  Color(0xFF3A5A40), // yeşil
  Color(0xFF3A5570), // mavi
  Color(0xFF707880), // gri
];

/// Bir baz rengi NpcVisual.clothingShift'ine göre kaydır.
/// shift > 0 → daha aydınlık + sıcak; < 0 → daha koyu + soğuk.
/// Pixel art görünümünü bozmasın diye küçük adımlarla.
Color tintCloth(Color base, double shift) {
  final r = (base.r * 255).round();
  final g = (base.g * 255).round();
  final b = (base.b * 255).round();
  final delta = (shift * 35).round(); // ±35 RGB
  // Hafif sıcak/soğuk: shift>0 → R+, B−; shift<0 tersi.
  final tempR = (delta * 0.4).round();
  final tempB = (-delta * 0.4).round();
  return Color.fromARGB(
    255,
    (r + delta + tempR).clamp(0, 255),
    (g + delta).clamp(0, 255),
    (b + delta + tempB).clamp(0, 255),
  );
}

/// Bir rengin daha açık tonu — highlight strip için.
Color lighter(Color c, [double amount = 0.18]) {
  final r = (c.r * 255).round();
  final g = (c.g * 255).round();
  final b = (c.b * 255).round();
  final d = (amount * 255).round();
  return Color.fromARGB(255,
      (r + d).clamp(0, 255),
      (g + d).clamp(0, 255),
      (b + d).clamp(0, 255));
}

/// Bir rengin daha koyu tonu — shadow stripe için.
Color darker(Color c, [double amount = 0.22]) {
  final r = (c.r * 255).round();
  final g = (c.g * 255).round();
  final b = (c.b * 255).round();
  final d = (amount * 255).round();
  return Color.fromARGB(255,
      (r - d).clamp(0, 255),
      (g - d).clamp(0, 255),
      (b - d).clamp(0, 255));
}
