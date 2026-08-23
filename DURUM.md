# DURUM — projenin o anki hâli

**Son güncelleme: 23 Ağustos 2026.**

Bu dosya ESKİR. Kalıcı kurallar için [CLAUDE.md](CLAUDE.md), "bu iş nerede
yaşıyor" için `lib/main.dart` başındaki HARİTA yorumu. Burası yalnız üç
soruya cevap verir: **ne bitti, ne eksik, ne fazla.**

Bir iş bitirdiğinde buradaki satırı taşı. Yeni bir eksik bulduğunda ekle.
Boş bir liste iyi haber değil, bakımsız bir belgedir.

---

## Ölçüler

| | |
|---|---|
| Kaynak | 300 dosya, 125.450 satır (`lib/`) |
| Test | 100 dosya, 15.880 satır, **827 test** (~13 dk) |
| `flutter analyze` | temiz |
| Varlıklar | 136 MB (85 MB'ı `assets/buildings`) |
| İçerik | 31 bina, 11 meslek, 8 kaynak, 34 hüküm, 10 suç türü |

En büyük dosyalar: `character_renderer` (3316), `main.dart` (2745),
`game_painter` (2493), `ui_gallery_capture_main` (2456),
`village_ledger` (2401), `scene_crime` (2128), `law_book_panel` (2000),
`scene_tick` (1917).

---

## ✅ Biten — omurga

Bunların hepsi kurulu, bağlı ve testli.

**Koşunun yayı**
- Kuruluş sinematiği + 12 mikro adımlık kuruluş + parmakla gösteren öğretici
- Tüzük merdiveni: 6 kimlik kademesi, ~40 görev (geç kademeler kararla ölçülür)
- **Orta oyun dersleri** — 7 sistemin kart öğreticisi *(2026-08-08)*
- **Yıl omurgası** — eskalasyonun tek kaynağı; vergi/olay/kış yılla sertleşir *(2026-08-08)*
- **Eğlence paketi** — hane uyarı rampası, karar anında 1× nefes, dilekçe temposu/kuyruğu ve yıllık imparatorluk karnesi *(2026-08-14)*
- **Hesaplaşma** — 6. yılda sancak/berat/ilhak, rejime göre kapanış *(2026-08-08)*
- **Yaşayan köy showcase görseli** — merkez yerleşim, binalar ve doğal çeper görünür *(2026-08-08)*
- **Sinematik seyreltmesi** — tam ekran film artık yalnız kuruluş / imparatorluk /
  hesaplaşma. Nikâh, ilk ateş, kıtlık ve tüzük kademesi filmden çıkarıldı;
  karşılıkları dünya içinde (şenlik FX, ateş başı toplanma, gövde dili, günce).
  İmparatorluk filmi üç "ilk kez" anına indi (ilk ziyaret / ilk devşirme /
  ret sonrası ilk dönüş), her biri koşuda bir kez. `lib/cutscene/` duruyor —
  animasyon odası hepsini hâlâ oynatabiliyor *(2026-08-10)*
- Kaybetme eşiği — hane ayrılığı → köy dağılır, kayıt mühürlenir

**Yönetişim (oyunun kalbi)**
- **Kapıda kuyruk** — SOSYAL DOKU TURU dilim 1/5 *(2026-08-12)*: karar isteyen
  olay ve dilekçe artık simi DONDURMUYOR ve modal kendiliğinden AÇILMIYOR.
  Olay vurunca HUD'a KARAR mührü iner (tükenen mühlet halkası; major %20 gün,
  minor %30), mühlet dolarsa köy PASİF seçeneği kendi yaşar
  (`EventOutcome.timeoutChoice` sözleşmesi: pasif şık hep SONDA; günceye
  "Söz gelmedi." düşer). Dilekçede zorunlu huzur donması → "kapıda bekleyen
  huzur": sözcü merkeze yürür, mühür kalıcı kızarır, bedel GÜN BAŞINA işler
  (hane −0.03/gün + moral sızıntısı); otomatik ret YOK, karar oyuncunun.
  Rejim yolları (sessiz düşürme / meclis çözer) aynen. Simi durduran yalnız
  üç şey kaldı: dağılma, sinematik, imparatorluk pazarlığı.
  Prova: `decision_queue_probe_test` (kuyruk + akış + eskalasyon + sözleşme).
  Sıradaki dilimler: baloncuk borcu (7 emoji) → sokak görünürlüğü →
  gün koreografisi → ritüel takvimi.
- Dilekçe/Divan/Meclis + governanceLegacy mirası
- Kanunname: 34 hüküm, altıgen petek UI, mühür töreni
- Politik pusula → 4 rejim (kimlik seçilmez, kazanılır) + huzursuzluk/kriz
- Haneler: duruş merdiveni (sadık→razı→serzeniş→el çekti→ambar→kopuş) +
  oyuncunun proaktif eylemleri (bağış/ceza/nikâh/sürgün/entrika)
- İmparatorluk: vergici heyeti, pazarlık, itibar, iki tabanlı öşür
- **Eşik sahnesi** — kazanılan direniş artık dünyada oynuyor: köy tırpan/balta
  ile heyetle meydan arasına dizilir, heyet bekler, bir hamle yapar, döner.
  Kronik yıllardır bu cümleyi yazıyordu ama sahnede dizilen kimse yoktu; kayıp
  sahneliydi, KAZANÇ bildirimdi *(2026-08-08)*
- **Kararın izi** — verilen her dilekçe kararı ve mühür günceye düşer; KRONİK
  süzgeci (kararlar/yaşam/sıkıntı), mühür günü, 14 eksik hafıza izi *(2026-08-08)*

**Yaşayan köy**
- NPC beyni 6 fazın tamamı (WorldPressure → Mind/Bid → Algı/Hafıza/Dedikodu →
  Act/Prop → hırsızlık tam sahnesi → basınç/siluet). **Hepsi DONE ve testli.**
- Kişilik, meslek çağrısı, yaşam evresi, yaşam öyküsü, moral
- **Baş üstü emoji borcu ödendi** — selam (👋) ve hikâye anlatımı (📖) gövdeye
  taşındı (`CharGesture.wave` / `.tell`: sağ kolu devralan jest katmanı),
  göktaşı (🌠) zaten var olan `wonder` postürüne bırakıldı. Baş üstünde
  yalnız NESNE anlatan işaretler kaldı (🌿 hasta ev, 🕊️ kavgadan çekilme) +
  sohbetin konu ikonları *(2026-08-08)*
- Suç + devriye + yargı; çekişme + kan davası; hastalık/veba; düğün/cenaze
- **Hırsızlık mal korunumu** — çuval/zula sayaçları ayrı stoktaki silahı da
  kapsıyor; yakalanma, kaçış, gömme ve geri alma yolları malı sızdırmıyor
  *(2026-08-23)*

**Üretim & hayatta kalma**
- Tarım kapalı döngüsü, 11 meslek, zanaat ilerlemesi, hayvancılık
- Kış: 4 eksenli hazırlık + yün→kışlık zinciri + soğuk çadır
- Ateş yakıtı, böğürtlen→aşçı zinciri, sazlık yatakları
- **Taşıyıcı görev yaşam döngüsü** — pickup/teslim/iptal/ölüm/sahne geçişi
  rezervasyonları atomik temizleniyor; gerçek yük iki elle çiziliyor
  *(2026-08-23)*

**Altyapı**
- Çoklu slot kayıt/yükleme, ayarlar kalıcılığı *(2026-08-08)*
- Ses: 3 katman, 30 dosya
- Mobil "kenar rayı" teması, iOS'a atma zinciri
- **Dekor nüfusu ve painter cache sözleşmesi** — sahipli kalıcı yüzeyler eski
  kayıtta sanitize ediliyor; geçici yükler florayı silmiyor; yerinde liste
  mutasyonu `decorVersion` ile bucket cache'i yeniliyor *(2026-08-23)*
- **Bina kataloğu yenilemesi** — metadata'dan thumbnail/maliyet/footprint,
  renk dışı seçim ve yeterlilik durumları, tam ekran mobil katalog ve
  896×414 + 760×360 taşma sözleşmeleri *(2026-08-23)*
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

### 3. Dilekçe katalogları — bütünlük kapandı, denge açık
`petition_catalog_test` (2026-08-10) katalogun **yapısını** koruyor: ölü
zincir bağı, öksüz takip halkası, hiçbir köyde açılmayan kapı, iki özdeş şık,
em-dash. Kurulurken dört ölü dilekçe ve 17 em-dash buldu.

Kalan boşluk **denge**: hangi dilekçe ne sıklıkta geliyor, ağırlıklar köyün
gündemini doğru mu kuruyor. Bu ölçüm işi, sözleşme işi değil.

### 4. Tek dil
`AppLanguage` enum'unda `tr` ve `en` var, yalnız `tr` dolu. Türkçe ek motoru
(`voice.dart`) dile bağlı — İngilizce eklemek metin çevirisi değil, motorun
ikinci bir gramere açılması demek. Küçük bir iş değil.

### 5. Kalan küçük eksikler
- Ses: `ui_tap` + 2 müzik parçası. **Kullanıcı kararıyla İSTENMEDİ** —
  yeniden önerme, kanca kodda sessiz duruyor.
- 55 dosya commit'siz (10 Ağustos itibarıyla): combat/prop/mezar varlıkları,
  `imperial_defense_test`, `save_roundtrip_test` ve sinematik seyreltmesi.

---

## 🗑️ Fazla — silinecek ya da küçültülecek

### 1. `lib/ui/ui_icon.dart` — ölü özellik
`UiIcon` sınıfı tanımlı, **hiçbir yerden import edilmiyor**. Karşılığı olan
`assets/ui/icon_*.png` dosyaları da hiç üretilmemiş (klasörde yalnız
`app_icon.svg` ve iki menü arka planı var). HUD `app_ui.dart`'taki `GameIcon`
kullanıyor. Ya ikonlar üretilmeli ya dosya silinmeli.

### 2. Varlık boyutu — 122 MB  ← büyüyor
85 MB'ı `assets/buildings`. Mobil için ağır ve **son ölçümden 28 MB arttı**.
Bina PNG'leri muhtemelen
gereğinden yüksek çözünürlükte; oyun onları `spriteScale` ile küçültüyor.
Ölçülmeden dokunulmamalı ama bakılmalı.

### 3. `lib/tools/` — 38 dosya, 9.548 satır
Kaynağın %7,6'sı geliştirici aracı. Çoğu tek seferlik capture harness'ı.
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
