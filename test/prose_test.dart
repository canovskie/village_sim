import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/crime_system.dart';
import 'package:village_sim/systems/event_system.dart';
import 'package:village_sim/systems/petition_system.dart';
import 'package:village_sim/text/voice.dart';
import 'package:village_sim/world/season.dart';

/// Metin gövdesinin bütünü: her dilekçe/olay, gerçek bir köylü bağlamıyla
/// konuşturulunca oyuncuya TEMİZ Türkçe cümle çıkmalı — ham `{yer-tutucu}`,
/// boş metin veya tanınmayan anahtar kalmamalı.
void main() {
  const ctx = VoiceCtx(
    seed: 7,
    name: 'İlyas',
    other: 'Ayşe',
    profession: 'Demirci',
    house: 'Karaoğlan',
    estate: 'Emekçiler',
    village: 'Bahçeköy',
    season: Season.winter,
    day: 41,
  );

  test('37 dilekçe: konuşturulunca ham yer tutucu kalmıyor', () {
    final all = PetitionSystem.allForTest;
    expect(all.length, greaterThanOrEqualTo(30));
    for (final raw in all) {
      // Her dilekçeyi BÜTÜN varyantlarıyla dolaş — biri bile bozuksa yakala.
      for (var s = 0; s < 12; s++) {
        final p = raw.spoken(
          VoiceCtx(
            seed: s,
            name: ctx.name,
            other: ctx.other,
            profession: ctx.profession,
            house: ctx.house,
            estate: ctx.estate,
            village: ctx.village,
            season: ctx.season,
            day: ctx.day,
          ),
        );
        final texts = <String>[
          p.title,
          p.body,
          p.petitioner,
          p.stakes ?? '',
          p.note ?? '',
          for (final o in p.options) ...[o.label, o.detail, o.resolution],
        ];
        for (final t in texts) {
          expect(
            t.contains('{'),
            isFalse,
            reason: 'DOKUNMAMIŞ yer tutucu — dilekçe "${raw.id}": $t',
          );
          expect(
            t.contains('}'),
            isFalse,
            reason: 'bozuk yer tutucu: ${raw.id}',
          );
        }
        expect(p.body.trim(), isNotEmpty, reason: 'boş gövde: ${raw.id}');
        expect(p.title.trim(), isNotEmpty, reason: 'boş başlık: ${raw.id}');
        for (final o in p.options) {
          expect(o.label.trim(), isNotEmpty, reason: 'boş buton: ${raw.id}');
        }
      }
    }
  });

  test('dilekçe gövdeleri gerçekten çeşitleniyor (ezber kırılmış)', () {
    for (final raw in PetitionSystem.allForTest) {
      final seen = {
        for (var s = 0; s < 30; s++)
          raw
              .spoken(VoiceCtx(seed: s, name: 'İlyas', profession: 'Demirci'))
              .body,
      };
      expect(
        seen.length,
        greaterThan(1),
        reason: '"${raw.id}" her seferinde AYNI cümleyi veriyor — havuz yok',
      );
    }
  });

  test('dilekçelerde dış kaynak yalnızca kervan üzerinden anlatılıyor', () {
    final undefinedPlace = RegExp(
      r'komşu (köy|kasaba|vadi)|komşudan (odun|elçi)',
      caseSensitive: false,
    );
    for (final p in PetitionSystem.allForTest) {
      final texts = <String>[
        p.title,
        p.petitioner,
        ...p.bodyPool,
        for (final o in p.options) ...[o.label, o.detail, ...o.resolutionPool],
      ];
      for (final text in texts) {
        expect(
          undefinedPlace.hasMatch(text),
          isFalse,
          reason: '${p.id} oyuncuya tanımlanmamış bir dış yer satıyor: $text',
        );
      }
    }

    final wood = PetitionSystem.byId('woodLow')!;
    final purchase = wood.options.first;
    expect(purchase.label, contains('Kervandan'));
    expect(purchase.goldDelta, -6);
    expect(purchase.woodDelta, 8);

    for (final id in [
      'woodLow',
      'fireDied',
      'lateLostCraft',
      'herdAilment',
      'neighborEnvoy',
    ]) {
      final petition = PetitionSystem.byId(id)!;
      final prose = [
        petition.petitioner,
        ...petition.bodyPool,
        for (final option in petition.options) ...[
          option.label,
          option.detail,
          ...option.resolutionPool,
        ],
      ].join(' ');
      expect(
        prose.toLowerCase(),
        contains('kervan'),
        reason: '$id dış kaynağı belirsiz',
      );
    }
  });

  test('10 suç: bütün havuzlar dokunuyor, ham yer tutucu sızmıyor', () {
    final all = CrimeSystem.all;
    expect(all.length, 10);
    // Suç metinleri failin/kurbanın adına ve OLAY YERİNE ({yer}) dokunur.
    for (final def in all) {
      for (var s = 0; s < 12; s++) {
        final c = VoiceCtx(
          seed: s,
          name: ctx.name,
          other: ctx.other,
          profession: ctx.profession,
          house: ctx.house,
          estate: ctx.estate,
          village: ctx.village,
          season: ctx.season,
          day: ctx.day,
          extra: const {'yer': 'Ambar'},
        );
        final texts = <String>[
          Voice.say(def.hintPool, c),
          Voice.say(def.deedPool, c),
          Voice.say(def.annalPool, c),
          Voice.say(def.caughtAnnalPool, c),
        ];
        for (final t in texts) {
          expect(
            t.trim(),
            isNotEmpty,
            reason: 'boş suç metni: ${def.kind.name}',
          );
          expect(
            t.contains('{'),
            isFalse,
            reason: 'DOKUNMAMIŞ yer tutucu — suç "${def.kind.name}": $t',
          );
          expect(
            t.contains('}'),
            isFalse,
            reason: 'bozuk yer tutucu: ${def.kind.name}',
          );
        }
      }
      // Her havuz gerçekten çeşitlenmeli (tek string yazılmamış).
      final seen = {
        for (var s = 0; s < 30; s++)
          Voice.say(
            def.deedPool,
            VoiceCtx(seed: s, name: 'İlyas', other: 'Ayşe'),
          ),
      };
      expect(
        seen.length,
        greaterThan(1),
        reason: '"${def.kind.name}" hep aynı cümleyi veriyor — havuz yok',
      );
    }
  });

  test('olaylar: mesaj + omen havuzları dolu, yer tutucu sızmıyor', () {
    for (final e in EventSystem.events) {
      expect(
        e.id.trim(),
        isNotEmpty,
        reason: 'olayın stabil id\'si yok: ${e.title}',
      );
      for (var s = 0; s < 8; s++) {
        final m = e.messageFor(s);
        expect(m.trim(), isNotEmpty, reason: 'boş olay mesajı: ${e.id}');
        expect(
          m.contains('{'),
          isFalse,
          reason: 'ham yer tutucu: ${e.id} → $m',
        );
      }
    }
  });
}
