import 'dart:math';

import '../characters/life_stage.dart';
import '../characters/villager_type.dart';
import '../systems/villager_act.dart';
import 'villager_entity.dart';

/// Köyün dış dünyayla kurduğu görünür temasın türü.
enum VisitorKind { caravan, traveler, stranger }

extension VisitorKindLabel on VisitorKind {
  String get label => switch (this) {
    VisitorKind.caravan => 'Kervan',
    VisitorKind.traveler => 'Yolcu',
    VisitorKind.stranger => 'Yabancı',
  };
}

/// Dışarıdan gelen NPC'nin ziyaret evresi. Giriş ile oyalanma arasındaki
/// [greeting] bilinçli olarak ayrı: varlık hedefe varınca birden boşta kalmaz;
/// etrafa bakar, selam verir ve ancak sonra kendi işine dağılır.
enum MerchantPhase { entering, greeting, browsing, leaving }

/// Köye uğrayıp sonra yoluna devam eden dış dünya aktörü. Tarihî adı
/// [MerchantEntity] geriye dönük uyumluluk için korunuyor; artık kervancı,
/// yolcu ve yabancıyı aynı yaşam döngüsünde taşıyor.
///
/// Köyün NÜFUSU/sakini DEĞİL: ayrı listede tutulur, yaşlanmaz, ev/iş/dilekçe
/// sistemlerine girmez ve kayda yazılmaz. Hareketini [step] sürer.
class MerchantEntity extends VillagerEntity {
  MerchantPhase phase = MerchantPhase.entering;

  /// Aynı yolculukta gelenleri birbirine bağlar. Kervanın arabası, tüccarları
  /// ve yükçüleri tek ziyaret olarak bu kimlikle okunur.
  final int groupId;
  final VisitorKind visitorKind;
  final bool isGroupLeader;

  /// true ise bu entity insan sprite'ı yerine at arabasının hareket/derinlik
  /// ankrajıdır. Eşlik eden insanlar ayrı entity'lerdir.
  final bool hasCart;

  /// Köy içindeki gezinme merkezi (han/pazar/meydan).
  final double browseX;
  final double browseY;

  /// Çıkış noktası. Girişten farklı tutulabilir; dış dünya köyün içinden akar.
  final double exitX;
  final double exitY;

  /// Ziyaretin geri kalan oyalanma süresi (sn). 0'a inince [leaving]'e geçer.
  double browseLeft;

  /// Hedefe varınca selam/çevreyi süzme evresinin kalan süresi.
  double greetingLeft;

  /// Gezinme alt-hedefi + sonraki hedefe kadar duraklama sayacı.
  double _wanderX = 0, _wanderY = 0;
  double _wanderDwell = 0;
  double _socialPulse = 0;

  /// true → çıkışa vardı, sahne listeden çıkarmalı.
  bool finished = false;

  MerchantEntity({
    required super.startCol,
    required super.startRow,
    required this.browseX,
    required this.browseY,
    required this.exitX,
    required this.exitY,
    this.groupId = 0,
    this.visitorKind = VisitorKind.caravan,
    this.isGroupLeader = true,
    this.hasCart = false,
    this.browseLeft = 90.0,
    this.greetingLeft = 3.0,
    VillagerType visualType = VillagerType.merchant,
    super.male = true,
    super.name = 'Kervan Tüccarı',
  }) : super(type: visualType, ageDays: kAdultStartDay) {
    _wanderX = browseX;
    _wanderY = browseY;
    _socialPulse = 4.0 + (groupId.abs() % 5);
    // Yoldan gelenin yükü uzaktan okunur. At arabası zaten kendi yükünü taşır.
    if (!hasCart) {
      prop = switch (visitorKind) {
        VisitorKind.caravan => isGroupLeader ? PropKind.basket : PropKind.sack,
        VisitorKind.traveler => PropKind.sack,
        VisitorKind.stranger => PropKind.none,
      };
    }
  }

  bool get canTrade =>
      visitorKind == VisitorKind.caravan && isGroupLeader && !hasCart;

  @override
  double get speed => hasCart ? 0.68 : super.speed;

  /// Sahne her tick çağırır — ziyaret evre makinesi + hareket + mikro jestler.
  /// VillagerEntity.update'in aksine yaşlanma/AI yok; yalnız seyahat eder.
  void step(
    double dt,
    Random rng, {
    Set<(int, int)> waterTiles = const {},
    Set<(int, int)> softObstacles = const {},
    double dayLight = 1.0,
    double rainIntensity = 0.0,
  }) {
    switch (phase) {
      case MerchantPhase.entering:
        isWalking = true;
        if (moveTowards(browseX, browseY, dt, arriveD: 0.6)) {
          phase = MerchantPhase.greeting;
          isWalking = false;
          waveTime = VillagerEntity.kWaveDuration;
          activity = VillagerActivity.storytelling;
          chatBubbleTime = greetingLeft;
          if (!hasCart) feel(NpcEmotion.wonder, greetingLeft);
        }
      case MerchantPhase.greeting:
        isWalking = false;
        greetingLeft -= dt;
        if (greetingLeft <= 0) {
          phase = MerchantPhase.browsing;
          activity = VillagerActivity.none;
          chatBubbleTime = 0;
          _wanderDwell = hasCart ? browseLeft : 0;
        }
      case MerchantPhase.browsing:
        browseLeft -= dt;
        _tickSocialLife(dt);
        if (hasCart) {
          // Araba han/pazar önünde park eder; atın koşum altında ağır ağır
          // solumasını renderer verir. İnsanlar çevresinde dağılır.
          isWalking = false;
        } else {
          _browseWander(dt, rng, waterTiles, softObstacles);
        }
        if (browseLeft <= 0) {
          phase = MerchantPhase.leaving;
          activity = VillagerActivity.none;
          chatBubbleTime = 0;
          waveTime = VillagerEntity.kWaveDuration;
        }
      case MerchantPhase.leaving:
        isWalking = true;
        if (moveTowards(exitX, exitY, dt, arriveD: 0.5)) {
          isWalking = false;
          finished = true;
        }
    }
    smoothMotion(dt);
    tickInnerLife(dt, dayLight, !isWalking);
    if (waveTime > 0) waveTime = max(0.0, waveTime - dt);
    if (chatBubbleTime > 0) {
      chatBubbleTime = max(0.0, chatBubbleTime - dt);
    } else if (activity == VillagerActivity.storytelling) {
      activity = VillagerActivity.none;
    }
    // Gece dışarıda kalan yaya ziyaretçi meşale yakar. Arabanın feneri kendi
    // renderer'ında; insan koluna ikinci bir meşale bindirilmez.
    tickTorch(
      dt,
      dayLight,
      rainIntensity,
      eligibleOverride: !finished && !hasCart,
    );
  }

  /// Uzun bekleyişi donuk idle olmaktan çıkarır: yolcu kısa bir haber anlatır,
  /// yabancı çevreyi hayretle süzer, kervancı malını işaret eder.
  void _tickSocialLife(double dt) {
    if (hasCart) return;
    _socialPulse -= dt;
    if (_socialPulse > 0) return;
    _socialPulse = switch (visitorKind) {
      VisitorKind.caravan => 8.0,
      VisitorKind.traveler => 6.5,
      VisitorKind.stranger => 7.5,
    };
    activity = VillagerActivity.storytelling;
    chatBubbleTime = 2.2;
    chatBubbleIcon = switch (visitorKind) {
      VisitorKind.caravan => '⚖',
      VisitorKind.traveler => '🗺',
      VisitorKind.stranger => '◌',
    };
    feel(
      visitorKind == VisitorKind.stranger
          ? NpcEmotion.wonder
          : NpcEmotion.content,
      2.2,
    );
  }

  /// Merkez çevresinde sakin turlar. Bir hedefe yürür, varınca birkaç saniye
  /// oyalanır, sonra yeni nokta seçer.
  void _browseWander(
    double dt,
    Random rng,
    Set<(int, int)> waterTiles,
    Set<(int, int)> softObstacles,
  ) {
    if (_wanderDwell > 0) {
      _wanderDwell -= dt;
      isWalking = false;
      if (_wanderDwell <= 0) {
        final t = pickWanderTarget(
          browseX,
          browseY,
          2.6,
          rng,
          waterTiles: waterTiles,
          softObstacles: softObstacles,
        );
        if (t != null) {
          _wanderX = t.$1;
          _wanderY = t.$2;
        }
      }
      return;
    }
    isWalking = true;
    if (moveTowards(_wanderX, _wanderY, dt, arriveD: 0.25, speedScale: 0.55)) {
      _wanderDwell = 1.5 + rng.nextDouble() * 3.0;
      isWalking = false;
    }
  }
}
