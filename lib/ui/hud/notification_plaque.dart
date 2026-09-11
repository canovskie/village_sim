import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../systems/events/village_news.dart';
import '../core/app_ui.dart';

/// Köyün tek haber yüzeyi. Konu, ton, önem ve zaman bilgisini [VillageNews]
/// taşır; bu widget yalnız tipografik hiyerarşiyi ve süre izini çizer.
class NotificationPlaque extends StatelessWidget {
  final String? message;
  final VillageNews? _structuredNews;
  final bool compact;
  final int pendingCount;

  /// Sahnenin görünür süre saati; galeri yalnız animasyon kullanabilir.
  final double? remainingFraction;

  const NotificationPlaque({
    super.key,
    required this.message,
    this.compact = false,
    this.pendingCount = 0,
    this.remainingFraction,
  }) : _structuredNews = null;

  const NotificationPlaque.news({
    super.key,
    required VillageNews news,
    this.compact = false,
    this.pendingCount = 0,
    this.remainingFraction,
  }) : _structuredNews = news,
       message = null;

  VillageNews get news =>
      _structuredNews ?? VillageNews.fromMessage(message ?? '');

  /// Kısa sistem geri bildirimleri de, iki satırlık köy haberleri de aynı
  /// hızda kaçmasın. Ana sahnedeki kuyruk ve alttaki zaman izi aynı hesabı
  /// kullanır.
  static Duration readDuration(String message) =>
      VillageNews.fromMessage(message).readDuration;

  Color get _accent {
    return switch (news.tone) {
      VillageNewsTone.neutral => AppUi.accent,
      VillageNewsTone.favorable => AppUi.sage,
      VillageNewsTone.caution => const Color(0xFFD79B54),
      VillageNewsTone.critical => AppUi.rust,
    };
  }

  GameIconData get _icon {
    if (news.tone == VillageNewsTone.critical) return GameIconData.bolt;
    return switch (news.topic) {
      VillageNewsTopic.village => GameIconData.home,
      VillageNewsTopic.people => GameIconData.people,
      VillageNewsTopic.work => GameIconData.hammer,
      VillageNewsTopic.stores => GameIconData.warehouse,
      VillageNewsTopic.weather => GameIconData.storm,
      VillageNewsTopic.safety => GameIconData.eye,
      VillageNewsTopic.council => GameIconData.scales,
      VillageNewsTopic.trade => GameIconData.market,
      VillageNewsTopic.imperial => GameIconData.crown,
      VillageNewsTopic.system => GameIconData.cog,
    };
  }

  @override
  Widget build(BuildContext context) {
    final width = compact ? 360.0 : 430.0;
    final minHeight = compact ? 62.0 : 74.0;
    final sealSize = compact ? 40.0 : 48.0;
    final contentLeft = compact ? 58.0 : 68.0;
    return AppReveal(
      key: ValueKey(news.dedupeKey),
      child: SizedBox(
        width: width,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Stack(
            children: [
              Positioned(
                left: sealSize * .42,
                right: 0,
                top: compact ? 4 : 5,
                bottom: compact ? 4 : 5,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xF2111419),
                        Color(0xDB111419),
                        Color(0x00111419),
                      ],
                      stops: [0, .82, 1],
                    ),
                    border: Border(
                      top: BorderSide(color: AppUi.lineSoft),
                      bottom: BorderSide(color: AppUi.lineSoft),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: Container(
                        width: sealSize,
                        height: sealSize,
                        decoration: BoxDecoration(
                          color: AppUi.surface0,
                          border: Border.all(
                            color: _accent.withValues(alpha: .82),
                            width: 1.2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x8A000000),
                              blurRadius: 12,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Transform.rotate(
                          angle: -math.pi / 4,
                          child: GameIcon(
                            _icon,
                            size: compact ? 17 : 20,
                            color: _accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  contentLeft,
                  compact ? 8 : 10,
                  compact ? 18 : 30,
                  compact ? 9 : 11,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            news.topic.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppUi.label.copyWith(
                              color: _accent,
                              fontSize: compact ? 6.5 : 7.5,
                              letterSpacing: 1.7,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(width: 16, height: 1, color: _accent),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            news.stamp,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppUi.label.copyWith(
                              color: AppUi.textLo,
                              fontSize: compact ? 6.5 : 7.5,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 3 : 4),
                    Text(
                      _upper(news.headline),
                      style: AppUi.title.copyWith(
                        color: AppUi.textHi,
                        fontSize: compact ? 11 : 13.5,
                        height: 1.12,
                        letterSpacing: compact ? .6 : .9,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      news.body,
                      style: AppUi.body.copyWith(
                        color: AppUi.textMid,
                        fontSize: compact ? 9.5 : 10.5,
                        height: 1.25,
                      ),
                    ),
                    if (pendingCount > 0) ...[
                      SizedBox(height: compact ? 2 : 3),
                      Text(
                        '$pendingCount HABER SIRADA',
                        style: AppUi.label.copyWith(
                          color: AppUi.textLo,
                          fontSize: compact ? 6 : 6.5,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: contentLeft,
                right: compact ? 28 : 48,
                bottom: compact ? 4 : 5,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 1,
                    end: remainingFraction ?? (AppUi.captureStatic ? .72 : 0),
                  ),
                  duration: AppUi.captureStatic || remainingFraction != null
                      ? Duration.zero
                      : news.readDuration,
                  builder: (_, value, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        height: 1.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_accent, _accent.withValues(alpha: 0)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: compact ? 8 : 10,
                right: compact ? 9 : 15,
                child: _PriorityMark(
                  priority: news.priority,
                  color: _accent,
                  compact: compact,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityMark extends StatelessWidget {
  final VillageNewsPriority priority;
  final Color color;
  final bool compact;

  const _PriorityMark({
    required this.priority,
    required this.color,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final count = priority.index + 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        4,
        (index) => Container(
          width: compact ? 2 : 2.5,
          height: 2,
          margin: const EdgeInsets.only(left: 2),
          color: index < count ? color : AppUi.lineSoft,
        ),
      ),
    );
  }
}

String _upper(String text) =>
    text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
