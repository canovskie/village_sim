import 'package:flutter/material.dart';
import 'app_ui.dart';
import 'mobile_ui.dart';

/// Oyun hakkında bilgi, sürüm ve kontroller listesini gösteren panel.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = '0.1.0 — alpha';

  static const _credits = [
    ('Oyun Tasarımı', 'Can Kaynar'),
    ('Programlama', 'Can Kaynar + Claude'),
    ('Pixel Art', 'Can Kaynar'),
    ('Müzik / SFX', 'Ortam & efekt sesleri'),
  ];

  static const _controls = [
    ('🖱  Sürükle', 'Haritayı kaydır'),
    ('🖱  Tekerlek', 'Yakınlaş / uzaklaş'),
    ('🖱  Tık', 'Bina seç / yerleştir'),
    ('🌾  Tarla modu', 'Sürükleyerek tarla seç'),
    ('🪓  Kes modu', 'Sürükleyerek ağaç işaretle'),
    ('⛏  Kaz modu', 'Sürükleyerek maden işaretle'),
    ('⚡  GOD', 'Sınırsız altın + anlık inşa'),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = useCompactGameUi(context);
    if (compact) return _compact(context);
    return Scaffold(
      backgroundColor: AppUi.surface0,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: AppReveal(
                child: AppPanel(
                  accent: AppUi.accent,
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: Text('HAKKINDA', style: AppUi.title)),
                      const SizedBox(height: 18),

                      // Çıplak duran tek yer burası → kor halesi AÇIK (madalyon
                      // yok). Hale kutuyu 1.5× büyüttüğü için glif 72→60.
                      const Center(child: GameLogo(size: 60, glow: true)),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'LUW',
                          style: AppUi.display.copyWith(
                            fontSize: 26,
                            color: AppUi.accentSoft,
                            letterSpacing: 8.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          _version,
                          style: AppUi.label.copyWith(letterSpacing: 1.6),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Text(
                          'Küçük bir köyü ateşten başlatıp\nbüyüten bir piksel simülasyonu.',
                          textAlign: TextAlign.center,
                          style: AppUi.body.copyWith(height: 1.5),
                        ),
                      ),

                      const SizedBox(height: 18),
                      const AppSectionLabel('Kontroller'),
                      const SizedBox(height: 2),
                      for (final (key, desc) in _controls)
                        _Row(left: key, right: desc),

                      const SizedBox(height: 14),
                      const AppSectionLabel('Krediler'),
                      const SizedBox(height: 2),
                      for (final (role, name) in _credits)
                        _Row(left: role, right: name),

                      const SizedBox(height: 20),
                      AppButton(
                        label: 'GERİ',
                        icon: GameIconData.chevron,
                        kind: AppButtonKind.filled,
                        expand: true,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// iPhone 11 yatay: kimlik solda, kontroller ve krediler sağda. Masaüstünün
  /// uzun tek sütununu telefona küçültmek yerine yatay alanı kullanır; pencere
  /// 360pt yüksekliği geçmez ve kapatma düğmesi başlıkta hep erişilebilirdir.
  Widget _compact(BuildContext context) {
    final window = MobileUi.windowSize(context, maxWidth: 720);
    return Scaffold(
      backgroundColor: AppUi.scrim,
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: window.width,
            height: window.height,
            child: AppReveal(
              child: AppPanel(
                accent: AppUi.accent,
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('HAKKINDA', style: AppUi.title),
                        ),
                        AppIconButton(
                          icon: GameIconData.close,
                          size: 32,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 3, child: _compactIdentity()),
                          const SizedBox(width: 14),
                          Container(width: 1, color: AppUi.line),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _compactControls()),
                                  const SizedBox(width: 14),
                                  Expanded(child: _compactCredits()),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactIdentity() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const GameLogo(size: 46, glow: true),
      const SizedBox(height: 8),
      Text(
        'LUW',
        style: AppUi.display.copyWith(
          fontSize: 22,
          color: AppUi.accentSoft,
          letterSpacing: 6,
        ),
      ),
      const SizedBox(height: 3),
      Text(_version, style: AppUi.label.copyWith(letterSpacing: 1.2)),
      const SizedBox(height: 10),
      Text(
        'Küçük bir köyü ateşten başlatıp büyüten bir piksel simülasyonu.',
        textAlign: TextAlign.center,
        style: AppUi.body.copyWith(height: 1.35),
      ),
    ],
  );

  Widget _compactControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AppSectionLabel('Kontroller'),
      const SizedBox(height: 3),
      for (final (key, desc) in _controls)
        _Row(left: key, right: desc, compact: true),
    ],
  );

  Widget _compactCredits() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AppSectionLabel('Krediler'),
      const SizedBox(height: 3),
      for (final (role, name) in _credits)
        _Row(left: role, right: name, compact: true),
    ],
  );
}

class _Row extends StatelessWidget {
  final String left;
  final String right;
  final bool compact;
  const _Row({required this.left, required this.right, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: compact ? 86 : 104,
            child: Text(
              left,
              style: AppUi.bodyHi.copyWith(
                fontSize: 11.5,
                color: AppUi.textMid,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              right,
              style: AppUi.body.copyWith(fontSize: 11.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
