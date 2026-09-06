import 'package:flutter/material.dart';

import '../systems/winter.dart';
import 'app_ui.dart';

/// KIŞ BÖLÜMÜ — tezgâhın durduğu binanın (ambar; ambar yoksa ocak başı)
/// panelinde açılan kış sayfası.
///
/// Bir zamanlar bu bilgi HUD'ın sağ üstünde SÜREKLİ duran bir kartti ve
/// sonbahar boyunca "%38 · 17 eksik" diye bağırıyordu. İki şeyi birden bozuyordu:
/// oyuncu kışa hazırlanmak yerine bir çubuğu doldurmaya çalışıyordu, ve kış
/// başlamadan haftalarca önce ekranda bir tehdit duruyordu — oysa köyün o an
/// yapabileceği bir şey yoktu (kırkım sonbaharda, dokuma zaman ister).
/// Panel oyunu gereksiz sert gösteriyordu.
///
/// Kış artık köyün AĞZINDAN duyulur (bkz. scene_winter `_maybeWinterEve`,
/// `_maybeWinterPinch`): sonbahar dönerken hatırlatılır, eksik kalırsa söylenir,
/// kışın ortasında bir şey tükenmeye yakınsa mırıldanılır. Sayının kendisini
/// merak eden buraya, tezgâhın başına gelir — bakmak İSTEYENİN işi olur,
/// bakmaya mecbur edilen bir gösterge değil.
///
/// Bölümün ikinci işi bir KARAR yüzeyi olmak: kışlık giysi kime? Köy
/// kendiliğinden "en doğru"yu yapmaz, oyuncunun dediğini yapar. Kararın burada
/// durması yerinde: giysiyi dokuyan tezgâh da bu binada.
class WinterSection extends StatelessWidget {
  const WinterSection({
    super.key,
    required this.readiness,
    required this.isWinter,
    required this.priority,
    required this.onPriority,
    this.undistributed = 0,
  });

  final WinterReadiness readiness;

  /// Kış başladı mı — başlık ve ton değişir ("hazırlık" → "dayanma").
  final bool isWinter;

  final CoatPriority priority;
  final ValueChanged<CoatPriority> onPriority;

  /// Dokunmuş ama henüz sırtlara dağıtılmamış giysi — varsa tezgâh çalışıyor.
  final int undistributed;

  static const _ice = Color(0xFF8FC2E8);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const GameIcon(GameIconData.snow, size: 12, color: _ice),
            const SizedBox(width: 7),
            Text(
              isWinter ? 'KIŞ SÜRÜYOR' : 'KIŞA HAZIRLIK',
              style: AppUi.label.copyWith(letterSpacing: 1.0, color: _ice),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final item in readiness.survival) ...[
          _bar(item),
          const SizedBox(height: 8),
        ],
        _coatBar(),
        const SizedBox(height: 10),
        Text(
          _verdict(),
          style: AppUi.body.copyWith(
            fontSize: 11,
            color: readiness.ready ? AppUi.sage : AppUi.textLo,
          ),
        ),
        const SizedBox(height: 12),
        _priorityRow(),
        if (undistributed > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Tezgâhta $undistributed kışlık hazır, dağıtılıyor.',
            style: AppUi.body.copyWith(fontSize: 11, color: AppUi.sage),
          ),
        ],
      ],
    );
  }

  /// Geçim kalemi — ölçüsü GÜN. "17 eksik" oyuncuya bir borç yükler, "9 gün
  /// yeter" bir durum bildirir; kartın sert tonu büyük ölçüde bu farktaydı.
  Widget _bar(WinterItem item) {
    final left = readiness.daysLeftOf(item);
    final (label, color) = switch (left) {
      final d when d.isInfinite => ('gerekmiyor', AppUi.textLo),
      final d when d >= readiness.days => ('kışı çıkarır', AppUi.sage),
      final d when d >= 2 => ('${d.floor()} gün yeter', AppUi.accent),
      final d when d >= 1 => ('son güne kaldı', AppUi.gold),
      _ => ('tükendi', AppUi.rust),
    };
    return AppStatBar(
      label: item.label.toUpperCase(),
      value: item.ratio,
      trailing: label,
      color: color,
    );
  }

  /// Kışlık RAHATLIK kalemidir, geçim değil: günle değil SIRTLA ölçülür.
  Widget _coatBar() {
    final have = readiness.coats.have.round();
    final need = readiness.coats.need.round();
    return AppStatBar(
      label: 'KIŞLIK',
      value: readiness.coats.ratio,
      trailing: '$have/$need sırt',
      color: readiness.coats.ready ? AppUi.sage : AppUi.accentSoft,
    );
  }

  /// Tek satırlık hüküm — köyün kendi cümlesiyle aynı şeyi söyler.
  String _verdict() {
    if (readiness.ready) {
      return isWinter ? 'Köy kışı rahat çıkarır.' : 'Köy kışa hazır.';
    }
    final t = readiness.tightest;
    final left = readiness.daysLeftOf(t);
    if (left.isInfinite || left >= readiness.days) {
      // Geçim tamam, eksik olan yalnız sırtlar.
      return 'Ambar yerinde; eksik olan sırtlar. Kış titreyerek geçer.';
    }
    final name = t.label.toLowerCase();
    if (left < 1) return 'Köyün $name\'ı bitti.';
    return 'İlk tükenecek $name — ${left.floor()} gün.';
  }

  Widget _priorityRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'KIŞLIK KİME',
          style: AppUi.label.copyWith(color: AppUi.textLo),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in CoatPriority.values)
              GestureDetector(
                onTap: () => onPriority(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: p == priority
                        ? Color.alphaBlend(
                            _ice.withValues(alpha: 0.18),
                            AppUi.surface2,
                          )
                        : AppUi.surface0,
                    borderRadius: BorderRadius.circular(AppUi.radiusSm),
                    border: Border.all(
                      color: p == priority
                          ? _ice.withValues(alpha: 0.6)
                          : AppUi.line,
                    ),
                  ),
                  child: Text(
                    p.label,
                    style: AppUi.body.copyWith(
                      fontSize: 11,
                      color: p == priority ? AppUi.textHi : AppUi.textMid,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          priority.hint,
          style: AppUi.body.copyWith(fontSize: 10.5, color: AppUi.textLo),
        ),
      ],
    );
  }
}
