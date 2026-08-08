import 'package:flutter/material.dart';

import '../systems/reckoning.dart';
import 'app_ui.dart';

/// HESAPLAŞMA EKRANI — koşunun kapanışı.
///
/// [CollapseScreen] mezar taşıdır; bu ekran KARNEDİR. Aradaki fark bilinçli:
/// dağılma tek bir cümleyle anlatılır ("el kalmadı"), hesaplaşma ise beş
/// sütunlu bir hesaptır. Oyuncu yalnız sonucu değil GEREKÇEYİ de görmeli —
/// hangi sütunun boş kaldığını okuyamayan oyuncu bir sonraki köyünde aynı
/// yere gelir ve oyun ona hiçbir şey öğretmemiş olur.
///
/// Palet karara göre ısınır: sancak ember, berat altın, ilhak soğuk grafit.
/// Kutlama konfetisi yok — en iyi sonuç bile bir imparatorluk kararıdır.
class ReckoningScreen extends StatelessWidget {
  final String village;
  final ReckoningVerdict verdict;

  /// Rejime göre kapanış cümlesi (bkz. `verdictEpilogue`).
  final String epilogue;

  /// Köyün kazandığı kimliğin adı — karnenin altında imza gibi durur.
  final String identity;

  final int years;
  final int days;
  final int population;

  /// Karar sütunları — neyin ne kadar taşıdığı.
  final List<ReckoningLedgerRow> rows;

  /// Kroniğin son kilometre taşları.
  final List<String> milestones;

  final VoidCallback onExit;

  const ReckoningScreen({
    super.key,
    required this.village,
    required this.verdict,
    required this.epilogue,
    required this.identity,
    required this.years,
    required this.days,
    required this.population,
    required this.rows,
    required this.milestones,
    required this.onExit,
  });

  /// Kararın vurgu rengi. İlhakta sıcak nokta yok: ekran soğur.
  Color get _accent => switch (verdict) {
        ReckoningVerdict.sancak => const Color(0xFFF0A95C),
        ReckoningVerdict.berat => AppUi.gold,
        ReckoningVerdict.ilhak => const Color(0xFF8892A0),
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF07090C),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        _accent.withValues(alpha: verdict.favorable ? 0.26 : 0.10),
                        const Color(0x00000000),
                      ]),
                    ),
                    child: Center(
                      child: Text(verdict.icon,
                          style: const TextStyle(fontSize: 25)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  verdict.title,
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
                  style: AppUi.body.copyWith(fontSize: 15, color: _accent),
                ),
                const SizedBox(height: 20),
                Text(
                  epilogue,
                  textAlign: TextAlign.center,
                  style: AppUi.body.copyWith(
                      fontSize: 12.5, color: AppUi.textMid, height: 1.55),
                ),
                const SizedBox(height: 26),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat('$years', 'yıl sürdü'),
                    _stat('$days', 'gün'),
                    _stat('$population', 'can'),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    identity,
                    style:
                        AppUi.label.copyWith(fontSize: 10, color: AppUi.textLo),
                  ),
                ),

                // ── KARNE — kararın gerekçesi ────────────────────────────
                if (rows.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppUi.surface0,
                      borderRadius: BorderRadius.circular(AppUi.radiusSm),
                      border: Border.all(color: AppUi.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DEFTERDE NE YAZIYORDU',
                            style: AppUi.label
                                .copyWith(fontSize: 9, color: AppUi.textLo)),
                        const SizedBox(height: 10),
                        for (final r in rows) _row(r),
                      ],
                    ),
                  ),
                ],

                if (milestones.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppUi.surface0,
                      borderRadius: BorderRadius.circular(AppUi.radiusSm),
                      border: Border.all(color: AppUi.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SON SATIRLAR',
                            style: AppUi.label
                                .copyWith(fontSize: 9, color: AppUi.textLo)),
                        const SizedBox(height: 8),
                        for (final line in milestones)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              '· $line',
                              style: AppUi.body.copyWith(
                                  fontSize: 11.5,
                                  color: AppUi.textMid,
                                  height: 1.45),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                Text(
                  'Bu köyün defteri kapandı. Kaydı menüde duruyor — '
                  'okuyabilirsin ama devam edemezsin.',
                  textAlign: TextAlign.center,
                  style: AppUi.body.copyWith(
                      fontSize: 11, color: AppUi.textLo, height: 1.45),
                ),
                const SizedBox(height: 24),
                Center(child: AppButton(label: 'Ana Menü', onTap: onExit)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tek karne satırı: ad + dolu/boş çubuk + tek cümle karşılık.
  ///
  /// Çubuk yüzde YAZMAZ. Bu bir istatistik ekranı değil bir defter sayfası;
  /// oyuncunun okuması gereken şey "%38" değil, "haneler yüzünü çevirmişti".
  Widget _row(ReckoningLedgerRow r) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.label,
                      style: AppUi.body.copyWith(
                          fontSize: 11.5,
                          color: AppUi.textHi,
                          fontWeight: FontWeight.w600)),
                ),
                SizedBox(
                  width: 92,
                  height: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: r.value.clamp(0.0, 1.0),
                      backgroundColor: AppUi.surface1,
                      valueColor: AlwaysStoppedAnimation(_accent),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(r.note,
                style: AppUi.body.copyWith(
                    fontSize: 10.5, color: AppUi.textLo, height: 1.4)),
          ],
        ),
      );

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value,
              style: AppUi.number.copyWith(fontSize: 24, color: AppUi.textHi)),
          const SizedBox(height: 2),
          Text(label,
              style: AppUi.label.copyWith(fontSize: 9.5, color: AppUi.textLo)),
        ],
      );
}
