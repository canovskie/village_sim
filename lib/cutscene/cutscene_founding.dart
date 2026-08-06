part of 'cutscene_player.dart';

// SİNEMATİK — kuruluş kararları (fikir çipi, kimlik, mühür düğmesi)
// (Bu dosya cutscene_player.dart bölünürken ayrıldı — sınıflar
//  aynen taşındı, tek satırı değişmedi.)

class _IdeaChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _IdeaChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: MobileUi.tap,
        // widthFactor: çip yalnız yazısı kadar yer kaplar. Kısıtsız bırakılırsa
        // [Center] gelen maxWidth'i doldurur ve Wrap içinde her çip TEK BAŞINA
        // bir satıra oturur (öneri şeridi dikey bir listeye dönüşür).
        child: Center(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AppUi.accent.withValues(alpha: 0.22)
                  : const Color(0x660A0E0C),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? AppUi.accent.withValues(alpha: 0.85)
                    : const Color(0x38FFFFFF),
              ),
            ),
            child: Text(
              label,
              style: AppUi.button.copyWith(
                fontSize: 10.5,
                letterSpacing: 0.6,
                color: selected ? AppUi.accentSoft : AppUi.textMid,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FoundingIdentity extends StatelessWidget {
  final String village;
  final String house;

  const _FoundingIdentity({required this.village, required this.house});

  @override
  Widget build(BuildContext context) {
    // upperTr: `toUpperCase()` Türkçe "i"yi noktasız "I" yapıyordu —
    // "Değirmenli" mührün üstünde "DEĞIRMENLI" diye yazıyordu (bkz. voice.dart).
    final villageName = village.isEmpty ? 'ADSIZ YURT' : upperTr(village);
    final houseName =
        house.isEmpty ? 'KURUCU HANE' : '${upperTr(house)} HANESİ';

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x2EE49139), Color(0x05101412)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: AppUi.accent.withValues(alpha: 0.12),
              border: Border.all(color: AppUi.accent.withValues(alpha: 0.55)),
            ),
            child: const GameIcon(
              GameIconData.home,
              size: 27,
              color: AppUi.accentSoft,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'BURADA KURULDU',
            style: AppUi.label.copyWith(
              color: AppUi.textLo,
              fontSize: 9,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              villageName,
              maxLines: 1,
              style: AppUi.display.copyWith(fontSize: 34, letterSpacing: 2.2),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Container(width: 26, height: 1, color: AppUi.accent),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  houseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppUi.label.copyWith(
                    color: AppUi.accentSoft,
                    fontSize: 9.5,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FoundingSubmitButton extends StatefulWidget {
  final VoidCallback onTap;
  const _FoundingSubmitButton({required this.onTap});

  @override
  State<_FoundingSubmitButton> createState() => _FoundingSubmitButtonState();
}

class _FoundingSubmitButtonState extends State<_FoundingSubmitButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 46,
        transform: _down
            ? Matrix4.translationValues(0, 1.5, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEAA04B), Color(0xFFBC6724)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF0C27B)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4DE49139),
              blurRadius: 16,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const GameIcon(GameIconData.flame, size: 15, color: AppUi.ink),
            const SizedBox(width: 9),
            Text(
              'Adını koy ▸',
              style: AppUi.button.copyWith(
                color: AppUi.ink,
                fontFamily: AppUi.fontDisplay,
                fontSize: 12.5,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kameranın tek karedeki hâli — piksel cinsinden yatay/dikey kayma ve dolly
/// büyütmesi. Katmanlar bunu KENDİ derinlikleriyle ölçekleyerek uygular.
