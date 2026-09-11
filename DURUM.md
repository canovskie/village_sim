# DURUM — projenin o anki hâli

**Son güncelleme: 8 Eylül 2026.**

Bu dosya değişen proje durumunu anlatır. Kalıcı çalışma kuralları için
[CLAUDE.md](CLAUDE.md), kod haritası için `lib/main.dart` başındaki HARİTA
yorumuna bak.

## Kısa özet

Oynanış omurgası, kayıt sistemi, yaşayan köy simülasyonu ve yönetişim katmanı
çalışır durumda. Statik analiz temizdir ve tam test süiti geçmektedir. Rastgele olay kataloğunda kuyu onarımı, fazla zahire ve fırtına hazırlığı
içeriği vardır. Yönetişim kataloğu altı gündelik, altı sistem-güdümlü karar,
on sekiz hikâye girdisi ve kayıtla geri kurulan dört rejim krizi taşır.

Çalışma ağacı kapsamlı ve henüz commitlenmemiş bir dönüşüm taşımaktadır. Bu
nedenle yeni işlerde toplu geri alma, bütün depoyu mekanik olarak formatlama ve
eski dosyaları varsayımla diriltme yapılmamalıdır.

## Ölçüler

### Ev içi prototip ve dekor çeşitliliği (8 Eylül)

- Ahşap eve dokunmak çatısı/ön duvarları açık tek oda izleyicisini açar.
  Ev bilgileri ve iç görünüm arasında geçiş yapılabilir.
- Ayrı çizilen iki yatak, masa/tabure, ocak, raf, sandık, kilim, kap kacak,
  perde ve kurutulan otlar; ahşap döşeme, gün/gece rengi, ateş ve buhar.
- Üç döşeme ailesi: kır evi, bitkili ev, dokumalı ev. Yatak başlıkları,
  oval/tahta masalar, minder/sırtlık, bombeli/boyalı sandıklar, hasır/desenli
  kilimler ve yamalı/işlemeli yorganlar biçim ve desen bakımından ayrılır.
- Saksılar, raf/pencere bitkileri, asılı saksı, çiçekler, kurutulmuş otlar,
  duvar dokuması, çelenk ve resim; hasır sepet, odun, mum, tabak ve kumaş yığınları.
  Yapraklar hafif salınır. Yeni zemin eşyaları yol engeli ve dokunma hedefidir.
- Denemede başlıktaki döşeme düğmesi üç aileyi NPC/zamanı sıfırlamadan değiştirir.
  Oyunda döşeme evin konumundan kararlı biçimde türetilir; yeni kayıt alanı yoktur
  ve bu çeşitlilik meslek, varlık veya üretim iddiası taşımaz.
- Her evin artık ayrı mobilya yerleşimi vardır: altı temel plan, bağımsız
  sofra/yatak/raf/sandık/dekor kaymaları ve üç döşeme ailesi birleşir. Konumlar
  çakışmasız Cantor eşlemesiyle tohumlanır; kayıttaki col/row aynı düzeni üretir.
  Bu sürümde eski evler de otomatik yeni kombinasyonlarını alır.
- `systems/npc/home_interior_layout.dart` çizim, dokunma, yatak/masa/ocak hedefi,
  pencere noktası ve yürüyüş için tek kaynaktır. Arka duvara dönen raf ve ocağa
  göre yer değiştiren pencereler/yerel ateş parıltısı da plana bağlıdır.
- Denemedeki ızgara simgeli yerleşim düğmesi altı planı dolaşır. Tarz, senaryo,
  saat ve yakınlaştırma korunur; NPC'ler yeni planda girişten yollarını kurar.
  Dar pencerede yerleşim/tarz kontrolleri ayrı kaydırılabilir satıra geçer.
- İçerideki NPC'ler aynı ten/saç/sakal kimliğiyle sade ev kıyafeti kullanır;
  masaya oturma, ocakla uğraşma, yatakta kapalı göz/nefes ve kalkış geçişleri var.
- Mobilya engelleri üzerinde yarım-tile yol arama. Model görsel ve geçici;
  dış dünya koordinatı, iş, ihtiyaç veya kayıt durumunu değiştirmez.
- `tools/run_home_interior.command` / `lib/tools/home_interior_main.dart`
  doğrudan hazır ev ve iki NPC açar. Hazır senaryolar, zaman/ışık kontrolleri,
  yakınlaştırma ve dışarı çıkıp eve tekrar tıklama bulunur.
- Oyun bağlantısı gerçek evdeki sakinleri gösterir; dışarıda olanları gizler.
  İlk kapsam yalnız ahşap ev ve iki yataktır; tester'daki gündelik döngüler
  henüz köylü AI'ının ev içi ihtiyaç/üretim davranışları değildir.
- Yol/poz yaşam döngüsü, mobil deneme ekranı ve gerçek oyunda ev tıklama →
  içeri → ev bilgileri → geri akışı hedefli testlerle doğrulandı.
  Üç döşemenin gün/gece çizimi, mobil döşeme geçişi ve yeni eşyalara dokunma
  da test edilir; görsel karşılaştırma `/tmp/home_interior_styles.png` üretir.
  Yerleşimler `/tmp/home_interior_layouts.png` ile karşılaştırılır; örnek 400
  evin ayrı/kararlı tasarımı, 600 yerleşimin çakışma/sınırları, tüm planların
  eylem yolları ve gerçek köyde iki farklı eve girme test kapsamındadır.

| Alan | Güncel durum |
|---|---|
| Dart kaynak | 337 dosya, yaklaşık 132 bin satır (`lib/`) |
| Test | 125 dosya, yaklaşık 18 bin satır (`test/`) |
| `flutter analyze` | Temiz |
| Varlıklar | 137 MB; 91 MB `assets/buildings/` |
| İçerik | 10 suç türü, 34 yönetişim kararı, 3 rastgele köy olayı |
| Geliştirici araçları | 39 Dart dosyası, 37 ayrı `*_main.dart` giriş noktası |

Test sayısı belgeye sabitlenmez; katalog ve sözleşme testleri geliştikçe sayı
hızla eskimektedir. Doğru kaynak `flutter test` çıktısıdır.

## Çalışan omurga

- Kuruluş akışı, görev/tüzük ilerlemesi, yıllık eskalasyon ve altıncı yıl
  hesaplaşması.
- 1×/2×/4×/duraklat hızları; karar açıldığında 1× nefes; ağır kararların ortak
  `DecisionPacing` kuyruğu.
- Dilekçe, Divan, Kanunname, haneler, rejim, imparatorluk ve günce/köy hafızası.
- NPC ihtiyaçları, algı/hafıza, gündelik eylemler, meslekler, suç, devriye,
  hastalık, düğün, cenaze ve hane bağları.
- Tarım, hayvancılık, taşıma, zanaat, kış, ateş/yakıt ve kaynak ekonomisi.
- Çoklu kayıt slotu, eski kayıt toleransı, ayarlar, mobil HUD ve geliştirici
  paneli.
- Saf sistem testleri, gerçek sahne prova testleri, mobil yerleşim testleri ve
  capture/tester araçları.

## 7 Eylül karar bütünlüğü

- Dilekçe maliyeti, kanun ve aktör varlığı ortak uygulama kapısında denetlenir.
  Meclis de yalnız uygulanabilir seçeneklerden karar verir; boş ambar bedava
  müdahale sağlayamaz.
- Yargı seçenekleri ilk sunum, kuyruktan çıkış ve yüklemede aynı kanunlardan
  kurulur. Rejim krizleri katalogdan geri gelir; huzursuzluk ve eylem etkileri
  düğme metnine bağlı değildir. Sürgün gerçek ayrılış başlatır ve ayrılış
  yürüyüşü de kaydedilir.
- Ortak köy meseleleri `EventChoiceModal`, kişiye bağlı talepler
  `PetitionModal` kullanır. Haber plaketi sonuç duyurmaya devam eder.
- Ocakta pişirme sırası, kuyu kovası, sıcak yerde öncelik, akşam müziği ve
  sürü çanı kalıcı usuller olarak gündelik davranışlara bağlandı. Muhafız
  takviyesi gerçek devriye/görüş etkisi taşır; asayişi yok saymak şüpheyi silmez.
- Evlenmeme tercihi kıyafetten bağımsız kaydedilir; düğün ve eşleştirme
  yolları, dışarıdan eş çağırma dahil, bu tercihi gözetir.
- Üç rastgele köy olayının koşulu, maliyeti, pasif kolu, kısa koreografisi ve
  kayıtla süren çalışma izi vardır.
- Doğrulama: karar sözleşmeleri, gerçek sahnede kaynak/kanun/kriz/ayrılış ve
  tercih kayıtları, üç olayın görünürlüğü/sonucu/zaman aşımı, 896×414 ve
  760×360 karar yerleşimleri. Tam süit 967 test geçti; son düzeltmelerin
  ardından ilgili 46 test yeniden geçti. `flutter analyze` temiz.

## 7 Eylül hareket ve atmosfer

- Köylü adımları kuru zeminde kısa toz, yağmurda sıçrama, karda sönümlenen
  ayak izi üretir. İzler dünya koordinatında, mesafeye bağlı ve kişi başına
  sınırlıdır; kapalı mekân, durma, ışınlanma ve sert kuru yüzeyler iz üretmez.
- Yağmurun yere çarpması dünya katmanına taşındı: pan/zoom ile zeminden
  kopmaz, binalar ve karakterler sıçramayı örter.
- Polen ve ateşböcekleri görünür dünya hücrelerinden türetilir; yakın kadrajda
  yoğunluk kaybolmaz. Kışta kapanır, yağmurda yumuşakça söner. Çalı çevresindeki
  kelebekler köylü yaklaşınca yükselir; şafak/alacakaranlıkta su üstünde alçak
  sis süzülür. Yeni atmosfer katmanları performans modunda atlanır.
- Deniz çiziminde önceki karenin dalga alpha'sının arka plana sızması düzeltildi.
- Adım yaşam döngüsü/çizimi ve gerçek köy bağlantısı hedefli testlerle doğrulandı.
  `flutter test test/atmosphere_preview_dump.dart`, aynı kadrajın altı atmosfer
  önizlemesini `/tmp/village_atmosphere.png` olarak üretir. Yaşayan köy capture'ı
  sabit yatay kadraj kullanır; ortak kare pompalama motor saatini takip eder.

## 6 Eylül kod temizliği ve kavram klasörleri

- `lib/scene`, `lib/systems`, `lib/ui` düz listeden kavram alt klasörlerine
  bölündü (world/player/npc/labor/governance/run/events/probe; ui için
  core/hud/ledger/events/screens/dev). 182 dosya taşındı, tüm import/part
  yolları ve belgelerdeki yol atıfları güncellendi; davranış değişmedi.
- Dokuz 2000+ satırlık dosya aynı kütüphanenin part'larına ayrıldı:
  `character_renderer` (5 part), `game_painter` (ground + lighting),
  `game_drawables` (villager + building), `village_ledger` (shell + tabs +
  hero + agenda), `petition_modal` (divan + hero + options + seal),
  `law_book_panel` (hex + seal ritual), `scene_save` (capture + restore),
  `scene_crime` (act + justice), `main.dart` (app root + harness bayrakları).
  Ana dosyaların hiçbiri artık 2400 satırı geçmiyor.
- Ölü kod silindi: hiç okunmayan 7 işçi hızı sabiti, iki nüfus-yiyecek sabiti,
  `yearLabel`, `heralded`, `averageQueueWaitDays`, `drawGrounded`,
  `openAnimationRoom`; kullanılmayan `cupertino_icons` bağımlılığı ve hiçbir
  koddan referans almayan altı varlık (birch/oak ağaç PNG'leri, iki ambiyans
  sesi, mevsim detay sayfası, eski at arabası karesi).
- Doğrulama: `flutter analyze` temiz; `flutter test --exclude-tags probe`
  915 test geçti. `flutter test --tags probe` koşusunda 23 prova geçti, bir
  tanesi (living_probe "hırsızlık tam sahne") tam süitte bir kez düştü, tek
  başına üç koşuda üçü de geçti; süit yüküne bağlı kararsızlık, taşımayla
  ilgili değil (kod satırı değişmedi, yalnız dosya taşındı).

## 8 Eylül haber bütünlüğü

- Doğum, aile kurma, büyüme ve hane ayrılık haberleri açık konu/önemle
  gönderilir. Eksik malzeme sistem cevabıdır; kişi adının içindeki `kar`
  hecesi haberin hava konusu sayılmasına neden olmaz.
- Önemli ve acil haberler okunmadan kuyruktan atılmaz. Gündelik gelişmelerin
  kısa tamponu ayrıdır. Oyuncunun işlem fişi krizle aynı anda görünür;
  yeni tıklama önceki işlem cevabını günceller.
- Yayın saati saf `VillageNewsQueue` içinde, gerçek görünür süreyle yürür.
  Panel, ders/olay kartı, sinematik, savaş, başka sayfa ve uygulama arka planı
  okuma bütçesini tüketmez. Dönüş karesi gizli süreyi saate eklemez. Plaketin
  süre çizgisi de aynı kalan bütçeyi çizer; ayrı otomatik kapanma timer'ı yok.
- Ders/olay kartı ile plaket aynı anda çizilmez; haber sonra kaldığı yerden
  devam eder. Sim duraklatılsa bile görünür haberin okuma süresi ilerler.
- Olay kimliği metin varyantlarını birleştirir. Kişisel yaşam, çatışma ve
  yargı haberlerinin tekrarlanan havuzları kişi/olay kimliği taşır. Okunan
  haber 30 saniye tekrar etmez; başka kişi ve ağırlaşan uyarı engellenmez.
- Doğrulama: saf model/kuyruk testleri; gerçek sahnede işlem fişi, kısa panel
  açıp kapama, uygulama arka planı, dört acil haberin okunması ve ders kartı
  sırasında bekleyiş provası geçti. 760×360 ve 896×414 alanda 1.5× yazı
  ölçeğinde haber + işlem fişi yerleşimi de test edildi. İlgili 29 test
  geçti; `flutter analyze` temiz.

## 6 Eylül haber plaketi

- Geçici bildirimler konu, ton, önem, başlık, gövde ve mevsim/gün damgası
  taşıyan `VillageNews` modeline bağlandı. Köy halkı, işlik, ambar, hava,
  asayiş, Divan, yol, imparatorluk ve oyun geri bildirimi ayrı haber diliyle
  görünür.
- Eski string bildirimleri otomatik sınıflandırılır; yeni içerik başlık ve
  önemini açıkça verebilir. Köy olayı ile Divan giriş/sonuçları yapılandırılmış
  haber üretir.
- Yayın sırası eş haberleri çoğaltmaz, en fazla iki önemli haberi saklar ve
  acil haberi aktif sıranın önüne alır. Rutin köy satırları basılmaz, kayda
  değer gündelik gelişmeler ekran doluyken kuyruğa girmez. Panel açıkken görünmeyen
  plaketin okuma süresi tüketilmez; panel kapandığında tam süreyle gösterilir.
- Kayıt, hız ve geçersiz oyuncu eylemi gibi arayüz cevapları büyük haber
  plaketi yerine küçük geri bildirim fişi kullanır.
- Plaket konu ikonu, tona bağlı renk, dört kademeli önem izi, sıradaki haber
  sayısı ve metin uzunluğuna bağlı süre taşır. Eski sabit kurucu galeri ve
  testlerle uyumlu kalır.
- Doğrulama: haber modeli/kuyruğu birim testleri, plaket widget testleri,
  iPhone 11 yerleşimi, oyuncu eylemi geri bildirimi, dilekçe kataloğu ve gerçek
  sahne karar kuyruğu geçti.

## 5 Eylül hikâye sürekliliği

- Bahçe, yapı ustalığı ve iki hane uzlaşması için üç aşamalı, dallanan üç
  hikâye eklendi. On sekiz katalog girdisi; normal bir yolda üç karar.
- Aynı iki köylü kayıt/yüklemede korunur. Aktör ölür veya ayrılırsa ayrı,
  bedelsiz kayıp kapanışı gelir; açık kararda eski bedel harcanmaz.
- Ortaklıklar sosyal niyet hakemine bağlandı. Bahçe ev çevresinde görünür;
  gerçek buluşmalar elde eşya ve el işiyle yaşanır; yapı ustalığı gerçek
  köylü bilgisinde ilerler ve aynı gün tekrar yüklenerek çoğaltılamaz.
- Son karşılaşmalar üçüncü/beşinci yıl kapılarını bekler; görev paneli aynı
  insanların geçmişini üretim ağı, zanaat ve hane desteği hedeflerine ekler.
- Doğrulama: statik analiz ve tam Flutter test süiti geçti. Yeni gerçek sahne
  provası dallanma, aynı aktörle kayıt/yükleme, yıl kapısı, ayrılık kapanışı,
  görünür buluşma ve ustalık kazanımını kapsıyor. İki telefon boyutunda tüm
  yeni kararların erişilebilirliği ayrıca doğrulandı.
- Akış ve kapsam: [docs/story_threads.md](docs/story_threads.md).

## 2 Eylül sağlamlaştırması

- Olay kataloğu motordan ayrılarak `lib/systems/events/event_catalog.dart`
  sınırına taşındı.
- `EventSystem` artık olayın `canFire` kapısını gerçekten uygular; sıfır veya
  negatif ağırlıklı olay seçime girmez.
- Sahnenin zorunlu kullandığı altı karar katalogda yeniden tek paket altında
  güvenceye alındı: suç hükmü, asayiş, fidye, odun azlığı, ateşin sönmesi ve
  düğün.
- Dilekçe kimlikleri `PetitionIds` altında toplandı. Oynanış çağrıları eksik
  girdiyi sessizce yutmak yerine `PetitionSystem.requireById` ile açık hata
  verir.
- Ateş/asayiş/fidye/düğün kararları dolu masada kaybolmaz; aynı karar iki kez
  eklenmeden merkezi ağır-karar kuyruğunda bekler.
- Kayıtta dayanağı kalmayan fidye/yargı payload'ları ve eski katalog
  isteklerinin hayalet kuyruk kayıtları temizlenir.
- Katalog bütünlüğü, metin dokuma, olay koşulu ve gerçek sahne karar kuyruğu
  regresyon testleri geri kuruldu.

## Açık işler — öncelik sırasıyla

### 1. Köy olayı paketlerini genişletme

İlk paket kuyu, pazar ve hava gündemini kapsar. Yeni paketlerde de koşul,
ücretli müdahale, bedelsiz pasif zaman aşımı ve dünyada görünen sonuç
sözleşmeleri korunmalıdır (`village_event_catalog.dart`).

### 2. Geç oyun gündemini genişletme

Kişisel hikâyeler üçüncü/beşinci yıl gündemine uzanır; dört rejim krizi artık
kalıcı katalog girdileridir. Topluluk, kurum ve zümrelerin daha uzun karar
zincirleri için ek içerik yazılabilir. Ortak meseleler Köy Olayı panelinde,
kişiye bağlı talepler portreli Divan ekranında sunulur.

### 3. Depo hijyeni tamamlanmadı

Çalışma ağacında çok sayıda değiştirilmiş, silinmiş ve yeni dosya vardır.
`tmp/` ve `.backups/` için yeni dosya üretimi ignore edilmiştir; daha önce Git'e
alınmış içerikler bilerek otomatik silinmemiştir. Değişiklikler konu bazlı
commitlere ayrılmadan güvenli geri alma ve code review zor kalacaktır.

### 4. Tablet doğrulaması yok

Telefon için iPhone 11 ve dar pencere sözleşmeleri bulunur. Tablet HUD'ı,
Köylü paneli ve geniş Divan yerleşimi gerçek cihaz profiliyle doğrulanmamıştır.

### 5. Tek dil

Uygulama Türkçedir. İngilizce eklemek yalnız metin çevirisi değildir;
`voice.dart` içindeki Türkçe ek/dokuma motorunun dil katmanına ayrılması gerekir.

### 6. Varlık ve araç maliyeti

`assets/buildings/` tek başına 91 MB'dır. Görseller çözünürlük/kullanım ölçümü
yapılmadan topluca küçültülmemelidir. `lib/tools/` içindeki 37 giriş noktasının
da CI veya belgelenmiş manuel akış karşılığı çıkarılmalı; ölü olanlar sonra
ayıklanmalıdır.

## Korunacak tasarım kararları

- Sis/reveal yerine kamera zoom sınırı.
- Tam ekran sinematik yalnız kuruluş, imparatorluk ve hesaplaşma gibi seyrek
  dönüm noktalarında.
- Doğal yaşam olayları kaynak bedeli almaz.
- Simülasyonu yalnız dağılma, sinematik ve imparatorluk pazarlığı durdurur;
  dilekçe ve normal kararlar dünyayı dondurmaz.
- Yeni mantık `lib/systems/`, sahne bağlantısı `lib/scene/`, çizim `lib/ui/`
  sınırını korur.
- Menü müziği ve `ui_tap` sesi kullanıcı tercihiyle kapsam dışıdır.
