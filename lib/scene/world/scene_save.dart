part of '../../main.dart';

/// Tam dünya kayıt/yükleme — köyün TÜM kalıcı state'ini JSON'a çevirir ve
/// kaldığı yerden geri kurar. Köylüler (isim/yaş/aile/moral/görsel kimlik),
/// binalar, kaynaklar, zümreler, dilekçe hafızası, harita, gün/saat dahil.
///
/// Tasarım:
///  - Kimlik yok → referanslar İNDEKS ile çözülür (köylü/bina liste sırası).
///    Yükleme aynı sırada kurar, sonra parents/children/homeBuilding bağlanır.
///  - Geçici state (görev hedefi, path cache, render lerp, anlık duygu/oturma)
///    KAYDEDİLMEZ → yükleme sonrası işçiler hedefi yeniden bulur, cache yeniden
///    türetilir. Görünür sonuç birebir aynı köy, içeride taze AI.
///  - Su tile'ları doğrudan kaydedilir → generator determinizmine bağımlı değil.
extension _SceneSave on _VillageSceneState {
  // ── Yardımcılar ────────────────────────────────────────────────────────────

  int _colInt(Color c) => c.toARGB32();
  Color _colFromInt(int v) => Color(v);

  T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
    if (name is String) {
      for (final v in values) {
        if (v.name == name) return v;
      }
    }
    return fallback;
  }

  double _d(Object? v, [double fb = 0]) => (v as num?)?.toDouble() ?? fb;
  int _i(Object? v, [int fb = 0]) => (v as num?)?.toInt() ?? fb;
  bool _b(Object? v, [bool fb = false]) => (v as bool?) ?? fb;

  // ── NpcVisual ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _visualToJson(NpcVisual v) => {
    'skin': _colInt(v.skin),
    'hair': _colInt(v.hair),
    'hairStyle': v.hairStyle.name,
    'eyes': _colInt(v.eyes),
    'hasBeard': v.hasBeard,
    'beardStyle': v.beardStyle.name,
    'clothingShift': v.clothingShift,
    'blinkPhase': v.blinkPhase,
    'isMale': v.isMale,
    'build': v.build,
  };

  NpcVisual _visualFromJson(Map<String, dynamic> j) => NpcVisual(
    skin: _colFromInt(_i(j['skin'], 0xFFFFCB9A)),
    hair: _colFromInt(_i(j['hair'], 0xFF3E2A14)),
    hairStyle: _enumByName(HairStyle.values, j['hairStyle'], HairStyle.short),
    eyes: _colFromInt(_i(j['eyes'], 0xFF4A381E)),
    hasBeard: _b(j['hasBeard']),
    beardStyle: _enumByName(
      BeardStyle.values,
      j['beardStyle'],
      BeardStyle.none,
    ),
    clothingShift: _d(j['clothingShift']),
    blinkPhase: _d(j['blinkPhase']),
    isMale: _b(j['isMale'], true),
    // Eski kayıtlarda yok → 1.0 (nötr beden), köylü aynı görünmeye devam eder.
    build: j['build'] == null ? 1.0 : _d(j['build']),
  );

  // ── Kayıt tetikleyiciler ────────────────────────────────────────────────────

  /// Gerçek-zaman birikimiyle periyodik otomatik kayıt. _onTick her frame çağırır.
  void _maybeAutoSave(double realDt) {
    _autoSaveAccum += realDt;
    if (_autoSaveAccum >= _VillageSceneState._kAutoSaveInterval) {
      _autoSaveAccum = 0;
      _saveNow();
    }
  }

  /// Mevcut köyü slota yazar (async, fire-and-forget). [manual] true ise
  /// kullanıcıya kısa "Kaydedildi" geri bildirimi gösterir.
  /// [asSlot]/[asName] verilirse kayıt SAHNENİN slotuna değil oraya yazılır.
  /// Godmode'un mevsimlik referans köyleri bunu kullanır: tek oturumda dört
  /// ayrı slot üretilebilsin (sahnenin `_slotId`'si final, değiştirilemez).
  Future<void> _saveNow({
    bool manual = false,
    String? asSlot,
    String? asName,
  }) async {
    final slot = asSlot ?? _slotId;
    if (_saving || slot.isEmpty) return;
    _saving = true;
    try {
      final data = <String, dynamic>{
        'version': SaveManager.schemaVersion,
        'meta': SaveSlotMeta(
          id: slot,
          name: asName ?? _slotName,
          savedAt: DateTime.now(),
          day: _dayCount,
          population: _villagers.length,
          identity: _houses.identityName,
          // Defteri KAPANMIŞ köyün kaydı mühürlü yazılır — bir daha yüklenemez.
          // İki kapanış da buradan geçer: dağılma (kayıp) ve hesaplaşma
          // (berat/sancak/ilhak). Mühür tek yerde basılsın; iki ayrı yol iki
          // ayrı "ended" tanımı demektir ve biri er geç unutulur.
          ended: _collapsed || _reckoningVerdict != null,
          endedReason:
              _reckoningVerdict?.sealReason ??
              (_collapsed
                  ? (_collapseCause == CollapseCause.emptied
                        ? 'Son can da gitti'
                        : 'Köyü döndürecek el kalmadı')
                  : null),
        ).toJson(),
        'world': captureWorld(),
      };
      await SaveManager.instance.writeSlot(slot, data);
      if (manual && mounted) {
        _showNotification('💾 Köy kaydedildi');
      }
    } catch (_) {
      if (manual && mounted) _showNotification('⚠ Kayıt başarısız');
    } finally {
      _saving = false;
    }
  }

  /// Köy dağıldı — kaydı KAPANMIŞ olarak mühürle. Silmez: oyuncunun onlarca
  /// saatlik köyünü oyun kendi eliyle yok etmez; kayıt menüde okunabilir bir
  /// mezar taşı olarak kalır, silmek oyuncunun kararıdır.
  void _sealSaveAsEnded() {
    if (_slotId.isEmpty) return;
    // `_collapsed` zaten true → normal kayıt yolu mührü meta'ya yazar.
    _saveNow();
  }

  /// Sol-alttaki menü kümesi — tek "⚙" tutamağı altında OYUN dışı işler:
  /// menüye dön + kaydet. Köy içi hiçbir şey burada durmaz (hikâye güncesi
  /// buradaydı, Köy Defteri'nin KRONİK bölümüne taşındı: köyün kendisiyle ilgili
  /// her şey tek kapıda). Açılınca öğeler gear'ın ÜSTÜNDE belirir (alttaki inşa
  /// çubuğundan uzakta). Varsayılan kapalı (sade ekran).
  Widget buildSaveButton() {
    // MOBİL: bu küme telefonda ÇİZİLMEZ. Dünyanın ortasında sahipsiz duran bir
    // "⚙ Menü" pill'iydi — beş yuvalı kenar ızgarasının ("Kenar Rayı",
    // ui/core/mobile_ui.dart) hiçbirine ait değildi ve tema hissini en çok bozan tek
    // öğeydi. İçeriği (Kaydet / Ana menü) sağ ray'ın araçlar menüsüne taşındı.
    if (useCompactGameUi(context)) return const SizedBox.shrink();
    // Sol-ÜST (HUD şeridinin altında, Defter mührünün eski yeri) — Komuta
    // çubuğu artık alt kenarı sahiplendi, gear ondan uzağa taşındı. Küme AŞAĞI
    // açılır: gear üstte, öğeler altında.
    return Positioned(
      left: 14,
      top: 56,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gear tutamağı — her zaman görünür; kümeyi aç/kapa.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () =>
                  setStateHere(() => _menuClusterOpen = !_menuClusterOpen),
              child: SizedBox(
                child: Center(
                  child: AppChip(
                    label: _menuClusterOpen ? '⚙ Kapat' : '⚙ Menü',
                    color: AppUi.accent,
                  ),
                ),
              ),
            ),
            if (_menuClusterOpen) ...[
              const SizedBox(height: 10),
              // Ana menüye dönüş — onay ister, onaylanınca kaydedip çıkar.
              MenuButton(
                onTap: () => setStateHere(() => _exitConfirmOpen = true),
              ),
              const SizedBox(height: 10),
              SaveButton(onTap: () => _saveNow(manual: true)),
            ],
          ],
        ),
      ),
    );
  }

  /// Ana menüye dönüş onay modal'ı — yanlışlıkla çıkışı önler. Çıkış
  /// otomatik kaydeder, böylece oyuncu hiçbir ilerleme kaybetmez.
  Widget buildExitConfirm() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setStateHere(() => _exitConfirmOpen = false),
              child: Container(color: const Color(0x99000000)),
            ),
          ),
          Center(
            child: AppPanel(
              width: 320,
              accent: AppUi.accent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ana menüye dön', style: AppUi.title),
                  const SizedBox(height: 8),
                  Text(
                    'Köy otomatik kaydedilecek ve ana menüye döneceksin. '
                    'Kaldığın yerden devam edebilirsin.',
                    style: AppUi.body.copyWith(color: AppUi.textMid),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Vazgeç',
                          kind: AppButtonKind.ghost,
                          onTap: () =>
                              setStateHere(() => _exitConfirmOpen = false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          label: 'Kaydet ve Çık',
                          kind: AppButtonKind.filled,
                          onTap: _exitToMenu,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kaydeder ve ana menüye döner.
  Future<void> _exitToMenu() async {
    setStateHere(() => _exitConfirmOpen = false);
    await _saveNow();
    widget.onExitToMenu?.call();
  }
}
