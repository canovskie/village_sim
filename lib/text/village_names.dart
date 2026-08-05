import 'dart:math';

/// KÖYÜN ADI — anlamı olan ad havuzu.
///
/// Kuruluşta oyuncuya boş bir kutu uzatılıyordu ("örn. Pınarköy") ve içine ne
/// yazılırsa yazılsın ad hiçbir şey ifade etmiyordu. Anadolu'da köy adı asla
/// keyfî değildir: yer neyle tanınıyorsa adını ondan alır — suyun gözünden,
/// sırttaki kayadan, dere boyu söğütten. Bu havuz o mantığı geri getirir:
/// her öneri, adın NEDEN o ad olduğunu tek cümleyle söyler.
///
/// KURAL — serbest yazı kaldırılmadı. Öneriler yalnız bir başlangıç: oyuncu
/// kendi adını yazarsa köy onu taşır. Öneri kutuyu doldurur, kilitlemez.
///
/// KURAL — buradaki adların hiçbiri hane (soy) adı havuzuyla çakışmamalı
/// (bkz. `characters/villager_names.dart`). Aynı kelime hem köyün hem kurucu
/// soyun adı olursa "Akpınar, Akpınar Hanesi'ni dinledi" gibi cümleler çıkar ve
/// oyuncu ikisini ayırt edemez.
class VillageNameIdea {
  /// Adın kendisi — kutuya bu yazılır.
  final String name;

  /// Adın NEREDEN geldiği. Tek cümle, köylü ağzı; ansiklopedi maddesi değil.
  final String meaning;

  const VillageNameIdea(this.name, this.meaning);
}

/// Ad havuzu — hepsi şeffaf etimolojili Anadolu köy adı kalıpları.
/// (-lı/-lu: neyle dolu; -ca/-ce: neye benzer; baş: kaynağın başı; cık: küçüğü.)
const List<VillageNameIdea> kVillageNameIdeas = [
  VillageNameIdea(
    'Pınarbaşı',
    'Suyun gözü tam burada açılır — ilk kova hep buradan dolar.',
  ),
  VillageNameIdea(
    'Çamlıca',
    'Sırtı baştan aşağı çam: gölge de yakın, kereste de.',
  ),
  VillageNameIdea(
    'Gölbaşı',
    'Suyun kıyısına kurulmuş; sabah sisi öğlene kadar dağılmaz.',
  ),
  VillageNameIdea(
    'Söğütlü',
    'Dere boyu söğüt: kökü toprağı tutar, dalı sepet olur.',
  ),
  VillageNameIdea(
    'Taşköprü',
    'Dereyi bir taş kemer bağlar; yolcu buradan geçmek zorunda.',
  ),
  VillageNameIdea(
    'Ovacık',
    'İki sırtın arasındaki küçük ova — rüzgâr kırılır, ekin durur.',
  ),
  VillageNameIdea(
    'Yenice',
    'Adı bile "daha dün geldik" der; en yeni ocak burada tütüyor.',
  ),
  VillageNameIdea(
    'Kayabaşı',
    'Sırttaki kaya uzaktan görünür; yolcuya işaret, köye ad olur.',
  ),
  VillageNameIdea(
    'Çiğdemli',
    'Çayır ilkbaharda çiğdemle sararır; kışın bittiğini o söyler.',
  ),
  VillageNameIdea(
    'Ilıca',
    'Yerden ılık su çıkar — kışın el yıkanacak tek yer burasıdır.',
  ),
  VillageNameIdea(
    'Gökpınar',
    'Suyu gök rengi görünür, demek ki kaynağı derinden gelir.',
  ),
  VillageNameIdea(
    'Harmanlı',
    'Harman yeri geniş, rüzgârı tam kararında: ekin burada savrulur.',
  ),
  VillageNameIdea(
    'Kavaklı',
    'Sıra sıra kavak; köy görünmeden önce ağaçları görünür.',
  ),
  VillageNameIdea(
    'Ardıçlı',
    'Ardıç çürümez — kapı direği de mezar taşı da ondan yapılır.',
  ),
  VillageNameIdea(
    'Ayvalı',
    'Ayva ekşi toprakta bile durur; kışlık meyve odur.',
  ),
  VillageNameIdea(
    'Değirmenli',
    'Dere değirmen çevirecek kadar hızlı akar; un burada öğütülür.',
  ),
];

/// Havuzun karışık bir kopyası. Kuruluş kapısı bunu BİR KEZ alır ve üçerli
/// pencerelerle gezdirir ("başka" düğmesi) — her karede yeniden karıştırmak
/// kartları zıplatır.
List<VillageNameIdea> shuffledVillageNameIdeas([Random? rng]) =>
    List<VillageNameIdea>.of(kVillageNameIdeas)..shuffle(rng ?? Random());

/// Yazılan ad havuzdaysa anlamını verir — oyuncu öneriyi seçmeden elle yazsa da
/// (ya da bir öneriyi düzeltse de) köy ona adının nereden geldiğini söyler.
String? meaningOfVillageName(String name) {
  final needle = name.trim().toLowerCase();
  if (needle.isEmpty) return null;
  for (final idea in kVillageNameIdeas) {
    if (idea.name.toLowerCase() == needle) return idea.meaning;
  }
  return null;
}
