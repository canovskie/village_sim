import 'package:flutter/material.dart';

import '../../systems/events/event_system.dart';
import '../../systems/governance/petition_system.dart';
import 'option_scene_card.dart';
import 'petition_scene_card.dart';

/// Olay içeriğini çevre/mekân sahnesine çevirir. Önce bildirimsel efekt ve
/// kalıcı id, sonra oyuncunun gördüğü metin okunur; katalog büyüdüğünde her
/// olay için ayrı UI dalı yazmak gerekmez.
PetitionScene eventSceneFor(EventOutcome event) {
  switch (event.effect?.fx) {
    case EventFx.fireOutbreak:
      return PetitionScene.fire;
    case EventFx.cropBlight:
    case EventFx.harvestBounty:
    case EventFx.droughtHaze:
      return PetitionScene.field;
    case EventFx.festival:
    case EventFx.wedding:
      return PetitionScene.gathering;
    case EventFx.vigil:
    case EventFx.cultRite:
      return PetitionScene.shrine;
    case EventFx.plagueAura:
    case EventFx.storm:
    case EventFx.beastEyes:
      return PetitionScene.home;
    case EventFx.none:
    case null:
      break;
  }

  final text = '${event.id} ${event.title} ${event.message}'.toLowerCase();
  if (_hasAny(text, const ['yangın', 'alev', 'fire', 'yanıyor'])) {
    return PetitionScene.fire;
  }
  if (_hasAny(text, const [
    'tarla',
    'ekin',
    'hasat',
    'kurak',
    'blight',
    'crop',
  ])) {
    return PetitionScene.field;
  }
  if (_hasAny(text, const [
    'kervan',
    'pazar',
    'tüccar',
    'zanaat',
    'uzman',
    'trade',
  ])) {
    return PetitionScene.market;
  }
  if (_hasAny(text, const [
    'ayin',
    'mabet',
    'cenaze',
    'anma',
    'inanç',
    'mezar',
  ])) {
    return PetitionScene.shrine;
  }
  if (_hasAny(text, const [
    'şenlik',
    'düğün',
    'toplandı',
    'meydan',
    'festival',
  ])) {
    return PetitionScene.gathering;
  }
  if (_hasAny(text, const [
    'kış',
    'don',
    'kar',
    'soğuk',
    'hane',
    'ev',
    'ocak',
    'salgın',
    'fırtına',
  ])) {
    return PetitionScene.home;
  }
  return PetitionScene.generic;
}

PetitionTone eventToneFor(EventOutcome event) => switch (event.category) {
  EventCategory.positive => PetitionTone.warm,
  EventCategory.negative =>
    event.severity == EventSeverity.major
        ? PetitionTone.ominous
        : PetitionTone.solemn,
  EventCategory.neutral => PetitionTone.neutral,
};

OptionScene eventChoiceSceneFor(EventChoice choice) {
  final text = '${choice.id} ${choice.label} ${choice.detail}'.toLowerCase();
  if (_hasAny(text, const ['sür', 'kov', 'kaç', 'exile'])) {
    return OptionScene.exile;
  }
  if (_hasAny(text, const ['cezalandır', 'yakala', 'dövüş', 'savaş'])) {
    return OptionScene.punish;
  }
  if (_hasAny(text, const ['öldür', 'idam', 'execute'])) {
    return OptionScene.execute;
  }
  if (_hasAny(text, const [
    'reddet',
    'sakla',
    'ambarda',
    'bekle',
    'bırak',
    'endure',
    'hide',
    'refuse',
  ])) {
    return OptionScene.refuse;
  }
  if (_hasAny(text, const [
    'kabul',
    'paylaştır',
    'yardım',
    'kurtar',
    'çağır',
    'satın al',
    'accept',
    'share',
    'help',
  ])) {
    return OptionScene.accept;
  }
  if (choice.moraleModifier > 0 ||
      (choice.requiresResources && choice.deltaSummary().isNotEmpty)) {
    return OptionScene.accept;
  }
  if (choice.moraleModifier < 0) return OptionScene.refuse;
  return OptionScene.generic;
}

bool _hasAny(String text, List<String> needles) =>
    needles.any((needle) => text.contains(needle));

class EventSceneCard extends StatelessWidget {
  final EventOutcome event;
  final double height;
  final bool drawBorder;

  const EventSceneCard({
    super.key,
    required this.event,
    required this.height,
    this.drawBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final scene = eventSceneFor(event);
    final card = SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            PetitionSceneCard.custom(
              scene: scene,
              tone: eventToneFor(event),
              height: height,
              drawBorder: false,
            ),
            _EventPropLayer(event: event, scene: scene),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x24000000),
                    Color(0x00000000),
                    Color(0x70000000),
                  ],
                  stops: [0, .55, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!drawBorder) return card;
    return ClipRRect(borderRadius: BorderRadius.circular(8), child: card);
  }
}

class _EventPropLayer extends StatelessWidget {
  final EventOutcome event;
  final PetitionScene scene;

  const _EventPropLayer({required this.event, required this.scene});

  bool get _winter {
    final text = '${event.id} ${event.title} ${event.message}'.toLowerCase();
    return _hasAny(text, const ['kış', 'don', 'kar', 'soğuk', 'winter']);
  }

  List<String> get _assets {
    final suffix = _winter ? '_winter' : '';
    return switch (scene) {
      PetitionScene.fire => [
        'assets/buildings/barn$suffix.png',
        'assets/buildings/minihouse$suffix.png',
      ],
      PetitionScene.field => [
        'assets/buildings/mill_base$suffix.png',
        'assets/buildings/barn$suffix.png',
      ],
      PetitionScene.market => [
        'assets/buildings/market$suffix.png',
        'assets/buildings/caravanserai$suffix.png',
      ],
      PetitionScene.shrine => [
        'assets/buildings/church$suffix.png',
        'assets/buildings/shrine$suffix.png',
      ],
      PetitionScene.gathering => [
        'assets/buildings/tavern$suffix.png',
        'assets/buildings/townhall$suffix.png',
      ],
      PetitionScene.home => [
        'assets/buildings/minihouse$suffix.png',
        'assets/buildings/warehouse$suffix.png',
      ],
      PetitionScene.herd => [
        'assets/buildings/stable$suffix.png',
        'assets/buildings/barn$suffix.png',
      ],
      PetitionScene.generic => [
        'assets/buildings/minihouse$suffix.png',
        'assets/buildings/townhall$suffix.png',
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final assets = _assets;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          Widget prop(String asset, {required bool foreground}) {
            final image = Image.asset(
              asset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            );
            return Opacity(
              opacity: foreground ? .92 : .68,
              child: _winter
                  ? ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0xFFD7E2EC),
                        BlendMode.modulate,
                      ),
                      child: image,
                    )
                  : image,
            );
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: -w * .08,
                bottom: h * .17,
                width: w * .57,
                height: h * .48,
                child: prop(assets.first, foreground: false),
              ),
              Positioned(
                right: -w * .09,
                bottom: h * .10,
                width: w * .76,
                height: h * .61,
                child: prop(assets.last, foreground: true),
              ),
              if (scene == PetitionScene.fire)
                Positioned(
                  left: w * .35,
                  bottom: h * .16,
                  width: w * .22,
                  height: h * .26,
                  child: Image.asset(
                    'assets/effects/flame.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class EventChoiceSceneCard extends StatelessWidget {
  final EventChoice choice;
  final double height;

  const EventChoiceSceneCard({
    super.key,
    required this.choice,
    required this.height,
  });

  @override
  Widget build(BuildContext context) =>
      OptionSceneCard(scene: eventChoiceSceneFor(choice), height: height);
}
