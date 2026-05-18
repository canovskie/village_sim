import 'package:flutter/material.dart';
import 'game_theme.dart';
import 'settings_model.dart';

/// Ses, görüntü ve dil seçeneklerini sunan ortaçağ stilinde panel.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _model = SettingsModel.instance;

  @override
  void initState() {
    super.initState();
    _model.addListener(_onChange);
  }

  @override
  void dispose() {
    _model.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0703),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
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
                            child: Text('AYARLAR',
                                style: MedievalTheme.titleStyle),
                          ),
                        ),
                        MedievalTheme.rivet(),
                      ],
                    ),
                    MedievalTheme.divider(),
                    const SizedBox(height: 6),

                    _SectionLabel('Ses'),
                    _Slider(
                      label: 'Müzik',
                      value: _model.musicVolume,
                      onChanged: (v) => _model.musicVolume = v,
                    ),
                    _Slider(
                      label: 'Efekt',
                      value: _model.sfxVolume,
                      onChanged: (v) => _model.sfxVolume = v,
                    ),

                    const SizedBox(height: 10),
                    _SectionLabel('Görüntü'),
                    _Toggle(
                      label: 'FPS Göster',
                      value: _model.showFps,
                      onChanged: (v) => _model.showFps = v,
                    ),
                    _Toggle(
                      label: 'Olay Sarsıntısı',
                      value: _model.shakeOnEvents,
                      onChanged: (v) => _model.shakeOnEvents = v,
                    ),

                    const SizedBox(height: 10),
                    _SectionLabel('Dil'),
                    Row(
                      children: [
                        for (final lang in AppLanguage.values) ...[
                          Expanded(
                            child: _LangChip(
                              language: lang,
                              selected: _model.language == lang,
                              onTap: () => _model.language = lang,
                            ),
                          ),
                          if (lang != AppLanguage.values.last)
                            const SizedBox(width: 6),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),
                    MedievalTheme.divider(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            label: 'Varsayılan',
                            accentColor: MedievalTheme.dangerColor,
                            onTap: _model.resetToDefaults,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: _ActionButton(
                            label: 'Geri',
                            accentColor: MedievalTheme.activeBorder,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ],
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

// ── Yardımcı widget'lar ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
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

class _Slider extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _Slider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label, style: MedievalTheme.labelStyle),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: MedievalTheme.activeBorder,
                inactiveTrackColor: MedievalTheme.chipBorder,
                thumbColor: MedievalTheme.textAccent,
                overlayColor: MedievalTheme.activeBorder.withValues(alpha: 0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text('$pct%',
                textAlign: TextAlign.right,
                style: MedievalTheme.smallStyle.copyWith(
                  color: MedievalTheme.textAccent,
                )),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            Expanded(child: Text(label, style: MedievalTheme.labelStyle)),
            Container(
              width: 56, height: 24,
              decoration: MedievalTheme.buttonDecoration(active: value),
              child: Stack(
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(
                        color: value
                            ? MedievalTheme.textAccent
                            : MedievalTheme.textDim,
                        border: Border.all(
                          color: value
                              ? MedievalTheme.activeBorder
                              : MedievalTheme.panelBorder,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;
  const _LangChip({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: MedievalTheme.chipDecoration(selected: selected),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(language.code,
                style: TextStyle(
                  color: selected
                      ? MedievalTheme.textAccent
                      : MedievalTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  letterSpacing: 1.5,
                )),
            const SizedBox(height: 2),
            Text(language.label,
                style: TextStyle(
                  color: selected
                      ? MedievalTheme.textPrimary
                      : MedievalTheme.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                )),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color accentColor;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: MedievalTheme.buttonDecoration(
          active: true,
          accentColor: accentColor,
        ),
        child: Center(
          child: Text(label.toUpperCase(),
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 1.5,
              )),
        ),
      ),
    );
  }
}
