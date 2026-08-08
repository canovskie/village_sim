import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/scene/scene_data.dart';
import 'package:village_sim/systems/chronicle.dart';
import 'package:village_sim/systems/law_book.dart';
import 'package:village_sim/systems/petition_system.dart';
import 'package:village_sim/text/voice.dart';

/// KARARIN İZİ — saf taraf.
///
/// Sorulan şey tek cümle: **oyuncunun verdiği her karar geriye bir kayıt
/// bırakabiliyor mu, ve o kayıt kaybolmadan (kayıt/yükleme, fesih) yaşıyor mu?**
/// Sahnede gerçekten YAZILDIĞINI prova testi kanıtlar
/// (test/decision_trace_probe_test.dart) — burası sözleşmenin kendisi.
void main() {
  group('kronik türü', () {
    test('tür kayda yazılır ve kayıttan aynen döner', () {
      const e = ChronicleEntry(
          day: 12,
          icon: '⚖',
          text: 'Nöbet başladı.',
          kind: ChronicleKind.decision);
      final back = ChronicleEntry.fromJson(e.toJson());
      expect(back.kind, ChronicleKind.decision);
      expect(back.day, 12);
      expect(back.text, 'Nöbet başladı.');
    });

    test('eski kayıtta tür yok → köyün yaşadığı sayılır (migrasyon)', () {
      final old = ChronicleEntry.fromJson(const {
        'day': 3,
        'icon': '📜',
        'text': 'Kuyu açıldı.',
      });
      expect(old.kind, ChronicleKind.life);
    });

    test('varsayılan tür JSON\'a yazılmaz — defter şişmesin', () {
      const e = ChronicleEntry(day: 1, icon: '📜', text: 'x');
      expect(e.toJson().containsKey('k'), isFalse);
    });
  });

  group('dilekçe şıkkının annali', () {
    test('her şık ya annal ya da çözüm cümlesi taşır — kararsız kayıt olmaz',
        () {
      // Bu iddia "her şıkka metin yazıldı" demek DEĞİL: sahne çözüm cümlesini
      // günceye çevirebiliyor (bkz. _chronicleDecision). Boş kalan bir şık
      // günceye "Başlık: Şık" diye kuru bir satır düşürür — testin engellediği
      // şey ikisinin de olmaması değil, ikisinin de BOŞ kalıp fark edilmemesi.
      final mute = <String>[];
      for (final p in PetitionSystem.all) {
        for (final o in p.options) {
          if (o.annal.trim().isEmpty && o.resolution.trim().isEmpty) {
            mute.add('${p.id} → ${o.label}');
          }
        }
      }
      expect(mute, isEmpty,
          reason: 'bu şıklar günceye ancak kuru bir başlık düşürür; '
              'annalPool yaz: ${mute.join(', ')}');
    });

    test('annal havuzu bağlamla dokunur (spoken)', () {
      const raw = PetitionOption(
        label: 'Kabul et',
        detail: '...',
        resolutionPool: ['oldu'],
        annalPool: ['{ad} dinlendi. Köy sustu.'],
      );
      final spoken = raw.spoken(const VoiceCtx(name: 'Yusuf', seed: 3));
      expect(spoken.annal, contains('Yusuf'));
      expect(spoken.annal, isNot(contains('{ad}')));
    });

    test('annal yazılmamışsa boş kalır — uydurma cümle üretilmez', () {
      const raw = PetitionOption(
          label: 'Kabul et', detail: '...', resolutionPool: ['oldu']);
      expect(raw.annal, isEmpty);
      expect(raw.spoken(const VoiceCtx(seed: 1)).annal, isEmpty);
    });
  });

  group('mühür günü', () {
    LawDef anyLaw() => kLawBook.first;
    LawDef otherLaw() => kLawBook[1];

    test('mühür günü damgalanır', () {
      final p = VillagePolicies();
      p.seal(anyLaw(), day: 41);
      expect(p.sealedOn[anyLaw().id], 41);
    });

    test('gün verilmezse damga yazılmaz (hazır kurulmuş köy)', () {
      final p = VillagePolicies();
      p.seal(anyLaw());
      expect(p.sealedOn, isEmpty);
      expect(p.sealed, contains(anyLaw().id));
    });

    test('kayıttan dönüşte damgalar geri kurulur', () {
      final p = VillagePolicies();
      p.restoreSealed([anyLaw().id], days: {anyLaw().id: 7});
      expect(p.sealedOn[anyLaw().id], 7);
    });

    test('fesihte damga da defterden düşer, kalanlar durur', () {
      final p = VillagePolicies();
      p.seal(anyLaw(), day: 5);
      p.seal(otherLaw(), day: 9);
      // Fesih yolu: gün haritası GEÇİLMEDEN sealed yeniden kurulur.
      p.restoreSealed([otherLaw().id]);
      expect(p.sealedOn.containsKey(anyLaw().id), isFalse,
          reason: 'feshedilen fermanın gün damgası defterde kalmamalı');
      expect(p.sealedOn[otherLaw().id], 9,
          reason: 'başka fermanın damgası fesihten etkilenmemeli');
    });
  });
}
