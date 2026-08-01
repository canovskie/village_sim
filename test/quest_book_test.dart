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
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/entities/villager_job.dart';
import 'package:village_sim/scene/scene_data.dart';
import 'package:village_sim/systems/quest_book.dart';

QuestContext _ctx({
  int charterTier = 0,
  int dayCount = 1,
  bool everCooked = false,
  int berriesPicked = 0,
  Set<JobRole> assigned = const {},
  Map<VillagerType, String> names = const {},
}) =>
    QuestContext(
      buildings: const [],
      farmTiles: const [],
      population: 0,
      stock: ResourceBundle(),
      policies: VillagePolicies(),
      decorCount: 0,
      charterTier: charterTier,
      dayCount: dayCount,
      everCooked: everCooked,
      berriesPicked: berriesPicked,
      playerAssignedRoles: assigned,
      speakerNames: names,
    );

void main() {
  group('merdiven kilitlenmez', () {
    test('her kademe eşiği altındaki görevlerle karşılanabilir', () {
      // i. kademeye geçerken elde olabilecek en fazla görev: tier <= i-1 olan
      // TÜM görevler (üst kademe görevleri henüz açılmamıştır).
      for (var i = 1; i < QuestBook.tiers.length; i++) {
        final reachable =
            QuestBook.all.where((q) => q.tier <= i - 1).length;
        expect(QuestBook.tiers[i].minQuests, lessThanOrEqualTo(reachable),
            reason: '"${QuestBook.tiers[i].name}" kademesi '
                '${QuestBook.tiers[i].minQuests} görev istiyor ama o noktaya '
                'kadar yalnız $reachable görev açılıyor. Merdiven burada '
                'kilitlenir: kademe hiç gelmez, üstündeki görevler hiç açılmaz.');
      }
    });

    test('eşikler nefes payı bırakır — tavan "hepsi hariç biri" olamaz', () {
      // Bir kademe, altındaki görevlerin NEREDEYSE hepsini isterse, isteğe
      // bağlı tek bir görevi atlayan oyuncu kalıcı olarak takılır. Geç
      // kademelerde en az 3 görevlik pay şart.
      for (var i = 4; i < QuestBook.tiers.length; i++) {
        final reachable = QuestBook.all.where((q) => q.tier <= i - 1).length;
        expect(reachable - QuestBook.tiers[i].minQuests,
            greaterThanOrEqualTo(3),
            reason: '"${QuestBook.tiers[i].name}" eşiği çok dar: '
                '$reachable görevin ${QuestBook.tiers[i].minQuests} tanesi '
                'zorunlu. İsteğe bağlı bir görevi atlayan oyuncu tavana çarpar.');
      }
    });

    test('eşikler yukarı doğru gevşemez', () {
      for (var i = 1; i < QuestBook.tiers.length; i++) {
        expect(QuestBook.tiers[i].minQuests,
            greaterThanOrEqualTo(QuestBook.tiers[i - 1].minQuests));
        expect(QuestBook.tiers[i].minPolicies,
            greaterThanOrEqualTo(QuestBook.tiers[i - 1].minPolicies));
      }
    });

    test('her kademede en az bir görev var', () {
      for (var i = 0; i < QuestBook.tiers.length; i++) {
        expect(QuestBook.all.any((q) => q.tier == i), isTrue,
            reason: '${QuestBook.tiers[i].name} kademesinde hiç görev yok — '
                'oyuncu oraya çıkıp boş bir panel görür');
      }
    });

    test('görev var olmayan kademeye asılı kalmaz', () {
      for (final q in QuestBook.all) {
        expect(q.tier, inInclusiveRange(0, QuestBook.maxTier),
            reason: '${q.id} görevi ${q.tier}. kademede ama merdiven '
                '${QuestBook.maxTier}. kademede bitiyor → görev hiç açılmaz');
      }
    });
  });

  test('görev id\'leri tekil', () {
    final ids = QuestBook.all.map((q) => q.id).toList();
    expect(ids.toSet().length, ids.length,
        reason: 'tekrar eden id: tamamlanma seti tek girdi tutar, '
            'ikinci görev sessizce ölü kalır');
  });

  group('kademe hesabı', () {
    test('sıfır ilerleme sıfırıncı kademe', () {
      expect(QuestBook.charterTier(0, 0), 0);
    });

    test('eşik dolunca kademe atlar, dolmadan atlamaz', () {
      for (var i = 1; i < QuestBook.tiers.length; i++) {
        final t = QuestBook.tiers[i];
        expect(QuestBook.charterTier(t.minQuests, t.minPolicies),
            greaterThanOrEqualTo(i),
            reason: '${t.name} eşiği tam dolduğunda kademe gelmedi');
        if (t.minQuests > 0) {
          expect(QuestBook.charterTier(t.minQuests - 1, t.minPolicies),
              lessThan(i),
              reason: '${t.name} eşiği eksikken kademe verildi');
        }
      }
    });

    test('her şey tamamlanınca son kademeye çıkılır', () {
      expect(QuestBook.charterTier(QuestBook.all.length, 99), QuestBook.maxTier);
    });

    test('son kademede sonraki kademe yok', () {
      expect(QuestBook.nextTier(QuestBook.maxTier), isNull);
      expect(QuestBook.nextTier(0), isNotNull);
    });
  });

  test('görev listesi yalnız açık kademeyi gösterir', () {
    final open = QuestBook.activeQuests(_ctx(), const {});
    expect(open.every((s) => s.quest.tier == 0), isTrue,
        reason: 'kademe 0\'daki oyuncuya üst kademe görevi gösteriliyor');
    expect(open.first.active, isTrue, reason: 'ilk görev vurgulanmalı');
  });

  // ── KURULUŞ KADEMESİ ───────────────────────────────────────────────────────
  // Buradaki sözleşme bir sayı değil bir TASARIM: erken oyunun boş hissetmesinin
  // sebebi kuruluşun beş "bina dik" görevinden ibaret olmasıydı. Biri o beşe
  // geri dönerse ya da adımları bina-only hâle getirirse burası kırılmalı.
  group('kuruluş kademesi boş bırakmaz', () {
    List<Quest> tier0() => QuestBook.all.where((q) => q.tier == 0).toList();

    test('kuruluşta en az 10 mikro adım var', () {
      expect(tier0().length, greaterThanOrEqualTo(10),
          reason: 'kuruluş yeniden beş adıma inerse oyuncu ilk on dakikayı '
              'yine bekleyerek geçirir — boşluğun kaynağı buydu');
    });

    test('kuruluş yalnız bina dikmekten ibaret değil', () {
      // En az bir KARAR adımı (oyuncunun birine iş vermesi) ve en az bir
      // SONUÇ adımı (o işin ürünü) olmalı.
      final ids = tier0().map((q) => q.id).toSet();
      expect(ids.contains('giveBasket'), isTrue,
          reason: 'kuruluşta oyuncunun bir KARAR verdiği adım kalmamış');
      expect(ids.contains('firstBerries'), isTrue,
          reason: 'kuruluşta kararın SONUCUNU gösteren adım kalmamış');
    });

    test('kuruluş adımlarının çoğunu bir kurucu ister', () {
      final withSpeaker = tier0().where((q) => q.speaker != null).length;
      expect(withSpeaker, greaterThanOrEqualTo(tier0().length ~/ 2),
          reason: 'görevler yeniden isimsiz bir alışveriş listesine dönmüş');
    });

    test('elle atama görevi OTOMATİK işle tamamlanmaz', () {
      // Boş küme = oyuncu kimseye iş vermedi. Köy kendiliğinden birini
      // toplayıcı yapsa bile bu görev açık kalmalı.
      final q = QuestBook.all.firstWhere((q) => q.id == 'giveBasket');
      expect(q.check(_ctx()), isFalse);
      expect(q.check(_ctx(assigned: {JobRole.forager})), isTrue);
    });

    test('ilk sepet STOĞA değil kümülatif toplamaya bakar', () {
      final q = QuestBook.all.firstWhere((q) => q.id == 'firstBerries');
      expect(q.check(_ctx(berriesPicked: 0)), isFalse);
      // Toplandı ama hepsi yenmiş olsa bile görev geri alınmaz.
      expect(q.check(_ctx(berriesPicked: 1)), isTrue);
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

    test('isteyen köylü yaşıyorsa adı panele düşer, yoksa düşmez', () {
      final q = QuestBook.all.firstWhere((q) => q.id == 'firepit');
      final speaker = q.speaker!;
      final withName = QuestBook.activeQuests(
          _ctx(names: {speaker: 'Dede'}), const {});
      expect(withName.first.speakerName, 'Dede');
      // Kurucu öldü → görev isimsiz ama YİNE DE listede.
      final without = QuestBook.activeQuests(_ctx(), const {});
      expect(without.first.speakerName, isNull);
      expect(without.first.quest.id, 'firepit');
    });
  });
}
