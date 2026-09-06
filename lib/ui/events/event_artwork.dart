import 'package:flutter/material.dart';

import '../systems/event_system.dart';
import '../systems/petition_system.dart';
import 'app_ui.dart';

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

String eventArtworkAsset(EventOutcome event) => switch (event.id) {
  EventIds.drought => 'assets/events/drought.png',
  EventIds.plague => 'assets/events/plague.png',
  EventIds.beastRaid => 'assets/events/beast_raid.png',
  EventIds.storm => 'assets/events/village_disaster.png',
  EventIds.houseFire => 'assets/events/house_fire.png',
  EventIds.bard => 'assets/events/bard.png',
  EventIds.caravan => 'assets/events/village_opportunity.png',
  EventIds.bounty => 'assets/events/bounty.png',
  EventIds.accord => 'assets/events/accord.png',
  _ => 'assets/events/village_disaster.png',
};

/// Suç dilekçeleri özel resim kullanır; diğer dilekçelerin mevcut prosedürel
/// sahneleri korunur.
String? petitionArtworkAsset(Petition petition) => switch (petition.id) {
  'crimeVerdict' => 'assets/events/crime_judgment.png',
  'crimeWave' || 'ransom' => 'assets/events/crime_discovered.png',
  _ => null,
};
