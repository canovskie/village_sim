import '../../characters/life_stage.dart';
import '../governance/petition_system.dart';
import 'event_system.dart';

bool isVillageIssue(String id) =>
    id.startsWith('regime.crisis.') ||
    const {
      PetitionIds.ovenTurn,
      PetitionIds.hearthSeat,
      PetitionIds.wellBucket,
      PetitionIds.animalBell,
      PetitionIds.quietEvening,
      PetitionIds.crimeWave,
      PetitionIds.fireDied,
      PetitionIds.woodLow,
    }.contains(id);

/// Sunum adaptörü: karar, mühlet ve kayıt aynı yönetişim otoritesinde kalır.
EventOutcome governanceEvent(Petition p) => EventOutcome(
  id: p.id,
  title: p.title,
  icon: p.icon,
  message: p.body,
  category: p.tone == PetitionTone.ominous
      ? EventCategory.negative
      : EventCategory.neutral,
  severity: EventSeverity.major,
  choices: [
    for (var i = 0; i < p.options.length; i++)
      EventChoice(
        id: '$i',
        label: p.options[i].label,
        detail: p.options[i].detail,
        resolutionMessage: p.options[i].resolution,
        annal: p.options[i].annal,
        requiresResources: true,
        foodDelta: p.options[i].foodDelta,
        goldDelta: p.options[i].goldDelta,
        woodDelta: p.options[i].woodDelta,
        stoneDelta: p.options[i].stoneDelta,
        ironDelta: p.options[i].ironDelta,
        moraleModifier: p.options[i].moraleAmount,
        duration: p.options[i].moraleDays * kGameDaySeconds,
      ),
  ],
);
