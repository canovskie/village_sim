import 'package:flutter/material.dart';
import 'game_theme.dart';

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
      backgroundColor: const Color(0xFF0D0703),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                decoration: MedievalTheme.panelDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        MedievalTheme.rivet(),
                        const Expanded(
                          child: Center(
                            child: Text('HAKKINDA',
                                style: MedievalTheme.titleStyle),
                          ),
                        ),
                        MedievalTheme.rivet(),
                      ],
                    ),
                    MedievalTheme.divider(),
                    const SizedBox(height: 10),

                    const Center(
                      child: Text('VILLAGE SIM',
                          style: TextStyle(
                            color: MedievalTheme.textAccent,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            letterSpacing: 4.0,
                          )),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text(_version,
                          style: TextStyle(
                            color: MedievalTheme.textSecondary,
                            fontSize: 10,
                            fontFamily: 'monospace',
                            letterSpacing: 1.5,
                          )),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'Küçük bir köyü ateşten başlatıp\nbüyüten bir piksel simülasyonu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: MedievalTheme.textPrimary,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          height: 1.6,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    MedievalTheme.divider(),
                    _SectionLabel('Kontroller'),
                    for (final (key, desc) in _controls)
                      _Row(left: key, right: desc),

                    const SizedBox(height: 12),
                    MedievalTheme.divider(),
                    _SectionLabel('Krediler'),
                    for (final (role, name) in _credits)
                      _Row(left: role, right: name),

                    const SizedBox(height: 16),
                    MedievalTheme.divider(),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: MedievalTheme.buttonDecoration(
                          active: true,
                          accentColor: MedievalTheme.activeBorder,
                        ),
                        child: const Center(
                          child: Text('GERİ',
                              style: TextStyle(
                                color: MedievalTheme.activeBorder,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                letterSpacing: 2.0,
                              )),
                        ),
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
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
            color: MedievalTheme.textAccent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 2.0,
          )),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(left,
                style: const TextStyle(
                  color: MedievalTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                )),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(right,
                style: const TextStyle(
                  color: MedievalTheme.textPrimary,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  height: 1.4,
                )),
          ),
        ],
      ),
    );
  }
}
