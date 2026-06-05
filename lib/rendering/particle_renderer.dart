import 'dart:math';
import 'package:flutter/material.dart';

/// Küçük procedural partikül efektleri — asset gerektirmez.
/// AI image-gen küçük yörüngeli animasyonları tutturamadığı için (frame
/// pozisyonu rastgele yer değiştiriyor), procedural en stabil yol.
///
/// Tüm metod'lar caller tarafından her frame çağrılır; içeride lifetime
/// hesabı yapılır (genelde caller'ın phase/state alanından türer).
class ParticleRenderer {
  static final _p = Paint()..isAntiAlias = false;

  /// Generic chip uçuşu — taş/tahta yongası. (originX, originY) çarpma
  /// noktası (vuruş yeri). [lifetime] 0..1 uçuş ilerlemesi:
  /// 0 = çarpma anı, 1 = yere düşmek üzere/kaybolma.
  ///
  /// Yörünge: parabolik (yukarı + yana → düşüş), [direction] +1 sağa
  /// −1 sola. Hafif dönüş için pseudo-random offset.
  static void drawChip(Canvas canvas,
      double originX, double originY, double lifetime,
      {required Color color, required Color shade,
       required double direction, int seed = 0}) {
    if (lifetime <= 0 || lifetime >= 1) return;
    final t = lifetime;
    // Yörünge: x doğrusal yana, y parabolik (yukarı çık + aşağı düş).
    final dx = direction * (12 + (seed & 7)) * t;            // -28..+28 px
    final arc = -32.0 * (4 * t * (1 - t));                   // tepe -32 px
    final px = originX + dx;
    final py = originY + arc;
    // Lifetime ilerledikçe alpha düşsün (son %25'te fade out).
    final a = t < 0.75 ? 1.0 : (1.0 - (t - 0.75) / 0.25);
    final alpha = (a * 255).round().clamp(0, 255);
    // 6-7 piksel düzensiz silüet (her seed farklı şekil verir).
    final r = ((seed >> 1) & 3);
    final shape = _chipShapes[r];
    for (final (ox, oy, kind) in shape) {
      _p.color = (kind == 0
              ? color
              : (kind == 1 ? shade : Colors.white))
          .withAlpha(kind == 2 ? (alpha * 0.7).round() : alpha);
      canvas.drawRect(
        Rect.fromLTWH(px + ox.toDouble(), py + oy.toDouble(), 1, 1),
        _p,
      );
    }
  }

  // 4 farklı chip silüeti — (offsetX, offsetY, kind 0=main 1=shade 2=highlight)
  static const List<List<(int, int, int)>> _chipShapes = [
    [(0,0,0),(1,0,0),(2,0,0),(0,1,0),(1,1,0),(2,1,1),(1,-1,2)],
    [(0,0,0),(1,0,0),(0,1,0),(1,1,0),(-1,0,1),(0,2,1),(0,-1,2)],
    [(0,0,0),(1,0,0),(2,0,0),(1,1,0),(2,1,1),(0,-1,2)],
    [(0,0,0),(1,0,0),(0,1,0),(2,1,0),(1,1,1),(1,2,1),(2,-1,2)],
  ];

  /// Su sıçraması — radyal damla yayılımı. [lifetime] 0..1.
  /// (cx, cy) sıçrama merkezi (su yüzeyi). 6 damla 60° arayla dışa fırlar,
  /// yere düşer, alpha söner.
  static void drawSplash(Canvas canvas, double cx, double cy, double lifetime) {
    if (lifetime <= 0 || lifetime >= 1) return;
    final t = lifetime;
    final a = t < 0.6 ? 1.0 : (1.0 - (t - 0.6) / 0.4);
    final alpha = (a * 255).round().clamp(0, 255);
    final mainColor = const Color(0xFFB8DCEC).withAlpha(alpha);
    final shadeColor = const Color(0xFF7AA8C0).withAlpha(alpha);

    // 6 damla — radyal pozisyon t'ye göre dışa açılır, y biraz aşağı düşer.
    const n = 6;
    for (int i = 0; i < n; i++) {
      final angle = i * (2 * pi / n);
      final radius = 14 * t;
      // Damla yörünge: çıkış (t<0.5) yukarı, sonra düşer (t>0.5).
      final yArc = -8 * (4 * t * (1 - t));
      final dx = cos(angle) * radius;
      final dy = sin(angle) * radius + yArc;
      _p.color = mainColor;
      canvas.drawRect(Rect.fromLTWH(cx + dx,     cy + dy, 2, 2), _p);
      _p.color = shadeColor;
      canvas.drawRect(Rect.fromLTWH(cx + dx + 1, cy + dy + 1, 1, 1), _p);
    }
    // Merkez beyaz parlaması (sadece ilk %30)
    if (t < 0.3) {
      final flashA = ((1.0 - t / 0.3) * 220).round().clamp(0, 255);
      _p.color = const Color(0xFFFFFFFF).withAlpha(flashA);
      canvas.drawRect(Rect.fromLTWH(cx - 1, cy - 1, 3, 3), _p);
    }
  }

  /// Uyku Z'si — uyuyan NPC kafası üstünde floating. [time] sahne zamanı.
  /// (cx, cy) baş üst pozisyonu. 2.5 sn'lik döngü: belir → yukarı drift +
  /// büyür → fade. [seed] NPC başına faz farkı.
  static void drawSleepZzz(Canvas canvas, double cx, double cy,
      double time, int seed) {
    const period = 2.5;
    final localT = ((time + seed * 0.41) % period) / period; // 0..1
    if (localT > 0.92) return;
    final t = localT / 0.92;
    final yOff = -10 - t * 14;               // -10..-24 (yukarı drift)
    final scale = 0.8 + t * 0.4;             // 0.8..1.2 büyür
    final a = t < 0.2 ? t / 0.2 : (t < 0.8 ? 1.0 : (1.0 - (t - 0.8) / 0.2));
    final alpha = (a * 180).round().clamp(0, 200);
    _drawZ(canvas, cx, cy + yOff, scale, alpha);
  }

  static void _drawZ(Canvas canvas, double cx, double cy,
      double scale, int alpha) {
    final color = const Color(0xFFFFFFFF).withAlpha(alpha);
    _p.color = color;
    // 5x5 piksel "Z" — üst kenar, çapraz, alt kenar.
    // Scale ile piksel boyutu büyür (1 px → 2 px gibi).
    final px = scale.clamp(0.8, 1.6);
    void rect(double dx, double dy) {
      canvas.drawRect(Rect.fromLTWH(cx + dx * px - px / 2,
                                     cy + dy * px - px / 2, px, px), _p);
    }
    // Üst yatay
    rect(-2, -2); rect(-1, -2); rect(0, -2); rect(1, -2); rect(2, -2);
    // Çapraz
    rect(1, -1); rect(0, 0); rect(-1, 1);
    // Alt yatay
    rect(-2, 2); rect(-1, 2); rect(0, 2); rect(1, 2); rect(2, 2);
  }

  /// Altın parıltısı — pazar satışında yukarı çıkan altın işareti.
  /// (cx, cy) çıkış noktası (pazar üstü). [lifetime] 0..1, ~1sn'lik anim.
  /// Başlangıçta parıltı, yukarı yükselir + fade.
  static void drawGoldSparkle(Canvas canvas, double cx, double cy,
      double lifetime) {
    if (lifetime <= 0 || lifetime >= 1) return;
    final t = lifetime;
    final yOff = -32 * t;
    final a = t < 0.7 ? 1.0 : (1.0 - (t - 0.7) / 0.3);
    final alpha = (a * 255).round().clamp(0, 255);
    final cx2 = cx;
    final cy2 = cy + yOff;
    final gold       = const Color(0xFFFFD040).withAlpha(alpha);
    final goldDark   = const Color(0xFFCFA020).withAlpha(alpha);
    final goldHi     = const Color(0xFFFFF4B0).withAlpha(alpha);

    // Para silüeti: 5x5 daire benzeri.
    _p.color = gold;
    canvas.drawRect(Rect.fromLTWH(cx2 - 2, cy2 - 1, 5, 3), _p);
    canvas.drawRect(Rect.fromLTWH(cx2 - 1, cy2 - 2, 3, 5), _p);
    _p.color = goldDark;
    canvas.drawRect(Rect.fromLTWH(cx2 + 1, cy2 + 1, 1, 1), _p);
    canvas.drawRect(Rect.fromLTWH(cx2 - 2, cy2 + 1, 1, 1), _p);
    _p.color = goldHi;
    canvas.drawRect(Rect.fromLTWH(cx2 - 1, cy2 - 1, 1, 1), _p);

    // Parıltı: 4 yöne sin tabanlı 1-piksel ışık (pulsing)
    final twinkle = (sin(t * 12) * 0.5 + 0.5);
    if (twinkle > 0.5) {
      _p.color = const Color(0xFFFFFFFF)
          .withAlpha((alpha * twinkle).round().clamp(0, 255));
      canvas.drawRect(Rect.fromLTWH(cx2,     cy2 - 4, 1, 1), _p);
      canvas.drawRect(Rect.fromLTWH(cx2 + 4, cy2,     1, 1), _p);
      canvas.drawRect(Rect.fromLTWH(cx2 - 4, cy2,     1, 1), _p);
    }
  }
}
