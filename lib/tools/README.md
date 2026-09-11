# Araçlar (harness / editör)

Bunlar oyunun parçası değil, **doğrulama ve ayar araçları**. Her biri kendi
`main()`'i olan ayrı bir giriş noktası; `flutter run -d macos -t <dosya>` ile
çalışır. Hiçbiri sürüme girmez.

Bir şeyi "gözle onayladım" demeden önce buradaki karşılığını çalıştır — bu
dosyaların varlık sebebi budur.

## Ölçen araçlar (sayı üretir, gözle bakmaz)

| Araç | Ne ölçer |
|---|---|
| `living_probe_main.dart` | Köyün DAVRANIŞI: niyet dağılımı, dürtüler, hafıza/dedikodu/ihbar sayaçları, köyün hâli. "Canlı mı?" sorusunun sayısal cevabı. |
| `mobile_capture_main.dart` | **MOBİL UI**: oyun ekranını gerçek telefon ölçülerinde sürer; taşma / ekran dışı / 44dp altı dokunma hedefi / 11px altı yazı sayar. Hem PNG hem `report.json` üretir. |
| `work_capture_main.dart` | Meslek iş döngüleri gerçekten dönüyor mu (avcı/çoban/değirmenci/hancı/rahip). |
| `crime_capture_main.dart` | Suçun evreleri + muhafız tepkisi + hüküm zinciri. |
| `anim_room_probe_main.dart` | Animasyon odasının kendi kendini kontrolü. |

## Canlı köy tester'ı

### Hazır ev içi denemesi

`home_interior_main.dart` doğrudan döşenmiş ahşap eve ve iki NPC'ye açılır.
Menü, harita üretimi, kayıt yükleme veya bina kurma adımı yoktur.
Gündelik yaşam, masa, ocak ve uyku senaryoları; gece/gündüz, duraklatma,
1×/2× hız, sıfırlama ve yakınlaştırma kullanılabilir. Kapat düğmesi hazır evin
dışına çıkar; eve dokunmak tekrar içeri alır.

Başlığın sağındaki koltuk simgeli **Kır evi / Bitkili ev / Dokumalı ev** düğmesi
üç döşeme ailesi arasında döner. Mobilya biçimleri, kilim/yorgan desenleri,
seramikler ve bitkiler değişir; NPC senaryosu, zaman ve yakınlaştırma korunur.
Saksı, sepet ve odun yığınına da dokunulabilir. Oyundaki evlerde bu çeşitlilik
ev konumuna bağlıdır, izleyiciyi yeniden açınca rastgele değişmez.

Yanındaki **ızgara simgeli yerleşim düğmesi** altı planı dolaşır: İki köşe,
Yan yana, Açık sofra, Çapraz köşeler, Pencere yanı, Uzun duvar. Demo artık
Uzun duvar + Dokumalı ev kombinasyonuyla açılır. Yerleşim değişince NPC'ler
girişten yeni yollarını kurar; senaryo, saat, tarz ve yakınlaştırma korunur.
Normal oyunda her ev kendi koordinatlarından ayrı bir kombinasyon üretir;
yerleşim yeniden açma ve kayıt yükleme ile değişmez. Oyuncuya eşya sürükleme
editörü eklenmemiştir, düzenler otomatik oluşturulur.

macOS'ta `tools/run_home_interior.command` dosyasına çift tıklanabilir.
VS Code çalıştırma listesindeki **Ev İçi Denemesi** de aynı girişi kullanır.

```
flutter run -d macos -t lib/tools/home_interior_main.dart
INTERIOR_CAPTURE=/tmp/home_interior.png flutter run -d macos -t lib/tools/home_interior_main.dart
```

İlk prototip tek oda ve iki yatakla sınırlıdır. Oyunda ahşap eve tıklamak aynı
izleyiciyi açar; içeride yalnız gerçekten evde bulunan sakinler görünür.
Tester'daki masa/ocak/dolaşma döngüleri görsel provadır; ekonomi ve ihtiyaç
sistemlerini çalıştırmaz. NPC kimliği mevcut karakter verisinden gelir.

Günlük köy testi için `village_tester_main.dart` kullanılır. Rastgele, normal
bir kuruluş açar; **hazır bina/NPC yerleştirmez ve god mode'u kendiliğinden
açmaz**. Sağ üstteki üç sekmeli panelden canlı teşhis, sim hızı, saat, hava,
kaynak enjeksiyonu ve sohbet/dans/kavga/suç gibi dünya tepkileri aynı koşu
üzerinde denenir. `Eylem → Dış Dünya` bölümünden kervan, yolcu veya yabancı
ziyareti de doğrudan sahneye çağrılabilir. Panel gizlenebilir; normal dev panelindeki uzun içerik
kataloglarına ihtiyaç duymaz.

```
flutter run -d macos -t lib/tools/village_tester_main.dart
flutter run --release -d <iphone-id> -t lib/tools/village_tester_main.dart
```

## Doğal kuruluş gözlemcisi

`founding_tester_main.dart`, capture aracı değildir. Ana menü ve normal kayıt
listesi yerine doğrudan rastgele taze köy açar; kuruluş halkası, intro seçimi,
ateş yerleştirme, saz yatakları, ilk gece, çadır ve ilk odun gerçek oyun
kurallarıyla işler. Sol üstteki gözlem paneli state'i yalnız okur; sabit tohum,
god mode, otomatik seçim, zaman dondurma veya hız boost'u kullanmaz. Panel
gizlenebilir ve **Taze Koşu** ile başka rastgele dünyada baştan başlanabilir.

```
flutter run -d macos -t lib/tools/founding_tester_main.dart
flutter run --release -d <iphone-id> -t lib/tools/founding_tester_main.dart
```

## Kare yakalayan araçlar (PNG üretir)

| Araç | Neyi gösterir |
|---|---|
| `ui_gallery_capture_main.dart` | **Tek çalıştırmada oyunun tüm UI yüzeyleri.** UI değişikliğinden sonra ilk bakılacak yer. |
| `scene_capture_main.dart` | Taze bir köy sahnesi (menüyü atlar). |
| `shots_capture_main.dart` | **Tanıtım seti:** referans köy, HUD dahil, 6 vakitte 1600×900 kare → `~/Desktop/village_shots/`. |
| `living_capture_main.dart` | Showcase köyü: binalar + sürü + meslekler bir arada. |
| `ledger_capture_main.dart` | Köy Defteri'nin beş bölümü. |
| `law_capture_main.dart` | Kanunname + mühür ritüeli. |
| `compass_capture_main.dart` | Politik pusula, dört farklı köy hâlinde. |
| `option_scene_capture_main.dart` | Karar-eylem sahnelerinin grid önizlemesi. |
| `villager_capture_main.dart` | Köylü paneli (GENEL/KİŞİLİK/ÖYKÜ). |
| `char_capture_main.dart` | NPC render'ı iki ölçekte yan yana. |
| `menu_capture_main.dart` | Ana menü şafak sahnesi. |
| `saveslots_capture_main.dart` | Kayıtlı Köyler paneli. |
| `sky_capture_main.dart` | HUD gök şeridi, günün dört vaktinde. |
| `imperial_alert_capture_main.dart` | İmparatorluk varış anonsu. |
| `cutscene_capture_main.dart` | Sinematik kareleri. |
| `reveal_capture_main.dart` | İnşaat şeffaflığı + yol önizlemesi. |

## Editörler (veri yazar — çalıştırıp kaydedince kaynak dosya değişir)

| Araç | Ne ayarlar |
|---|---|
| `light_editor_main.dart` | Bina ışık + baca noktaları. **Yeni bina eklendiğinde çalıştır.** |
| `placement_editor_main.dart` | Bina ebat/yerleşim (spriteScale / groundY / cols / rows), otomatik kaydeder. |
| `animation_room_main.dart` | Sinematik ve karakter animasyonlarını canlı deneme odası. |

## Mobil otomasyon

`mobile_capture_main.dart` diğerlerinden farklı: tek kare çekmez, **oyun
ekranını sürer**. Altı yatay telefon/tablet profilinde (mobil yatay kilitli,
bkz. `systems/platform/platform_adapt.dart`) 19 adım koşar — pan, pinch-zoom, inşa
paleti, köylü seçimi, Köy Defteri'nin beş bölümü + Haneler sekmesi — her adımda
kare çeker ve dört şeyi SAYAR: taşma, ekran dışına düşen yazı/hedef, 44dp altı
dokunma hedefi, 11px altı yazı.

**Sayı yetmez, kareye de bak.** Bu araç bir dönem defterin bütün bölümlerinde
`of:0 off:0 tap:0 font:0` veriyordu — hiçbiri taşmıyordu, çünkü içerik zaten
kaydırma alanının içinde fold altında kalıyordu. NÜFUS bölümünde 18 kişilik
köyden ekranda BİR BUÇUK köylü vardı ve sayaçlar bunu göremedi: "taşma yok"
ile "işe yarıyor" aynı şey değil. Telefon yerleşiminin bugünkü hâli ve
gerekçesi `ui/ledger/ledger_board.dart` başında; sözleşmesi de
`test/ledger_board_layout_test.dart`'ta kilitli (bölüm gövdesi dikey kaydırma
AÇMAZ — sayfalar).

```
flutter run -d macos -t lib/tools/mobile_capture_main.dart
DEVICES=small,iphone15 STEPS=01_hud,13_ledger_divan flutter run -d macos -t …
```

İki tuzağı kendi içinde çözer, dokunma:
* **Kare zorlama** — macOS penceresi arkadayken vsync gelmez, öbür harness'lar
  ilk karede donar. Burada frame elle sürülür (`_forceFrame`).
* **Zaman damgası** — kare damgası motorun saatinden türetilir; kendi
  saatimizi kullanmak `AnimationController` assert'i patlatıp yarım kalan
  geçişleri ekranda bırakıyordu.

`law_demo_ctx.dart` bir giriş noktası değil — kanun harness'larının paylaştığı
sahte bağlam.
