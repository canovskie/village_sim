import 'package:flutter/material.dart';
import 'app_ui.dart';
import 'mobile_ui.dart';
import 'settings_model.dart';

/// Ses, görüntü ve dil seçeneklerini sunan modern koyu ayar ekranı.
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
    // Telefon YATAY: ekran geniş ama ALÇAK (iPhone 11 → 896×414). Tek sütunluk
    // 460dp'lik masaüstü levhası buraya sığmıyordu — gövde 155px taşıp DİL
    // bölümünü ve alttaki düğmeleri tamamen erişilemez bırakıyordu. İki cevap
    // birlikte: gövde KAYAR (hangi yükseklikte olursa olsun taşma yok) ve
    // alçak ekranda İKİ SÜTUNA açılır (boşta duran genişliği kullanır, böylece
    // kaydırmaya hiç gerek kalmaz).
    final compact = useCompactGameUi(context);
    final mobileWindow = compact
        ? MobileUi.windowSize(context, maxWidth: 720)
        : null;
    return Scaffold(
      backgroundColor: AppUi.scrim,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 720 : 460),
            child: Padding(
              padding: EdgeInsets.all(compact ? MobileUi.gutter : 20),
              child: AppReveal(
                child: SizedBox(
                  width: mobileWindow?.width,
                  height: mobileWindow?.height,
                  child: AppPanel(
                    accent: AppUi.accent,
                    padding: EdgeInsets.fromLTRB(
                      compact ? 14 : 18,
                      compact ? 11 : 16,
                      compact ? 14 : 18,
                      compact ? 12 : 18,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            GameIcon(
                              GameIconData.gear,
                              size: 18,
                              color: AppUi.accent,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text('AYARLAR', style: AppUi.title),
                            ),
                            AppIconButton(
                              icon: GameIconData.close,
                              size: 32,
                              onTap: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        const AppDivider(),
                        Flexible(
                          child: SingleChildScrollView(
                            child: compact
                                ? _twoColumnBody()
                                : _singleColumnBody(),
                          ),
                        ),
                        SizedBox(height: compact ? 8 : 16),
                        const AppDivider(),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: 'SIFIRLA',
                                kind: AppButtonKind.ghost,
                                expand: true,
                                onTap: _model.resetToDefaults,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: AppButton(
                                label: 'GERİ',
                                kind: AppButtonKind.filled,
                                icon: GameIconData.chevron,
                                expand: true,
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
        ),
      ),
    );
  }

  /// Alçak ekran: SES solda, GÖRÜNTÜ + DİL sağda — hiçbiri fold altında kalmaz.
  Widget _twoColumnBody() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: _soundSection(),
        ),
      ),
      const SizedBox(width: 20),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._displaySection(),
            const SizedBox(height: 12),
            ..._languageSection(),
          ],
        ),
      ),
    ],
  );

  Widget _singleColumnBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      ..._soundSection(),
      const SizedBox(height: 12),
      ..._displaySection(),
      const SizedBox(height: 12),
      ..._languageSection(),
    ],
  );

  List<Widget> _soundSection() => [
    const AppSectionLabel('SES'),
    _Slider(
      label: 'Müzik',
      value: _model.musicVolume,
      onChanged: (v) => _model.musicVolume = v,
    ),
    // ORTAM ayrı bir kaydırıcı: eskiden kuş/cırcır/yağmur döngüleri
    // "Müzik"e bağlıydı, yani etiket yalan söylüyordu. Köyün doğa sesini
    // kısmak isteyip müziği bırakmak (ya da tersi) artık mümkün.
    _Slider(
      label: 'Ortam',
      value: _model.ambientVolume,
      onChanged: (v) => _model.ambientVolume = v,
    ),
    _Slider(
      label: 'Efekt',
      value: _model.sfxVolume,
      onChanged: (v) => _model.sfxVolume = v,
    ),
  ];

  List<Widget> _displaySection() => [
    const AppSectionLabel('GÖRÜNTÜ'),
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
  ];

  List<Widget> _languageSection() => [
    const AppSectionLabel('DİL'),
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
          if (lang != AppLanguage.values.last) const SizedBox(width: 8),
        ],
      ],
    ),
  ];
}

// ── Yardımcı widget'lar ─────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: AppUi.body)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: AppUi.accent,
                inactiveTrackColor: AppUi.surface3,
                thumbColor: AppUi.accentSoft,
                overlayColor: AppUi.accent.withValues(alpha: 0.18),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(value: value, onChanged: onChanged),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: AppUi.number.copyWith(fontSize: 12, color: AppUi.accent),
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppUi.body)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 50,
              height: 26,
              decoration: BoxDecoration(
                color: value
                    ? Color.alphaBlend(
                        AppUi.accent.withValues(alpha: 0.28),
                        AppUi.surface2,
                      )
                    : AppUi.surface0,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: value ? AppUi.accent : AppUi.line,
                  width: 1.2,
                ),
                boxShadow: value
                    ? [
                        BoxShadow(
                          color: AppUi.accent.withValues(alpha: 0.35),
                          blurRadius: 9,
                        ),
                      ]
                    : null,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value ? AppUi.accentSoft : AppUi.textLo,
                    ),
                  ),
                ),
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
    final tint = AppUi.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(tint.withValues(alpha: 0.16), AppUi.surface1)
              : AppUi.surface1,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(
            color: selected ? tint : AppUi.line,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: tint.withValues(alpha: 0.3), blurRadius: 9)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              language.code,
              style: AppUi.button.copyWith(
                fontSize: 13,
                letterSpacing: 1.5,
                color: selected ? AppUi.textHi : AppUi.textMid,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              language.label,
              style: AppUi.body.copyWith(
                fontSize: 9.5,
                color: selected ? AppUi.textMid : AppUi.textLo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
