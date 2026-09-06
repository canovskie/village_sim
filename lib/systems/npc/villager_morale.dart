/// Bireysel köylü moralinin KOŞUL formülü. Saf/yan-etkisiz: girdi koşullarından
/// bir hedef moral (0..1) + baskın sebep etiketi üretir. Sahne (`scene_tick`)
/// her köylü için ~1sn'de bir çağırır ve `VillagerEntity.morale`'i bu hedefe
/// yavaşça süzer. Yaşam olaylarının anlık etkisi ayrıca `feel(moodDelta)`
/// üzerinden gelir (bkz. villager_entity).
///
/// Cozy/no-fail: değerler ölçülü; en kötü koşul yığını bile moralı ~0.1'in
/// altına nadiren indirir, toparlama hızlıdır.
library;

class MoraleEval {
  final double target; // 0..1
  final String reason; // panelde gösterilecek baskın sebep
  const MoraleEval(this.target, this.reason);
}

/// [houseMood] köylünün HANESİNİN morali (0..1, ~0.55 nötr) — hanesine nasıl
/// davrandığın üyelerinin moraline geri döner.
/// [elderRespected] yaşlı + "huzur/saygı" politikası aktif.
MoraleEval evaluateVillagerMorale({
  required bool homeless,
  required bool starving,
  required bool lowWater,
  required bool cold, // gece + ateş/ısı yok
  required double houseMood,
  required bool elderRespected,
  bool callingMismatch = false, // mesleği içindeki çağrıya uymuyor (kırgınlık)
  bool feudMember = false, // bir kan davasının içinde (sürekli tehdit/gerilim)
  bool injured = false, // kavgada yaralı (akut ağrı/iş göremezlik)
  bool poorHousing = false, // evi var ama çadır gibi derme çatma (düşük konfor)
  // Kışın ocağın sıcağı ulaşmayan çadır: bezin altında ısınacak hiçbir şey yok.
  // Yalnız [poorHousing] ile birlikte anlamlıdır (bkz. hearth_warmth).
  bool coldShelter = false,
  bool comfortHousing = false, // taş konut: Köy Evi'nden konforlu (hafif moral+)
  bool luxuryHousing = false, // konak: en lüks yuva (güçlü moral+)
  // Köyün AMENİTE morali — civic binaların (taverna/kilise/kuyu/kütüphane…)
  // toplam katkısı, doyuma sokulmuş hâlde. Tek kaynak: VillageStats.amenityMorale
  // (bkz. building_system.amenityMoraleFrom). Burada tekrar bina sayılmaz.
  double amenityMorale = 0.0,
}) {
  const base = 0.62;
  double t = base;

  // Negatif koşullar (sebep adayları, büyüklükçe).
  final neg = <(double, String)>[];
  if (homeless) {
    t -= 0.30;
    neg.add((0.30, 'evsiz'));
  } else if (poorHousing) {
    // Çadır vb. derme çatma barınak: evsizlik kadar ağır değil ama gerçek
    // bir evin huzurunu da vermez. Köylü "bir çatı altında" ama hoşnutsuz.
    // Ocağa yakınlığın karşılığı ayrı bir terimdir (bkz. [coldShelter]).
    t -= 0.10;
    neg.add((0.10, 'çadırda'));
  } else if (luxuryHousing) {
    // Konak: lüks bir yuvada yaşamanın huzuru — belirgin moral bonusu.
    t += 0.12;
  } else if (comfortHousing) {
    // Taş konut: Köy Evi'nden konforlu — ölçülü moral bonusu.
    t += 0.06;
  }
  // ÇADIR + KIŞ + OCAKTAN UZAK. Çadırın kendi ocağı yoktur; kışın ısınmasının
  // tek yolu köyün ateşinin yakınında kurulmuş olmaktır. Uzaktaki çadır sabaha
  // kadar üşür ve bu, "çadırda" olmanın üstüne biner (0.10 + 0.13 = 0.23) —
  // ama yine de evsizlikten (0.30) hafif kalır: bir dam, kötü de olsa, damdır.
  if (coldShelter) {
    t -= 0.13;
    neg.add((0.13, 'çadırı ateşten uzak'));
  }
  if (starving) {
    t -= 0.26;
    neg.add((0.26, 'aç'));
  }
  if (cold) {
    t -= 0.16;
    neg.add((0.16, 'üşüyor'));
  }
  if (lowWater) {
    t -= 0.14;
    neg.add((0.14, 'susuz'));
  }
  // Çağrı kırgınlığı: çağrısına rağmen başka mesleğe çekilen köylü, temel
  // ihtiyaçları karşılansa bile sürekli hafif huzursuzdur (gönlü başka işte).
  if (callingMismatch) {
    t -= 0.10;
    neg.add((0.10, 'gönlü başka işte'));
  }
  // Kan davası: sürekli husumet/tehdit altında yaşamak ağır basar.
  if (feudMember) {
    t -= 0.16;
    neg.add((0.16, 'kan davası'));
  }
  // Yaralı: ağrı + iş göremezlik morali düşürür (iyileşince geçer).
  if (injured) {
    t -= 0.14;
    neg.add((0.14, 'yaralı'));
  }

  // Hane durumu: memnun hane üyesini kaldırır, küskün hane çeker (±~0.18).
  final houseShift = (houseMood - 0.55) * 0.42;
  t += houseShift;

  // Yaşlıya saygı politikası.
  if (elderRespected) t += 0.08;

  // Amenite: köyün civic binaları (taverna, kilise, kuyu, çiçekçi, kütüphane,
  // hamam, anıt, şadırvan, türbe, çan) köylüyü "yaşanası bir yerde" hissettirir.
  // Ağırlıklar bina tablosundan gelir, doyum çağıran tarafta uygulanmıştır —
  // burası yalnız toplar.
  t += amenityMorale;

  t = t.clamp(0.0, 1.0);

  // Baskın sebep: en büyük negatif; yoksa zümre/seviye temelli olumlu etiket.
  String reason;
  if (neg.isNotEmpty) {
    neg.sort((a, b) => b.$1.compareTo(a.$1));
    reason = neg.first.$2;
  } else if (houseShift < -0.05) {
    reason = 'hanesi küskün';
  } else if (luxuryHousing && t >= 0.7) {
    reason = 'konağında huzurlu';
  } else if (t >= 0.75) {
    reason = 'huzurlu';
  } else if (t >= 0.5) {
    reason = 'hoşnut';
  } else {
    reason = 'idare ediyor';
  }

  return MoraleEval(t, reason);
}
