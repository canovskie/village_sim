part of '../../main.dart';

/// Dilekçe sahibinde kalan kişisel sonuçlar. İçerik id'si bilmez; seçenek
/// [PetitionActorEffect] bildirir, bu katman onu gerçek köylüye uygular.
extension _ScenePetitionActorEffects on _VillageSceneState {
  void _applyPetitionActorEffect(
    PetitionActorEffect effect,
    VillagerEntity? author,
  ) {
    if (author == null || author.isDying) return;
    switch (effect) {
      case PetitionActorEffect.none:
        return;
      case PetitionActorEffect.flowingOutfit:
        author.wardrobe = NpcWardrobe.flowing;
        author.feel(NpcEmotion.joy, 5.0, moodDelta: 0.18);
        _reactNearby(
          author.gridX,
          author.gridY,
          4.0,
          NpcEmotion.wonder,
          2.6,
          moodDelta: 0.01,
        );
        _lifeEvent(
          author,
          'Divan önünde kendi hayatını ve kıyafetini seçme hakkını aldı.',
          icon: '🧵',
          milestone: true,
        );
      case PetitionActorEffect.traditionalOutfit:
        author.wardrobe = NpcWardrobe.traditional;
        author.feel(NpcEmotion.grief, 5.0, moodDelta: -0.18);
        _reactNearby(
          author.gridX,
          author.gridY,
          3.0,
          NpcEmotion.grief,
          2.2,
          moodDelta: -0.01,
        );
        _lifeEvent(
          author,
          'Divan talebini reddetti; köy geleneğine uygun yaşaması istendi.',
          icon: '🧥',
          milestone: true,
        );
    }
  }
}
