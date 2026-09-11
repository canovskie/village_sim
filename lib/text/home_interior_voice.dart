part of 'voice.dart';

abstract final class HomeInteriorVoice {
  static String get title => Voice.pick(['Evin içi', 'Evin yaşamı'], 0);
  static String get lab =>
      Voice.pick(['Ev içi denemesi', 'Ev yaşamı denemesi'], 0);
  static String get enter => Voice.pick(['İçeri bak', 'Evi izle'], 0);
  static String get outside =>
      Voice.pick(['Dışarı çık', 'Eve dışarıdan bak'], 0);
  static String get manage => Voice.pick(['Ev bilgileri', 'Evin durumu'], 0);
  static String get close => Voice.pick(['Kapat', 'Köye dön'], 0);
  static String get daily => Voice.pick(['Gündelik yaşam', 'Evde bir gün'], 0);
  static String get supper => Voice.pick(['Sofra', 'Masa başı'], 0);
  static String get hearth => Voice.pick(['Ocak başı', 'Yemek hazırlığı'], 0);
  static String get sleep => Voice.pick(['Uyku', 'Dinlenme'], 0);
  static String get day => Voice.pick(['Gündüz', 'Gün ışığı'], 0);
  static String get night => Voice.pick(['Gece', 'Akşam'], 0);
  static String get pause => Voice.pick(['Duraklat', 'Beklet'], 0);
  static String get resume => Voice.pick(['Oynat', 'Devam et'], 0);
  static String get reset => Voice.pick(['Baştan', 'Yeniden başlat'], 0);
  static String get empty =>
      Voice.pick(['Şu an evde kimse yok.', 'Ev şimdi sessiz.'], 0);
  static String get hint => Voice.pick([
    'Eşyaya dokun, yakından tanı.',
    'Evdeki eşyaları inceleyebilirsin.',
  ], 0);
  static String get exteriorHint => Voice.pick([
    'Hazır evin içine girmek için eve dokun.',
    'Ev hazır. İçeriye bakabilirsin.',
  ], 0);
  static String get away => Voice.pick(['Dışarıda', 'Köyde'], 0);
  static String layout(int index) => Voice.pick(
    [
      ['Karşılıklı köşeler', 'İki köşe'],
      ['Solda yataklar', 'Yan yana'],
      ['Sağda yataklar', 'Açık sofra'],
      ['Ayrı uyku köşeleri', 'Çapraz köşeler'],
      ['Ön köşe yatağı', 'Pencere yanı'],
      ['Duvar boyunca yataklar', 'Uzun duvar'],
    ][index],
    0,
  );
  static String style(int index) => Voice.pick(
    [
      ['Kır döşemesi', 'Kır evi'],
      ['Yeşil köşe', 'Bitkili ev'],
      ['Dokuma köşesi', 'Dokumalı ev'],
    ][index],
    0,
  );
  static String activity(int index) => Voice.pick(
    [
      ['Yürüyor', 'Evde dolaşıyor'],
      ['Masada', 'Sofrada'],
      ['Ocakla uğraşıyor', 'Yemek hazırlıyor'],
      ['Pencerede', 'Dışarıyı seyrediyor'],
      ['Uyuyor', 'Dinleniyor'],
    ][index],
    0,
  );
  static String furniture(int index) => Voice.pick(
    [
      ['Ahşap yatak', 'Yatak ve yün örtü'],
      ['Yemek masası', 'Ev sofrası'],
      ['Ahşap tabure', 'Masa taburesi'],
      ['Taş ocak', 'Ev ocağı'],
      ['Kap kacak rafı', 'Mutfak rafı'],
      ['Çeyiz sandığı', 'Ahşap sandık'],
      ['Dokuma kilim', 'El dokuması kilim'],
      ['Saksı bitkisi', 'Yeşil köşe'],
      ['Örgü sepet', 'Hasır sepet'],
      ['Ocak odunları', 'Kışlık odun'],
    ][index],
    0,
  );
}
