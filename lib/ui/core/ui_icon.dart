import 'package:flutter/material.dart';

/// Pixel-art HUD ikonu — `assets/ui/icon_<name>.png` yükler; dosya yoksa
/// [fallback] emoji'sine düşer. Böylece ikon seti tek tek üretildikçe otomatik
/// devreye girer, henüz üretilmeyenler emoji olarak çalışmaya devam eder
/// (hiçbir şey kırılmaz). Pixel-art keskinliği için filtreleme kapalı.
///
/// Kullanım: `UiIcon('wood', fallback: '🪵', size: 15)`.
class UiIcon extends StatelessWidget {
  /// Dosya adı çekirdeği — `assets/ui/icon_<name>.png`.
  final String name;
  /// PNG yokken gösterilecek emoji (mevcut davranış korunur).
  final String fallback;
  /// Kare kenar uzunluğu (px). Emoji fallback'i de buna göre ölçeklenir.
  final double size;
  /// Opsiyonel renk tonu — tek-renk (maske) ikonları boyamak için. Tam renkli
  /// ikonlarda null bırak.
  final Color? tint;

  const UiIcon(
    this.name, {
    super.key,
    required this.fallback,
    this.size = 16,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/ui/icon_$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      color: tint,
      // Dosya henüz yoksa emoji'ye düş — üretim sırasında kademeli geçiş.
      errorBuilder: (context, error, stack) =>
          Text(fallback, style: TextStyle(fontSize: size * 0.95)),
    );
  }
}
