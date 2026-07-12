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

  /// Her frame (scene_tick). Köy büyüdükçe kamera "reach"i yumuşakça genişler →
  /// izin verilen zoom-out + pan artar, dünya açılır; gerçek kenar yine hiç
  /// görünmez (reach kenarda ~8 tile tampon bırakır: [_kReachMax]).
  ///
  /// Karma plan: ilk açılımlar hikâye beat'lerine bağlanacak (Faz 2), sonrası bu
  /// organik sürücüyle sessizce devam eder.
  void _updateLandExpansion(double dt) {
    final target = (_VillageSceneState._kReachStart + _buildings.length * 0.8)
        .clamp(_VillageSceneState._kReachStart, _VillageSceneState._kReachMax);
    if (_reachRadius < target) {
      _reachRadius = (_reachRadius + dt * 1.2).clamp(0.0, target); // ~1.2 tile/sn
    }
  }
}
