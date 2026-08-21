import '../entities/work_site.dart';

/// Dünya üstündeki kısa etkileşim kılavuzları.
///
/// Metin kararı saf tutulur: sahne yalnız o anki bağlamı verir, widget aynı
/// sözlüğü masaüstü, mobil ve görsel provalarda kullanır.
String npcInteractionGuide({
  required bool isCriminalInAct,
  required bool isInConflict,
}) {
  if (isCriminalInAct) return 'Tıkla: suçüstü yakala';
  if (isInConflict) return 'Tıkla: ayır · sürükle: çek';
  return 'Tek tık: sor · çift tık: kimlik';
}

String workSiteInteractionGuide(WorkSiteKind kind) =>
    kind == WorkSiteKind.construction
    ? 'Tıkla: ilerlemeyi gör'
    : 'Tıkla: çalışanları gör';

String cameraInteractionGuide({required bool mobile}) => mobile
    ? 'Tek parmak: gez · iki parmak: yakınlaş'
    : 'Sürükle: köyü gez · tekerlek: yakınlaş';
