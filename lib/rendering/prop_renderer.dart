import 'dart:math';
import 'package:flutter/material.dart';

import '../characters/npc_visual.dart';
import '../systems/villager_act.dart';

/// ELDEKİ NESNELERİN ÇİZİMİ — kova, çuval, ekmek, maşrapa, sepet, odun.
///
/// PROSEDÜREL, PNG DEĞİL. Sebep: sprite akışı ayrı bir iş (prompt → görsel →
/// yerleştirme); nesne sistemi bir PNG paketini beklerse Faz 3 hiç görünmez.
/// Buradaki her nesne, character_renderer'ın pixel-art diliyle (gölgeli
/// dikdörtgen, anti-alias kapalı, üstten ışık) çizilir — aynı köyün eşyası gibi
/// dursun diye. PNG geldiğinde tek tek değiştirilebilirler.
///
/// Koordinat uzayı: köylü sprite'ının yerel uzayı. (0,0) = ayaklar, y yukarı
/// negatif. Göğüs ≈ y=-52, bel ≈ y=-40, el (yan) ≈ x=±9.
abstract final class PropRenderer {
  static final Paint _fill = Paint()..isAntiAlias = false;
  static final Paint _stroke = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  static const Color _outline = Color(0xFF20191A);

  static Paint _f(Color c) => _fill..color = c;
  static Paint _s(Color c) => _stroke..color = c;

  /// character_renderer ile aynı gölgeleme dili: üst/sol highlight,
  /// sağ/alt gölge, koyu dış çizgi.
  static void _shaded(Canvas c, Rect r, Color base) {
    if (r.width < 3 || r.height < 3) {
      c.drawRect(r, _f(base));
      c.drawRect(r, _s(_outline));
      return;
    }
    final hl = lighter(base, 0.18);
    final sh = darker(base, 0.22);
    c.drawRect(r, _f(base));
    c.drawRect(Rect.fromLTWH(r.left + 1, r.top + 1, r.width - 2, 1), _f(hl));
    c.drawRect(Rect.fromLTWH(r.left + 1, r.top + 1, 1, r.height - 2), _f(hl));
    c.drawRect(Rect.fromLTWH(r.right - 2, r.top + 1, 1, r.height - 2), _f(sh));
    c.drawRect(Rect.fromLTWH(r.left + 1, r.bottom - 2, r.width - 2, 1), _f(sh));
    c.drawRect(r, _s(_outline));
  }

  /// Nesneyi köylünün yerel uzayında çizer.
  ///
  /// [facingRight] hangi elde/tarafta duracağını belirler. [walkPhase] yürürken
  /// yükün hafifçe sallanmasını sağlar — sabit yapıştırılmış bir çuval ölü
  /// durur. [time] sıvı titremesi gibi ince hareketler için.
  static void draw(
    Canvas canvas,
    PropKind prop, {
    required bool facingRight,
    double walkPhase = 0,
    double moveIntensity = 0,
    double time = 0,
  }) {
    if (prop == PropKind.none) return;
    final dir = facingRight ? 1.0 : -1.0;
    // Yürürken yükün hafif salınımı — genlik hareket şiddetiyle ölçekli.
    final sway = sin(walkPhase * 2) * 0.9 * moveIntensity.clamp(0.0, 1.0);

    canvas.save();
    switch (prop) {
      case PropKind.none:
        break;
      case PropKind.bucketEmpty:
        _bucket(canvas, dir, sway, full: false);
      case PropKind.bucketFull:
        _bucket(canvas, dir, sway, full: true, time: time);
      case PropKind.sack:
        _sack(canvas, dir, sway);
      case PropKind.bread:
        _bread(canvas, dir, sway);
      case PropKind.mug:
        _mug(canvas, dir, sway);
      case PropKind.basket:
        _basket(canvas, dir, sway);
      case PropKind.firewood:
        _firewood(canvas, dir, sway);
    }
    canvas.restore();
  }

  // ── KOVA — yanda, elden sarkar ────────────────────────────────────────────
  static void _bucket(Canvas c, double dir, double sway,
      {required bool full, double time = 0}) {
    const wood = Color(0xFF7A5A3A);
    const band = Color(0xFF4A4A50);
    const water = Color(0xFF3E6E86);
    // Dolu kova daha aşağı sarkar (ağırlık) — gövde dili sayı değil, konum.
    final y = full ? -30.0 : -33.0;
    final x = dir * 9 + sway;
    c.save();
    c.translate(x, y);
    // Sap.
    c.drawRect(const Rect.fromLTWH(-3, -5, 6, 1), _f(band));
    // Gövde (hafif konik: alt biraz dar).
    _shaded(c, const Rect.fromLTWH(-4, -4, 8, 9), wood);
    // Çemberler.
    c.drawRect(const Rect.fromLTWH(-4, -2, 8, 1), _f(band));
    c.drawRect(const Rect.fromLTWH(-4, 2, 8, 1), _f(band));
    if (full) {
      // Su yüzeyi — çok hafif titrer (taşımanın huzursuzluğu).
      final ripple = sin(time * 6.0) * 0.4;
      c.drawRect(Rect.fromLTWH(-3, -3.2 + ripple, 6, 1.6), _f(water));
    }
    c.restore();
  }

  // ── ÇUVAL — SIRTTA. Hırsızın yükü; silueti uzaktan okunmalı ───────────────
  static void _sack(Canvas c, double dir, double sway) {
    const cloth = Color(0xFF9A8A62);
    const tie = Color(0xFF5C4A2E);
    // Sırtta, omuz üstünde: yön ne olursa olsun GERİDE durur.
    c.save();
    c.translate(-dir * 5, -56 + sway * 0.5);
    c.rotate(dir * 0.12);
    _shaded(c, const Rect.fromLTWH(-6, -8, 12, 15), cloth);
    // Boğaz + bağ.
    c.drawRect(const Rect.fromLTWH(-3, -10, 6, 3), _f(cloth));
    c.drawRect(const Rect.fromLTWH(-3, -9, 6, 1), _f(tie));
    c.restore();
  }

  // ── EKMEK — elde, göğüs hizası ────────────────────────────────────────────
  static void _bread(Canvas c, double dir, double sway) {
    const crust = Color(0xFFB07A3C);
    c.save();
    c.translate(dir * 8 + sway, -44);
    c.rotate(dir * 0.2);
    _shaded(c, const Rect.fromLTWH(-5, -3, 10, 6), crust);
    // Üstte iki çentik.
    c.drawRect(const Rect.fromLTWH(-2, -3, 1, 2), _f(darker(crust, 0.25)));
    c.drawRect(const Rect.fromLTWH(1, -3, 1, 2), _f(darker(crust, 0.25)));
    c.restore();
  }

  // ── MAŞRAPA — elde, ağız hizasına yakın ───────────────────────────────────
  static void _mug(Canvas c, double dir, double sway) {
    const clay = Color(0xFF8A6A55);
    const foam = Color(0xFFE8DCC0);
    c.save();
    c.translate(dir * 8 + sway, -46);
    _shaded(c, const Rect.fromLTWH(-3, -4, 6, 8), clay);
    // Köpük.
    c.drawRect(const Rect.fromLTWH(-3, -5, 6, 2), _f(foam));
    // Kulp.
    c.drawRect(Rect.fromLTWH(dir * 3, -2, 2, 1), _f(clay));
    c.drawRect(Rect.fromLTWH(dir * 4, -2, 1, 4), _f(clay));
    c.drawRect(Rect.fromLTWH(dir * 3, 1, 2, 1), _f(clay));
    c.restore();
  }

  // ── SEPET — iki elle, karın önünde ────────────────────────────────────────
  static void _basket(Canvas c, double dir, double sway) {
    const wicker = Color(0xFFA98346);
    const goods = Color(0xFF6E8C4A);
    c.save();
    c.translate(dir * 4 + sway, -38);
    _shaded(c, const Rect.fromLTWH(-7, -4, 14, 9), wicker);
    // Örgü çizgileri.
    c.drawRect(const Rect.fromLTWH(-7, -1, 14, 1), _f(darker(wicker, 0.22)));
    // İçindeki mal — sepeti "dolu" yapan tek detay.
    c.drawRect(const Rect.fromLTWH(-5, -6, 4, 3), _f(goods));
    c.drawRect(const Rect.fromLTWH(1, -6, 4, 3), _f(darker(goods, 0.15)));
    c.restore();
  }

  // ── ODUN DEMETİ — iki elle, göğüste ───────────────────────────────────────
  static void _firewood(Canvas c, double dir, double sway) {
    const bark = Color(0xFF6B4E32);
    c.save();
    c.translate(dir * 3 + sway, -44);
    c.rotate(dir * 0.08);
    for (var i = 0; i < 3; i++) {
      _shaded(c, Rect.fromLTWH(-8, -4.0 + i * 3.0, 16, 3), i.isEven
          ? bark
          : lighter(bark, 0.10));
    }
    c.restore();
  }
}
