part of 'main_menu_screen.dart';

// ANA MENÜ — şafakta uyanan köy.
//
// Arka plan bilerek sabittir. Önceki sürüm aynı yüksek çözünürlüklü WebP'yi
// ikinci kez tam ekran çizip anti-alias'lı ClipPath içinde her kare kaydırıyor,
// üstüne tam ekran parçacık painter'ı çalıştırıyordu. Tam ekranda maliyet piksel
// alanıyla büyüyordu. Yeni key art atmosferi kendi içinde taşıyor; tek decode,
// tek resim katmanı ve iki ucuz statik okunabilirlik gradyanı yeterli.
class _MenuDawnBackground extends StatelessWidget {
  final bool touch;
  final bool wideMobile;

  const _MenuDawnBackground({required this.touch, required this.wideMobile});

  @override
  Widget build(BuildContext context) {
    final asset = wideMobile
        ? 'assets/ui/menu_dawn_v2_mobile.webp'
        : 'assets/ui/menu_dawn_v2_desktop.webp';

    return Positioned.fill(
      child: RepaintBoundary(
        child: IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                asset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: touch
                        ? const [
                            Color(0x26101A1D),
                            Color(0x10101A1D),
                            Color(0x00101A1D),
                          ]
                        : const [
                            Color(0x96101619),
                            Color(0x70101619),
                            Color(0x2E10181B),
                            Color(0x0010181B),
                          ],
                    stops: touch
                        ? const [0.0, 0.52, 1.0]
                        : const [0.0, 0.25, 0.48, 0.72],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: touch
                        ? const [
                            Color(0x4D0A1117),
                            Color(0x0010181B),
                            Color(0x8F0B1115),
                          ]
                        : const [
                            Color(0x220A1117),
                            Color(0x0010181B),
                            Color(0x4A0B1115),
                          ],
                    stops: const [0.0, 0.5, 1.0],
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
