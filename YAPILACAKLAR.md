# YAPILACAKLAR — Eğlence Paketi (gerilim görünürlüğü + tempo + uyarı rampası)

> ✅ UYGULANDI — 14 Ağustos 2026. Kod, kayıt/restore ve test doğrulaması tamamlandı.

Bu liste, oyunun eğlence analizinden çıkan 4 maddelik iş paketinin UYGULAMA
talimatıdır. Her madde bağımsız uygulanabilir; sıra önerisi: 1 → 3 → 4 → 2
(kolaydan zora). Satır numaraları yaklaşıktır (dosyalar oynayabilir), çapa
olarak verilen kod parçasını ara.

## Genel kurallar (CLAUDE.md'nin bu işe düşen özü)

- `flutter analyze` SIFIR sorunla bitmeli. Pazarlık yok.
- **Her yeni state alanı `scene_save`'de hem capture hem restore'a eklenir.**
  Eklenmezse yüklenen köyde sistem sıfırlanır (bilinen tuzak).
- Oyuncu-yüzü ANLATI metni varyant havuzuyla yazılır (`Voice.say`/`Voice.pick`,
  en az 3 varyant). Kısa UI etiketi/künye (rozet, şerit parçası) düz string
  olabilir — defterdeki mevcut üslup bu. Oyun metninde em-dash YASAK.
- Eskalasyonun TEK kaynağı `systems/village_year.dart`. 1. yıl TÜM çarpanlar
  1.0 (taban denge korunur).
- Saf mantık `lib/systems/` altına, sahne bağlama `scene_*` part'ına.
- Panelde gösterilen sayı = simin okuduğu sayı. Karne ASLA cache'lenmiş kopya
  göstermez; her build'de canlı `_reckoningInput()`tan türer.
- Commit ATMA — kullanıcı istemeden commit yok.

---

## ✅ UYGULANDI (tekrar yapma, üstüne inşa et)

1. `lib/systems/house_stance.dart` — `HouseStanceX` extension'ına `costHint`
   getter'ı eklendi (basamağın kısa bedel künyesi). `nextRung(...)` zaten vardı.
2. `lib/ui/village_ledger.dart` — `_houseRow` içindeki
   `if (!s.stance.withholds) return row;` kapısı `!s.stance.audible` yapıldı ve
   `_withholdLine` yerine `_stanceStrip` geldi: serzeniş kehribar (AppUi.gold),
   esirgeyen basamaklar kızıl (AppUi.rust), sona `bir adım ötede: <costHint>`
   önizlemesi eklendi.

Bu ikisi `flutter analyze`'dan temiz geçti.

---

## MADDE 1 (kalan iki parça) — hane uyarı rampası

### 1a. Hane eylem kartına duruş satırı
Dosya: `lib/ui/ledger_house_cards.dart`, `_HouseActionCard.build` başlık sütunu
(`'reis ${seat.name} · ...'` Text'inin hemen ALTINA, aynı Column içine):

```dart
// Hanenin duruşu + bir adım ötesinin bedeli — oyuncu kartı açtığında
// merdivenin neresinde olduğunu ve sıradaki basamağın ne götüreceğini
// eylemleri seçmeden ÖNCE okur (bkz. house_stance.nextRung yorumu).
if (seat.stance != HouseStance.content) ...[
  const SizedBox(height: 2),
  Text(
    () {
      final next = nextRung(seat.stance);
      final head = '${seat.stance.icon} ${seat.stance.label}';
      return next == null
          ? head
          : '$head · bir adım ötede: ${next.costHint}';
    }(),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: AppUi.label.copyWith(
      color: seat.stance == HouseStance.loyal
          ? AppUi.gold
          : seat.stance.withholds
              ? AppUi.rust
              : AppUi.gold,
    ),
  ),
],
```

Not: `ledger_house_cards.dart` `village_ledger.dart`'ın part'ı; `house_stance`
import'u ana dosyada zaten var, yeni import gerekmez.

### 1b. Mobil defterde duruş görünürlüğü
Dosya: `lib/ui/ledger_mobile.dart`, `_MiniTension.build` — soyad `SizedBox`'ının
hemen ARKASINA (bar'dan önce):

```dart
// Duruş ikonu: telefon satırı 24dp, etikete yer yok — ikon tek başına
// "bu hane sesini çıkarıyor" der; ayrıntı masaüstü defterde.
if (house.stance.audible) ...[
  const SizedBox(width: 4),
  Text(house.stance.icon, style: const TextStyle(fontSize: 9)),
],
```

TUZAK: iPhone 11 (896×414) bütçesi — satır yüksekliği 24dp sabit, Row'a
genişleyen bir şey EKLEME (bar `Expanded` zaten). İkon + 4dp güvenli.

### Doğrulama (madde 1)
- `flutter analyze` temiz.
- `flutter test test/house_stance_test.dart` (mevcut) kırılmamalı.
- Yeni birim testi ekle (`test/house_stance_test.dart`): her basamak için
  `costHint` boş değil; `nextRung(murmuring) == withdrawn`;
  `nextRung(defiant) == null`; `nextRung(loyal) == null`.

---

## MADDE 3 — karar mührü inince hız kendiliğinden 1×

Sorun: major karar mühleti 1×'te 48 sn ama oyuncu 64 dakikalık yılı doğal
olarak 4×'te oynuyor → mühlet gerçek zamanda 12 sn'ye düşüyor.

### 3a. Helper
Dosya: `lib/main.dart`, `_cycleSpeed()`'in hemen altına:

```dart
/// KARAR MÜHRÜ İNİNCE hız kendiliğinden 1×'e iner. Mühlet, hız çarpanının
/// kurbanı olmamalı: 4×'te major karara 12 sn kalıyordu. Donma/modal DEĞİL
/// (kapıda kuyruk sözleşmesi bozulmaz): sim akmaya devam eder, yalnız nefes
/// 1×'e iner; oyuncu isterse tekrar hızlandırır. Duraklatma (0×) korunur.
/// SESSİZ: bildirim slotu tek — mührün kendi bildirimini ezmesin.
void _easeToBaseSpeed() {
  if (_timeScale <= 1.0) return;
  setState(() {
    _speedIdx = 0; // _speedSteps[0] == 1.0
    _timeScale = 1.0;
  });
}
```

### 3b. Çağrı yerleri (ikisi de setStateHere bloğunun DIŞINDA, sonrasında)
- `lib/scene/scene_events.dart` → `_queueChoiceEvent(...)`: `setStateHere`
  bloğundan sonra, `kProbeChoiceWaiting = e.id;` satırının yanına
  `_easeToBaseSpeed();`
- `lib/scene/scene_petitions.dart` → `_presentPetition(...)`: `setStateHere`
  bloğundan sonra (`_walkPetitionerToCenter` çağrısından önce)
  `_easeToBaseSpeed();`

Dev kısayolları (`_forcePetition`, `_forcePetitionById`, ...) DOKUNMA — onlar
zaten modal açıyor.

TUZAK KONTROLÜ: prova testleri hızı `kDevSpeedBoostOverride` ile basıyor
(`scene_tick.dart:98-110` civarı). `_timeScale`'i 1'e çekmek override'ı
etkilememeli — kontrol et: boost, `_timeScale`'den bağımsız uygulanıyorsa sorun
yok; çarpım olarak uygulanıyorsa bile prova köyünde `_timeScale` zaten 1.

### Doğrulama (madde 3)
- Telemetri: `scene_probe.dart`'taki global kalıbına uyarak
  `bool kProbeAutoSlowed = false;` ekle; `_easeToBaseSpeed` gerçekten
  yavaşlattığında `true` yap. (Bağlanmayan alan olmasın: en az bir testte oku.)
- `test/decision_queue_probe_test.dart` içinde uygun bir noktada: hızı 2×'e
  çıkar (HUD butonu `find` edilebiliyorsa tap; edilemiyorsa bu adımı atla),
  dilekçe zorla, `kProbeAutoSlowed == true` bekle.

---

## MADDE 4 — dilekçe temposu: jitter + yıl çarpanı + kuyruk tavanı 2

### 4a. Yıl çarpanı (saf çekirdek)
Dosya: `lib/systems/village_year.dart`.

`EraPressure`'a alan ekle (diğer alanların yanına, doc yorumuyla):

```dart
/// Dilekçe geliş aralığı çarpanı. KÜÇÜLDÜKÇE SIK: köy yaşlandıkça kapı
/// daha işlek — yönetişim yükü de yılla artmalı, yoksa 1. yılın ve 6.
/// yılın kapısı aynı kalıyordu (oyunun kalbi dilekçeyse kalp atışı sabit
/// olamaz). Olay temposundan (0.65) bilerek yumuşak: dilekçe KARAR ister,
/// olay çoğu kez kendi yaşar.
final double petitionTempo;
```

Constructor'a `required this.petitionTempo,` ekle; `pressureForYear`'da:

```dart
// 1.0 → 0.70. Taban aralık ~1.1-1.9 gün → son yılda ~0.8-1.3 gün.
petitionTempo: 1.0 - 0.06 * step,
```

### 4b. Jitter (sahne)
Dosya: `lib/scene/scene_petitions.dart`, `_petitionInterval()`'ı değiştir.
ÖNEMLİ: mevcut yorumdaki kullanıcı kararına DOKUNMA — küskün-hane
hızlandırması (×0.6) reddedilmiş yoldur, GERİ GELMEZ. Yorumun o kısmını koru,
üstüne şunu anlat:

```dart
/// Dilekçeler arası bekleme — taban sabit, üstüne İKİ büküm:
///   • JITTER [×0.73..×1.27] — metronom kırılır: sessiz gün ile işlek kapı
///     ayrışır. Ortalama ×1.0 → 1. yıl ortalaması 1.5 gün KORUNUR (taban
///     denge kuralı).
///   • YIL ÇARPANI (village_year.petitionTempo) — köy yaşlandıkça sıklaşır.
/// Küskün-hane hızlandırması BİLEREK YOK (reddedilmiş yol): kızgın hane
/// anlatı üretir, baskı çarpanı üretmez.
double _petitionInterval() =>
    _kPetitionInterval *
    (0.73 + 0.54 * _rng.nextDouble()) *
    pressureForDay(_dayCount).petitionTempo;
```

### 4c. Kuyruk alanları
Dosya: `lib/main.dart`, `Petition? _pendingPetition;` (satır ~1464) yanına:

```dart
/// KAPIDA SIRA — aktif dilekçe çözülmeden mayalanan İKİNCİ dilekçe (tavan 2).
/// Ham (spoken edilmemiş) durur; sözcüsü/mühleti sırası gelince atanır.
Petition? _queuedPetition;

/// Slot boşaldıktan sonra sıradakinin öne çıkmadan bekleyeceği nefes payı (sn).
double _queuedPresentDelay = 0;
```

### 4d. Tick akışı
Dosya: `lib/scene/scene_petitions.dart`, `_tickPetitions` içinde.

(1) Bekleyen-dilekçe dalını şöyle değiştir (overdue İKEN kuyruk mayalanmaz —
oyuncu bilerek bekletiyorsa üstüne ikinci sözcü yığılmasın):

```dart
if (_pendingPetition != null) {
  if (_petitionOverdue) {
    _tickOverduePetition(dt);
    return;
  }
  _petitionDeadline -= dt;
  if (_petitionDeadline <= 0) {
    _deadlineReached();
    return;
  }
  _brewQueuedPetition(dt); // kapıda sıra: ikinci dilekçe mayalanabilir
  return;
}
```

(2) Boş-slot dalında, zincir (follow-up) bloğundan SONRA ve
`_petitionTimer -= dt;` satırından ÖNCE:

```dart
// Sırada bekleyen varsa önce o konuşur (kapıda kuyruk, 2. slot). Nefes
// payı: modal kapanır kapanmaz yeni sözcü fırlamasın, ~19 sn (1×) geçsin.
if (_queuedPetition != null) {
  _queuedPresentDelay -= dt;
  if (_queuedPresentDelay > 0) return;
  final q = _queuedPetition!;
  _queuedPetition = null;
  _presentPetition(q);
  return;
}
```

(3) Yeni fonksiyon (aynı extension içine):

```dart
/// Aktif dilekçe beklerken zaman İŞLEMEYE devam eder: sayaç dolarsa ikinci
/// dilekçe kapıda SIRAYA girer (tavan 2 — üçüncü mayalanmaz). Sıradaki ham
/// bekler: sözcü/mühlet, sırası gelince _presentPetition'da atanır.
void _brewQueuedPetition(double dt) {
  if (_queuedPetition != null) return;
  if (_policies.sealed.contains('nizam.sole')) return;
  _petitionTimer -= dt;
  if (_petitionTimer > 0) return;
  _petitionTimer = _petitionInterval();
  final blocked = <String>{
    for (final e in _petitionCooldowns.entries)
      if (e.value > _time) e.key,
    _pendingPetition!.id, // aynı dilekçe iki kez kapıda olmasın
  };
  final p =
      PetitionSystem.roll(_buildPetitionContext(), _rng, blocked: blocked);
  if (p == null) return;
  setStateHere(() {
    _queuedPetition = p;
    _queuedPresentDelay = 0.08 * kGameDaySeconds;
  });
  _showNotification(Voice.say(const [
    '📜 Kapıda bir dilekçe daha bekliyor.',
    '📜 Bir başkası da derdini yazdırmış; kapıda sırada.',
    '📜 Kapıdaki kuyruk uzadı: ikinci bir dilekçe var.',
  ], _voice(null, seed: _stableSeed('petitionQueue', _dayCount))));
}
```

### 4e. HUD'da "SIRADA" mührü
Dosya: `lib/scene/scene_petitions.dart`, `buildDecisionSeals()` içinde,
bekleyen dilekçe mührünün eklendiği `if` bloğunun ARKASINA:

```dart
// Kapıda sıradaki dilekçe — halkasız, sakin rozet. Dokununca eldeki karar
// açılır: sıra, eldeki iş bitmeden konuşmaz.
if (_queuedPetition != null) {
  seals.add(PetitionSeal(
    onTap: _pendingPetition != null ? _openPetition : () {},
    progress: 1.0,
    tone: PetitionTone.solemn,
    label: 'SIRADA',
    statusIdle: 'kapıda bir dilekçe daha',
    statusUrgent: 'kapıda bir dilekçe daha',
  ));
}
```

### 4f. Kayıt + sıfırlama
Dosya: `lib/scene/scene_save.dart`.
- Capture (`'pendingPetition': _pendingPetition?.id,` yanına):

```dart
'queuedPetition': _queuedPetition?.id,
'queuedPresentDelay': _queuedPresentDelay,
```

- Restore (`_petitionTimer = ...` satırlarının yanına):

```dart
_queuedPetition = PetitionSystem.byId((w['queuedPetition'] as String?) ?? '');
_queuedPresentDelay = _d(w['queuedPresentDelay']);
```

  (`PetitionSystem.byId` null döndürebiliyor — boş id'de null döndüğünü
  doğrula; dönmüyorsa `w['queuedPetition'] == null ? null : byId(...)` yaz.)
- Dünya sıfırlama bölümünde (`_petitionFollowUps.clear();` civarı, ~794):

```dart
_queuedPetition = null;
_queuedPresentDelay = 0;
```

### Doğrulama (madde 4)
- `test/village_year_test.dart`'a ekle: `petitionTempo` yıl 1'de tam 1.0;
  yıl arttıkça tekdüze azalır; yıl 6'da 0.70'e eşit; yıl 9 istense de 0.70
  altına inmez (clamp sözleşmesi).
- `test/decision_queue_probe_test.dart`'a senaryo ekle: dilekçe zorla
  (`_forcePetition` dev yolu) → `_brewQueuedPetition`'ı kısa sayaçla tetikle
  (sayaç erişilemiyorsa: `kProbe*` kalıbıyla bir zorlama kancası ekle,
  mevcut `_forcePetitionShortFuse` örneğini kopyala) → ekranda `SIRADA`
  rozetini `find.text('SIRADA')` ile kanıtla → aktif dilekçeyi çöz →
  sıradakinin bekleyen dilekçeye dönüştüğünü doğrula.
- Kayıt gidiş-dönüşü: `test/save_roundtrip_test.dart` kalıbına
  `queuedPetition` alanını ekle (kaydet → yükle → alan duruyor).

---

## MADDE 2 — yıllık imparatorluk karnesi + 5. yıl "şunları düzelt"

Sorun: `standing` (hesaplaşma iğnesi) 6. yıla kadar hiçbir UI'da yok; oyuncu
sancak/berat/ilhak yolunda nerede olduğunu göremiyor.

### 2a. Saf çekirdek
Dosya: `lib/systems/reckoning.dart` — dosyanın sonuna ekle:

```dart
/// YILLIK KARNE — kapanış karnesinin ŞİMDİKİ ZAMAN hâli. Aynı beş kalem,
/// ama koşu sürerken okunur: "yüzünü çevirmişti" değil "çeviriyor".
/// Komutanın yıllık pusulası ve Defter > Divan'daki İMPARATORLUĞUN GÖZÜ
/// bloğu bunu okur. Saf ve testli (bkz. test/reckoning_test.dart).
List<ReckoningLedgerRow> karneLedger(ReckoningInput i) => [
      ReckoningLedgerRow('Hanelerin rızası', i.unity, _band(i.unity, const [
        'Haneler yüzünü çeviriyor.',
        'Bazı haneler seninle, bazıları değil.',
        'Haneler arkanda duruyor.',
      ])),
      ReckoningLedgerRow('Tüzüğün kalınlığı', i.charter,
          _band(i.charter, const [
        'Köyün yazılı bir huyu yok.',
        'Birkaç hüküm var, bir duruş yok.',
        'Kanunname köyün huyunu belirliyor.',
      ])),
      ReckoningLedgerRow('Köyün ağırlığı', i.grit, _band(i.grit, const [
        'Köy küçük, sesi uzağa gitmiyor.',
        'Köy kendini döndürüyor, fazlası değil.',
        'Kalabalık ve tok bir kasaba.',
      ])),
      ReckoningLedgerRow('Kararların mirası', i.legacy, _band(i.legacy, const [
        'Büyük kararlar kötü iz bırakıyor.',
        'Kararlar gelip geçiyor, iz bırakmıyor.',
        'Kararların köyün hafızasında iyi duruyor.',
      ])),
      ReckoningLedgerRow('İmparatorlukla arası', i.favor,
          _band(i.favor, const [
        'Komutanın defterinde adın kırmızı.',
        'Ne dost ne düşman: ödüyorsun, geçiyor.',
        'Heyet buraya gelmeyi iş değil usul sayıyor.',
      ])),
    ];

/// Karnenin EN HAFİF iki kefesi — yalnız standing'e giren dört kalem
/// (İmparatorlukla arası HARİÇ: o ayrı bir kurtuluş yolu, standing'e
/// girmez). Değere göre artan sıralı döner: [0] en zayıf.
List<ReckoningLedgerRow> karneAdvice(ReckoningInput i) {
  final rows = karneLedger(i)
      .where((r) => r.label != 'İmparatorlukla arası')
      .toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  return rows.take(2).toList();
}

/// Zayıf kefenin "ne yapmalı" künyesi — 5. yıl hazırlık penceresi ve
/// Defter bloğu okur. Etiketler [karneLedger] ile birebir aynı olmalı.
const Map<String, String> kKarneHints = {
  'Hanelerin rızası':
      'küskün haneyi barıştır: bağış, nikâh, dilekçesine kulak',
  'Tüzüğün kalınlığı': 'yeni hüküm mühürle, kimliğe yat',
  'Köyün ağırlığı': 'nüfusu büyüt, keseyi ve ambarı doldur',
  'Kararların mirası': 'büyük dilekçelerde iz bırakan şıkları seç',
};
```

### 2b. Sahne alanı
Dosya: `lib/main.dart`, `bool _reckoningHeralded = false;` (satır ~1679)
yanına:

```dart
/// Komutanın yıllık pusulasının en son düştüğü yıl (0 = henüz yok).
/// 2. yıldan itibaren her yıl başında bir kez düşer (bkz. scene_reckoning).
int _karneYear = 0;
```

### 2c. Pusulanın düşüşü
Dosya: `lib/scene/scene_reckoning.dart`, `_tickReckoning` içinde İLAN
bloğundan ÖNCE (ilan ve hesaplaşma öncelikli kalsın diye onların ARKASINA
DEĞİL — sıra: ilan → hesaplaşma → karne; her biri `return` ile ayrışıyor,
karne bloğunu hesaplaşma bloğunun ARKASINA koy ve `year < kReckoningYear`
kapısı ekle):

```dart
// ── 3) YILLIK PUSULA — 2. yıldan itibaren her yıl başında bir kez ─────────
if (year >= 2 && year < kReckoningYear && year > _karneYear) {
  _karneYear = year;
  _deliverKarne();
}
```

Yeni fonksiyon (aynı extension'a):

```dart
/// KOMUTANIN YILLIK PUSULASI — hesaplaşma iğnesi 6. yıla kadar görünmezdi;
/// oyuncu "acaba yetişir miyim" gerilimini hiç yaşamıyordu. Pusula yılda bir
/// kez iğneyi diegetik gösterir: bugün tartılsa ne çıkardı, en hafif kefe
/// hangisi. Ayrıntı Defter > Divan'da CANLI durur (cache yok: panel = sim).
void _deliverKarne() {
  final input = _reckoningInput();
  final v = judge(input);
  final weak = karneAdvice(input).first;
  final seed = _stableSeed('karne', _dayCount);
  _showNotification('📯 ${Voice.pick(const [
        'Komutandan pusula geldi.',
        'Heyetin katibi yıllık pusulayı bıraktı.',
        'İmparatorluğun defterinden bir satır düştü.',
      ], seed)} Bugün tartılsa: ${v.name}. '
      'En hafif kefe: ${weak.label.toLowerCase()}.');
  _chronicle(
      'Komutanın pusulası: bugün tartılsa ${v.name}. '
      'En hafif kefe ${weak.label.toLowerCase()}.',
      icon: '📯',
      kind: ChronicleKind.life);
  logDev('KARNE: yıl ${yearOf(_dayCount)} ${v.name} '
      'standing=${input.standing.toStringAsFixed(2)}');
}
```

Ayrıca `_heraldReckoning()`'e (5. yıl ilanı) hazırlık listesi ekle — mevcut
`_chronicle` satırından SONRA:

```dart
// Hazırlık penceresi takvim değil YAPILACAK LİSTESİ olmalı: en hafif iki
// kefe + ne yapılacağı. Bildirim slotu dolu (ilan konuşuyor) → günceye.
final advice = karneAdvice(_reckoningInput());
_chronicle(
    'Hazırlık yılı: en hafif kefeler ${advice[0].label.toLowerCase()} ve '
    '${advice[1].label.toLowerCase()}. '
    'İlki için: ${kKarneHints[advice[0].label]}.',
    icon: '📯', kind: ChronicleKind.life);
```

### 2d. Kayıt
Dosya: `lib/scene/scene_save.dart`.
- Capture: `'reckoningHeralded': _reckoningHeralded,` yanına
  `'karneYear': _karneYear,`
- Restore: `_reckoningHeralded = ...` yanına
  `_karneYear = _i(w['karneYear'], 0);`

### 2e. Defter yüzeyi (Divan)
İki parça: gündem satırı (masaüstü + mobil OTOMATİK) ve masaüstü detay bloğu.

**(1) Gündem satırı** — dosya: `lib/scene/scene_divan.dart`, `_divanAgenda()`
başına (bekleyen dilekçe bloğundan sonra):

```dart
// İMPARATORLUĞUN GÖZÜ — pusula düştüyse gündemde kalıcı bir satır.
// pressure çubuğu standing'in kendisi: iğne artık görünür.
if (_karneYear >= 2 && _reckoningVerdict == null) {
  final input = _reckoningInput();
  final v = judge(input);
  final weak = karneAdvice(input).first;
  out.add(DivanMatter(
    icon: '📯',
    title: 'İmparatorluğun gözü',
    sub: 'bugün tartılsa: ${v.name} · '
        'en hafif kefe: ${weak.label.toLowerCase()}',
    pressure: input.standing,
    tone: v == ReckoningVerdict.ilhak
        ? PetitionTone.ominous
        : v == ReckoningVerdict.sancak
            ? PetitionTone.warm
            : PetitionTone.neutral,
    pending: false,
  ));
}
```

**(2) Masaüstü detay bloğu** — beş kalemin çubuklu dökümü.
- `lib/ui/village_ledger.dart`: `VillageLedger`'a parametreler ekle
  (constructor + final alanlar, varsayılanları boş):

```dart
final List<ReckoningLedgerRow> karne; // boş = pusula henüz düşmedi
final int karneYear;
final String karneVerdict; // 'sancak' | 'berat' | 'ilhak' | ''
final String karneAdviceLine; // 5. yıldan itibaren dolu, yoksa ''
```

  (import zaten `../systems/`den yapılıyor; `import '../systems/reckoning.dart';`
  ekle.)
- `_meclisTab()` içinde `agenda` listesinin SONUNA (identityBonus bloğundan
  sonra):

```dart
if (karne.isNotEmpty) ...[
  const SizedBox(height: 16),
  AppSectionLabel('İMPARATORLUĞUN GÖZÜ — $karneYear. YIL'),
  const SizedBox(height: 6),
  _karneBlock(),
],
```

- Yeni widget (VillageLedger sınıfına):

```dart
/// Karne dökümü — hesaplaşmanın beş kalemi, koşu SÜRERKEN. Değerler her
/// build'de simden gelir (cache yok); kapanış ekranıyla aynı satır tipi.
Widget _karneBlock() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final r in karne)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: [
              SizedBox(
                width: 116,
                child: Text(r.label,
                    style: AppUi.body
                        .copyWith(fontSize: 10.5, color: AppUi.textMid)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppUi.surface0,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppUi.line, width: 0.8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: r.value.clamp(0.0, 1.0),
                        child: Container(color: AppUi.gold),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 150,
                child: Text(r.note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppUi.body
                        .copyWith(fontSize: 10, color: AppUi.textLo)),
              ),
            ],
          ),
        ),
      if (karneVerdict.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text('Defter bugün kapansaydı: $karneVerdict',
              style: AppUi.bodyHi
                  .copyWith(fontSize: 11, color: AppUi.gold)),
        ),
      if (karneAdviceLine.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(karneAdviceLine,
              style: AppUi.body
                  .copyWith(fontSize: 10.5, color: AppUi.textMid)),
        ),
    ],
  );
}
```

- `lib/scene/scene_divan.dart` → `buildVillageLedger()`'da parametreleri doldur
  (⚖ DİVAN grubuna):

```dart
karne: (_karneYear >= 2 && _reckoningVerdict == null)
    ? karneLedger(_reckoningInput())
    : const [],
karneYear: _karneYear,
karneVerdict: (_karneYear >= 2 && _reckoningVerdict == null)
    ? judge(_reckoningInput()).name
    : '',
karneAdviceLine: (_karneYear >= kReckoningHeraldYear &&
        _reckoningVerdict == null)
    ? () {
        final a = karneAdvice(_reckoningInput());
        return 'Hazırlık: ${a[0].label.toLowerCase()} için '
            '${kKarneHints[a[0].label]}.';
      }()
    : '',
```

  (İnce ayar: `_reckoningInput()` burada 2-3 kez çağrılıyor; istersen tek
  değişkende topla. Pahalı değil ama temiz olur.)

TUZAK: sayısal 0..1 çubuk gösteriyoruz ama SAYI yazmıyoruz — bu bilinçli
(baş üstü sayısal refleksiyon yasağının paneli değil ama üslup aynı: çubuk +
cümle yeter, "0.61" yazma).

MOBİL: detay bloğu telefona EKLENMEZ (tahta sabit boylu, taşar — bilinen
tuzak). Telefon, gündem satırı (2e-1) üzerinden görür; o satır BoardPager'da
zaten akıyor.

### Doğrulama (madde 2)
- `test/reckoning_test.dart`'a ekle:
  - `karneLedger` 5 satır döner, etiketleri `reckoningLedger` ile birebir aynı.
  - `karneAdvice` 2 satır döner, 'İmparatorlukla arası' asla içinde değil,
    artan sıralı (`[0].value <= [1].value`).
  - `kKarneHints` dört standing etiketinin dördünü de kapsar (karneLedger
    etiketleriyle çapraz doğrula — etiket yazımı kayarsa test kırılsın).
- `test/reckoning_probe_test.dart` kalıbıyla prova: `kProbeJumpToDay` ile
  2. yıla atla → pump → kronikte '📯' satırı VE Defter açılınca (ya da
  `_divanAgenda()` telemetrisiyle) 'İmparatorluğun gözü' maddesi var.
  Mevcut prova köyü muafiyet listesine DOKUNMA — karne `_reckoningEnabled`
  kapısının arkasında kalmalı ki harness köyleri pusula yağmuruna tutulmasın
  (prova kendi `kProbeReckoningArmed` bayrağıyla açar).

---

## Son doğrulama (hepsi bitince)

```bash
flutter analyze                       # sıfır sorun
flutter test                          # tam süit (~4 dk), kırmızı bırakma
```

DURUM.md'ye tek satır ekle (⚠ Eksik listesinden düşen bir şey yok; ✅ Biten'e
"Eğlence paketi: karne + tempo + rampa + hız düşüşü" satırı).

---

## MADDE 5 — ritüel takvimi: SPEC YOK, ÖNCE VİZYON

Bilerek yazılmadı (CLAUDE.md: yön belirleyici işten önce sor). Kullanıcıyla
konuşulacak sorular:
1. Sosyal doku turunun sırası bozulsun mu (ritüeller öne), yoksa plandaki
   sıra mı (baloncuk borcu → sokak → koreografi → ritüeller)?
2. Hangi ritüeller? (mevsim başı şenliği / hasat şükranı / kış gecesi hikâye
   saati / bahar nikâh mevsimi / yıldönümü anmaları)
3. Takvim yüzeyi: HUD'da yaklaşan-ritüel şeridi mi, Defter'e takvim sayfası mı?
4. Ritüel bedeli: tamamen bedava mı (chill kuralı), yoksa küçük hazırlık
   kararı mı (ör. şenlik için ambar payı)?
