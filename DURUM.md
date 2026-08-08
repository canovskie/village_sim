# DURUM — projenin o anki hâli

**Son güncelleme: 8 Ağustos 2026.**

Bu dosya ESKİR. Kalıcı kurallar için [CLAUDE.md](CLAUDE.md), "bu iş nerede
yaşıyor" için `lib/main.dart` başındaki HARİTA yorumu. Burası yalnız üç
soruya cevap verir: **ne bitti, ne eksik, ne fazla.**

Bir iş bitirdiğinde buradaki satırı taşı. Yeni bir eksik bulduğunda ekle.
Boş bir liste iyi haber değil, bakımsız bir belgedir.

---

## Ölçüler

| | |
|---|---|
| Kaynak | 275 dosya, ~107.600 satır (`lib/`) |
| Test | 71 dosya, ~10.500 satır, **671 test** |
| `flutter analyze` | temiz |
| Varlıklar | 94 MB (62 MB'ı `assets/buildings`) |
| İçerik | 31 bina, 11 meslek, 8 kaynak, 34 hüküm, 10 suç türü |

En büyük dosyalar: `game_painter` (2406), `character_renderer` (2369),
`village_ledger` (2307), `main.dart` (2288), `scene_tick` (1832),
`scene_crime` (1810).

---

## ✅ Biten — omurga

Bunların hepsi kurulu, bağlı ve testli.

**Koşunun yayı**
- Kuruluş sinematiği + 12 mikro adımlık kuruluş + parmakla gösteren öğretici
- Tüzük merdiveni: 6 kimlik kademesi, ~40 görev (geç kademeler kararla ölçülür)
- **Orta oyun dersleri** — 7 sistemin kart öğreticisi *(2026-08-08)*
- **Yıl omurgası** — eskalasyonun tek kaynağı; vergi/olay/kış yılla sertleşir *(2026-08-08)*
- **Hesaplaşma** — 6. yılda sancak/berat/ilhak, rejime göre kapanış *(2026-08-08)*
- **Yaşayan köy showcase görseli** — merkez yerleşim, binalar ve doğal çeper görünür *(2026-08-08)*
- Kaybetme eşiği — hane ayrılığı → köy dağılır, kayıt mühürlenir

**Yönetişim (oyunun kalbi)**
- Dilekçe/Divan/Meclis + governanceLegacy mirası
- Kanunname: 34 hüküm, altıgen petek UI, mühür töreni
- Politik pusula → 4 rejim (kimlik seçilmez, kazanılır) + huzursuzluk/kriz
- Haneler: duruş merdiveni (sadık→razı→serzeniş→el çekti→ambar→kopuş) +
  oyuncunun proaktif eylemleri (bağış/ceza/nikâh/sürgün/entrika)
- İmparatorluk: vergici heyeti, pazarlık, itibar, iki tabanlı öşür
- **Kararın izi** — verilen her dilekçe kararı ve mühür günceye düşer; KRONİK
  süzgeci (kararlar/yaşam/sıkıntı), mühür günü, 14 eksik hafıza izi *(2026-08-08)*

**Yaşayan köy**
- NPC beyni 6 fazın tamamı (WorldPressure → Mind/Bid → Algı/Hafıza/Dedikodu →
  Act/Prop → hırsızlık tam sahnesi → basınç/siluet). **Hepsi DONE ve testli.**
- Kişilik, meslek çağrısı, yaşam evresi, yaşam öyküsü, moral
- Suç + devriye + yargı; çekişme + kan davası; hastalık/veba; düğün/cenaze

**Üretim & hayatta kalma**
- Tarım kapalı döngüsü, 11 meslek, zanaat ilerlemesi, hayvancılık
- Kış: 4 eksenli hazırlık + yün→kışlık zinciri + soğuk çadır
- Ateş yakıtı, böğürtlen→aşçı zinciri, sazlık yatakları

**Altyapı**
- Çoklu slot kayıt/yükleme, ayarlar kalıcılığı *(2026-08-08)*
- Ses: 3 katman, 30 dosya
- Mobil "kenar rayı" teması, iOS'a atma zinciri
- Dev konsol, dev panel, almanak, 35 capture/prova aracı

---

## ⚠️ Eksik — öncelik sırasıyla

### 1. Kararsız (flaky) test
Bir tam koşuda tek bir hata düştü (`Expected: true / Actual: false`), adı
yakalanamadı. Ardından **8 temiz tam koşu** geldi; tekrarlanmadı.
Çözülmedi, yalnız görülmedi. Avlama komutu CLAUDE.md §6'da.

### 2. Tablet doğrulanmadı
Referans cihaz iPhone 11 (telefon). Tablet HUD'ı ve köylü paneli hiç
sınanmadı.

### 3. Dilekçe katalogları testsiz
9 dosya, ~3.000 satır, neredeyse **sıfır test** — projedeki en büyük test
boşluğu. Çoğu veri ama `petition_catalog_estates` (644 satır) mantık taşıyor.
İlk kanca atıldı: `decision_trace_test` her şıkkın günceye yazacak bir cümlesi
olduğunu tarıyor (iki suskun şık böyle bulundu).

### 4. Tek dil
`AppLanguage` enum'unda `tr` ve `en` var, yalnız `tr` dolu. Türkçe ek motoru
(`voice.dart`) dile bağlı — İngilizce eklemek metin çevirisi değil, motorun
ikinci bir gramere açılması demek. Küçük bir iş değil.

### 5. Kalan küçük eksikler
- `main.dart` tepesinde 4 Ağustos'tan kalma **"YARIN İLK İŞ"** notu duruyor:
  el sallama sohbet balonundan çıkarılıp gövde animasyonuna çevrilecek.
- Ses: `ui_tap` + 2 müzik parçası. **Kullanıcı kararıyla İSTENMEDİ** —
  yeniden önerme, kanca kodda sessiz duruyor.
- 70 dosya commit'siz (8 Ağustos itibarıyla).

---

## 🗑️ Fazla — silinecek ya da küçültülecek

### 1. README.md yalan söylüyor  ← en acili
452 satır ve **belgelediği mimari artık yok**. Saydığı 9 dosyadan 8'i
silinmiş (`builder_entity`, `woodcutter_entity`, `miner_entity`,
`fisher_entity`, `farm_farmer`, `lumber_camp_entity`, `axe_renderer`,
`bale_test`). `kCols=96, kRows=64` diyor — harita 128×128. "12 bina tipi"
diyor — 31 tane var.

Bu bir eksik değil **tuzak**: yeni bir yapay zeka bunu okuyup silinmiş bir
katmanın üstüne kod yazar. Kısa ve doğru bir dosyayla değiştirilmeli
(CLAUDE.md + DURUM.md'ye işaret eden).

### 2. `lib/ui/ui_icon.dart` — ölü özellik
`UiIcon` sınıfı tanımlı, **hiçbir yerden import edilmiyor**. Karşılığı olan
`assets/ui/icon_*.png` dosyaları da hiç üretilmemiş (klasörde yalnız
`app_icon.svg` ve iki menü arka planı var). HUD `app_ui.dart`'taki `GameIcon`
kullanıyor. Ya ikonlar üretilmeli ya dosya silinmeli.

### 3. Varlık boyutu — 94 MB
62 MB'ı `assets/buildings`. Mobil için ağır. Bina PNG'leri muhtemelen
gereğinden yüksek çözünürlükte; oyun onları `spriteScale` ile küçültüyor.
Ölçülmeden dokunulmamalı ama bakılmalı.

### 4. `lib/tools/` — 35 dosya, 9.076 satır
Kaynağın %8,4'ü geliştirici aracı. Çoğu tek seferlik capture harness'ı.
Silmek şart değil ama hangisinin hâlâ koştuğu bilinmiyor; ölmüş olanlar
bakım yükü.

---

## Reddedilmiş yollar (bir daha önerme)

Bunlar denendi ve kullanıcı tarafından geri çevrildi:

- Reveal örtüsü/sis (4 kez) → doğrusu **kamera zoom kısıtı**
- Kuşbakışı sinematik · Ana menüde mor palet + kukuletalı silüet
- Yuvarlak ("round") NPC · Bank binası · Ayrı kurulum ekranı
- İmece/malzeme taşıma/iskele paketi · Selam & Hediye etkileşimleri
- Menü müziği + `ui_tap` sesi · Kanunname için path/ağaç UI (5 yüzey reddedildi)
