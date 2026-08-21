import 'package:flutter/material.dart';

import '../systems/village_collapse.dart';
import 'app_ui.dart';
import 'gameplay_dioramas.dart';

/// KÖY DAĞILDI — koşunun kapanış ekranı.
///
/// Bir "başarısız oldun" tabelası DEĞİL, bir MEZAR TAŞI. Oyuncu buraya
/// geldiğinde onlarca saatlik bir köyü kaybetmiştir; ekranın işi suçlamak değil,
/// o köyü son bir kez saymaktır: adı, kaç gün yaşadığı, en kalabalık hâli,
/// hangi hanenin gölgesinde durduğu ve vakanüvisin son satırları.
///
/// Palet bilerek soğuk (bkz. feedback_no_wood_palette): ember vurgusu tek bir
/// yerde, sönmüş közün üstünde durur. Kutlama yok, tantana yok.
class CollapseScreen extends StatelessWidget {
  final String village;
  final CollapseCause cause;
  final int days;
  final int peakAdults;
  final String identity;

  /// Kroniğin son satırları — köyün kendi ağzından son sözleri.
  final List<String> epitaph;
  final VoidCallback onExit;

  const CollapseScreen({
    super.key,
    required this.village,
    required this.cause,
    required this.days,
    required this.peakAdults,
    required this.identity,
    required this.epitaph,
    required this.onExit,
  });

  String get _causeLine => switch (cause) {
    CollapseCause.emptied => 'Son can da çekip gitti. Geriye kimse kalmadı.',
    CollapseCause.noHands =>
      'Köyü döndürecek el kalmadı. Kalanlar ocağı taşıyamadı.',
  };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF07090C),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VillageOutcomeDiorama(
                  thriving: false,
                  accent: AppUi.rust,
                  population: peakAdults,
                ),
                const SizedBox(height: 16),
                Text(
                  'KÖY DAĞILDI',
                  textAlign: TextAlign.center,
                  style: AppUi.title.copyWith(
                    fontSize: 22,
                    letterSpacing: 3,
                    color: AppUi.textHi,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  village,
                  textAlign: TextAlign.center,
                  style: AppUi.body.copyWith(fontSize: 15, color: AppUi.gold),
                ),
                const SizedBox(height: 20),
                Text(
                  _causeLine,
                  textAlign: TextAlign.center,
                  style: AppUi.body.copyWith(
                    fontSize: 12.5,
                    color: AppUi.textMid,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat('$days', 'gün yaşadı'),
                    _stat('$peakAdults', 'en kalabalık'),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    identity,
                    style: AppUi.label.copyWith(
                      fontSize: 10,
                      color: AppUi.textLo,
                    ),
                  ),
                ),
                if (epitaph.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppUi.surface0,
                      borderRadius: BorderRadius.circular(AppUi.radiusSm),
                      border: Border.all(color: AppUi.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SON SATIRLAR',
                          style: AppUi.label.copyWith(
                            fontSize: 9,
                            color: AppUi.textLo,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final line
                            in epitaph.reversed.take(2).toList().reversed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              '· $line',
                              style: AppUi.body.copyWith(
                                fontSize: 11.5,
                                color: AppUi.textMid,
                                height: 1.45,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Sönmüş ocağın izi kayıtlarda kaldı.',
                  textAlign: TextAlign.center,
                  style: AppUi.body.copyWith(
                    fontSize: 11,
                    color: AppUi.textLo,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: AppButton(label: 'Ana Menü', onTap: onExit),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
    children: [
      Text(
        value,
        style: AppUi.number.copyWith(fontSize: 24, color: AppUi.textHi),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: AppUi.label.copyWith(fontSize: 9.5, color: AppUi.textLo),
      ),
    ],
  );
}
