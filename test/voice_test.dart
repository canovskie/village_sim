import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/text/voice.dart';

void main() {
  test('ünlü uyumu + ünsüz sertleşmesi', () {
    expect(withSuffix('İlyas', Suffix.genitive), "İlyas'ın");
    expect(withSuffix('Ayşe', Suffix.genitive), "Ayşe'nin");
    expect(withSuffix('Kumru', Suffix.genitive), "Kumru'nun");
    expect(withSuffix('Gülsüm', Suffix.genitive), "Gülsüm'ün");
    expect(withSuffix('Mehmet', Suffix.dative), "Mehmet'e");
    expect(withSuffix('Hasan', Suffix.dative), "Hasan'a");
    expect(withSuffix('Ayşe', Suffix.dative), "Ayşe'ye");
    expect(withSuffix('Zeynep', Suffix.ablative), "Zeynep'ten"); // sert p → t
    expect(withSuffix('Hasan', Suffix.ablative), "Hasan'dan");
    expect(withSuffix('Mehmet', Suffix.locative), "Mehmet'te");
    expect(withSuffix('Ayşe', Suffix.accusative), "Ayşe'yi");
    expect(withSuffix('Yusuf', Suffix.accusative), "Yusuf'u");
    expect(withSuffix('Ayşe', Suffix.instrumental), "Ayşe'yle");
    expect(withSuffix('Demir', Suffix.instrumental), "Demir'le");
  });

  test('dokuma + havuz', () {
    const c = VoiceCtx(seed: 3, name: 'İlyas', other: 'Ayşe', profession: 'Demirci');
    expect(Voice.weave('{ad-in} örsü soğudu; {öteki-e} haber saldı.', c),
        "İlyas'ın örsü soğudu; Ayşe'ye haber saldı.");
    // eksik bağlam → "null" yazmaz
    expect(Voice.weave('{hane} küstü.', const VoiceCtx(seed: 1)), 'bir hane küstü.');
    // aynı seed → aynı varyant (kayıt/yükleme tutarlılığı)
    final pool = ['bir', 'iki', 'üç', 'dört'];
    expect(Voice.pick(pool, 42), Voice.pick(pool, 42));
    // farklı seed'ler havuzu gerçekten dolaşıyor mu
    expect({for (var i = 0; i < 40; i++) Voice.pick(pool, i)}.length, greaterThan(1));
  });
}
