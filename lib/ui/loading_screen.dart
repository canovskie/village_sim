import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'app_ui.dart';

/// Asset cache'leri (sprite PNG'leri) hazırlanırken gösterilir.
/// Pulse eden ateş ışıltısı + koyu oyun teması — ana menü estetiği ile uyumlu.
class LoadingScreen extends StatefulWidget {
  final VoidCallback? onCancel;
  const LoadingScreen({super.key, this.onCancel});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _t = 0;

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
                  gradient: RadialGradient(colors: [
                    AppUi.accent.withValues(alpha: (0.5 * pulse).clamp(0.18, 1.0)),
                    AppUi.accent.withValues(alpha: 0.0),
                  ]),
                ),
                child: GameIcon(GameIconData.flame,
                    size: 40,
                    color: Color.lerp(
                        AppUi.accentDeep, AppUi.accentSoft, pulse)!),
              ),
              const SizedBox(height: 22),
              Text('KÖY UYANIYOR',
                  style: AppUi.title.copyWith(
                    fontSize: 14,
                    letterSpacing: 2.4,
                    color: AppUi.textHi,
                  )),
              const SizedBox(height: 8),
              Text('asset yükleniyor',
                  style: AppUi.label.copyWith(letterSpacing: 1.6)),
            ],
          ),
        ),
      ),
    );
  }
}
