// TÜZÜK MERDİVENİ — görev kataloğu + kimlik kademeleri.
//
// Bu testin derdi görevlerin İÇERİĞİ değil, merdivenin KİLİTLENMEMESİ. Geç
// oyun kademeleri (4-5) eklenirken çıkan asıl risk şuydu: bir kademenin
// eşiği, o kademeye gelene kadar AÇILAN görev sayısından büyük olursa köy
// oraya hiçbir zaman ulaşamaz ve merdiven sessizce durur. Oyuncu bunu bir
// hata olarak değil "oyun bitti galiba" diye yaşar; en kötü tür bozukluk.
//
// Kilitlenen sözleşmeler:
//   • Her kademe eşiği, ALTINDAKİ kademelerin görev toplamıyla karşılanabilir.
//   • Görev id'leri tekil (aynı id iki kez tamamlanamaz, ödül bir kez düşer).
//   • Hiçbir görev var olmayan bir kademeye asılı kalmaz.
//   • Kademe ilerlemesi tek yönlü ve eşiklerle tutarlı.

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_entity.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/scene/scene_data.dart';
import 'package:village_sim/systems/quest_book.dart';

QuestContext _ctx({
  int charterTier = 0,
  int dayCount = 1,
  int woodHarvested = 0,
  List<BuildingEntity> buildings = const [],
  Map<VillagerType, String> names = const {},
}) => QuestContext(
  buildings: buildings,
  farmTiles: const [],
  population: 0,
  stock: ResourceBundle(),
  policies: VillagePolicies(),
  decorCount: 0,
  charterTier: charterTier,
  dayCount: dayCount,
  woodHarvested: woodHarvested,
  speakerNames: names,
);

void main() {
  group('merdiven kilitlenmez', () {
    test('her kademe eşiği altındaki görevlerle karşılanabilir', () {
      // i. kademeye geçerken elde olabilecek en fazla görev: tier <= i-1 olan
      // TÜM görevler (üst kademe görevleri henüz açılmamıştır).
      for (var i = 1; i < QuestBook.tiers.length; i++) {
        final reachable = QuestBook.all.where((q) => q.tier <= i - 1).length;
        expect(
          QuestBook.tiers[i].minQuests,
          lessThanOrEqualTo(reachable),
          reason:
              '"${QuestBook.tiers[i].name}" kademesi '
              '${QuestBook.tiers[i].minQuests} görev istiyor ama o noktaya '
              'kadar yalnız $reachable görev açılıyor. Merdiven burada '
              'kilitlenir: kademe hiç gelmez, üstündeki görevler hiç açılmaz.',
        );
      }
    });

    test('eşikler nefes payı bırakır — tavan "hepsi hariç biri" olamaz', () {
      // Bir kademe, altındaki görevlerin NEREDEYSE hepsini isterse, isteğe
      // bağlı tek bir görevi atlayan oyuncu kalıcı olarak takılır. Geç
      // kademelerde en az 3 görevlik pay şart.
      for (var i = 4; i < QuestBook.tiers.length; i++) {
        final reachable = QuestBook.all.where((q) => q.tier <= i - 1).length;
        expect(
          reachable - QuestBook.tiers[i].minQuests,
          greaterThanOrEqualTo(3),
          reason:
              '"${QuestBook.tiers[i].name}" eşiği çok dar: '
              '$reachable görevin ${QuestBook.tiers[i].minQuests} tanesi '
              'zorunlu. İsteğe bağlı bir görevi atlayan oyuncu tavana çarpar.',
        );
      }
    });

    test('eşikler yukarı doğru gevşemez', () {
      for (var i = 1; i < QuestBook.tiers.length; i++) {
        expect(
          QuestBook.tiers[i].minQuests,
          greaterThanOrEqualTo(QuestBook.tiers[i - 1].minQuests),
        );
        expect(
          QuestBook.tiers[i].minPolicies,
          greaterThanOrEqualTo(QuestBook.tiers[i - 1].minPolicies),
        );
      }
    });

    test('her kademede en az bir görev var', () {
      for (var i = 0; i < QuestBook.tiers.length; i++) {
        expect(
          QuestBook.all.any((q) => q.tier == i),
          isTrue,
          reason:
              '${QuestBook.tiers[i].name} kademesinde hiç görev yok — '
              'oyuncu oraya çıkıp boş bir panel görür',
        );
      }
    });

    test('görev var olmayan kademeye asılı kalmaz', () {
      for (final q in QuestBook.all) {
        expect(
          q.tier,
          inInclusiveRange(0, QuestBook.maxTier),
          reason:
              '${q.id} görevi ${q.tier}. kademede ama merdiven '
              '${QuestBook.maxTier}. kademede bitiyor → görev hiç açılmaz',
        );
      }
    });
  });

  test('görev id\'leri tekil', () {
    final ids = QuestBook.all.map((q) => q.id).toList();
    expect(
      ids.toSet().length,
      ids.length,
      reason:
          'tekrar eden id: tamamlanma seti tek girdi tutar, '
          'ikinci görev sessizce ölü kalır',
    );
  });

  group('kademe hesabı', () {
    test('sıfır ilerleme sıfırıncı kademe', () {
      expect(QuestBook.charterTier(0, 0), 0);
    });

    test('eşik dolunca kademe atlar, dolmadan atlamaz', () {
      for (var i = 1; i < QuestBook.tiers.length; i++) {
        final t = QuestBook.tiers[i];
        expect(
          QuestBook.charterTier(t.minQuests, t.minPolicies),
          greaterThanOrEqualTo(i),
          reason: '${t.name} eşiği tam dolduğunda kademe gelmedi',
        );
        if (t.minQuests > 0) {
          expect(
            QuestBook.charterTier(t.minQuests - 1, t.minPolicies),
            lessThan(i),
            reason: '${t.name} eşiği eksikken kademe verildi',
          );
        }
      }
    });

    test('her şey tamamlanınca son kademeye çıkılır', () {
      expect(
        QuestBook.charterTier(QuestBook.all.length, 99),
        QuestBook.maxTier,
      );
    });

    test('son kademede sonraki kademe yok', () {
      expect(QuestBook.nextTier(QuestBook.maxTier), isNull);
      expect(QuestBook.nextTier(0), isNotNull);
    });
  });

  test('görev listesi yalnız açık kademeyi gösterir', () {
    final open = QuestBook.activeQuests(_ctx(), const {});
    expect(
      open.every((s) => s.quest.tier == 0),
      isTrue,
      reason: 'kademe 0\'daki oyuncuya üst kademe görevi gösteriliyor',
    );
    expect(open.first.active, isTrue, reason: 'ilk görev vurgulanmalı');
  });

  // ── KURULUŞ KADEMESİ ───────────────────────────────────────────────────────
  // Buradaki sözleşme bir sayı değil bir TASARIM: erken oyunun boş hissetmesinin
  // sebebi kuruluşun beş "bina dik" görevinden ibaret olmasıydı. Sonraki
  // sarkaç ters yöne gitti — on iki adımın üçü "şu köylüye şu işi ver"di ve
  // karar diye eklenen şey mikro kontrol çıktı. Burası ikisini de tutar.
  group('kuruluş kademesi boş bırakmaz', () {
    List<Quest> tier0() => QuestBook.all.where((q) => q.tier == 0).toList();

    test('kuruluş 7-10 mikro adım bandında kalır', () {
      // ALT sınır: beş "bina dik" görevine geri dönülürse oyuncu ilk on
      // dakikayı yine bekleyerek geçirir — boşluğun kaynağı buydu.
      // ÜST sınır: on ikiye çıktığında liste bir iş listesi gibi okundu.
      expect(tier0().length, greaterThanOrEqualTo(7));
      expect(tier0().length, lessThanOrEqualTo(10));
    });

    test('hiçbir adım tek tek köylü atamasına dayanmaz', () {
      // MİKRO KONTROL NÖBETÇİSİ. "Sepeti birine ver / ocağa aşçı ver" adımları
      // kâğıtta karardı, oyunda her seferlik bir angaryaydı: köy kendi
      // açlığına bakmıyordu, oyuncu tek tek köylüye böğürtlen atıyordu. Kadro
      // artık köyün refleksi (scene_jobs `_foragerTarget`/`_cookTarget`);
      // buraya rol ataması isteyen bir adım geri dönerse o refleks de
      // anlamsızlaşır.
      expect(QuestBook.all.any((q) => q.id == 'giveBasket'), isFalse);
      expect(QuestBook.all.any((q) => q.id == 'giveCook'), isFalse);
    });

    test('Kanunname kuruluşta görünmez, Belediye sonrasında açılır', () {
      final firstPolicy = QuestBook.all.firstWhere(
        (q) => q.id == 'firstPolicy',
      );
      final townhallIndex = QuestBook.all.indexWhere((q) => q.id == 'townhall');
      final policyIndex = QuestBook.all.indexOf(firstPolicy);
      expect(
        tier0().any((q) => q.uiTarget == QuestUi.lawBook),
        isFalse,
        reason: 'Belediye yokken kuruluş öğreticisi Kanunname gösteriyor',
      );
      expect(firstPolicy.tier, 1);
      expect(firstPolicy.guided, isTrue);
      expect(policyIndex, townhallIndex + 1);
    });

    test('yazılı hüküm rehberi Belediye görevi bitmeden sıra almaz', () {
      final foundingDone = {
        for (final q in QuestBook.all.where((q) => q.tier == 0)) q.id,
      };
      final beforeHall = QuestBook.activeQuests(
        _ctx(charterTier: 1),
        foundingDone,
      );
      expect(beforeHall.first.quest.id, 'townhall');

      final afterHall = QuestBook.activeQuests(
        _ctx(
          charterTier: 1,
          buildings: [
            BuildingEntity(type: BuildingType.townhall, col: 4, row: 4),
          ],
        ),
        {...foundingDone, 'townhall'},
      );
      expect(afterHall.first.quest.id, 'firstPolicy');
      expect(afterHall.first.quest.uiTarget, QuestUi.lawBook);
    });

    test('öğretici 3-5 adıma eşlik eder, kuruluşun tamamına değil', () {
      // Kapsam bir süre "kademe 0"dı: dokuz adımın dokuzunda da spot açılıyor,
      // oyuncu köyü kurarken sürekli birinin parmağını izliyordu. Rehberli
      // adım sayısı büyürse öğretici yine eşlikçiye döner.
      final guided = QuestBook.all.where((q) => q.guided).toList();
      expect(guided.length, greaterThanOrEqualTo(3));
      expect(guided.length, lessThanOrEqualTo(5));
      expect(guided.where((q) => q.tier == 0).length, 3);
      expect(
        guided.where((q) => q.tier > 0).map((q) => q.id),
        orderedEquals(const ['firstPolicy']),
      );
    });

    test('rehberli adımlar listenin BAŞINDA ve kesintisiz', () {
      // Adım sırası = `all` sırası (bkz. activeQuests). Rehberli adımlar araya
      // dağılırsa öğretici susup susup yeniden konuşur; oyuncu için bu
      // "öğretici bozuldu" demektir.
      final t0 = tier0();
      final lastGuided = t0.lastIndexWhere((q) => q.guided);
      expect(lastGuided, greaterThanOrEqualTo(0));
      expect(
        t0.take(lastGuided + 1).every((q) => q.guided),
        isTrue,
        reason: 'rehberli adımların arasına rehbersiz bir adım girmiş',
      );
    });

    test('her rehberli adımın gösterecek bir hedefi var', () {
      // Hedefsiz rehberli adım = ekranda hiçbir yeri göstermeyen bir spot.
      for (final q in QuestBook.all.where((q) => q.guided)) {
        expect(
          q.buildTarget != null || q.uiTarget != QuestUi.none,
          isTrue,
          reason: '${q.id} rehberli ama gösterecek bir şeyi yok',
        );
      }
    });

    test('kuruluş adımlarının çoğunu bir kurucu ister', () {
      final withSpeaker = tier0().where((q) => q.speaker != null).length;
      expect(
        withSpeaker,
        greaterThanOrEqualTo(tier0().length ~/ 2),
        reason: 'görevler yeniden isimsiz bir alışveriş listesine dönmüş',
      );
    });

    test('ilk gece ikinci güne çıkınca tamamlanır', () {
      final q = QuestBook.all.firstWhere((q) => q.id == 'firstNight');
      expect(q.check(_ctx(dayCount: 1)), isFalse);
      expect(q.check(_ctx(dayCount: 2)), isTrue);
    });

    test('çadır ile ev AYNI görevi doldurmaz', () {
      // İkisi de housing rolü; tek kontrole bağlansalardı bir çadır iki görevi
      // birden kapatır ve merdiven bir basamak boş geçerdi.
      final tent = QuestBook.all.firstWhere((q) => q.id == 'tent');
      final house = QuestBook.all.firstWhere((q) => q.id == 'house');
      expect(tent.check, isNot(same(house.check)));
    });

    test('oduncu görevi kulübe dikilince değil ilk kütük inince biter', () {
      final q = QuestBook.all.firstWhere((q) => q.id == 'lumber');
      final camp = BuildingEntity(
        type: BuildingType.lumberCamp,
        col: 1,
        row: 1,
      );
      expect(q.check(_ctx()), isFalse);
      expect(q.check(_ctx(buildings: [camp])), isFalse);
      expect(q.check(_ctx(buildings: [camp], woodHarvested: 1)), isTrue);
    });

    test('isteyen köylü yaşıyorsa adı panele düşer, yoksa düşmez', () {
      final q = QuestBook.all.firstWhere((q) => q.id == 'firepit');
      final speaker = q.speaker!;
      final withName = QuestBook.activeQuests(
        _ctx(names: {speaker: 'Dede'}),
        const {},
      );
      expect(withName.first.speakerName, 'Dede');
      // Kurucu öldü → görev isimsiz ama YİNE DE listede.
      final without = QuestBook.activeQuests(_ctx(), const {});
      expect(without.first.speakerName, isNull);
      expect(without.first.quest.id, 'firepit');
    });
  });
}
