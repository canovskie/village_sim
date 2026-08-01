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
| `bell_chime.mp3` | efekt | görev tamamlanır / dilekçe açılır / meclis reddeder |
| `rooster_crow.mp3` | efekt | şafak |
| `owl.mp3` | efekt | gece aksanı (seyrek) |
| `birds_singing.mp3` | efekt | gündüz aksanı (seyrek) |
| `thunder_clap.mp3` | efekt | şimşek + imparatorluk sertliği |
| `crowd_fair.mp3` | efekt | şenlik/kutlama |
| `cow_moo.mp3` / `chicken_cluck.mp3` | efekt | hayvan alımı, kümes |
| `imperial_march.mp3` | efekt | vergici kolonu yaklaşır |

## BEKLENEN (bağlandı, dosya yok)

Uzunluk önerileri kabaca; asıl ölçüt **tekrar duyulduğunda yormaması**.
Oyunun tonu cozy/ağırbaşlı: vurucu değil, yumuşak ataklı sesler.

| Dosya | Süre | Nerede çalar | Ton |
|---|---|---|---|
| `seal_stamp.mp3` | ~1 sn | Kanunname'de ferman mühürlenir (`scene_law._sealLaw`) | Ahşap masaya basılan mühür; tok, tek vuruş. Kararın ağırlığı. |
| `birth_joy.mp3` | ~2 sn | Bebek doğar (`_spawnBabyFromParents`) | Yumuşak, ılık, küçük. Fanfar DEĞİL. |
| `funeral_toll.mp3` | ~3 sn | Cenaze töreni başlar (`_holdFuneral`) | Tek, uzak, sönen çan. Ağıt değil. |
| `wedding_joy.mp3` | ~3 sn | Düğün alayı (`_reactWedding`) | Kısa halk ezgisi kıvamı; def/ney tınısı olabilir. |
| `fight_scuffle.mp3` | ~1.5 sn | Yumruklaşma (`scene_conflict`, yalnız brawl) | Boğuk itiş kakış; kan/şiddet efekti değil. |
| `build_done.mp3` | ~1 sn | Bina tamamlanır (`scene_jobs`) | Son çekiç + oturma tınısı. Sık duyulur → alçak. |
| `ui_tap.mp3` | ~0.15 sn | Her `AppButton` dokunuşu | Çok kısa, çok alçak, tok. En sık duyulan ses; parlak olursa yorar. |
| `music_menu.mp3` | 1-2 dk döngü | Ana menü (şafak sahnesi) | Sakin, tek enstrüman ağırlıklı, döngüsü belli olmayan. |
| `music_village.mp3` | 2-4 dk döngü | Oyun sahnesi | Arka planda kalan, melodisi öne çıkmayan; ortam sesini boğmamalı (motor zaten 0.55 tavanla serer). |

## Kanca eklerken

1. `Sfx` (ya da `MusicTrack`) enum'una gir.
2. `_sfxFile` tablosuna dosya adını yaz.
3. `_sfxGain` tablosuna taban seviye ver (sık duyulan ses = alçak).
4. Bu tabloya bir satır ekle.

Aynı sesi iki farklı olaya bağlama: `bell_chime` bugün dört ayrı olayı
karşılıyor ve bu, oyunun bütün önemli anlarının aynı duyulmasının sebebi.
