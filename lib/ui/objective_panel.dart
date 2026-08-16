import 'package:flutter/material.dart';
import '../systems/quest_book.dart';
import 'app_ui.dart';
import 'semantic_icon.dart';

/// Köy Defteri — köyün kimlik kademesi (başlık) + akan görev listesi.
/// Koyu panel: başlıkta kademe adı + ✓ tamamlanan sayısı; aktif görev
/// ember vurgu + ipucu; altta bir sonraki kademe ipucu.
/// Ödüller görseldir (kutlama + köyün çiçeklenmesi) — burada sayı/kaynak yok.
class ObjectivePanel extends StatelessWidget {
  /// Açık (tamamlanmamış) görevler — ilki `active`.
  final List<QuestState> quests;
  final int tierIndex;
  final String tierName;
  final String tierIcon;
  final int completedCount;
  final int totalCount;
  /// Bir sonraki kademe (varsa) — ilerleme ipucu.
  final CharterTier? next;
  final bool collapsed;
  final VoidCallback onToggleCollapse;

  /// Başlığa dokununca Köy Defteri'nin TÜZÜK bölümü açılır (kademe merdiveni +
  /// biten görevler orada). Bu pano yalnız bir "şu an ne yapıyorum" hatırlatıcı;
  /// tam döküm defterde. Daralt/aç oku ayrı kalır.
  final VoidCallback? onOpenLedger;

  const ObjectivePanel({
    super.key,
    required this.quests,
    required this.tierIndex,
    required this.tierName,
    required this.tierIcon,
    required this.completedCount,
    required this.totalCount,
    required this.next,
    required this.collapsed,
    required this.onToggleCollapse,
    this.onOpenLedger,
  });

  @override
  Widget build(BuildContext context) {
    final activeIdx = quests.indexWhere((q) => q.active);

    return SizedBox(
      width: 224,
      child: AppPanel(
        accent: AppUi.accent,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            if (!collapsed) ...[
              const SizedBox(height: 8),
              if (quests.isEmpty)
                _allClear()
              else
                for (final q in quests) _row(q),
              if (activeIdx >= 0) ...[
                const SizedBox(height: 9),
                _hintBar(quests[activeIdx]),
              ],
              if (next != null) ...[
                const SizedBox(height: 9),
                _nextTierBar(next!),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        // Künye kısmı → defterin TÜZÜK bölümü (tam döküm). onOpenLedger yoksa
        // (harness/preview) eski davranış: daralt/aç.
        Expanded(
          child: GestureDetector(
            onTap: onOpenLedger ?? onToggleCollapse,
            behavior: HitTestBehavior.opaque,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Row(
                children: [
                  SemanticIcon(
                    tierIcon,
                    size: 14,
                    color: AppUi.accentSoft,
                    fallback: GameIconData.crown,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(tierName.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.title.copyWith(
                          fontSize: 12,
                          color: AppUi.accentSoft,
                          letterSpacing: 1.2,
                        )),
                  ),
                  const GameIcon(GameIconData.star, size: 11, color: AppUi.sage),
                  const SizedBox(width: 3),
                  Text('$completedCount',
                      style: AppUi.number
                          .copyWith(fontSize: 11, color: AppUi.sage)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 7),
        // Daralt/aç oku — yön collapsed durumuna göre döner.
        GestureDetector(
          onTap: onToggleCollapse,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Transform.rotate(
              angle: collapsed ? 1.5708 : -1.5708,
              child: const GameIcon(GameIconData.chevron,
                  size: 13, color: AppUi.textLo),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(QuestState s) {
    final active = s.active;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            // Emoji DEĞİL — HUD'la aynı temalı Phosphor glyph (renkli oyuncak
            // emoji tema/göz yorgunluğunun bir parçasıydı).
            child: GameIcon(questGlyph(s.quest.id),
                size: 12, color: active ? AppUi.accent : AppUi.textLo),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(s.quest.label,
                style: active
                    ? AppUi.bodyHi.copyWith(fontSize: 11)
                    : AppUi.body.copyWith(
                        fontSize: 11,
                        color: AppUi.textMid.withValues(alpha: 0.7),
                      )),
          ),
        ],
      ),
    );
  }

  Widget _hintBar(QuestState active) {
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
      decoration: BoxDecoration(
        color: AppUi.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.accent.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // GÖREVİ KİM İSTİYOR — kuruluş görevlerinin çoğu bir kurucunun
          // ağzından çıkar. İsim üstte durur ki ipucu bir sistem mesajı değil
          // birinin ricası gibi okunsun; kurucu ölmüşse satır hiç çizilmez.
          if (active.speakerName case final who?) ...[
            Text('$who istiyor',
                style: AppUi.label.copyWith(
                  fontSize: 9,
                  color: AppUi.accentSoft,
                  letterSpacing: 0.5,
                )),
            const SizedBox(height: 3),
          ],
          Text(active.quest.hint,
              style: AppUi.body.copyWith(
                fontSize: 10,
                color: AppUi.textHi,
                height: 1.4,
              )),
        ],
      ),
    );
  }

  Widget _nextTierBar(CharterTier n) => Row(
        children: [
          const GameIcon(GameIconData.chevron, size: 10, color: AppUi.textLo),
          const SizedBox(width: 4),
          SemanticIcon(n.icon,
              size: 11, color: AppUi.textLo, fallback: GameIconData.crown),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Sonraki: ${n.name}  (${n.minPolicies} berat · ${n.minQuests} görev)',
              style: AppUi.body.copyWith(
                fontSize: 9.5,
                color: AppUi.textLo,
                height: 1.3,
              ),
            ),
          ),
        ],
      );

  Widget _allClear() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('Bu kademe tamam — yeni berat çıkar, köy ilerlesin.',
          style: AppUi.body.copyWith(
            color: AppUi.sage,
            fontSize: 10,
            height: 1.4,
          )),
    );
  }
}

/// Görev kimliği → temalı Phosphor glyph (emoji yerine). ObjectivePanel ve
/// QuestTracker paylaşır. Bilinmeyen id star'a düşer — yeni görev eklenince
/// buraya bir satır ekle.
GameIconData questGlyph(String id) => switch (id) {
      'firepit' => GameIconData.flame,
      'lumber' => GameIconData.axe,
      'house' => GameIconData.home,
      'farm' => GameIconData.wheat,
      'well' => GameIconData.drop,
      // ── Kuruluş mikro adımları ──────────────────────────────────────────
      'tent' => GameIconData.home,
      'firstNight' => GameIconData.moon,
      'townhall' => GameIconData.bank,
      'firstPolicy' => GameIconData.scroll,
      'tavern' => GameIconData.tankard,
      'pop10' => GameIconData.people,
      'church' => GameIconData.church,
      'market' => GameIconData.market,
      'beehive' => GameIconData.honey,
      'florist' => GameIconData.flower,
      'threePolicies' => GameIconData.scales,
      'neighborly' => GameIconData.handshake,
      'pop20' => GameIconData.people,
      'bloomVillage' => GameIconData.flower,
      'fivePolicies' => GameIconData.crown,
      'hospitality' => GameIconData.door,
      'warehouse' => GameIconData.warehouse,
      'pop30' => GameIconData.star,
      _ => GameIconData.star,
    };
