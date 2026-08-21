import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/entities/work_site.dart';
import 'package:village_sim/systems/contextual_guides.dart';

void main() {
  test('acil NPC bağlamı genel tıklama kılavuzunun önüne geçer', () {
    expect(
      npcInteractionGuide(isCriminalInAct: true, isInConflict: true),
      'Tıkla: suçüstü yakala',
    );
    expect(
      npcInteractionGuide(isCriminalInAct: false, isInConflict: true),
      'Tıkla: ayır · sürükle: çek',
    );
    expect(
      npcInteractionGuide(isCriminalInAct: false, isInConflict: false),
      'Tek tık: sor · çift tık: kimlik',
    );
  });

  test('şantiye ilerlemeyi, diğer açık iş yerleri çalışanları işaret eder', () {
    expect(
      workSiteInteractionGuide(WorkSiteKind.construction),
      'Tıkla: ilerlemeyi gör',
    );
    expect(
      workSiteInteractionGuide(WorkSiteKind.field),
      'Tıkla: çalışanları gör',
    );
  });

  test('kamera kılavuzu giriş yöntemine uyarlanır', () {
    expect(
      cameraInteractionGuide(mobile: false),
      'Sürükle: köyü gez · tekerlek: yakınlaş',
    );
    expect(
      cameraInteractionGuide(mobile: true),
      'Tek parmak: gez · iki parmak: yakınlaş',
    );
  });
}
