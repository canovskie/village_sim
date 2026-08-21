import 'law_book.dart';

/// OCAK SÖZÜ → YAZILI HÜKÜM köprüsü.
///
/// Belediye öncesindeki kararlar kanun değildir; küçük köy onları ateş başında
/// yaşar. Belediye kurulunca tarih sıfırlanmaz: erken kararlar sayılır ve köy
/// hafızasındaki belirli izler ilgili fermanların toplumsal dayanağı olur.
abstract final class OralTradition {
  static const String decisionPrefix = 'tradition.decision.';

  /// Belediye öncesi dilekçenin seçilen şıkkını kalıcı ve stabil kaydeder.
  static String decisionFlag(String petitionId, int optionIndex) =>
      '$decisionPrefix$petitionId.$optionIndex';

  static int decisionCount(Set<String> memory) =>
      memory.where((f) => f.startsWith(decisionPrefix)).length;

  /// Erken karar izi → yazıya dökülebilecek ferman. Harita bilinçli olarak
  /// dar: yalnız anlamı gerçekten örtüşen izler bağ kurar.
  static const Map<String, Set<String>> _rootsByLaw = {
    'neighborliness': {'assembly.tradition', 'dissent.heard', 'pact.neighbor'},
    'sharedHarvest': {'house.curbed'},
    'farmLabor': {'fields.tended'},
    'hospitality': {'migrants.welcomed', 'road.open'},
    'apprenticeship': {'craft.school'},
    'tradeGuidance': {'craft.guild'},
    'nizam.watch': {'crime.watch'},
    'nizam.sole': {'village.hushed', 'dissent.silenced'},
    'dergah.holyDay': {
      'holyDay.active',
      'festival.tradition',
      'founders.remembered',
    },
    'dergah.lodge': {'cult.active', 'cult.temple'},
    'dergah.oneFaith': {'cult.united'},
    'rejim.meclisDaimi': {
      'assembly.tradition',
      'dissent.heard',
      'house.curbed',
      'council.youth',
    },
    'rejim.mulkTapusu': {'house.blessed', 'legacy.owned'},
  };

  static const Map<String, String> _rootLabels = {
    'assembly.tradition': 'meydan günü',
    'dissent.heard': 'itirazı dinleme',
    'pact.neighbor': 'komşuyla el sıkışma',
    'house.curbed': 'sözü hanelere bölme',
    'fields.tended': 'toprağın hakkını verme',
    'migrants.welcomed': 'yabancıya kapı açma',
    'road.open': 'yolu açık tutma',
    'craft.school': 'zanaatı öğretme',
    'craft.guild': 'tezgâhta sıra tutma',
    'crime.watch': 'gece nöbeti',
    'village.hushed': 'köyü susturma',
    'dissent.silenced': 'itirazı kesme',
    'holyDay.active': 'kutsal gün',
    'festival.tradition': 'şenlik geleneği',
    'founders.remembered': 'kurucuları anma',
    'cult.active': 'kök salmış inanç',
    'cult.temple': 'kurulmuş mabet',
    'cult.united': 'birleşmiş inanç',
    'council.youth': 'gençlerin sözü',
    'house.blessed': 'büyük haneyi gözetme',
    'legacy.owned': 'eski kararın arkasında durma',
  };

  static Set<String> rootsFor(LawDef law, Set<String> memory) => {
    for (final flag in _rootsByLaw[law.id] ?? const <String>{})
      if (memory.contains(flag)) flag,
  };

  static bool supports(LawDef law, Set<String> memory) =>
      rootsFor(law, memory).isNotEmpty;

  static String supportLine(LawDef law, Set<String> memory) {
    final roots = rootsFor(law, memory).toList()..sort();
    if (roots.isEmpty) return '';
    final labels = [for (final f in roots.take(2)) _rootLabels[f] ?? f];
    return 'Köy bunu daha önce ${labels.join(' ve ')} olarak yaşadı. '
        'Yazıya geçirmek meclis desteğini güçlendirir.';
  }
}
