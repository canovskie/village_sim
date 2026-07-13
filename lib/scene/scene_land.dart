part of '../main.dart';

/// Arazi / reveal — **ZOOM KISITLAMASI** modeli.
///
/// Reveal artık bir örtü (sis/orman duvarı) DEĞİL, bir KAMERA kısıtı: kamera
/// "reach" tile-kutusunun dışını gösteremez (bkz. scene_input._clampCamera), bu
/// yüzden gerçek harita kenarı asla kadraja girmez ("havada yüzen ada" yok).
/// Dünya, reach büyüdükçe açılır — hiçbir şey çizilmez/gizlenmez.
///
/// Bu dosyada kalan tek iş: reach'in zamanla büyümesi (organik; hikâye beat'leri
/// ileride buradan sıçratacak).
///
/// Eski "vahşi orman / sabah sisi" reveal'ı SÖKÜLDÜ. [_cleared] / [_wilderness] /
/// [_wildTreeTiles] setleri kalıntı olarak duruyor ama HEP BOŞ (placement gate,
/// obstacle, painter guard'ları boş-guard'la kendiliğinden devre dışı) — tam
/// alan temizliği ayrı bir refactor.
///
/// part of main.dart — State'in tüm private alanlarına erişir.
extension _SceneLand on _VillageSceneState {
  /// Açılmamış (yasak) tile mı? Zoom-reveal modelinde HEP false — harita baştan
  /// sona inşa edilebilir; ulaşamadığın yeri zaten kamera göstermez.
  bool _isWilderness(int c, int r) => _wilderness.contains((c, r));

  /// Kurulum: land setlerini boş bırakır (reveal = kamera kısıtı, örtü yok).
  void _initLand() {
    _cleared.clear();
    _wilderness.clear();
    _wildTreeTiles.clear();
  }

  /// Eski ön-hat açma kancası (scene_tick devrilen ağaç döngüsü hâlâ çağırıyor).
  /// Zoom-reveal'de ağaç kesimi arazi açmaz → no-op.
  bool _openFrontierTile(int c, int r) => false;

  // ── Reach büyümesi (dünyanın açılması) ──────────────────────────────────────

  /// Her frame (scene_tick). Reach span'i (hu+hv) büyüdükçe izin verilen zoom-out
  /// + pan artar → dünya açılır; gerçek kenar yine hiç görünmez. Üst sınır
  /// `_maxSpan` = min(kCols,kRows)-1-[_VillageSceneState._kEdgeBuffer] (elmasa
  /// içten sığan en büyük ekran-hizalı dikdörtgen; bkz. scene_input._clampCamera).
  ///
  /// **Karma ilerleme (faz anahtarı YOK):** hedef = max(hikâye, organik).
  ///  • Hikâye: tamamlanan görev başına (scene_flow beat'leri) — erken oyunda
  ///    bina az / görev çok olduğu için AÇILIMI HİKÂYE SÜRER.
  ///  • Organik: bina sayısıyla — köy büyüyünce bu baskın gelir, yani hikâye
  ///    kendiliğinden PASİFLEŞİR ve dünya sessizce açılmaya devam eder.
  void _updateLandExpansion(double dt) {
    const start = _VillageSceneState._kSpanStart;
    final story   = start + _completedQuests.length * 1.5; // hikâye beat'leri
    final organic = start + _buildings.length * 0.5;        // köyün büyümesi
    final target =
        (story > organic ? story : organic).clamp(start, _maxSpan);
    if (_reachSpan < target) {
      _reachSpan = (_reachSpan + dt * 1.2).clamp(0.0, target); // ~1.2 span/sn
    }

    // "Dünya açılıyor" anı — reach genişledikçe, oyuncu ZATEN tam zoom-out'taysa
    // (min'e yapışık) kamerayı yumuşakça geriye bırak → açılan dünya gözünün
    // önünde belirir. Oyuncu içeri zoom'lamışsa DOKUNMA (elini rahatsız etme).
    final mz = _minZoomForReach(_viewSize);
    if (_zoom <= _lastMinZoom * 1.03 + 0.001 && _zoom > mz) {
      _zoom += (mz - _zoom) * (dt * 1.5).clamp(0.0, 1.0); // yumuşak geri çekilme
    }
    _lastMinZoom = mz;
  }
}
