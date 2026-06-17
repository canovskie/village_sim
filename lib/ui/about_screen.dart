import 'package:flutter/material.dart';
import 'app_ui.dart';

/// Oyun hakkında bilgi, sürüm ve kontroller listesini gösteren panel.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = '0.1.0 — alpha';

  static const _credits = [
    ('Oyun Tasarımı', 'Can Kaynar'),
    ('Programlama',   'Can Kaynar + Claude'),
    ('Pixel Art',     'Can Kaynar'),
    ('Müzik / SFX',   'Henüz yok'),
  ];

  static const _controls = [
    ('🖱  Sürükle',       'Haritayı kaydır'),
    ('🖱  Tekerlek',      'Yakınlaş / uzaklaş'),
    ('🖱  Tık',           'Bina seç / yerleştir'),
    ('🌾  Tarla modu',    'Sürükleyerek tarla seç'),
    ('🪓  Kes modu',      'Sürükleyerek ağaç işaretle'),
    ('⛏  Kaz modu',       'Sürükleyerek maden işaretle'),
    ('⚡  GOD',           'Sınırsız altın + anlık inşa'),
  ];

  @override
  Widget build(BuildContext context) {
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
                      Center(
                        child: Text('HAKKINDA', style: AppUi.title),
                      ),
                      const SizedBox(height: 18),

                      Center(
                        child: GameIcon(GameIconData.flame,
                            size: 38, color: AppUi.accent),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text('VILLAGE SIM',
                            style: AppUi.display.copyWith(
                              fontSize: 26,
                              color: AppUi.accentSoft,
                              letterSpacing: 4.0,
                            )),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(_version,
                            style: AppUi.label.copyWith(letterSpacing: 1.6)),
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
}

class _Row extends StatelessWidget {
  final String left;
  final String right;
  const _Row({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(left,
                style: AppUi.bodyHi.copyWith(
                  fontSize: 11.5,
                  color: AppUi.textMid,
                )),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(right,
                style: AppUi.body.copyWith(fontSize: 11.5, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
