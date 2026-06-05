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
