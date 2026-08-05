import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../buildings/building_lore.dart';
import '../buildings/building_renderer.dart';
import '../buildings/building_type.dart';
import '../core/resources.dart';
import '../rendering/asset_style.dart';
import 'app_ui.dart';
import 'mobile_ui.dart';

/// İNŞA KÜNYESİ — palette'ten bir bina seçildiği an açılan bilgi kartı.
///
/// İş bölümü: "NE işe yarar" komuta çubuğunun orta yuvasında (bina summary'si),
/// bu kart ise "NEREYE kurulmalı"yı anlatır:
///   • **Yerleşim ipuçları** — [BuildingLore.tips]; ölçülebilenler hayaletin
///     durduğu yere göre CANLI işaretlenir (✓ kazanıldı / ○ kaçıyor / ! kural).
///   • **Neden kurulamaz** — [reason] (kırmızı satır, eski 🚫 çubuğunun yerine)
///   • **Tatlı not** — binanın kendi ağzından bir cümle (havuzdan).
///
/// Kart hayaletin ÜSTÜNDE değil ekranın altında durur ve tıklamayı geçirir
/// ([IgnorePointer] çağıran tarafta): oyuncu okurken de yerini seçebilsin.
class BuildingBrief extends StatelessWidget {
  final BuildingType type;

  /// Hayaletin durduğu yerin ölçümü — null ise ipuçları nötr okunur (henüz
  /// haritaya gelinmedi).
  final SiteFacts? facts;

  /// Yerleştirme geçersizse sebebi; geçerliyse null.
  final String? reason;

  /// Tatlı not seçici (her seçimde artan sayaç).
  final int noteSeed;

  const BuildingBrief({
    super.key,
    required this.type,
    required this.facts,
    required this.reason,
    required this.noteSeed,
  });

  @override
  Widget build(BuildContext context) {
    final meta = kBuildingMeta[type];
    if (meta == null) return const SizedBox.shrink();
    final compact = useCompactGameUi(context);
    final lore = loreOf(type);
    final note = sweetNote(type, noteSeed);

    return AppPanel(
      width: compact ? 320 : 360,
      padding: compact
          ? const EdgeInsets.fromLTRB(10, 7, 10, 8)
          : const EdgeInsets.fromLTRB(12, 10, 12, 11),
      borderRadius: compact ? BorderRadius.circular(MobileUi.radius) : null,
      accent: reason != null ? AppUi.rust : AppUi.accent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MOBİLDE BAŞLIK YOK: bina adı + maliyet zaten komuta çubuğunun inşa
          // ve bağlam yuvalarında duruyor. Alçak ekranda künye, o yuvanın
          // üstüne yapışan İNCE bir şerittir — ortada yüzen ikinci bir levha
          // değil (bkz. mobile_ui "tek ızgara").
          if (!compact) _header(meta, compact),
          // ÖZET BURADA DEĞİL: "ne işe yarar" cümlesi komuta çubuğunun orta
          // yuvasında duruyor (bkz. _commandContext). İki bitişik panelde aynı
          // paragrafı iki kez yazmak yerine iş bölümü: çubuk NE, künye NEREYE.
          if (lore != null && lore.tips.isNotEmpty) ...[
            if (!compact) const SizedBox(height: 10),
            if (!compact) const AppSectionLabel('NEREYE KURULMALI'),
            for (final tip in lore.tips) _tipRow(tip, compact),
          ],
          if (note != null) ...[
            SizedBox(height: compact ? 6 : 9),
            _noteRow(note, compact),
          ],
          if (reason != null) ...[
            SizedBox(height: compact ? 6 : 9),
            _reasonRow(reason!),
          ],
        ],
      ),
    );
  }

  // ── Başlık: portre + ad + maliyet ─────────────────────────────────────────

  Widget _header(BuildingMeta meta, bool compact) {
    final thumb = BuildingRenderer.thumbnails[type];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 34,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppUi.surface0,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: AppUi.line, width: 1),
          ),
          child: thumb != null
              ? CustomPaint(painter: _ThumbPainter(thumb))
              : const Center(
                  child: GameIcon(GameIconData.home,
                      size: 17, color: AppUi.textMid),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                meta.label,
                style: AppUi.title.copyWith(fontSize: compact ? 13 : 14),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                '${meta.cols}×${meta.rows} · ${_costLabel(meta.cost)}',
                style: AppUi.body.copyWith(fontSize: 10.5, color: AppUi.textLo),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _costLabel(ResourceCost cost) {
    if (cost.isFree) return 'ücretsiz';
    return [
      for (final (kind, amount) in cost.entries) '$amount ${_resName(kind)}',
    ].join(' · ');
  }

  static String _resName(ResourceKind k) => switch (k) {
        ResourceKind.wood => 'odun',
        ResourceKind.stone => 'taş',
        ResourceKind.iron => 'demir',
        ResourceKind.coal => 'kömür',
        ResourceKind.food => 'yem',
        ResourceKind.gold => 'altın',
        ResourceKind.honey => 'bal',
        ResourceKind.wool => 'yün',
        ResourceKind.reed => 'saz',
      };

  // ── Yerleşim ipucu satırı ─────────────────────────────────────────────────

  Widget _tipRow(SiteTip tip, bool compact) {
    final f = facts;
    // Hayalet henüz haritada değilse ölçüm yok: ipucu nötr okunur (metin
    // yine de öğretir). Yanlış bir ✓/✗ göstermektense hiç göstermeyiz.
    final state = f == null ? SiteTipState.neutral : tipState(tip, f);
    final value = f == null ? null : tipValue(tip, f);

    final (glyph, tint) = switch (state) {
      SiteTipState.met => ('✓', AppUi.sage),
      // Kural sağlanmıyorsa bu bir uyarı (kurulamaz); avantaj kaçıyorsa sakin
      // bir "○" — oyuncuyu her ipucu için paniğe sokmayız (cozy).
      SiteTipState.unmet => tip.rule ? ('!', AppUi.rust) : ('○', AppUi.textLo),
      SiteTipState.neutral => ('·', AppUi.textLo),
    };

    return Padding(
      padding: EdgeInsets.only(top: compact ? 3 : 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 13,
            child: Text(
              glyph,
              style: AppUi.bodyHi.copyWith(fontSize: 11.5, color: tint),
            ),
          ),
          Expanded(
            child: Text(
              // Telefonda satır başına ~35 karakter var: uzun metni oraya
              // sıkıştırmak yarım cümle üretir. Kısa hâl ayrı yazılıdır.
              compact ? tip.short : tip.text,
              maxLines: compact ? 1 : 3,
              overflow: TextOverflow.ellipsis,
              style: AppUi.body.copyWith(
                fontSize: 11,
                height: 1.25,
                color: state == SiteTipState.met ? AppUi.textHi : AppUi.textMid,
              ),
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: tint.withValues(alpha: 0.45)),
              ),
              child: Text(
                value,
                style: AppUi.number.copyWith(fontSize: 9.5, color: tint),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tatlı not ─────────────────────────────────────────────────────────────

  Widget _noteRow(String note, bool compact) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Süslü tipografik işaret (❦) fontta yok → emoji fallback'i sarı bir
          // leke olarak çiziliyordu. Sade em-dash hem yükte hem okumada temiz.
          Text('—',
              style: AppUi.body.copyWith(fontSize: 11, color: AppUi.gold)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              note,
              // Telefonda da İKİ satır: tek satıra sığmayan not "…inanma…"
              // diye yarıda kesiliyordu — yarım kalan bir cümle tatlı değil.
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: AppUi.body.copyWith(
                fontSize: 11,
                height: 1.25,
                color: AppUi.textLo,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );

  // ── Geçersizlik sebebi ────────────────────────────────────────────────────

  Widget _reasonRow(String reason) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: AppUi.rust.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(color: AppUi.rust.withValues(alpha: 0.6)),
        ),
        child: Text(
          '🚫 $reason',
          style: AppUi.bodyHi.copyWith(fontSize: 11, color: AppUi.rust),
        ),
      );
}

/// Pre-scaled thumbnail'ı orijinal oranıyla çizen hafif painter.
class _ThumbPainter extends CustomPainter {
  final ui.Image img;
  _ThumbPainter(this.img);

  static final _paint = AssetStyle.paint();

  @override
  void paint(Canvas canvas, Size size) {
    final sw = img.width.toDouble();
    final sh = img.height.toDouble();
    final scale = (sw / sh > size.width / size.height)
        ? size.width / sw
        : size.height / sh;
    final w = sw * scale;
    final h = sh * scale;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, sw, sh),
      Rect.fromLTWH((size.width - w) / 2, size.height - h, w, h),
      _paint,
    );
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.img != img;
}
