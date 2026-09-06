part of '../../main.dart';

/// HARNESS BAYRAKLARI — kProbe*/kCapture*: prova ve yakalama araçlarının köye
/// müdahale kolları. Oyunda hepsi varsayılan değerinde durur; yalnız test ve
/// capture giriş noktaları yazar.
// ─── MAIN SCENE ──────────────────────────────────────────────────────────────

/// Debug/capture hook: true iken yeni oyun açılış sinematiğini + ateş-yerleştirme
/// modunu atlar, sim doğrudan akar (scene_capture_main.dart bunu set eder).
bool kCaptureMode = false;

/// Doğal kuruluş provasının yalnız-GÖZLEM arayüzü. Capture modu değildir:
/// saat, dünya tohumu, kararlar, NPC aklı ve kaynak ekonomisi normal oyundaki
/// gibi işler. Yalnız `tools/founding_tester_main.dart` bunu açar.
bool kFoundingTesterMode = false;

/// Hazır/showcase köy kurmadan mevcut doğal koşuyu canlı kontrol eden ayrı
/// tester target'ı. Normal oyunda ve capture araçlarında kapalıdır.
bool kVillageTesterMode = false;

/// Açılış halkasını gerçek sahnede prova ederken ses/platform eklentilerini
/// kapalı tutup yalnız bu prelüdü capture modunda çalıştırır.
bool kCaptureFoundingCouncil = false;
double kCaptureZoom = 1.0;
int kCaptureCarve =
    0; // capture: başlangıçta bu kadar halka ön-hattı "oy" (kütük/recede demo)
bool kCaptureSceneReady =
    false; // asset yüklenip sahne hazır olunca true (harness bekler)
/// capture: günün vaktini DONDUR (0..1; negatif = kapalı, saat normal akar).
/// Işıklandırma gibi vakte bağlı katmanların "önce/sonra" karşılaştırmasını
/// yapabilmek için şart: iki kare farklı saatte çekilirse fark ölçülemez.
double kCaptureTimeOfDay = -1;

/// capture: referans köy hangi MEVSİMDE kurulsun (bkz. kReferenceDayFor).
/// Kışın çadır/yakıt/tarla davranışını çekmek için harness'ın köyü yazın kurup
/// takvimi elle sarmasına gerek kalmasın — köy doğrudan o mevsimde doğar.
Season kCaptureReferenceSeason = kReferenceBaseSeason;

/// capture/teşhis: akış tik'inin nabzı. `_tickFlow` her taramada yazar —
/// harness kareyi çekmeden önce okur. "Adım şeridi bazen hiç görünmüyor"
/// şikâyetinde ilk soru şudur: tarama koştu mu, koştuysa ne buldu?
String kFlowDebug = '';

/// capture/teşhis: sim'i DURDURAN modalın adı ('' = akıyor). Harness'te
/// "köy neden ilerlemedi" sorusunun tek satırlık cevabı — donmuş bir sahnede
/// kFlowDebug artık güncellenmediği için son değeri yalan söyler.
String kProbePause = '';
bool kCaptureShowcase =
    false; // capture: showcase köyünü kur (meslek iş döngüsü testi)

/// NPC tek-tık konuşmasını görsel olarak doğrulayan capture harness kapısı.
/// Normal oyun ve testlerde kapalıdır; referans köy kurulduğunda merkezdeki
/// bir köylüyü konuşturur (bkz. tools/npc_interaction_capture_main.dart).
bool kCaptureNpcInteraction = false;

/// Aynı etkileşim harness'ında çift-tık sonucunu (tam kart) seçer.
bool kCaptureNpcCard = false;

/// Dış dünya trafiği görsel provası: referans köye zorla bir kervan getirir,
/// grubu han/pazar önüne alır ve kamerayı at arabasına çevirir.
bool kCaptureVisitors = false;
bool kCaptureVisitorsSpawned = false;
bool kCaptureVisitorsFocused = false;
String kCaptureVisitorReport = '';

/// capture: iş döngüsü telemetrisi — harness bunu okuyup davranışı doğrular.
String kCaptureWorkReport = '';

/// capture: suç test yatağı — suç yoksa sürekli yenisini zorlar (olasılık kapısı
/// atlanır) ki bütün evreler (sokulma/eylem/kaçış/yakalanma) gözlenebilsin.
bool kCaptureCrime = false;

/// capture: suç telemetrisi — harness evreleri + muhafız tepkisini buradan okur.
String kCaptureCrimeReport = '';

/// capture: yalnız BU suçu tetikle (null = rastgele) — riskli yolları hedefli test et.
CrimeKind? kCaptureCrimeKind;

/// capture: İmparatorluk varış anonsunu (buildImperialAlert) sahne hazır olunca
/// bir kez tetikle → tasarımı harness'te görsel doğrulamak için.
bool kCaptureImperialAlert = false;

/// Capture harness'ı pazarlık modalını otomatik olarak karşı hücumla kapatır;
/// normal oyunda false. Dünya üstündeki muharebe karesini insan tıklaması
/// olmadan tekrarlanabilir biçimde yakalamak için.
bool kCaptureImperialBattle = false;

/// capture: muhafızları devre dışı bırak — suçun TAMAMLANIP kaçmasını gözle
/// (kaçış → şüphe → asayiş dilekçesi zinciri muhafızlı köyde hiç tetiklenmez).
bool kCaptureNoGuard = false;

/// capture: NİZAM kolunu baştan mühürle — Kürek Cezası hükmü + Hane Sicili
/// (meçhul suç yok) sim'de gerçekten yürüyor mu doğrula.
bool kCaptureSealNizam = false;

/// PROVA: köyün davranış özeti — harness ([living_probe_main]) her aralıkta
/// buraya yazılan raporu stdout'a basar. "Tek tek NPC izleyemem" sorununun
/// cevabı: köyün yaşadığı sayıyla görülür.
bool kProbeOn = false;
String kProbeReport = '';
int kProbeReportSeq = 0; // her yeni raporda artar (harness "yeni mi" anlar)
/// Harness sim hızını buradan yükseltir (0 = dokunma, normal oyun hızı).
/// Sahne her tick bunu okur; DevPanel slider'ı yerine geçmez, onunla çarpışmaz.
double kDevSpeedBoostOverride = 0;

/// Harness bunu true yapınca sahne bir sonraki fırsatta suç tetikler (tanık →
/// dedikodu → ihbar zincirini gözlemek için). Sahne tüketip false'a çeker.
bool kProbeTriggerCrime = false;

/// Harness bunu true yapınca sahne bir sonraki üreme taramasında doğumu ZORLAR
/// (uygun her anneyi hazır say). Sahne tüketip false'a çeker.
///
/// Neden var: referans köyde boş yatak yok → 34 sim gününde tek doğum olmuyor,
/// yani doğum yolu hiçbir testte çalışmıyordu. Tam da bu yüzden orada bir
/// `ConcurrentModificationError` fark edilmeden durabildi (bkz.
/// `_tickReproduction`). Bu bayrak o kör noktayı kapatır.
bool kProbeForceBirth = false;

/// Prova: bu koşuda kaç bebek doğdu (doğum yolunun gerçekten koştuğunun kanıtı).
int kProbeBirths = 0;

/// Bir sonraki rastgele olayı BU kimliğe zorlar ([EventIds]); boşsa normal
/// ağırlıklı çekiliş yapılır. Sahne tüketip temizler.
///
/// Neden var: her olayın kendi NPC vinyeti var (bkz. scene_vignette) ama
/// çekiliş ağırlıklı — 9 sahnenin tamamını gözlemek/test etmek rastgeleliğe
/// kalırsa hiçbiri düzenli koşmaz. Dev konsol "Olay Sahnele" komutu ve
/// event_vignette_test bunu kullanır.
String kForcedEventId = '';

/// Harness bunu true yapınca sahne bir sonraki tick'te olay mayalandırır
/// (godMode açık olsa bile). [kForcedEventId] ile birlikte kullanılır.
/// Sahne tüketip false'a çeker.
bool kProbeTriggerEvent = false;

/// Sahnedeki vinyetin olay kimliği ('' = sahne yok) ve kadro büyüklüğü.
/// "Olay sessizce sahnelenmedi" kör noktasının tek kanıtı bu iki sayı.
String kProbeVignetteId = '';
int kProbeVignetteCast = 0;

/// Eşik muharebesi prova telemetrisi: yalnız kadronun kurulmasını değil,
/// asker-savunmacı eşleşmesi ve gerçek temas karesini de kanıtlar.
int kProbeImperialCombatPairs = 0;
bool kProbeImperialCombatContactSeen = false;
bool kProbeImperialBattleActive = false;
bool kProbeImperialBattleActorsReleased = true;
int kProbeImperialBattleHits = 0;
String kProbeImperialBattleResult = '';

/// NPC düellosu prova kancası ve yapışkan temas telemetrisi.
bool kProbeStartNpcBrawl = false;
int kProbeNpcCombatPairs = 0;
bool kProbeNpcCombatContactSeen = false;

/// Capture harness: vinyet sahneye çıkar çıkmaz kamerayı odağına kilitler
/// ("İzle" düğmesine basılmış gibi). Yalnız görsel doğrulama içindir; oyunda
/// kamerayı olay ele geçirmez (bkz. scene_vignette._watchVignette).
bool kCaptureAutoWatch = false;

/// `ceremony` niyetinde takılı kalan köylü sayısı (yalnız [kMindTelemetryOn]
/// açıkken güncellenir). Vinyet kadrosu salıverilmezse burası sıfıra dönmez —
/// scene_vignette'in en ölümcül tuzağının alarmı.
int kProbeCeremonyLocked = 0;

/// ÇADIR & OCAK telemetrisi (scene_shelter yazar). Mekanik sessizce hiç
/// çalışmayabilir — "kışın çadır üşütür" cümlesi ancak sayılan bir şey varsa
/// doğrulanabilir. `_coldTents` son taramadaki üşüyen köylü sayısı, `_rouses`
/// bu koşuda soğuktan kaç kez kalkıldığı.
int kProbeColdTents = 0;

/// PROVA: kar çarpanını TAŞIYAN köylü sayısı (bkz. scene_winter
/// `_applySnowFooting`). Kural saf ve testli olsa bile kimse uygulamazsa kış
/// aynı hızda geçer ve hiçbir şey patlamaz — bu sayaç o sessiz kopmayı görünür
/// kılar (bkz. test/snow_test.dart).
int kProbeSnowFooted = 0;
int kProbeColdRouses = 0;

/// FAZ 4 telemetrisi — hırsızlık sahnesinin ânları (`_tickProbe` her tick yazar).
/// "İçeride" penceresi birkaç saniyedir; yarım günlük rapor aralığı onu kaçırır.
bool kProbeTheftInside = false;
bool kProbeTheftSack = false;
int kProbeLootCount = 0;
int kProbeLootTotal = 0;

/// Hırsızlığın dokunduğu üç kaynağın stok toplamı.
int kProbeStockTotal = 0;

/// Bu koşuda çalınan toplam ganimet + geri alınan toplam ganimet. Silah ayrı
/// stok alanında tutulsa da aynı korunum hesabına girer.
///
/// Korunum bunlarla ölçülür, ham stokla DEĞİL: köyün ekonomisi paralel dönüyor
/// (köylü yiyor, işçi üretiyor), o yüzden stok toplamı hırsızlıktan bağımsız
/// oynar. Sözleşme: `çalınan == toprakta duran + geri alınan`.
int kProbeTheftTaken = 0;
int kProbeLootRecovered = 0;

// ── HANE KARŞILIĞI provası (bkz. scene_house_stance) ────────────────────────
// "Yapıldı ama canlı görülmedi" tuzağına karşı: esirgeme merdiveni gerçek
// sahnede döndüğünde ölçülebilsin. Harness [kProbeHouseWithhold] ile en nüfuzlu
// haneyi küstürür, [kProbeHouseAppease] ile barıştırır; sayaçlar sonucu söyler.

/// Harness true yapınca sahne en nüfuzlu haneyi merdivenin ambar basamağına
/// iter. Sahne tüketip false'a çeker.
bool kProbeHouseWithhold = false;

/// Harness true yapınca esirgeyen hanenin gönlü alınır (dilekçe hükmü ile aynı
/// yol). Sahne tüketip false'a çeker.
bool kProbeHouseAppease = false;

/// Küstürülen hanenin soyadı — testin doğru haneyi izlemesi için.
String kProbeHouseName = '';

/// Şu an bir şey esirgeyen hane sayısı + o hanelerin ambarlarında saklı toplam.
int kProbeHousesWithholding = 0;
int kProbeHouseStash = 0;

/// İzlenen hanenin barıştan sonra köy ambarına gerçekten geri verdiği toplam.
/// Anlık stash fotoğrafından ayrıdır: hane günler sonra yeniden küserse daha
/// önce görünür biçimde geri akan ürünü inkâr etmez.
int kProbeHouseReleased = 0;

/// Hanesi elini çektiği için işsiz kalan köylü sayısı (o andaki fotoğraf).
int kProbeHouseIdled = 0;

// ── Hesaplaşma provası (bkz. scene_reckoning) ───────────────────────────────

/// Harness bunu true yaparsa hesaplaşma PROVA köyünde de işler. Dağılmanın
/// [kProbeCollapseArmed] muafiyetiyle aynı sözleşme.
bool kProbeReckoningArmed = false;

/// >0 ise sahne gün sayacını buraya ATLATIR (tek atışlık, sahne sıfırlar).
/// Hesaplaşma altıncı yıldadır; oraya gerçek zamanda pump ederek varmak
/// dakikalar sürer ve ölçülen şey zamanın geçişi değil, tarihin geldiğinde
/// ne olduğudur.
int kProbeJumpToDay = 0;

/// Orta oyun dersleri provası (bkz. scene_lessons). Harness bunu true yaparsa
/// dersler PROVA köyünde de açılır; normalde kapalıdır (kare yakalama ders
/// kartını çekerdi).
bool kProbeLessonsArmed = false;
int kProbeLessonsShown = 0;
String kProbeLastLesson = '';

/// Prova telemetrisi — sahnenin okuduğu değerlerin ta kendisi.
int kProbeYear = 0;
bool kProbeReckoningHeralded = false;
String kProbeVerdict = '';
double kProbeStanding = 0;

/// Denge ölçümü için gün/kese/nüfus. Hesaplaşma "köyün ağırlığını" refahtan
/// da okuyor (bkz. ReckoningInput.grit) ve vergi iştahı yılla iki katına
/// çıkıyor — kesenin o eğriyi taşıyıp taşımadığı ölçülebilir olmalı.
int kProbeDay = 0;
int kProbeGold = 0;
int kProbePop = 0;

// ── Kaybetme eşiği provası (bkz. scene_collapse) ────────────────────────────

/// Harness bunu true yaparsa kaybetme eşiği PROVA köyünde de işler. Normalde
/// referans/showcase/capture köyleri ölümsüzdür (harness ölürse prova ölür);
/// bu bayrak o muafiyeti bilerek kaldırır.
bool kProbeCollapseArmed = false;

/// Harness true yapınca sahnede aşamalı OLAY patlamaz. Karar isteyen olay
/// modali simi durdurur; prova bunu "sistem çalışmıyor" sanır.
bool kProbeNoEvents = false;

/// Harness true yapınca en nüfuzlu hane kopuşa itilir ve ayrılık sayacı
/// eşiğin hemen altına kurulur.
///
/// Kanca KALICIDIR (bkz. [kProbeSchismHouse]): tek atışlık bir dürtme yetmez,
/// çünkü oyun küskünlüğü geri çeker — hane mood'u üye moraline gravite eder,
/// moral de koşullara. Sistem kendini toparladığı için sayaç sıfırlanıyor ve
/// prova "ayrılık kolu ölü" diye YANLIŞ yerden düşüyordu.
bool kProbeForceSchism = false;

/// Kopuşta TUTULAN hane (prova). Boş = tutma yok. Test temizler.
String kProbeSchismHouse = '';

/// Harness true olduğu SÜRECE köy geri sayım bandında tutulur (yetişkinler
/// budanır). Aynı sebeple kalıcı: referans köyde çocuklar yetişkinliğe geçip
/// köyü banttan çıkarıyor ve geri sayım sıfırlanıyordu — ki bu oyunun DOĞRU
/// davranışı (köy toparlandı), yalnız provanın kurgusu yanlıştı.
bool kProbeDrainVillage = false;

/// Telemetri: köyün evresi, geri sayımın kalanı, dağıldı mı, kaç hane gitti.
String kProbeVitality = '';
double kProbeCollapseDaysLeft = -1;
bool kProbeCollapsed = false;
int kProbeHousesLeft = 0;

/// Köyü döndüren el sayısı (prova tanısı) — evre beklenmedikse önce buna bak.
int kProbeAdults = 0;

/// Harness bunu true yapınca sahne meydana GÖRÜLMÜŞ bir zula gömer — zulanın
/// bulunma+iade yolunun gerçekten koştuğunu sınamak için. Sahne tüketip
/// false'a çeker.
bool kProbePlantLoot = false;

/// PROVA: imparatorluk heyetini bastırır. Pazarlık modali simi DONDURUR
/// (kProbePause 'imparatorluk') ve heyeti ölçmeyen harness'lar bu pencerede
/// ölür — olay modalinin kProbeNoEvents'i neyse bu da odur.
bool kProbeNoImperial = false;

/// PROVA: koşu boyunca EN AZ BİR köylü el salladı mı (bkz. CharGesture.wave).
/// Selam gövdeye taşındı; en sinsi hata "jest var ama hiç tetiklenmiyor"dur ve
/// jestin kendisi hiçbir sayıya dokunmadığı için başka türlü görülmez.
bool kProbeWaveSeen = false;

/// PROVA: baş üstünde görülen YASAKLI ikon (selam/hikâye/olay baloncuğu geri
/// sızarsa dolar). Boş = borç ödenmiş duruyor.
String kProbeBannedBubble = '';

/// PROVA: harness'in imparatorluk MUAFİYETİNİ kaldırır. Prova/showcase
/// köylerinde pazarlık modalı her tick siliniyor (tıklayacak oyuncu yok, modal
/// simi sonsuza dek dondururdu — bkz. scene_tick'teki bastırma listesi). Eşik
/// provası bu modalın düğmesine BASACAĞI için muafiyetten çıkar.
bool kProbeImperialArmed = false;

/// PROVA: heyeti bir sonraki tick'te sahneye çağırır (`_devSummonImperial`).
/// Sahne tüketip false'a çeker. Modal açılınca sim DURUR — bundan sonrasını
/// pump değil, testin karar düğmesine basması yürütür.
bool kProbeSummonImperial = false;

/// PROVA: karar KUYRUĞUNUN muafiyetini kaldırır. Prova/showcase köylerinde
/// `_pendingChoice` her tick siliniyor (bastırma listesi) — kuyruk provası tam
/// da o bekleyişi ve zaman aşımını ölçeceği için muafiyetten çıkar
/// (kProbeImperialArmed'ın kuyruk karşılığı).
bool kProbeChoiceQueueArmed = false;

/// PROVA telemetrisi: şu an kuyrukta bekleyen karar olayının id'si ('' = yok).
/// "Kuyruk var ama hiç dolmuyor / hiç boşalmıyor" ancak buradan görülür.
String kProbeChoiceWaiting = '';

/// PROVA telemetrisi: mühleti dolup KENDİ yoluna giren karar sayısı. Zaman
/// aşımı simin akmasına bağlıdır (donuk simde mühlet hiç erimez) — bu sayaç
/// artıyorsa hem kuyruk hem akış canlı demektir.
int kProbeChoiceTimeouts = 0;

/// PROVA: gecikmiş dilekçenin (kapıda bekleyen huzur) muafiyetini kaldırır.
/// Bastırma listesi `_petitionOverdue`'yu her tick düşürür (uzun telemetri
/// koşularında hane/moral eğrisi kirlenmesin); gecikme provası tam da o
/// bekleyişi ölçeceği için muafiyetten çıkar.
bool kProbePetitionQueueArmed = false;

/// PROVA telemetrisi: koşuda EN AZ BİR dilekçe kapıda beklemeye geçti mi
/// (mühlet doldu, donma yok, bedel işliyor). "Eskalasyon kodu var ama hiç
/// tetiklenmiyor" ancak buradan görülür.
bool kProbePetitionOverdueSeen = false;

/// PROVA: bir sonraki tick'te bu katalog dilekçesini sahne-güdümlü olarak
/// merkezi karar kuyruğuna ekler; sahne tüketince boşaltır.
String kProbeRequestPetition = '';

/// PROVA telemetrisi: merkezi kuyrukta yüzeye çıkmayı bekleyen dilekçe id'leri.
String kProbeQueuedPetitions = '';

/// PROVA telemetrisi: bir ağır karar 2×/4× akışı en az bir kez 1×'e indirdi.
bool kProbeAutoSlowed = false;

/// KARAR İZİ provası — harness bunu true yapınca sahne bekleyen dilekçenin İLK
/// şıkkını seçer (oyuncunun kararı gibi); bekleyen yoksa dilekçe kuyruğunu
/// hemen açar. Sahne tüketip false'a çeker.
bool kProbeDecideNow = false;

/// Hikâye provası: alternatif şık ve canlı aktörün köyden ayrılması.
int kProbeDecisionOption = 0;
String kProbeStoryDepartLead = '';
bool kProbeStoryMeetingVisible = false;
String kProbeStoryReport = '';

/// Güncedeki KARAR türü satır sayısı — "karar verildi ama hiçbir yere
/// yazılmadı" hatasının tek görünür kanıtı.
int kProbeDecisionLines = 0;

/// Son karar satırının metni (tanı için).
String kProbeLastDecision = '';

/// KAYIT GİDİŞ-DÖNÜŞÜ provası — harness bunu true yapınca sahne kendi köyünü
/// kaydeder (captureWorld → jsonEncode) ve o JSON'dan geri yükler
/// (restoreWorld). Yani "kaydet, sonra aç" tek tick'te yaşanır.
/// Sahne tüketip false'a çeker; sonucu [kProbeSaveError]'a yazar.
bool kProbeSaveRoundtrip = false;

/// Gidiş-dönüşte atılan istisna ('' = temiz). Kayıt yolu istisnayı YUTUYOR
/// (`_saveNow` catch'i "⚠ Kayıt başarısız" der ve susar) — bu yüzden hata
/// ancak burada görünür.
String kProbeSaveError = '';

/// Sahnenin kaydettiği dünyanın JSON'u — [kProbeSaveRoundtrip] tüketilince
/// yazılır. Harness bunu bozup (alan silip) [kProbeRestoreJson]'a koyarak
/// ESKİ SÜRÜM kaydı taklit edebilir.
String kProbeWorldJson = '';

/// Harness buraya bir dünya JSON'u koyarsa sahne onu yükler ve tüketir.
/// "Bu kaydı aç" demenin headless yolu.
String kProbeRestoreJson = '';

/// Bespoke sahnesi OLMAYAN kararların günceye düşen satır sayısı — yani bu
/// turda eklenen yolun (`_chronicleDecision`) gerçekten koştuğunun kanıtı.
/// Kendi cümlesini zaten yazan fx'ler (sulh/çağrı/suç hükmü) buraya sayılmaz.
int kProbePlainDecisions = 0;

/// Bekleyen dilekçenin id'si (tanı) — 'karar düşmedi' bulgusunda ilk bakılacak
/// yer: dilekçe hiç gelmedi mi, yoksa gelip kaydedilmedi mi?
String kProbePendingPetition = '';

/// TEST/capture: hakem telemetrisi. Açıkken scene_mind her müzakere turunda
/// köyün canlılık kanıtını buraya yazar — kaç köylü yürüdü, kaç farklı niyet
/// var, en uzun süredir değişmeyen niyet kaç saniyelik. Donma testi
/// (test/mind_liveness_test.dart) "köy hâlâ yaşıyor mu" sorusunu bundan
/// yanıtlar; ekran görüntüsü ya da widget sayısı bu soruyu yanıtlayamaz.
bool kMindTelemetryOn = false;

/// Toplam kat edilen mesafe (tile) — donmuş köyde artmaz.
double kMindDistance = 0;

/// Sahnede o an görülen farklı niyet sayısı.
int kMindDistinctIntents = 0;

/// En uzun süredir değişmemiş niyetin yaşı (sn) — kilitlenme göstergesi.
double kMindOldestIntent = 0;

/// capture: yargıda kürek cezası varsa hep onu seç (taş kazanımını gözle).
bool kCaptureLaborOnly = false;
