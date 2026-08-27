# CLAUDE.md — bu projede nasıl çalışılır

Bu dosya, projeye yeni giren bir yapay zeka (ya da insan) için **kalıcı**
çalışma kılavuzudur. Anlık durum burada DEĞİL, [DURUM.md](DURUM.md)'dedir:
orası eskir, burası eskimemeli. Bir kural değişirse burayı düzelt; bir iş
biterse DURUM.md'yi güncelle.

---

## 1. Bu oyun nedir

Flutter ile yazılmış izometrik **köy simülasyonu**. Oyuncu bir köy kurar,
yönetir ve altı yıl sonra imparatorluğa hesap verir.

Tür olarak "cozy" ama **oyuncaksı değil**: kararların bedeli var, köy
dağılabilir, koşu kaybedilebilir. Oynanışın omurgası kaynak yönetimi değil
**YÖNETİŞİM**'dir — dilekçeler, kanunname, haneler ve imparatorluk.

### Koşunun yayı (baştan sona)

```
KURULUŞ            → 8 mikro adım, parmakla gösteren öğretici (scene_guide)
   ↓
ORTA OYUN          → Tüzük merdiveni 6 kademe + 7 ders kartı (scene_lessons)
   ↓  her yıl baskı artar (systems/village_year.dart — TEK KAYNAK)
5. YIL             → berat ilan edilir, bir yıllık hazırlık penceresi
   ↓
6. YIL HESAPLAŞMA  → sancak / berat / ilhak (systems/reckoning.dart)
```

Paralel kaybetme kolu: haneler küser → ayrılır → **köy dağılır**
(`systems/village_collapse.dart`). İki kapanış da kaydı **mühürler**, silmez.

Bir yıl = 4 mevsim = 16 oyun günü ≈ 64 dakika (1× hızda).

---

## 2. Ne nerede

**"Bu iş nerede yaşıyor?" sorusunun cevabı `lib/main.dart`'ın başındaki HARİTA
yorumudur.** Orası 40+ part'ın dizinidir ve tek doğruluk kaynağıdır. Yeni bir
sistem eklerken **oraya bir satır ekle** — haritasız kalan kod, takip
edilemeyen koddur.

Katman sözleşmesi:

| Klasör | İş | Kural |
|---|---|---|
| `lib/systems/` | SAF çekirdek mantık | Flutter yok, sahne yok, rastgelelik yok → **test edilebilir** |
| `lib/scene/` | `main.dart`'ın part'ları | Saf çekirdekleri köye BAĞLAR; mantık buraya yazılmaz |
| `lib/ui/` | Widget'lar | Yalnız çizer; sim state'i tutmaz |
| `lib/rendering/` | CustomPainter katmanı | |
| `lib/world/`, `lib/entities/` | Veri modelleri | |
| `lib/tools/` | Bağımsız `*_main.dart` giriş noktaları | `flutter run -t lib/tools/x_main.dart` |

**En önemli tek kural:** yeni mantık `systems/` altına yazılır, `scene_*` onu
bağlar. Sahneye gömülen bir denge kararı test edilemez ve er geç unutulur.

---

## 3. Değiştirilemez tasarım kuralları

Bunlar tercih değil, **daha önce denenip reddedilmiş** yollardır. Birini
bozmadan önce kullanıcıya sor.

### Oynanış
- **No-fail DEĞİL.** Gerçek game over var (köy dağılır) ve gerçek kapanış var
  (hesaplaşma). Ama **kayıp her zaman haber verilir** — sessiz ölüm yok. Her
  kaybetme kolunun önünde görünür bir uyarı rampası olmalı.
- **Doğal yaşam olayları kaynak bedeli almaz** (doğum/ölüm ücretsiz).
- **Bina seviyesi/yükseltmesi YOK.** Yapılar yan yana yaşar (çadır ↔ ahşap ev).
- **Eskalasyonun tek kaynağı `systems/village_year.dart`.** Hiçbir sistem
  kendi içinde "gün N'den sonra şöyle olsun" demez; oradaki çarpanı okur.
  1. yıl bütün çarpanları 1.0'dır — taban denge korunur.
- **Kış cezalandırmaz, hazırlığı ödüllendirir.** Ölüm yalnız ihmal birikince.
- **Sayısal ayar kararlarını SAHİPLEN.** Eşik/katsayı sorularını kullanıcıya
  devretme; kararı ver, gerekçesini kodda yaz.

### Metin
- **Tüm oyuncu-yüzü metin `lib/text/voice.dart`'tan geçer**: varyant havuzu
  kullan, tek string yazma. Türkçe ek motoru orada.
- **Em-dash yasak** oyun metninde.
- İstisna: öğretici/ders metinleri düz sabittir (bir kılavuz sayfası varyant
  havuzu olmaz).

### Görsel
- **Işıklandırma KİLİTLİ** (`game_painter` 3 katman) — kullanıcı istemedikçe
  dokunma.
- Yeni karakter/rol **mutlaka shaded yardımcılarla** (`_shadedRect`/
  `_shadedArm`/…). NPC kalitesi bir ÖLÇEK sorunudur: 37 px'te 1 px detay yok
  olur, siluet çalışır.
- Olay/duygu **gövde dili animasyonuyla** anlatılır. Baş üstü emoji ve
  sayısal refleksiyon YASAK.
- Görselde alpha tweak değil **gerçek ambiyans** beklenir.
- Palet: soğuk grafit yüzeyler, sıcak ember accent. Skeuomorphic
  ahşap/parşömen/çivi YASAK ("cozy" ≠ ucuz).

### UI
- Yeni yoğun panelde ortak `AppTabs` (app_ui.dart) kullan.
- **Panelde gösterilen sayı = simin okuduğu sayı.** İkinci bir liste/hesap
  açma; gösterge ile motor ayrılırsa panel yalan söyler.
- Köy içi her şey **tek kapıdan**: Köy Defteri (`_ledgerSection`, Tab).

---

## 4. Tekrar eden tuzaklar

Hepsi en az bir kez gerçekten oldu.

| Tuzak | Belirti | Çözüm |
|---|---|---|
| **Non-uniform Border + borderRadius** | Panel hiç çizilmez (assert) | Tek kenarlı şerit için `Border` değil ayrı `Container` + `ClipRRect` |
| **Yeni state kaydedilmez** | Yüklenen köyde sistem sıfırlanır | Her yeni alanı `scene_save` capture **ve** restore'a ekle |
| **İki anlatım aynı anda konuşur** | Spot, köylünün cümlesini yutar | Önce ses, sonra parmak; pencere kontrolü tek yerde |
| **Modal harness'i dondurur** | Prova "sistem ölü" der, oysa sim durmuş | `kProbeNoEvents` / `kProbePause`'a bak; capture modunda modalları bastır |
| **Masaüstünde yazılan panel telefonda taşar** | Sarı-siyah şerit, düğme erişilemez | iPhone 11 (896×414 → 760×360 bütçe) testine ekle; başlık sabit + gövde kayar |
| **Ölçüm aralığı gün uzunluğunun böleni** | Prova hep aynı saati örnekler | Aralığı böleni olmayacak şekilde seç |
| **Ardışık perf ölçümü** | Bu makinede 2× yalan söyler | Dönüşümlü A/B + medyan & min |

---

## 5. Doğrulama — "çalışıyor" ne demek

Doğrulama değişikliğin riskiyle orantılıdır; her işte bütün kademeler koşulmaz:

1. **Küçük UI / metin / asset işi:** `flutter analyze` + yalnız ilgili hedefli
   test. Prova ve tam süit gerekmez.
2. **Çekirdek sistem mantığı:** `flutter analyze` + ilgili birim testi + ilgili
   prova testi.
3. **Tam `flutter test` süiti:** yalnız kullanıcı açıkça isterse veya değişiklik
   çok sayıda sistemi yatay kesiyorsa çalıştırılır.

**Birim testi** (`test/*_test.dart`) — `systems/` altındaki saf mantık.
Sözleşmeyi test et, sayıyı değil: "hanelerin rızası en ağır sütundur"
iyi bir test, "unity 0.34'tür" kötü.

**PROVA testi** (`test/*_probe_test.dart`) — **gerçek sahnede**. En sinsi
hata "kod var ama hiç tetiklenmiyor"dur ve bunu hiçbir birim testi görmez.
Bir özellik ekranda görünmesi gerekiyorsa, göründüğünü prova testi
kanıtlamalı.

Prova kalıbı: referans köyü boot et → `kProbe*Armed = true` →
`kDevSpeedBoostOverride = 24` → pump → telemetriyi oku → widget'ı `find` et.
Örnek: `test/reckoning_probe_test.dart`.

> **Prova kancaları oyunda etkisizdir** ama referans/showcase/capture
> köylerinin muafiyetini kaldırır. Yeni bir kapanış/kesinti sistemi eklersen
> aynı muafiyet listesini kullan, yoksa harness'lar ölür.

**Denge kararı verirken ÖLÇ.** Bu turda iki kez tahmin yanlış çıktı: sancak
eşiği ortalama köye 0.013 uzaktaydı (bedava), ve vergi ikiye katlanmasına
rağmen altın gelirinin yanında hiçbir şey ifade etmiyordu. İkisi de ancak
referans köyü koşturup sayıya bakınca görüldü.

---

## 6. Yararlı komutlar

```bash
flutter analyze
flutter test                              # 659 test, ~4 dk
flutter test test/reckoning_probe_test.dart

# Kararsız test avı — [E] satırı testin adını verir
for i in 1 2 3 4 5; do flutter test --reporter expanded > run$i.log 2>&1; \
  grep -B2 '\[E\]' run$i.log; done

# Geliştirici araçları (bağımsız giriş noktaları)
flutter run -t lib/tools/animation_room_main.dart   # sinematik/animasyon denemesi
flutter run -t lib/tools/light_editor_main.dart     # bina ışık noktası editörü
flutter run -t lib/tools/ui_gallery_capture_main.dart

# Oyun içi: ` (backtick) → dev konsol, Tab → Köy Defteri
```

**iOS'a atarken:** `flutter build ios --release` + `devicectl install app`.
`flutter install` KULLANMA (uninstall edip güveni düşürüyor). Ücretsiz imza =
7 günlük profil, haftalık yeniden güven gerekir.

---

## 7. Çalışma tarzı

- **Ağır işten önce sor.** Yön belirleyici bir iş başlamadan bol soruyla
  vizyonu çıkar; yanlış yöne yazılan 2000 satır geri alınmaz.
- **Görselde önce ucuz taslak.** Uzun capture/süit koşularını onaydan sonra
  tek seferde çalıştır.
- **Temizlikte:** emin olduğunu düzelt, belirsiz yarım kodu bağlamaya
  çalışmak yerine **SİL**.
- **Bağlanmayan alan eklenmez.** Kullanılmayan bir alan/sistem, ileride
  birinin doğru sanıp üstüne inşa edeceği bir yalandır.
- **Commit'i kullanıcı istemeden atma.**
