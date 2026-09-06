import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_ui.dart';
import 'guide_spotlight.dart';
import 'mobile_ui.dart';
import 'semantic_icon.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TAHTA — telefon yatayda YÖNETİM EKRANI yerleşimi
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Bu dosya tek bir gözlemin sonucudur:
///
///   **Yatay telefonda kıt olan eksen YÜKSEKLİK, bol olan eksen GENİŞLİKTİR.**
///   Masaüstü yerleşimi tam tersini varsayar.
///
/// Köy Defteri masaüstünde doğdu ve oradaki refleksi telefona taşıdı: kroma
/// üst üste YATAY BANTLAR halinde dizilir (başlık · bölüm sekmeleri · alt
/// sekmeler · KPI şeridi · sırala şeridi), altına da TEK SÜTUNLUK bir liste
/// akar. iPhone 11'de defter penceresi 760×360; ölçtüğümüzde NÜFUS bölümünde
/// o bantlar 270dp'yi yiyordu — 18 kişilik köyün listesine 90dp kalıyor, yani
/// oyuncu BİR BUÇUK köylü görüyordu. Aynı karede her satır 720dp genişliğinde
/// olup içinde beş kelime taşıyordu: kıt eksen kromaya, bol eksen boşluğa
/// gidiyordu.
///
/// Tahta bunu ters çevirir:
///
///  1. **GEZİNME DİKEY, SOLDA** ([BoardRail]) — bölüm rafı yükseklikten hiç
///     yemez, ucuz olan genişlikten 136dp alır. Yanı sıra sol kenar yatay
///     tutuşta BAŞPARMAĞIN durduğu yerdir; kapatma da oraya iner.
///
///  2. **İÇERİK SÜTUNLARA AYRILIR** ([BoardCol]) — 597dp'lik gövdeye tek
///     sütun akıtmak yerine iki-üç sütun yan yana durur, her biri görünür
///     alanın TAMAMINI kaplar. Aynı piksel bütçesinde 2-3 katı bilgi.
///
///  3. **KAYDIRMA YERİNE SAYFA** ([BoardPager]) — bir bölümün içeriği gerçekten
///     sınırsızsa (nüfus, kronik) dikey kaydırma açmayız; içerik ekrana tam
///     oturan sayfalara bölünür ve oyuncu sayfa çevirir. Kaydırmada ekran
///     hiçbir zaman "tam" değildir, yarım satırlar altta asılı kalır ve nerede
///     olduğun belirsizdir; sayfada her kare kararlı ve eksiksizdir. Üstelik
///     defter metaforuna da bu uyar — defterin sayfası çevrilir.
///
/// Masaüstü bu dosyayı HİÇ görmez; çağrı yerlerinin hepsi
/// [useCompactGameUi] arkasındadır.
abstract final class LedgerBoard {
  /// Sol gezinme rayının genişliği.
  ///
  /// 116 ile başladı, ölçünce yetmedi: telefonda [MobileTextScaler] bütün
  /// yazıyı 11px'e çekiyor (9.5'lik etiket dahil) ve iki haneli rozet 24dp
  /// yiyor — "DİVAN 2" bile "DİVA… 2" olarak kırpılıyordu. Kırpılan gezinme
  /// etiketi en pahalı kırpmadır: oyuncu nereye gittiğini okuyamaz. 136 hem
  /// beş etiketin en uzununu (KRONİK) hem de iki haneli rozeti taşır.
  static const railW = 136.0;

  /// Ray öğesi yüksekliği — 44dp dokunma tabanının üstünde, beş öğe + kimlik
  /// satırı + kapat düğmesi 360dp'lik pencereye sığacak kadar kısa.
  static const railItemH = 46.0;

  /// Tahta gövdesinin kenar boşluğu.
  static const pad = 12.0;

  /// Sütunlar arası ve sütun içi öğeler arası tek boşluk.
  static const gap = 10.0;

  /// Sütun başlığının kapladığı toplam yükseklik (yazı + altındaki boşluk).
  static const headH = 22.0;

  /// Sayfa çubuğunun yüksekliği ([BoardPager] birden fazla sayfa olduğunda).
  static const pagerH = 26.0;
}

// ─── Sol gezinme rayı ────────────────────────────────────────────────────────

/// [BoardRail] öğesi — bir bölüm.
class BoardRailItem {
  /// Emoji künye (bölümün kimliği).
  final String icon;

  /// KISA etiket. Ray dar; "KANUNNAME" değil "KANUN".
  final String label;

  /// Bekleyen iş sayısı (0 = rozet çizilmez).
  final int badge;

  final bool selected;
  final Color color;
  final VoidCallback onTap;

  /// Öğreticinin bu rafı gösterebilmesi için çapa kimliği (bkz. [GuideAnchors]).
  /// null = öğreticinin işi yok. Masaüstü rayı ile telefon rayı AYRI dosyalar;
  /// çapa yalnız birinde olursa öğretici platformların birinde susar.
  final String? guideId;

  const BoardRailItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppUi.accent,
    this.badge = 0,
    this.guideId,
  });
}

/// Dikey bölüm rafı — yönetim ekranının SOL kenarı.
///
/// Üstte kimlik satırı (defterin künyesi), ortada bölümler, altta KAPAT.
/// Kapat en altta çünkü yatay tutuşta sol başparmak oraya düşer; ayrıca
/// "yanlışlıkla kapatma" en pahalı hata olduğu için gezinme öğelerinden
/// mesafeli durur.
class BoardRail extends StatelessWidget {
  /// Kimlik satırı — köyün adı. Yüksekliği [headerH].
  final Widget header;

  final List<BoardRailItem> items;
  final VoidCallback onClose;

  static const headerH = 38.0;

  const BoardRail({
    super.key,
    required this.header,
    required this.items,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: LedgerBoard.railW,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF15181D), AppUi.surface0],
        ),
        border: Border(right: BorderSide(color: AppUi.line)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // Ray SABİT ölçülerle kurulmuştu; 640×360'lık ucuz Android'de pencere
          // 324dp'ye iniyor ve KAPAT düğmesinin tepesi kesiliyordu. Ölçüler
          // artık kalan yerden türer — ama İSTENEN SIRAYLA feda edilir:
          //
          //   1. kimlik satırı kısalır (38 → 30)   — künye, dokunulmaz
          //   2. öğe araları daralır  (4 → 2)      — yalnız nefes
          //   3. EN SON öğe boyu kısalır (46 → 34) — dokunma hedefi burada
          //
          // Böylece dar ekranda 44dp'lik dokunma tabanı olabildiğince korunur:
          // önce süs, sonra hedef gider. Kademelerden İLK SIĞAN seçilir.
          const tiers = [
            (headerH, 6.0, 4.0),
            (30.0, 4.0, 2.0),
            (26.0, 3.0, 1.0),
          ];
          var (head, headGap, gap) = tiers.last;
          for (final t in tiers) {
            final (h, hg, g) = t;
            if (h + hg + items.length * (MobileUi.tap + g) + MobileUi.tap <=
                c.maxHeight) {
              (head, headGap, gap) = t;
              break;
            }
          }
          final fixed = head + headGap + MobileUi.tap + gap * items.length;
          final free = math.max(0.0, c.maxHeight - fixed);
          final itemH = items.isEmpty
              ? 0.0
              : (free / items.length).clamp(34.0, LedgerBoard.railItemH);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: head, child: header),
              SizedBox(height: headGap),
              for (final it in items) ...[
                if (it.guideId != null)
                  GuideTarget(
                    id: it.guideId!,
                    child: _RailButton(item: it, height: itemH),
                  )
                else
                  _RailButton(item: it, height: itemH),
                SizedBox(height: gap),
              ],
              const Spacer(),
              _CloseButton(onTap: onClose),
            ],
          );
        },
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final BoardRailItem item;
  final double height;
  const _RailButton({required this.item, required this.height});

  @override
  Widget build(BuildContext context) {
    final on = item.selected;
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: on
                ? Color.alphaBlend(
                    item.color.withValues(alpha: 0.25),
                    AppUi.surface1,
                  )
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
              color: on
                  ? item.color.withValues(alpha: 0.72)
                  : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 2,
                height: on ? 22 : 8,
                decoration: BoxDecoration(
                  color: on ? item.color : AppUi.line.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: on
                      ? [
                          BoxShadow(
                            color: item.color.withValues(alpha: 0.32),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Opacity(
                opacity: on ? 1 : 0.7,
                child: SemanticIcon(
                  item.icon,
                  size: 14,
                  color: on ? item.color : AppUi.textLo,
                  fallback: GameIconData.scroll,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppUi.label.copyWith(
                    fontSize: 9.5,
                    letterSpacing: 0.9,
                    color: on ? AppUi.textHi : AppUi.textMid,
                  ),
                ),
              ),
              if (item.badge > 0) ...[
                const SizedBox(width: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: on ? 0.95 : 0.62),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '${item.badge}',
                    style: AppUi.number.copyWith(fontSize: 9, color: AppUi.ink),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: MobileUi.tap,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(color: AppUi.line.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const GameIcon(GameIconData.close, size: 14, color: AppUi.textMid),
            const SizedBox(width: 6),
            Text(
              'KAPAT',
              style: AppUi.label.copyWith(fontSize: 9, color: AppUi.textMid),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sütun ───────────────────────────────────────────────────────────────────

/// Tahtanın bir sütunu: isteğe bağlı başlık + görünür alanı DOLDURAN gövde.
///
/// Gövde `Expanded` içinde durur — yani sütun ne kadar yer varsa onu bilir ve
/// içindeki [BoardPager] sayfa başına kaç satır sığdığını buradan hesaplar.
/// Sütunun kendisi ASLA kaydırmaz; taşan içerik sayfalanır ya da kırpılır.
class BoardCol extends StatelessWidget {
  final int flex;
  final String? head;

  /// Başlığın sağ ucuna oturan küçük künye (sayaç, sayfa oku, filtre).
  final Widget? headTrailing;

  final Widget child;

  const BoardCol({
    super.key,
    required this.child,
    this.flex = 1,
    this.head,
    this.headTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (head != null)
            SizedBox(
              height: LedgerBoard.headH,
              child: Row(
                children: [
                  Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppUi.accent.withValues(alpha: 0.72),
                        border: Border.all(
                          color: AppUi.accentSoft.withValues(alpha: 0.42),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    head!,
                    style: AppUi.label.copyWith(
                      fontSize: 9,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 1, color: AppUi.line)),
                  if (headTrailing != null) ...[
                    const SizedBox(width: 8),
                    headTrailing!,
                  ],
                ],
              ),
            ),
          Expanded(child: ClipRect(child: child)),
        ],
      ),
    );
  }
}

/// Sütunları yan yana dizen tahta gövdesi.
class BoardRow extends StatelessWidget {
  final List<Widget> children;
  const BoardRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: LedgerBoard.gap),
          children[i],
        ],
      ],
    );
  }
}

// ─── Sayfalayıcı ─────────────────────────────────────────────────────────────

/// Dikey kaydırma YERİNE yatay sayfa.
///
/// Verilen alana kaç satır sığdığını ölçer, öğeleri o boyda sayfalara böler ve
/// bir sayfayı bütün olarak çizer. Yarım satır yoktur, "aşağıda daha var mı?"
/// belirsizliği yoktur; altta `‹ 2/3 ›` künyesi durur ve parmakla yatay
/// sürüklemek de sayfayı çevirir.
///
/// [rowH] sabit verilmelidir: sayfa başına satır sayısı ondan türer. Değişken
/// boylu içerik sayfalanamaz — sayfalanabilir olmak için satırın boyu bilinmeli.
class BoardPager extends StatefulWidget {
  final int count;

  /// Tek satırın yüksekliği (aradaki boşluk hariç).
  final double rowH;

  /// Yan yana kaç öğe. 1 = tek sütun liste, 2-3 = ızgara.
  final int columns;

  final double rowGap;
  final double colGap;

  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Hiç öğe yoksa yazılacak cümle.
  final String? emptyText;

  const BoardPager({
    super.key,
    required this.count,
    required this.rowH,
    required this.itemBuilder,
    this.columns = 1,
    this.rowGap = 6,
    this.colGap = LedgerBoard.gap,
    this.emptyText,
  });

  @override
  State<BoardPager> createState() => _BoardPagerState();
}

class _BoardPagerState extends State<BoardPager> {
  int _page = 0;

  @override
  void didUpdateWidget(BoardPager old) {
    super.didUpdateWidget(old);
    // Liste kısalırsa (ör. sıralama değişti, köylü öldü) son sayfada asılı
    // kalma — sahne her tick rebuild ediyor, sessizce boş sayfa göstermek
    // "defter bozuldu" gibi okunuyor.
    if (widget.count != old.count) _page = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count == 0) {
      return Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            widget.emptyText ?? '—',
            style: AppUi.body.copyWith(fontSize: 11.5, color: AppUi.textLo),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        // Sayfa çubuğu yalnız GEREKİYORSA yer kaplar. Önce çubuksuz ölç: her
        // şey sığıyorsa çubuk hiç çizilmez ve o 26dp içeriğe kalır.
        int rowsIn(double h) => math.max(
          1,
          ((h + widget.rowGap) / (widget.rowH + widget.rowGap)).floor(),
        );

        var rows = rowsIn(c.maxHeight);
        var pages = (widget.count / (rows * widget.columns)).ceil();
        if (pages > 1) {
          rows = rowsIn(c.maxHeight - LedgerBoard.pagerH);
          pages = (widget.count / (rows * widget.columns)).ceil();
        }
        final perPage = rows * widget.columns;
        final page = _page.clamp(0, pages - 1);
        if (page != _page) {
          // clamp yalnız bu karede geçerli; state'i bir sonraki karede düzelt.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _page != page) setState(() => _page = page);
          });
        }
        final start = page * perPage;
        final grid = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int r = 0; r < rows; r++) ...[
              if (r > 0) SizedBox(height: widget.rowGap),
              SizedBox(
                height: widget.rowH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int col = 0; col < widget.columns; col++) ...[
                      if (col > 0) SizedBox(width: widget.colGap),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final i = start + r * widget.columns + col;
                            if (i >= widget.count) return const SizedBox();
                            return widget.itemBuilder(context, i);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );

        if (pages <= 1) return grid;
        return GestureDetector(
          // Sayfayı parmakla da çevir. Dikey sürüklemeyi TUTMAZ: altındaki
          // dünya/panel dikey jestlerini kendi işine kullanmaya devam etsin.
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() < 120) return;
            setState(() {
              _page = (v < 0 ? page + 1 : page - 1).clamp(0, pages - 1);
            });
          },
          behavior: HitTestBehavior.translucent,
          child: Column(
            children: [
              Expanded(child: grid),
              SizedBox(
                height: LedgerBoard.pagerH,
                child: _PageBar(
                  page: page,
                  pages: pages,
                  onGo: (p) => setState(() => _page = p),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PageBar extends StatelessWidget {
  final int page, pages;
  final void Function(int) onGo;
  const _PageBar({required this.page, required this.pages, required this.onGo});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _arrow(false, page > 0, () => onGo(page - 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '${page + 1} / $pages',
            style: AppUi.number.copyWith(fontSize: 10.5, color: AppUi.textMid),
          ),
        ),
        _arrow(true, page < pages - 1, () => onGo(page + 1)),
      ],
    );
  }

  Widget _arrow(bool forward, bool on, VoidCallback tap) {
    // Çubuk 26dp yüksek ama dokunma hedefi 44dp olmalı (Apple HIG). [OverflowBox]
    // hedefin YERLEŞİMİ 26dp kalırken GERÇEK kutusunu 44dp'ye açar: ok bölgesinin
    // üstünde çizilen bir şey olmadığı için taşan alan kimseyle çakışmaz.
    return SizedBox(
      width: MobileUi.tap,
      height: LedgerBoard.pagerH,
      child: OverflowBox(
        minHeight: 0,
        maxHeight: MobileUi.tap,
        child: GestureDetector(
          onTap: on ? tap : null,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: MobileUi.tap,
            height: MobileUi.tap,
            child: Center(
              child: Transform.rotate(
                angle: forward ? 0 : math.pi,
                child: GameIcon(
                  GameIconData.chevron,
                  size: 14,
                  color: on
                      ? AppUi.accentSoft
                      : AppUi.textLo.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Küçük yapı taşları ──────────────────────────────────────────────────────

/// Tahta yüzeyi — sütun içindeki tek kart. Tek reçete: aynı zemin, aynı çeper,
/// aynı yarıçap (bkz. [MobileSurface]'in kroma için yaptığı, bunun içerik için).
class BoardTile extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// Sol kenara çizilen 3dp'lik ton şeridi (mesele rengi, hane rengi…).
  final Color? edge;

  /// Kartı hafifçe boyar — "bu satır seni bekliyor".
  final Color? tint;

  final bool highlight;

  const BoardTile({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(9, 6, 9, 6),
    this.onTap,
    this.edge,
    this.tint,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final base = tint == null
        ? const Color(0xFF0D1211)
        : Color.alphaBlend(
            tint!.withValues(alpha: 0.12),
            const Color(0xFF0D1211),
          );
    final body = ClipRRect(
      borderRadius: BorderRadius.circular(AppUi.radiusSm),
      child: Stack(
        children: [
          Container(
            padding: padding.add(EdgeInsets.only(left: edge == null ? 0 : 4)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(Colors.white.withValues(alpha: 0.025), base),
                  base,
                ],
              ),
              borderRadius: BorderRadius.circular(AppUi.radiusSm),
              border: Border.all(
                color: highlight
                    ? AppUi.accent.withValues(alpha: 0.5)
                    : edge != null || onTap != null
                    ? (edge ?? tint ?? AppUi.line).withValues(alpha: 0.32)
                    : AppUi.line.withValues(alpha: 0.34),
                width: highlight ? 1.2 : 0.7,
              ),
            ),
            child: child,
          ),
          if (edge != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 3, color: edge),
            ),
          Positioned(
            left: edge == null ? 8 : 12,
            right: 8,
            top: 0,
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.035),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(cursor: SystemMouseCursors.click, child: body),
    );
  }
}

/// İnce ölçü çubuğu — tahtada her yerde aynı 4dp'lik çubuk.
class BoardBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const BoardBar(this.value, this.color, {super.key, this.height = 4});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.03, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.72),
                    Color.lerp(color, Colors.white, 0.22)!,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sütun başlığının sağ ucuna oturan sayaç künyesi.
class BoardCount extends StatelessWidget {
  final String text;
  final Color? color;
  const BoardCount(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppUi.number.copyWith(fontSize: 10, color: color ?? AppUi.textLo),
  );
}
