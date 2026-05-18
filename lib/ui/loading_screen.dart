import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'game_theme.dart';

/// Asset cache'leri (sprite PNG'leri) hazırlanırken gösterilir.
/// Pulse eden ateş ışıltısı + ortaçağ teması — ana menü estetiği ile uyumlu.
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
        backgroundColor: const Color(0xFF1A0F30),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    Color.fromRGBO(255, 160, 60, (0.55 * pulse).clamp(0.2, 1.0)),
                    const Color(0x00FF8030),
                  ]),
                ),
                child: const Center(
                  child: Text('☼',
                      style: TextStyle(
                        color: MedievalTheme.textAccent,
                        fontSize: 32,
                      )),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Köy uyanıyor...',
                  style: TextStyle(
                    color: MedievalTheme.textAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    letterSpacing: 2.0,
                  )),
              const SizedBox(height: 6),
              const Text('asset yükleniyor',
                  style: TextStyle(
                    color: MedievalTheme.textDim,
                    fontSize: 10,
                    fontFamily: 'monospace',
                    letterSpacing: 1.5,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
