part of '../main.dart';

/// SAHNE ARAYÜZÜ — bildirim, dev günlüğü, imparatorluk uyarısı, ipucu şeridi.
///
/// scene_ui.dart 2245 satırdı; tek uzantı üç parçaya bölündü. Uzantı adı
/// farklı ama hedef aynı ([_VillageSceneState]) — çağıranlar için hiçbir
/// şey değişmez, metotlar aynen taşındı.
extension _SceneUiOverlays on _VillageSceneState {
  Widget buildImperialClashOverlay() => ListenableBuilder(
    listenable: _frame,
    builder: (_, _) => Positioned(
      top: useCompactGameUi(context) ? 54 : 84,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: AppReveal(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xE6121820),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppUi.accent.withValues(alpha: 0.7)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/combat/combat_badge.png',
                    width: 30,
                    height: 30,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SAVUNMA KARŞILIK VERİYOR',
                    style: AppUi.label.copyWith(
                      color: AppUi.accent,
                      fontSize: 10,
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

  Widget buildNotificationToast() {
    // Sabit `top: 70` masaüstü varsayımıydı. iPhone 11'de (414dp yükseklik) o
    // hat tam olarak Köy Defteri'nin SEKME şeridine denk geliyor ve bildirim
    // TÜZÜK sekmesinin üstüne oturuyordu — geçici bir bildirim, kalıcı bir
    // gezinme öğesini örtmemeli. Telefonda toast alta iner (komuta çubuğunun
    // üstüne): orada yalnız içeriğin üstünden geçer, hiçbir kontrolü kapatmaz.
    final compact = useCompactGameUi(context);
    final toast = Center(
      child: AppReveal(
        child: AppChip(label: _notification!, color: AppUi.accent, solid: true),
      ),
    );
    if (!compact) {
      return Positioned(top: 70, left: 0, right: 0, child: toast);
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: MobileUi.bottom(context) + MobileUi.actionH + MobileUi.gap,
      child: toast,
    );
  }

  // ── Dev olay günlüğü konsolu ────────────────────────────────────────────────
  // Sol-altta yarı saydam, salt-okunur konsol: en yeni satır üstte ve parlak,
  // eskiler kademeli soluk. IgnorePointer → dokunuşları geçirir (oyun altında
  // tıklanabilir). Yalnız _devLogOn açıkken ve satır varken Stack'e eklenir.
  Widget buildDevLogConsole() {
    return Positioned(
      left: 12,
      bottom: 92,
      child: IgnorePointer(
        child: Container(
          width: 276,
          padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
          decoration: BoxDecoration(
            color: const Color(0xE60C1014),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎲', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 6),
                  Text(
                    'OLAY GÜNLÜĞÜ',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: Colors.white.withValues(alpha: 0.42),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_devLog.length}',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Colors.white.withValues(alpha: 0.30),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (int i = 0; i < _devLog.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Opacity(
                    opacity: (1.0 - i * 0.055).clamp(0.32, 1.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4, right: 7),
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: _devLog[i].color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                if (_devLog[i].tag.isNotEmpty)
                                  TextSpan(
                                    text: '${_devLog[i].tag} ',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                TextSpan(text: _devLog[i].text),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.25,
                              color: Colors.white.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── İmparatorluk varış anonsu ───────────────────────────────────────────────
  // Kolon yaklaşırken birkaç saniyelik gergin, tam-ekran "İMPARATORLUK GELİYOR".
  // Sim'i DURDURMAZ (IgnorePointer → oyuncu kolonu görür, pan yapabilir). Giriş:
  // letterbox açılır + başlık slam-in (easeOut); çıkış: solar. Kırmızı vignette +
  // nabızlı kızıl glow = tehdit tonu. Cinzel oyma-kapital başlık.
  // TUZAK: bu anons dış widget ağacında duruyor ama o ağaç her frame rebuild
  // OLMUYOR (perf: sadece _frame/_hudFrame'e bağlı leaf'ler repaint eder).
  // ListenableBuilder olmadan intro fade/slam-in tek bir yarı-saydam karede
  // donuyordu ve ancak oyuncu tıklayınca (setState) "netleşiyordu".
  Widget buildImperialAlert() => ListenableBuilder(
    listenable: _frame,
    builder: (_, _) => _imperialAlertBody(),
  );

  Widget _imperialAlertBody() {
    const total = _VillageSceneState._kImperialAlertDur;
    if (_imperialAlertLeft <= 0) return const SizedBox.shrink();
    final left = _imperialAlertLeft.clamp(0.0, total);
    final elapsed = total - left;
    final introT = (elapsed / 0.5).clamp(0.0, 1.0);
    final outT = (left / 1.15).clamp(0.0, 1.0);
    final alpha = introT * outT;
    if (alpha <= 0.004) return const SizedBox.shrink();

    final ease = Curves.easeOutCubic.transform(introT);
    final scale = 1.0 + (1.0 - ease) * 0.13; // 1.13 → 1.0 slam-in
    final pulse = 0.5 + 0.5 * sin(_time * 3.4);
    final barH = 76.0 * ease;
    final w = _viewSize.width <= 0 ? 900.0 : _viewSize.width;
    final big = (w * 0.088).clamp(40.0, 96.0);
    final topSize = big * 0.60;

    const bone = Color(0xFFF0EEE9);
    const blood = Color(0xFFC9351F);

    Widget bar(bool isTop) => Container(
      height: barH,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isTop ? Alignment.topCenter : Alignment.bottomCenter,
          end: isTop ? Alignment.bottomCenter : Alignment.topCenter,
          colors: const [Color(0xF2090607), Color(0x00090607)],
        ),
        border: Border(
          top: isTop
              ? BorderSide.none
              : BorderSide(color: blood.withValues(alpha: 0.45), width: 1.2),
          bottom: isTop
              ? BorderSide(color: blood.withValues(alpha: 0.45), width: 1.2)
              : BorderSide.none,
        ),
      ),
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: alpha.clamp(0.0, 1.0),
          child: Stack(
            children: [
              // Kanlı vignette — TÜM ekranı bastır (HUD panelleri de dahil geri
              // çekilsin), kenarlara doğru neredeyse siyaha git.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.18,
                    colors: [
                      Color(0x9E0B0605),
                      Color(0xCC240808),
                      Color(0xF5120402),
                    ],
                    stops: [0.0, 0.68, 1.0],
                  ),
                ),
                child: SizedBox.expand(),
              ),
              // Sinematik letterbox — üst/alt.
              Positioned(top: 0, left: 0, right: 0, child: bar(true)),
              Positioned(bottom: 0, left: 0, right: 0, child: bar(false)),
              // Okunabilirlik perdesi — radial vignette merkezi ŞEFFAF; parlak
              // gündüz köyü üstünde başlık kaybolmasın diye yalnız merkez metin
              // bloğunun arkasını yumuşakça karartır (kenarlarda tamamen erir).
              const Center(
                child: FractionallySizedBox(
                  widthFactor: 0.92,
                  heightFactor: 0.62,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.72,
                        colors: [
                          Color(0xCF0B0605),
                          Color(0x780B0605),
                          Color(0x000B0605),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              // Merkez başlık bloğu.
              Center(
                child: Transform.scale(
                  scale: scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: Text(
                          '⚔   D I Ş   G Ü Ç',
                          style: AppUi.label.copyWith(
                            color: blood.withValues(alpha: 0.75 + 0.25 * pulse),
                            letterSpacing: 5,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // letterSpacing son harfin SAĞINA da boşluk koyar →
                      // ortalama sola kayar; eşit padding ile telafi et.
                      Padding(
                        padding: EdgeInsets.only(left: topSize * 0.05),
                        child: Text(
                          'İMPARATORLUK',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            fontWeight: FontWeight.w700,
                            fontSize: topSize,
                            height: 1.0,
                            letterSpacing: topSize * 0.05,
                            color: bone,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 16),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: big * 0.08),
                        child: Text(
                          'GELİYOR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            fontWeight: FontWeight.w900,
                            fontSize: big,
                            height: 1.06,
                            letterSpacing: big * 0.08,
                            color: blood,
                            shadows: [
                              Shadow(
                                color: blood.withValues(
                                  alpha: 0.35 + 0.35 * pulse,
                                ),
                                blurRadius: 38,
                              ),
                              const Shadow(
                                color: Colors.black54,
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Kan-kırmızı hat + elmas.
                      SizedBox(
                        width: 244,
                        height: 10,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 1.5,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    blood.withValues(alpha: 0),
                                    blood.withValues(alpha: 0.85),
                                    blood.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                            Transform.rotate(
                              angle: 0.7853981634,
                              child: Container(
                                width: 7,
                                height: 7,
                                color: blood,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 470),
                        child: Text(
                          _imperialAlertSub,
                          textAlign: TextAlign.center,
                          style: AppUi.body.copyWith(
                            color: bone.withValues(alpha: 0.86),
                            fontSize: 13.5,
                            height: 1.5,
                            shadows: const [
                              Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Yerleştirme/seçim modu ipucu ────────────────────────────────────────────

  Widget buildHintRibbon() {
    return Positioned(
      top: 52,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          color: _mineMode
              ? const Color(0xEE0A0A2A)
              : _lumberMode
              ? const Color(0xEE2A1A00)
              : _roadMode
              ? const Color(0xEE2A1808)
              : const Color(0xEE1A3A1A),
          child: Text(
            _mineMode
                ? 'Madenci — sürükle seç, madenleri işaretle'
                : _lumberMode
                ? 'Oduncu — sürükle seç, bırak ağaçları işaretle'
                : _farmMode
                ? 'Tarla — sürükle seç, bırak onayla'
                : _roadMode
                ? _roadHint()
                : '${kBuildingMeta[_placing!]!.label} — tıkla (basılı tut: çoklu)',
            style: TextStyle(
              color: _mineMode
                  ? const Color(0xFFAABBFF)
                  : _lumberMode
                  ? const Color(0xFFFFAA44)
                  : _roadMode
                  ? const Color(0xFFDDB880)
                  : const Color(0xFF88FF88),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  /// Yol modu ipucu — sürükleme sırasında CANLI bilanço: kaç tile döşenecek,
  /// neye mal olacak. Oyuncu bırakmadan önce ne alacağını bilir; "yanlışlıkla
  /// yol döşedim" için yer kalmaz.
  String _roadHint() {
    if (_roadPreview.isEmpty) {
      return _roadErase
          ? 'Yol Silgisi — sürükle, bırak kaldır'
          : '${_placingRoad!.label} — sürükle, bırak döşe (dik güzergâh)';
    }
    final ok = _roadPreview.where((e) => e.$2).length;
    if (_roadErase) {
      return ok == 0
          ? 'Yol Silgisi — güzergâhta yol yok'
          : 'Yol Silgisi — $ok tile kaldırılacak (bırak onayla)';
    }
    if (ok == 0) return '${_placingRoad!.label} — güzergâh uygun değil';
    final bill = [
      for (final (kind, amt) in _placingRoad!.cost.entries)
        '${amt * ok} ${kind.icon}',
    ].join(' ');
    return '${_placingRoad!.label} — $ok tile · '
        '${bill.isEmpty ? 'bedava' : bill} (bırak onayla)';
  }

  /// Bir köylünün ev kademesi → Nüfus Defteri etiketi + sıralama katı.
  /// tier: 0 evsiz · 1 çadır · 2 ahşap · 3 taş · 4 konak.
  (String, int) _housingInfo(VillagerEntity v) {
    final home = v.homeBuilding;
    if (home == null) return ('Evsiz', 0);
    switch ((home as BuildingEntity).type) {
      case BuildingType.manor:
        return ('Konak', 4);
      case BuildingType.stoneHouseBlue:
      case BuildingType.stoneHouseGreen:
        return ('Taş Ev', 3);
      case BuildingType.woodenHouse:
        return ('Ahşap Ev', 2);
      case BuildingType.tent:
        return ('Çadır', 1);
      default:
        return ('Barınak', 2);
    }
  }
}
