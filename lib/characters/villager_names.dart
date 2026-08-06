import 'dart:math';

/// Erkek köylü isim havuzu (Anadolu Türk).
const List<String> _kMaleNames = [
  'Ahmet', 'Mehmet', 'Mustafa', 'Hasan', 'Hüseyin', 'Ali', 'Veli',
  'Recep', 'Ömer', 'Süleyman', 'İbrahim', 'Yusuf', 'Halil', 'Murat',
  'Selim', 'Bekir', 'Kemal', 'Sefer', 'Davut', 'Yakup',
];

/// Kadın köylü isim havuzu (Anadolu Türk).
const List<String> _kFemaleNames = [
  'Ayşe', 'Fatma', 'Hatice', 'Emine', 'Zeynep', 'Meryem', 'Elif',
  'Saliha', 'Naime', 'Hanife', 'Sultan', 'Şerife', 'Esma', 'Rabia',
  'Hayriye', 'Nazlı', 'Gül', 'Münire', 'Adviye', 'Cemile',
];

/// Cinsiyete uygun rastgele isim seçer. [male] true → erkek havuzu,
/// false → kadın havuzu. Ad ve visual.isMale kesinlikle uyumlu olsun diye
/// caller önce gender'a karar verir, isim ve visual'ı buna göre üretir.
String randomVillagerName(Random rng, {required bool male}) {
  final pool = male ? _kMaleNames : _kFemaleNames;
  return pool[rng.nextInt(pool.length)];
}

/// Hane (soy) adı havuzu — "her soy bir hane". Kurucu/göçmen yeni bir hane
/// açar; doğan çocuk baba (yoksa anne) tarafının hanesini miras alır.
const List<String> _kSurnames = [
  'Demirhan', 'Akpınar', 'Karaca', 'Yıldırım', 'Gündoğdu', 'Yeşilova',
  'Boztepe', 'Çakır', 'Karaağaç', 'Aydın', 'Seferoğlu', 'Doğan',
  'Toprak', 'Korkut', 'Alpay', 'Bozok', 'Sarıca', 'Demirtaş',
  'Yörük', 'Uçar', 'Duran', 'Bağcı',
];

/// Yeni bir soyun (kurucu/göçmen) hane adını rastgele seçer.
String randomVillagerSurname(Random rng) =>
    _kSurnames[rng.nextInt(_kSurnames.length)];

// pickDistinctSurnames() kurucuları AYRI hanelere dağıtmak içindi; köy artık
// TEK AİLE ile kuruluyor (yeni hane yalnız dışarıdan gelir) → çağıranı kalmadı.
