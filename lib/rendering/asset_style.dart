import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// PNG asset'lerinin nasıl çizileceğine dair MERKEZİ konfigürasyon.
///
/// İki kademe:
///   1. **Yükleme anında bir kez** [softenAtLoad] ile blur uygulanıp önbelleğe
///      alınır.  Her frame yeniden hesaplanmaz → sıfır runtime maliyet.
///   2. **Çizim sırasında** [paint] fabrikasından gelen Paint kullanılır —
///      sadece ölçekleme/anti-alias kalitesi (ucuz GPU işi).
///
/// Tuning için bu dosyadaki sabitleri değiştir; renderer'ları tek tek dolaşma.
class AssetStyle {
  AssetStyle._();

  // ── Konfigürasyon ──────────────────────────────────────────────────────────

  /// Ölçeklemede kullanılacak interpolasyon kalitesi.
  /// - `none`: pixel-perfect, sert kenarlar
  /// - `low`:  hızlı bilinear, hafif yumuşatma
  /// - `medium`: bilinear + mipmap, dengeli
  /// - `high`: bicubic, en yumuşak ama yavaş
  static const FilterQuality quality = FilterQuality.medium;

  /// Kenar anti-aliasing — sprite kenarlarını sub-pixel yumuşatır.
  static const bool antiAlias = true;

  /// Yükleme anında bir kez uygulanacak Gaussian blur sigma'sı (piksel).
  /// 0 → blur yok.  ~0.3–0.8 hafif soft texture.  >1.2 belirgin blur, detay
  /// kaybı.  Bu değer **render maliyeti üretmez** — pre-process'tir.
  static const double softness = 0.6;

  // ── Çizim Paint fabrikası ──────────────────────────────────────────────────

  /// Çizim için Paint — sadece bilinear filtre + AA.  Her frame uygulanır
  /// ama O(1) GPU işi; blur bu aşamada YOK (yükleme aşamasında halledildi).
  static Paint apply(Paint p) {
    p.filterQuality = quality;
    p.isAntiAlias   = antiAlias;
    return p;
  }

  static Paint paint() => apply(Paint());

  // ── Yükleme-zamanı blur ────────────────────────────────────────────────────

  /// PNG yüklendikten sonra bir kez çağrılır.  ImageFilter.blur ile
  /// Gaussian blur uygulayıp yeni bir [ui.Image] döner.
  /// Sonuç önbelleğe alınır — her frame normal `drawImageRect` yapılır.
  ///
  /// Maliyet: yalnız uygulama açılırken bir kez (asset başına ~1-5 ms).
  /// `softness == 0` ise orijinal görüntü olduğu gibi döner.
  /// [tileMode]: blur'un görüntü sınırı dışını nasıl örnekleyeceği.
  /// - `decal` (varsayılan): dışarısı saydam → sprite kenarları yumuşakça
  ///   saydama solar (silüetli karakter/bina için doğru).
  /// - `clamp`: dışarısı kenar pikseliyle doldurulur → görüntü kenara kadar
  ///   OPAK kalır.  Kenar kenara DÖŞENEN tile'lar (çim) için zorunlu; yoksa
  ///   solan saydam kenarlar bitişik karelerde açık dikiş çizgisi yapar.
  static Future<ui.Image> softenAtLoad(ui.Image src,
      {TileMode tileMode = TileMode.decal}) async {
    if (softness <= 0) return src;
    final w = src.width;
    final h = src.height;
    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);
    final rect     = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());

    // saveLayer + ImageFilter.blur: layer içeriği composite öncesi Gaussian
    // blur'lanır.  maskFilter sadece alpha kenarını blurlardı; ImageFilter.blur
    // RGB+alpha hepsini blurlar → gerçek texture softening.
    final blurPaint = Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: softness,
        sigmaY: softness,
        tileMode: tileMode,
      );
    canvas.saveLayer(rect, blurPaint);
    canvas.drawImage(src, Offset.zero, Paint());
    canvas.restore();

    final picture = recorder.endRecording();
    final result  = await picture.toImage(w, h);
    picture.dispose();
    return result;
  }
}
