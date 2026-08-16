import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../characters/npc_visual.dart';
import '../systems/villager_act.dart';
import 'asset_style.dart';

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
  static final Map<PropKind, ui.Image> _sprites = {};
  static final Paint _spritePaint = AssetStyle.paint();

  static final Paint _fill = Paint()..isAntiAlias = false;
  static final Paint _stroke = Paint()
    ..isAntiAlias = false
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  static const Color _outline = Color(0xFF20191A);

  static Paint _f(Color c) => _fill..color = c;
  static Paint _s(Color c) => _stroke..color = c;

  /// Imagegen prop'ları. Yükleme başarısız olursa eski prosedürel çizim
  /// otomatik olarak devreye girer; prop sistemi hiçbir zaman boş el
  /// bırakmaz.
  static Future<void> loadAll() async {
    const paths = <PropKind, String>{
      PropKind.bucketEmpty: 'assets/tools/prop_bucket_empty.png',
      PropKind.bucketFull: 'assets/tools/prop_bucket_full.png',
      PropKind.sack: 'assets/tools/prop_sack.png',
      PropKind.bread: 'assets/tools/prop_bread.png',
      PropKind.mug: 'assets/tools/prop_mug.png',
      PropKind.basket: 'assets/tools/prop_basket.png',
      PropKind.firewood: 'assets/tools/prop_firewood.png',
      PropKind.scythe: 'assets/tools/prop_scythe.png',
      // Balta için projede zaten uyumlu, yönlü alet sprite'ı vardı.
      PropKind.axe: 'assets/tools/axe.png',
    };
    await Future.wait(paths.entries.map((e) => _load(e.key, e.value)));
  }

  static Future<void> _load(PropKind kind, String path) async {
    try {
      final bytes = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _sprites[kind] = await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('PropRenderer: $path yüklenemedi — prosedürel fallback: $e');
    }
  }

  static ui.Image? _sprite(PropKind kind) => _sprites[kind];

  /// [bottomY], mevcut prosedürel prop koordinatlarıyla aynı yerel uzayda
  /// zemini/eli sabitler. Yatay aynalama, köylünün yön değişiminde sapın ve
  /// kulpun doğru tarafa geçmesini sağlar.
  static void _drawSprite(
    Canvas c,
    ui.Image img, {
    required double x,
    required double bottomY,
    required double width,
    required bool flip,
    double sway = 0,
  }) {
    final height = width * img.height / img.width;
    c.save();
    c.translate(x + sway, bottomY);
    if (flip) c.scale(-1, 1);
    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    final dst = Rect.fromLTWH(-width / 2, -height, width, height);
    c.drawImageRect(img, src, dst, _spritePaint);
    c.restore();
  }

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
        final img = _sprite(prop);
        if (img != null) {
          _drawSprite(
            canvas,
            img,
            x: dir * 9,
            bottomY: -28,
            width: 15,
            flip: dir < 0,
            sway: sway,
          );
        } else {
          _bucket(canvas, dir, sway, full: false);
        }
      case PropKind.bucketFull:
        final img = _sprite(prop);
        if (img != null) {
          _drawSprite(
            canvas,
            img,
            x: dir * 9,
            bottomY: -28,
            width: 15,
            flip: dir < 0,
            sway: sway,
          );
        } else {
          _bucket(canvas, dir, sway, full: true, time: time);
        }
      case PropKind.sack:
        final img = _sprite(prop);
        if (img != null) {
          _drawSprite(
            canvas,
            img,
            x: -dir * 5,
            bottomY: -40,
            width: 15,
            flip: dir < 0,
            sway: sway * 0.5,
          );
        } else {
          _sack(canvas, dir, sway);
        }
      case PropKind.bread:
        final img = _sprite(prop);
        if (img != null) {
          _drawSprite(
            canvas,
            img,
            x: dir * 8,
            bottomY: -42,
            width: 14,
            flip: dir < 0,
            sway: sway,
          );
        } else {
          _bread(canvas, dir, sway);
        }
      case PropKind.mug:
        final img = _sprite(prop);
        if (img != null) {
          _drawSprite(
            canvas,
            img,
            x: dir * 8,
            bottomY: -38,
            width: 12,
            flip: dir < 0,
            sway: sway,
          );
        } else {
          _mug(canvas, dir, sway);
        }
      case PropKind.basket:
        final img = _sprite(prop);
        if (img != null) {
          _drawSprite(
            canvas,
            img,
            x: dir * 4,
            bottomY: -29,
            width: 20,
            flip: dir < 0,
            sway: sway,
          );
        } else {
          _basket(canvas, dir, sway);
        }
      case PropKind.firewood:
        final img = _sprite(prop);
        if (img != null) {
          _drawSprite(
            canvas,
            img,
            x: dir * 3,
            bottomY: -40,
            width: 22,
            flip: dir < 0,
            sway: sway,
          );
        } else {
          _firewood(canvas, dir, sway);
        }
      case PropKind.scythe:
        final img = _sprite(prop);
        if (img != null) {
          _drawSprite(
            canvas,
            img,
            x: dir * 9,
            bottomY: -26,
            width: 16,
            flip: dir < 0,
            sway: sway,
          );
        } else {
          _scythe(canvas, dir, sway);
        }
      case PropKind.axe:
        final img = _sprite(prop);
        if (img != null) {
          _drawSprite(canvas, img, x: dir * 9, bottomY: -26, width: 15,
              flip: dir < 0, sway: sway);
        } else {
          _axe(canvas, dir, sway);
        }
    }
    canvas.restore();
  }

  // ── KOVA — yanda, elden sarkar ────────────────────────────────────────────
  static void _bucket(
    Canvas c,
    double dir,
    double sway, {
    required bool full,
    double time = 0,
  }) {
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
      _shaded(
        c,
        Rect.fromLTWH(-8, -4.0 + i * 3.0, 16, 3),
        i.isEven ? bark : lighter(bark, 0.10),
      );
    }
    c.restore();
  }

  // ── TIRPAN — dikine, gövdeden UZUN ────────────────────────────────────────
  //
  // Bu ikisi (tırpan/balta) diğer nesnelerden farklı bir işe bakıyor: elde
  // görünmek değil, SİLUETTE okunmak. 37 px'lik köylüde göğsündeki ekmek bir
  // benek kadardır; ama başının ÜSTÜNE taşan bir sap, kalabalığın içinde bile
  // "bu adam silahlanmış" der. Bu yüzden sap gövdeden uzun (-78) ve ağız
  // yatayda dışa çıkıyor: dikey çizgi + tepede kanca.
  static void _scythe(Canvas c, double dir, double sway) {
    const wood = Color(0xFF7A5A3A);
    const steel = Color(0xFFB9C2CC);
    c.save();
    c.translate(dir * 9 + sway, -34);
    c.rotate(dir * 0.10); // hafif dışa yatık — dik bir çubuk cansız durur
    // Sap: elden aşağı biraz sarkar, yukarı baş hizasını aşar.
    _shaded(c, const Rect.fromLTWH(-1, -44, 2, 52), wood);
    // Ağız: sapın tepesinden dışa uzanır, ucu incelir (tırpanın kavsi).
    c.save();
    c.translate(0, -44);
    c.drawRect(Rect.fromLTWH(dir > 0 ? 0 : -9, 0, 9, 2), _f(steel));
    c.drawRect(Rect.fromLTWH(dir > 0 ? 5 : -8, 2, 3, 1), _f(steel));
    c.drawRect(
      Rect.fromLTWH(dir > 0 ? 0 : -9, 0, 9, 1),
      _f(lighter(steel, 0.20)),
    );
    // Bilezik: ağzın sapa oturduğu koyu boğum — ikisi tek parça görünmesin.
    c.drawRect(const Rect.fromLTWH(-1, -1, 2, 4), _f(_outline));
    c.restore();
    c.restore();
  }

  // ── BALTA — omuzda, baş yukarıda ──────────────────────────────────────────
  static void _axe(Canvas c, double dir, double sway) {
    const haft = Color(0xFF6B4E32);
    const steel = Color(0xFFAEB6C0);
    c.save();
    c.translate(dir * 9 + sway, -38);
    c.rotate(dir * 0.26); // omza yaslanmış açı
    _shaded(c, const Rect.fromLTWH(-1, -26, 2, 32), haft);
    // Baş: sapın tepesinde, dışa bakan kama.
    c.save();
    c.translate(dir * 2, -26);
    _shaded(c, Rect.fromLTWH(dir > 0 ? -1 : -5, -1, 6, 7), steel);
    // Ağız — dış kenarda bir tık parlak şerit (kamanın yüzü).
    c.drawRect(
      Rect.fromLTWH(dir > 0 ? 4 : -5, 0, 1, 5),
      _f(lighter(steel, 0.25)),
    );
    c.restore();
    c.restore();
  }
}
