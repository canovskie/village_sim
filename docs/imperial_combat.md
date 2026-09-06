# İmparatorluk çatışması

Direniş ve ödeme reddi, köy haritasında `ImperialBattle` simülasyonunu başlatır.
Sonuç karar düğmesinde seçilmez. Eski eşik vinyeti, ışınlanan kadro ve 12 saniyelik
zafer/kayıp koreografisi kaldırılmıştır.

- Savaşçılar gerçek köylüler ve ziyarete gelmiş askerlerdir. Köylüler işyerlerinden
  yürür; çocuklar, içeridekiler, uyuyanlar ve ağır yaralılar savunmaya alınmaz.
- Her kişinin hedefi, sağlığı, morali, dayanıklılığı, saldırı hazırlığı ve darbe
  sonrası toparlanması ayrıdır. Menzilden çıkan rakibe veya duvar arkasına hasar
  uygulanmaz. Hedef düşerse hayatta kalanlar yeni rakip bulur.
- Muhafızlık, mevcut silahlar, eski yaralar, kişisel moral, rejim desteği,
  hava, gece ve baskın kuvveti savaşçıların hareketini veya performansını etkiler.
- Kalkan hattı mevzi çevresini savunur. Dar geçit kereste tüketir ve mevzide
  koruma sağlar; geçici barikatlar haritada kalır. Hücum savunucuları rakibe
  götürür ve ilk darbeyi güçlendirir. Canlı emirler düzeni değiştirebilir.
- Bir taraf dağılırsa veya savunmasız hedef altı saniye tutulursa sonuç oluşur.
  Hedefe ulaşamayan saldırı 90 saniyede kesilir; bu emniyet sınırı uzaktan hasar
  veya rastgele kayıp üretmez. Oyuncu ayrıca geri çekilme emri verebilir.
- Yaralar temas anında gerçek köylüye yazılır. Yere düşen savunucunun ölümü,
  düşüş gösterildikten sonra normal cenaze akışına geçer; favori koruması sürer.
  Köy dışındaki rastgele kişiler savaş bilançosuna kurban seçilmez.
- Savaşçı gövdeleri kütle, hız, ivmelenme ve zemin tutuşu taşır. Darbe, geldiği
  yönde itiş üretir; ağır zırh ve sağlam savunma duruşu geri savrulmayı azaltır.
  Gövde temasları yaklaşma momentumunu sönümler; duvar kenarında kayma mümkündür.
  Süpürülen gövde alanı hızlı darbelerde bile duvarın içinden geçişi engeller.
- Saldırı hazırlığı, silahın uzanması, temas ve toparlanma aynı savaş saatini
  izler. Hasar silah uzandığında uygulanır. Yere düşüş kademeli çizilir.
- Asker ve komutanın adımları katettikleri mesafeyle ilerler; dururken yerinde
  yürümezler. Ortak NPC bacak çizimi sabit uzunluklu uyluk/baldır, bükülen diz
  ve zemin üstünde basan veya kaldırılan ayak kullanır.

Savaş ayrı, sabit adımlı (30 Hz) bir saat kullanır. Ekonomi ve gündelik iş AI'sı
bu sırada bekler; sivil kaçışı ve savaşçı hareketleri çatışma tarafından yürütülür.
Oyun hızı dövüşü görünmez biçimde hızlandırmaz; normal duraklatma çalışır.
Savaş bittiğinde karakterlerin geçici göstergeleri, nesneleri ve kamera yakınlığı
bırakılır. Yenilen köye ilerleyen asker, binayı ancak hedefe gerçekten varınca vurur.

Savaşın tüm ara durumu ve kişi bağlantıları dünya kaydına dahildir: hedef,
saldırı hazırlığı, can, moral, gövde hızı/kütlesi, düşüş ilerlemesi, sayaç artığı,
emir ve sonuç. Yükleme aynı savaşı
sürdürür ve uygulanmış sonuçları tekrar ödemez. Eski kayıtlar bu alan olmadan açılır.
`ImperialDefensePreview` hazırlık/seçenek hesabıdır; içindeki oran savaş sonucu
çekilişinde kullanılmaz ve oyuncuya kazanma yüzdesi olarak sunulmaz.

Doğrulama: `imperial_battle_test.dart` menzil, engel, güç farkı, kare hızından
bağımsızlık, hedef değiştirme, hedef işgali, geri çekilme ve kayıt devamlılığını
kontrol eder. `imperial_threshold_probe_test.dart` gerçek karar arayüzünden
çatışmayı başlatır, telefon boyutunda emir verir, savaşta kayıt/yükleme yapar ve
sonunda karakterlerin temizlendiğini doğrular.
`npc_physics_test.dart` ivmelenme, kütleye bağlı itiş, momentum, duvar ve gövde
temasını; `imperial_gait_test.dart` asker/komutanın gerçek bacak piksellerinin
yürürken değişmesini ve mesafeye bağlı adım ilerlemesini kontrol eder.
