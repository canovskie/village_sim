# DURUM — projenin o anki hâli

**Son güncelleme: 6 Eylül 2026.**

Bu dosya değişen proje durumunu anlatır. Kalıcı çalışma kuralları için
[CLAUDE.md](CLAUDE.md), kod haritası için `lib/main.dart` başındaki HARİTA
yorumuna bak.

## Kısa özet

Oynanış omurgası, kayıt sistemi, yaşayan köy simülasyonu ve yönetişim katmanı
çalışır durumda. Statik analiz temizdir ve tam test süiti geçmektedir. En büyük
ürün boşluğu içeriktir: rastgele olay motoru hazır olmasına rağmen olay kataloğu
boş; dilekçe kataloğunda altı gündelik, altı sistem-güdümlü karar ve üç hikâyenin
on sekiz başlangıç/devam/kapanış girdisi var.

Çalışma ağacı kapsamlı ve henüz commitlenmemiş bir dönüşüm taşımaktadır. Bu
nedenle yeni işlerde toplu geri alma, bütün depoyu mekanik olarak formatlama ve
eski dosyaları varsayımla diriltme yapılmamalıdır.

## Ölçüler

| Alan | Güncel durum |
|---|---|
| Dart kaynak | 337 dosya, yaklaşık 132 bin satır (`lib/`) |
| Test | 125 dosya, yaklaşık 18 bin satır (`test/`) |
| `flutter analyze` | Temiz |
| Varlıklar | 137 MB; 91 MB `assets/buildings/` |
| İçerik | 10 suç türü, 30 dilekçe, 0 rastgele olay |
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

### 1. Rastgele olay içeriği yok

`EventOutcome`, seçim, zaman aşımı, efekt, koreografi, UI ve kayıt altyapısı
duruyor; `EventSystem.events` ise boştur. Yeni olaylar tek tek motor dosyasına
gömülmemeli, `lib/systems/events/` altında içerik paketi olarak eklenmelidir.
Her seçimli olayın pasif zaman-aşımı kolu ve sahnede görünen karşılığı olmalıdır.

### 2. Dilekçe gündemi dar

Rastgele havuzda altı kişisel/gündelik dilekçe ile koşullu asayiş kararı vardır.
Diğer beş katalog girdisi yalnız sahne olaylarının zorunlu karar yüzeyidir.
Üç kişisel hikâye artık aynı aktörlerle dallanıp üçüncü/beşinci yıl gündemine
uzanıyor. Daha geniş topluluk, kurum, zümre ve rejim gündemleri içerik ister.
Önce communal, sonra civic/critical paketleri eklenmelidir; her paket mevcut
`petition_catalog_test` sözleşmesini geçmelidir.

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
