import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/npc_visual.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/cutscene/cutscene.dart';

void main() {
  test('açılış her çekimde fiziksel bir sahne kurar', () {
    expect(kOpeningCutscene.shots.map((s) => s.setPiece), [
      CutsceneSetPiece.caravan,
      CutsceneSetPiece.camp,
      CutsceneSetPiece.camp,
    ]);
    final caravan = kOpeningCutscene.shots.first.actors;
    expect(caravan.skip(1).every((a) => a.entranceDelay > 0), isTrue);
  });

  test('ateş sahnesinde oyuncu ayakta duran heykellere bakmaz', () {
    final shot = kFireLightingCutscene.shots.single;
    expect(shot.setPiece, CutsceneSetPiece.camp);
    expect(shot.actors.every((a) => a.pose == CutsceneActorPose.sit), isTrue);
  });

  test('düğün çekimleri kalabalık ve kutlama hareketi taşır', () {
    final visual = NpcVisual.fromSeed(4);
    final film = weddingCutscene(
      brideType: VillagerType.farmer,
      brideVisual: visual,
      brideName: 'Ayla',
      groomType: VillagerType.blacksmith,
      groomVisual: NpcVisual.fromSeed(8),
      groomName: 'Demir',
    );
    expect(
      film.shots.every((s) => s.setPiece == CutsceneSetPiece.wedding),
      isTrue,
    );
    expect(
      film.shots.last.actors.every(
        (a) => a.gesture == CutsceneActorGesture.wave,
      ),
      isTrue,
    );
  });

  test('kıtlık görsel sonucu ve yas duruşunu taşır', () {
    final shot = kFamineCutscene.shots.single;
    expect(shot.setPiece, CutsceneSetPiece.famine);
    expect(shot.actors.first.pose, CutsceneActorPose.mourn);
  });
}
