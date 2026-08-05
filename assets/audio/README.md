# assets/audio — ses kütüphanesi

Motor `lib/systems/audio_manager.dart`. Üç katman: **ortam** (döngü), **müzik**
(döngü), **efekt** (tek atış). Dosya adları kodda sabit; buraya doğru adla bir
MP3 bırakmak yeterli, kod değişmez.

**Eksik dosya sessizdir, çökmez.** `playSfx`/`playMusic` hatayı yutar. Bu
yüzden aşağıdaki "beklenen" satırlar önden bağlandı: MP3 düştüğü an duyulur.

`pubspec.yaml` `assets/audio/` klasörünü toptan dahil ediyor → yeni dosya için
pubspec düzenlemesi gerekmez, `flutter pub get` yeter.

## Ayar eşlemesi

| Katman | Slider | Not |
|---|---|---|
| Ortam döngüleri | **Ortam** | Eskiden yanlışlıkla "Müzik"e bağlıydı |
| Müzik | **Müzik** | |
| Efektler | **Efekt** | |

## Mevcut (çalışıyor)

| Dosya | Katman | Nerede |
|---|---|---|
| `morning_garden.mp3` | ortam | gündüz döngüsü |
| `crickets_night.mp3` | ortam | gece döngüsü |
| `rain_light.mp3` | ortam | yağmur |
| `thunderstorm.mp3` | ortam | fırtına (yağmur > 0.6) |
| `campfire.mp3` | ortam | köyde yanan ateş varken |
| `bell_chime.mp3` | efekt | görev tamamlanır / meclis reddeder |
| `rooster_crow.mp3` | efekt | şafak |
| `owl.mp3` | efekt | gece aksanı (seyrek) |
| `birds_singing.mp3` | efekt | gündüz aksanı (seyrek) |
| `thunder_clap.mp3` | efekt | şimşek + imparatorluk sertliği |
| `crowd_fair.mp3` | efekt | şenlik/kutlama |
| `cow_moo.mp3` / `chicken_cluck.mp3` | efekt | hayvan alımı, kümes |
| `imperial_march.mp3` | efekt | vergici kolonu yaklaşır |

### İnsan sesleri (2026-08-03)

Köyde bugüne dek hiç insan sesi yoktu: çan, hayvan ve hava vardı, ağız yoktu.
Hepsi **kelimesiz** — metni `voice.dart` yazıyor, ses ayrıca cümle kurarsa
ikisi çelişir ve dil eklenince kadro çöpe gider.

| Dosya | Katman | Nerede |
|---|---|---|
| `child_laugh_1.mp3` / `child_laugh_2.mp3` | efekt | gündüz seyrek aksan, köyde 1-2 çocuk varken (varyant çifti) |
| `children_play.mp3` | efekt | aynı aksan, köyde **3+** çocuk varken (kıkırdama yerine oyun uğultusu) |
| `cough_1.mp3` / `cough_2.mp3` | efekt | hastalık başlar + hasta varken seyrek (`scene_illness`) |
| `throat_clear.mp3` | efekt | dilekçe sunulur (`_presentPetition`) — çandan devraldı |
| `seal_stamp.mp3` | efekt | ferman mühürlenir (`scene_law`) — sert ahşap vuruş, 0.42 sn |
| `funeral_toll.mp3` | efekt | cenaze töreni (`_holdFuneral`) — çan kaydının ilk 2 sn'si + fade |
| `crowd_applause.mp3` | efekt | düğün alayı (`_reactWedding`) |
| `build_start.mp3` | efekt | şantiye kurulur, aletler çıkar (`scene_placement`) |
| `build_done.mp3` | efekt | bina tamamlanır (`scene_jobs`) — kalas yığını iner |
| `fight_scuffle.mp3` | efekt | yumruklaşma (`scene_conflict`, yalnız brawl) — gövde yere düşer |
| `birth_joy.mp3` | efekt | bebek doğar (`_spawnBabyFromParents`) — marimba, 2 sn'ye kırpıldı + fade |

**Varyant desteği:** `_sfxFile` artık `Map<Sfx, List<String>>`. Listede birden
çok dosya varsa her çalışta rastgele biri seçilir ve **aynı varyant üst üste
gelmez** (ikilikte saf rastgelelik %50 tekrar demek, kulak onu tek ses sanar).
Yeni varyant eklemek = listeye bir dosya adı yazmak.

## BEKLENEN (bağlandı, dosya yok)

Şu an **boş** — bağlanmış her kancanın dosyası düştü.

Yeni bir kanca eklerken buraya satır yaz. Uzunluk önerileri kabaca; asıl ölçüt
**tekrar duyulduğunda yormaması**. Oyunun tonu cozy/ağırbaşlı: vurucu değil,
yumuşak ataklı sesler.

## Ham kayıttan dosyaya

İndirilen kayıt genelde uzun kuyruklu (marimba'nın son 1.3 sn'si -35 dB altı,
duyulmuyor ama her doğumda çalınıyor). Kırpma ölçüsü kulak değil ölçüm:

```
ffmpeg -i ham.wav -af "atrim=0:2.0,asetpts=N/SR/TB,afade=t=out:st=1.6:d=0.4" \
       -ar 44100 -ac 2 -codec:a libmp3lame -q:a 4 assets/audio/hedef.mp3
```

Seviye normalize ETME: süitin bütünleşik gürlüğü -11..-19 LUFS bandında
dağınık, tek dosyayı hizalamak onu komşularından ayırır. Ses fazla/az geliyorsa
`_sfxGain` tablosundan ayarla — seviye kararı kodda tek yerde dursun.

## İSTENMEDİ (kanca duruyor, dosya aranmayacak)

Kullanıcı kararı (2026-08-03) — kanca kodda kalıyor, sessiz duruyor. Fikir
değişirse dosyayı bırakmak yeter; yeniden ÖNERME.

| Dosya | Nerede olurdu |
|---|---|
| `ui_tap.mp3` | her `AppButton` dokunuşu |
| `music_menu.mp3` / `music_village.mp3` | menü + oyun müziği |

## Kanca eklerken

1. `Sfx` (ya da `MusicTrack`) enum'una gir.
2. `_sfxFile` tablosuna dosya adı **listesi** yaz (tek dosya da liste).
3. `_sfxGain` tablosuna taban seviye ver (sık duyulan ses = alçak).
4. Bu tabloya bir satır ekle.

Aynı sesi iki farklı olaya bağlama: `bell_chime` bir ara dört ayrı olayı
karşılıyordu ve oyunun bütün önemli anları aynı duyuluyordu. Dilekçe
`throat_clear`'a, düğün `crowd_applause`'a ayrıldı; çanda görev + meclis reddi
kaldı.
