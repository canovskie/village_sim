import '../core/resources.dart';

/// Harita genişledikçe karşılaşılan, ana akıştan bağımsız küçük ilgi noktaları.
enum WorldLandmarkKind {
  ruinedWatchtower,
  forgottenShrine,
  abandonedCamp,
  sunkenCellar,
  plagueStone,
}

extension WorldLandmarkKindText on WorldLandmarkKind {
  String get title => switch (this) {
    WorldLandmarkKind.ruinedWatchtower => 'Yıkık Gözetleme Kulesi',
    WorldLandmarkKind.forgottenShrine => 'Unutulmuş Nişan Taşı',
    WorldLandmarkKind.abandonedCamp => 'Terk Edilmiş Konak',
    WorldLandmarkKind.sunkenCellar => 'Çökmüş Mahzen',
    WorldLandmarkKind.plagueStone => 'Kara Yazılı Taş',
  };

  String get icon => switch (this) {
    WorldLandmarkKind.ruinedWatchtower => '🏚️',
    WorldLandmarkKind.forgottenShrine => '🕯️',
    WorldLandmarkKind.abandonedCamp => '⛺',
    WorldLandmarkKind.sunkenCellar => '🗝️',
    WorldLandmarkKind.plagueStone => '🪦',
  };
}

/// Bir yerin ilk keşfinde, bir kez uygulanan küçük sonuç.
enum LandmarkOutcome { salvage, provisions, oldCoin, spoiledStores, illOmen }

class LandmarkEffect {
  final ResourceKind? resource;
  final int resourceDelta;
  final double moraleDelta;
  final double moraleDays;
  final String text;

  const LandmarkEffect({
    this.resource,
    this.resourceDelta = 0,
    this.moraleDelta = 0,
    this.moraleDays = 0,
    required this.text,
  });

  bool get isBoon => resourceDelta > 0 || moraleDelta > 0;
}

LandmarkEffect landmarkEffect(LandmarkOutcome outcome) => switch (outcome) {
  LandmarkOutcome.salvage => const LandmarkEffect(
    resource: ResourceKind.stone,
    resourceDelta: 5,
    text: 'Sağlam taşlar söküldü: +5 taş.',
  ),
  LandmarkOutcome.provisions => const LandmarkEffect(
    resource: ResourceKind.food,
    resourceDelta: 7,
    text: 'Kuru erzak bulundu: +7 yiyecek.',
  ),
  LandmarkOutcome.oldCoin => const LandmarkEffect(
    resource: ResourceKind.gold,
    resourceDelta: 1,
    text: 'Topraktan eski bir sikke çıktı: +1 altın.',
  ),
  LandmarkOutcome.spoiledStores => const LandmarkEffect(
    resource: ResourceKind.food,
    resourceDelta: -4,
    text: 'Bozuk erzak ambara karıştı: en çok 4 yiyecek kaybedildi.',
  ),
  LandmarkOutcome.illOmen => const LandmarkEffect(
    moraleDelta: -0.03,
    moraleDays: 0.5,
    text: 'Uğursuz işaret köyün diline düştü: kısa süreli huzursuzluk.',
  ),
};

class WorldLandmark {
  final int col;
  final int row;
  final WorldLandmarkKind kind;
  final LandmarkOutcome outcome;

  /// Sonuç yalnız ilk keşifte uygulanır; kayıt/yüklemede korunur.
  bool discovered;

  WorldLandmark({
    required this.col,
    required this.row,
    required this.kind,
    required this.outcome,
    this.discovered = false,
  });

  double get depth => col + row + 0.7;
}
