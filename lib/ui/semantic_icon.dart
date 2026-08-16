import 'package:flutter/material.dart';

import 'app_ui.dart';

/// Oyun verisinde yıllardır duran emoji işaretlerini arayüzdeki tek ikon
/// diline çevirir. Veri metin olarak kalır; yüzeyler artık platforma göre
/// değişen renkli emoji yerine Phosphor çizimlerini gösterir.
class SemanticIcon extends StatelessWidget {
  const SemanticIcon(
    this.token, {
    super.key,
    this.size = 16,
    this.color,
    this.fallback = GameIconData.star,
    this.label,
  });

  final String token;
  final double size;
  final Color? color;
  final GameIconData fallback;
  final String? label;

  static GameIconData dataFor(
    String token, {
    GameIconData fallback = GameIconData.star,
  }) {
    return switch (token.trim()) {
      '🔥' => GameIconData.flame,
      '🌾' || '🥕' || '🍞' || '🥣' => GameIconData.wheat,
      '🪵' => GameIconData.wood,
      '🪨' => GameIconData.stone,
      '⛏' || '⛏️' || '⚙' || '⚙️' => GameIconData.pickaxe,
      '♦' || '💎' => GameIconData.coal,
      '💧' || '🌊' => GameIconData.drop,
      '🍯' || '🐝' => GameIconData.honey,
      '🪙' || '💰' || '💸' => GameIconData.coin,
      '🪓' => GameIconData.axe,
      '🔨' || '⚒' || '⚒️' || '🏗' => GameIconData.hammer,
      '🐟' || '🎣' => GameIconData.fish,
      '☀' || '☀️' => GameIconData.sun,
      '🌙' || '🌘' || '🌑' => GameIconData.moon,
      '🌅' || '🌄' => GameIconData.dawn,
      '🌧' || '🌧️' || '☔' => GameIconData.rain,
      '⛈' || '⛈️' || '🌩' || '🌩️' => GameIconData.storm,
      '❄' || '❄️' => GameIconData.snow,
      '🏠' || '🏡' || '🏚' || '🏘' || '⛺' => GameIconData.home,
      '👥' || '👪' || '🧑‍🤝‍🧑' || '👶' || '🧑' => GameIconData.people,
      '⛪' || '🙏' || '🕯' || '🕯️' => GameIconData.church,
      '🐄' || '🐑' || '🐐' => GameIconData.herd,
      '🌷' || '🌸' || '💐' => GameIconData.flower,
      '🌿' || '🌱' || '🌲' || '🌳' => GameIconData.reed,
      '🏛' || '🏰' => GameIconData.bank,
      '🛒' || '🏪' => GameIconData.market,
      '📦' => GameIconData.warehouse,
      '🛣' || '🛣️' || '🗺' || '🗺️' => GameIconData.map,
      '📜' || '📖' || '📚' || '✍' || '✍️' => GameIconData.scroll,
      '⚖' || '⚖️' => GameIconData.scales,
      '👑' => GameIconData.crown,
      '🤝' || '👋' => GameIconData.handshake,
      '💗' || '💝' || '💞' || '🩸' || '😊' => GameIconData.heart,
      '🎲' || '🎯' || '🎪' => GameIconData.dice,
      '⚔' || '⚔️' || '🗡' || '🏹' => GameIconData.bow,
      '⚡' || '💥' || '💣' => GameIconData.bolt,
      '🚪' || '🚷' || '🔒' || '🔓' => GameIconData.door,
      '👁' || '👁️' => GameIconData.eye,
      '🎉' || '🎊' || '🏆' || '🎁' => GameIconData.festival,
      '👉' || '➜' || '→' => GameIconData.chevron,
      '⚠' || '⚠️' || '❗' || '❕' => GameIconData.flame,
      _ => fallback,
    };
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: ExcludeSemantics(
          child: GameIcon(
            dataFor(token, fallback: fallback),
            size: size,
            color: color ?? AppUi.textMid,
          ),
        ),
      );
}
