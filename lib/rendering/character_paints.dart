part of 'character_renderer.dart';

/// KÖYÜN HÂLİ + RENK PALETİ + PAINT YARDIMCILARI — CharacterRenderer'ın kütüphane-özel yardımcıları (aynı kütüphane, private erişim serbest).
// ── KÖYÜN HÂLİ (Faz 5) ─────────────────────────────────────────────────────
//
// Basınç tablosunun çizime inen iki değeri. Parametre olarak 15 ayrı meslek
// fonksiyonuna taşımak yerine [_accent] ile aynı kalıpta statik: çizim tek
// iş parçacığında, tek karakter için, baştan sona sürer. ÇAĞIRAN SORUMLU —
// her NPC'den önce [beginNpc] çağrılmalı, yoksa bir önceki karakterin hâli
// sızar (aynı tuzak [_accent]'te de var, o yüzden aynı yerde yazılıyorlar).

/// Köyün ambar hâli: -1 yoksunluk … +1 refah. Giysi renkleri buradan solar
/// ya da doyar (bkz. [_cloth]).
double _provision = 0;

/// Örtünme 0..1 — tedirginliğin siluete inmiş hâli (omuzda şal, başta
/// kapüşon). Köylünün `bearingTense` değerinden gelir.
double _shroud = 0;

/// Terzi kurulmadan önce bütün yerleşiklerin giydiği kaba post/bez kılığı.
bool _primitiveClothing = false;

/// GİYSİ RENGİ — tek kapı. Kişisel ton ([NpcVisual.clothingShift]) üstüne
/// köyün hâli biner. Dosyadaki bütün kumaş renkleri buradan geçer; yeni bir
/// meslek eklerken doğrudan `tintCloth` çağırma, yoksa o meslek köyün
/// kıtlığından etkilenmeyen tek kişi olur.
///
/// Ölçek bilinçli ölçülü: en kötü günde bile kumaş TANINIR kalır — amaç
/// "kostüm değişti" değil, "bu köy bugün yorgun" hissi.
Color _cloth(Color base, double shift) {
  if (_primitiveClothing) base = const Color(0xFF8A6945);
  final c = tintCloth(base, shift);
  final p = _provision;
  if (p.abs() < 0.02) return c;

  final r = c.r * 255, g = c.g * 255, b = c.b * 255;
  // Algısal gri — yeşil ağırlıklı (göz yeşile duyarlı).
  final grey = r * 0.30 + g * 0.59 + b * 0.11;

  if (p < 0) {
    // YOKSUNLUK — doygunluk griye çekilir + tozlu bir gri-kahve karışır +
    // hafif koyulaşma. Üç etki birlikte "yıkanmış, yamalı, güneş yemiş"
    // okunur; yalnız alpha/koyuluk oynatmak kirli değil KARANLIK gösterirdi.
    final t = (-p).clamp(0.0, 1.0);
    final desat = 0.45 * t;
    var nr = r + (grey - r) * desat;
    var ng = g + (grey - g) * desat;
    var nb = b + (grey - b) * desat;
    const dustR = 110.0, dustG = 103.0, dustB = 92.0;
    final mix = 0.16 * t;
    nr += (dustR - nr) * mix;
    ng += (dustG - ng) * mix;
    nb += (dustB - nb) * mix;
    final dim = 1.0 - 0.10 * t;
    return Color.fromARGB(
      (c.a * 255).round(),
      (nr * dim).clamp(0, 255).round(),
      (ng * dim).clamp(0, 255).round(),
      (nb * dim).clamp(0, 255).round(),
    );
  }

  // REFAH — doygunluk artar (kanallar griden UZAKLAŞIR) + çok hafif
  // aydınlanma. Boya parası olan köyün kumaşı canlıdır.
  final t = p.clamp(0.0, 1.0);
  final sat = 0.28 * t;
  final lift = 1.0 + 0.06 * t;
  return Color.fromARGB(
    (c.a * 255).round(),
    ((r + (r - grey) * sat) * lift).clamp(0, 255).round(),
    ((g + (g - grey) * sat) * lift).clamp(0, 255).round(),
    ((b + (b - grey) * sat) * lift).clamp(0, 255).round(),
  );
}

// ─── RENK PALETİ ──────────────────────────────────────────────────────────
const _skin1 = Color(0xFFFFCB9A);
const _skin2 = Color(0xFFD4956A);
const _linen = Color(0xFFD4C090);
const _woolBrown = Color(0xFF6A4A28);
const _woolDark = Color(0xFF3E2A10);
const _leather = Color(0xFF8A6040);
const _leatherDk = Color(0xFF4A2A10);
const _straw = Color(0xFFC8A042);
const _ironGrey = Color(0xFF8A8880);
const _ironDk = Color(0xFF484440);
const _woodBrown = Color(0xFF7A5030);
const _outline = Color(0xFF2A1A08);

// ── Yeni meslek renk imzaları — hiçbiri mevcut meslekle çakışmaz ──────────
/// Rahip: çivit-arduvaz cüppe (eski büyücünün lacivert kaftanının yerine).
const _kPriestRobe = Color(0xFF3E4560);

/// Çoban: boyanmamış ham yün (üstüne kahve post yelek).
const _kShepherdWool = Color(0xFFCFC3A8);

/// Avcı: koyu orman yeşili kukuleta/pelerin.
const _kHunterGreen = Color(0xFF2E4632);

/// Değirmenci: kül-bej iş kumaşı (üstüne UNLU beyaz önlük — imza).
const _kMillerCloth = Color(0xFF8A8577);
const _kFlourWhite = Color(0xFFE4DECC);

/// Hancı: şarap kırmızısı yelek (üstüne beyaz önlük).
const _kInnkeeperWine = Color(0xFF6A3A3A);

// ─── PAINT YARDIMCILARI ───────────────────────────────────────────────────
// PERF: Her çağrıda yeni Paint yerine 4 önbellekli statik instance — yalnız
// color/strokeWidth mutate edilir (style/AA/join/cap bir kez set). Tüm
// kullanımlar inline `drawX(..., _f(color))` formunda ve paint çizimde
// anında tüketilir → tek paylaşımlı instance güvenli (iki sonuç asla aynı
// anda yaşamaz). ~230 alloc/NPC/frame GC baskısını ortadan kaldırır.
final Paint _fPaint = Paint()
  ..style = PaintingStyle.fill
  ..isAntiAlias = false;
Paint _f(Color c) => _fPaint..color = c;

final Paint _sPaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.miter
  ..strokeCap = StrokeCap.square
  ..isAntiAlias = false;
Paint _s(Color c, [double w = 1.0]) => _sPaint
  ..color = c
  ..strokeWidth = w;

// ── Yumuşak (anti-aliased) paint'ler — yalnızca yüz/ifade için ───────────
// Gövde pixel-art kalır (sert kenar); yüz tatlı/yuvarlak olsun diye AA.
final Paint _faPaint = Paint()
  ..style = PaintingStyle.fill
  ..isAntiAlias = true;
Paint _fa(Color c) => _faPaint..color = c;

final Paint _saPaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round
  ..isAntiAlias = true;
Paint _sa(Color c, [double w = 1.0]) => _saPaint
  ..color = c
  ..strokeWidth = w;

// ─── ORTAK PARÇALAR ───────────────────────────────────────────────────────

/// Çizilmekte olan NPC'nin hane aksan rengi — null ise kuşak çizilmez.
///
/// INVARIANT: her public giriş noktası ([draw], [drawSleeping] ve iş sprite'ı
/// çizicileri) İLK satırında bunu set eder. Böylece bir önceki NPC'nin rengi
/// sızamaz; ayrı bir "temizle" adımına güvenilmez. Renderer zaten tümüyle
/// static ve tek karede tek NPC çiziliyor — rengi 15 helper'a parametre
/// olarak threadlemek yerine tek alan.
Color? _accent;

/// Temas gölgesi — yumuşak elips, ışık vektörüne göre hafif sağa-aşağı
/// kaydırılmış (binaların drop shadow yönüyle aynı).
///
/// Eski hali sert bir dikdörtgendi ve [anim] ile hiç değişmiyordu; figür
/// zıplarken gölge sabit kaldığı için karakterler yerde durmuyor, "yüzüyor"
/// gibi görünüyordu. Artık bob/sway ile küçülüp soluklaşır → temas hissi.
final Paint _shadowPaint = Paint()..isAntiAlias = true;

void _shadow(Canvas c, [_Anim? anim]) {
  // bob negatif = gövde yukarıda. Yükseldikçe gölge küçülür + soluklaşır.
  final lift = anim == null ? 0.0 : (-anim.bob).clamp(0.0, 6.0);
  final k = 1.0 - lift * 0.055; // 1.0 → ~0.67
  final cx = 2.0 + (anim?.sway ?? 0.0) * 0.35;
  final outer = Rect.fromCenter(
    center: Offset(cx, -0.5),
    width: 27 * k,
    height: 9.5 * k,
  );
  c.drawOval(
    outer,
    _shadowPaint..color = Color.fromARGB((0x30 * k).round(), 0, 0, 0),
  );
  // Çekirdek — ayak dibinde koyu küçük leke; temas noktasını çiviler.
  c.drawOval(
    Rect.fromCenter(
      center: outer.center,
      width: outer.width * 0.50,
      height: outer.height * 0.50,
    ),
    _shadowPaint..color = Color.fromARGB((0x2A * k).round(), 0, 0, 0),
  );
}
