import 'package:flutter/material.dart';

import '../../systems/events/event_system.dart';
import '../../systems/governance/petition_system.dart';
import '../core/app_ui.dart';

/// Olay ve suç kararlarını bir bakışta okunur kılan sinematik resim yüzeyi.
///
/// Görseller başlık/metin taşımıyor; yerelleştirme Flutter katmanında kalır.
/// [alignment] dar ekran kırpmasında olayın asıl kanıtını kadrajda tutar.
class EventArtwork extends StatelessWidget {
  final String asset;
  final double height;
  final Alignment alignment;
  final Color accent;

  const EventArtwork({
    super.key,
    required this.asset,
    required this.height,
    required this.accent,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppUi.surface0,
            border: Border.all(color: accent.withValues(alpha: 0.52)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                asset,
                fit: BoxFit.cover,
                alignment: alignment,
                filterQuality: FilterQuality.medium,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x5C080706)],
                    stops: [0.55, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Yeni içerik kendi görselini tanımlayana kadar olay kartı metinle çalışır.
String? eventArtworkAsset(EventOutcome event) => null;

/// Yeni dilekçeler kendi görsel eşlemesini ekleyebilir.
String? petitionArtworkAsset(Petition petition) => null;
