import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../text/voice.dart';
import 'app_ui.dart';

/// Asset cache'leri (sprite PNG'leri) hazırlanırken gösterilir.
/// Pulse eden ateş ışıltısı + koyu oyun teması — ana menü estetiği ile uyumlu.
class LoadingScreen extends StatefulWidget {
  final VoidCallback? onCancel;

  /// Yüklenen köyün ADI — kayıt açılırken oyuncuyu kendi köyünün adı karşılar
  /// ("PINARBAŞI UYANIYOR"). Yeni oyunda henüz ad yoktur, jenerik kalır.
  final String village;

  const LoadingScreen({super.key, this.onCancel, this.village = ''});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _t = 0;

  /// Yükleme başlığı — adı olan köy kendi adıyla uyanır.
  String get _title {
    final v = widget.village.trim();
    if (v.isEmpty || v.toLowerCase() == 'köy') return 'KÖY UYANIYOR';
    return '${upperTr(v)} UYANIYOR';
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
      _last = elapsed;
      setState(() => _t += dt);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulse = (sin(_t * 4.0) * 0.25 + 0.75).clamp(0.4, 1.0);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onCancel?.call();
      },
      child: Scaffold(
        backgroundColor: AppUi.surface0,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppUi.accent.withValues(
                        alpha: (0.5 * pulse).clamp(0.18, 1.0),
                      ),
                      AppUi.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                // Nabız artık tek rengi değil gradyanın canlılığını sürüyor
                // (bkz. GameLogo.warmth) — sönerken de simgenin biçimi kalır.
                child: GameLogo(size: 40, warmth: pulse),
              ),
              const SizedBox(height: 22),
              Text(
                _title,
                style: AppUi.title.copyWith(
                  fontSize: 14,
                  letterSpacing: 2.4,
                  color: AppUi.textHi,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
