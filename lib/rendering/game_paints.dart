part of 'game_painter.dart';

// ÇİZİM PALETİ — painter genelinde paylaşılan Paint havuzu.
//
// Neden ayrı dosya: game_painter.dart 2610 satırdı ve ilk 200 satırı hiç
// mantık içermeyen sabit tablosuydu; dosyayı açan önce boyaları geçmek
// zorunda kalıyordu. Paint'ler her karede yeniden kurulmasın diye statik —
// bu dosyada TANIM durur, kullanım painter'da.

// ── Static Paint havuzu (game_painter genelinde paylaşılır) ───────────────────
// Progress bar
final _ppBg = Paint()
  ..color = const Color(0xFF111111)
  ..isAntiAlias = false;
final _ppFill = Paint()
  ..color = const Color(0xFFE8A020)
  ..isAntiAlias = false;
final _ppBorder = Paint()
  ..color = const Color(0xFFFFFFFF)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1
  ..isAntiAlias = false;

// Selection overlays — sabit renkler, bir kez yaratılır
final _pFarmFill = Paint()
  ..color = const Color(0x5544AA22)
  ..isAntiAlias = false;
final _pFarmBorder = Paint()
  ..color = const Color(0xCC66DD33)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.5
  ..isAntiAlias = false;
final _pLumberFill = Paint()
  ..color = const Color(0x44AA4400)
  ..isAntiAlias = false;
final _pLumberBorder = Paint()
  ..color = const Color(0xCCDD6600)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.5
  ..isAntiAlias = false;

// Harman — tarla dışındaki sıkıştırılmış, tırmıklanmış 2×2 toprak alanı.
final _pHarmanGround = Paint()
  ..color = const Color(0xFFC9A46C)
  ..isAntiAlias = false;
final _pHarmanBorder = Paint()
  ..color = const Color(0xFF76552F)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.15
  ..isAntiAlias = false;
final _pHarmanRake = Paint()
  ..color = const Color(0x55704C27)
  ..strokeWidth = 0.8
  ..isAntiAlias = false;

// Marker paints
final _pTreeX = Paint()
  ..color = const Color(0xDDFF3300)
  ..strokeWidth = 2.5
  ..isAntiAlias = false;
final _pMineX = Paint()
  ..color = const Color(0xDDFFCC00)
  ..strokeWidth = 2.0
  ..isAntiAlias = false;

// Scaffold — sıkıştırılmış toprak zemin (build site marker). Ahşap iskele
// kaldırıldı; sprite reveal + hammer spark + completion pop yeterli.
final _pScaffGround = Paint()
  ..color = const Color(0xFFD4B896)
  ..isAntiAlias = false;
final _pScaffBorder = Paint()
  ..color = const Color(0xFF7A5810)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1
  ..isAntiAlias = false;

// Lighting pass paint havuzu (lokal ışık + halo).
// saveLayer içine karanlık + vignette → bu paint normal blend.
final _pLighting = Paint()..isAntiAlias = false;

// Ambient color grade — fullscreen modulate (= multiply). Sahnenin "günün
// içinde bulunduğu ışık tonu" (mehtap mavi, altın saat amber, ...). Strength=0
// için identity beyaza lerp edilir → öğle neredeyse dokunulmaz.
final _pAmbientGrade = Paint()
  ..blendMode = BlendMode.modulate
  ..isAntiAlias = false;
// Gündüz atmosfer pass'i — fullscreen blend katmanları (güneş formu / hava
// perspektifi / bloom / sıcak vignette). Blend modu her katmanda set edilir.
final _pDayGrade = Paint()..isAntiAlias = false;
// Köylü vurgu halkası (HUD "evsizleri göster") — ayak altı nabızlı kehribar.
final _pHighlightRing = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2.5
  ..isAntiAlias = true;
// Mehtap dolgusu — gece ışıksız alanlarda hafif soğuk-mavi plus
// (saveLayer'ın DIŞINA, dstOut tarafından korunmadan). Karanlığı
// "düz siyah" olmaktan kurtarır, ışığa kontrast üretir.
final _pMoonFill = Paint()
  ..blendMode = BlendMode.plus
  ..isAntiAlias = false;

// Sohbet baloncuğu — fill + stroke. Renk (alpha) her frame değişir, ama
// nesne değil: çağrı başına .color set edilir → frame başına 2 Paint allocation
// (konuşan NPC × frame) kalkar, çıktı bit-aynı. Dosyanın _pXxx havuz deseni.
final _pBubbleFill = Paint()..isAntiAlias = true;
final _pBubbleBorder = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1
  ..isAntiAlias = true;

// Map border
final _pMapBorder = Paint()
  ..color = const Color(0xFF1E4820)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2
  ..isAntiAlias = false;

// Kıyı sisi — kara kenarı boyunca yumuşak karanlık hale. Tek path/frame,
// 3 kalın stroke (azalan alpha) ile yumuşak görünüm — MaskFilter.blur'dan
// 4–8× ucuz (CPU shader yolu).
final _pEdgeMistOuter = Paint()
  ..color = const Color(0x180A1018)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 26
  ..isAntiAlias = false;
final _pEdgeMistMid = Paint()
  ..color = const Color(0x300A1018)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 16
  ..isAntiAlias = false;
final _pEdgeMistInner = Paint()
  ..color = const Color(0x520A1018)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 8
  ..isAntiAlias = false;

// Gece ateş böcekleri — 2 katmanlı circle (geniş soluk + parlak çekirdek).
// Blur yok → particle başı maliyet ~5× düşer.
final _pFireflyGlow = Paint()..isAntiAlias = true;
final _pFireflyCore = Paint()..isAntiAlias = true;

// Gündüz polen/toz zerreleri — küçük blur kaldırıldı, anti-aliased crisp circle.
final _pPollen = Paint()..isAntiAlias = true;

// Mevsim partikülleri — kış kar tanesi + sonbahar sürüklenen yaprak.
final _pSnow = Paint()..isAntiAlias = true;
final _pLeaf = Paint()..isAntiAlias = true;
final _pLeafVein = Paint()
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..isAntiAlias = true;

// Ghost
final _pGhostFill = Paint()..isAntiAlias = false;
final _pGhostBorder = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 2
  ..isAntiAlias = false;

// Rain — 3 parallax katman + ground splash. Paint havuzu (per-frame
// allocation yok). AA AÇIK: damlalar piksel satırları arasında geçerken
// sub-pixel akıyor → yağmur akıcı kayar. Pixel-art kapalı AA tile/sprite'a
// özgü; ekran uzayı efektleri (yağmur, mist) AA ile daha temiz.
// _pRain: 1px far/mid katmanı, _pRainBold: 1.6px ön katman,
// _pRainTail: ön katman damlaların soluk motion-trail çizgisi.
// _pSplash: yere çarpan damlanın droplet/crown daireleri (fill, AA).
// _pSplashRing: çarpma noktasında genişleyen iso oval (stroke, AA).
// _pRainMist: yoğun yağmurda hafif mavi-gri atmosfer perde overlay.
// PERF: arka+orta katman (en yoğun, en sönük) AA KAPALI — AA'lı ince çizgi
// Skia'da pahalı; bu katmanlar hızlı akan sönük perde, aliasing fark edilmez.
// Hero ön katman (_pRainBold) + kuyruk (_pRainTail) AA kalır (okunur damlalar).
final _pRain = Paint()
  ..strokeWidth = 1.0
  ..strokeCap = StrokeCap.round
  ..isAntiAlias = false;
final _pRainBold = Paint()
  ..strokeWidth = 1.6
  ..strokeCap = StrokeCap.round
  ..isAntiAlias = true;
final _pRainTail = Paint()
  ..strokeWidth = 0.9
  ..strokeCap = StrokeCap.round
  ..isAntiAlias = true;
final _pSplash = Paint()..isAntiAlias = true;
final _pSplashRing = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.0
  ..isAntiAlias = true;
final _pRainMist = Paint();

// Gölgeler — karakter/ağaç için yumuşak eliptik, bina için yumuşak diamond.
// Önce: 2 katman sert diamond + sert contact AO → toplam 3 stamp, "öküz".
// Şimdi: 2 katman BLUR'LU diamond, alpha düşük → tek yumuşak ambient gölge
// hissi. Contact AO ayrı olarak yok — alttaki katman zaten o işi yapıyor.
final _pShadow = Paint()
  ..color = const Color(0x77000000)
  ..isAntiAlias = true;
final _pBuildingShadowOuter = Paint()
  ..color =
      const Color(0x1E000000) // ~12% black, çok soluk halo
  ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5.0)
  ..isAntiAlias = true;
final _pBuildingShadowInner = Paint()
  ..color =
      const Color(0x32000000) // ~20% black, çekirdek koyuluk
  ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.0)
  ..isAntiAlias = true;
