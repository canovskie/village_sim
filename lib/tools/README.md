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

## Kare yakalayan araçlar (PNG üretir)

| Araç | Neyi gösterir |
|---|---|
| `ui_gallery_capture_main.dart` | **Tek çalıştırmada oyunun tüm UI yüzeyleri.** UI değişikliğinden sonra ilk bakılacak yer. |
| `scene_capture_main.dart` | Taze bir köy sahnesi (menüyü atlar). |
| `living_capture_main.dart` | Showcase köyü: binalar + sürü + meslekler bir arada. |
| `ledger_capture_main.dart` | Köy Defteri'nin beş bölümü. |
| `law_capture_main.dart` | Kanunname + mühür ritüeli. |
| `compass_capture_main.dart` | Politik pusula, dört farklı köy hâlinde. |
| `petition_capture_main.dart` | Dilekçe modalı, gerçek metinlerle. |
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
ekranını sürer**. Beş yatay telefon/tablet profilinde (mobil yatay kilitli,
bkz. `systems/platform_adapt.dart`) 18 adım koşar — pan, pinch-zoom, inşa
paleti, köylü seçimi, Köy Defteri'nin beş bölümü — her adımda kare çeker ve
dört şeyi SAYAR: taşma, ekran dışına düşen yazı/hedef, 44dp altı dokunma
hedefi, 11px altı yazı.

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
