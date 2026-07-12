part of '../main.dart';

/// Hikâye-temelli SABAH SİSİ reveal sistemi.
///
/// Vizyon: köy küçük ve odaklı başlar (düşük görsel yük). Dünya baştan aydınlık
/// bir sabah sisinin altındadır; yalnız ocak çevresi açıktır. Köy kurulup kök
/// saldıkça (önce hikâye beat'leri, sonra organik büyüme) sis parça parça çekilir
/// ve altındaki NORMAL harita (world_generator'ın ağaç/su/dekoru) görünür.
/// Orman duvarı / koyu sis YOK — açılmamış alan hafif, parlak, sürüklenen sistir.
///
/// Setler:
///  • [_cleared]  = AÇILMIŞ (revealed) tile'lar — görünür + inşa edilebilir.
///  • [_wilderness] = AÇILMAMIŞ tile'lar — sis altında (engel + placement gate);
///    içindeki gen içeriği (ağaç/su/maden/dekor) çizilmez (sisle gizli), açılınca
///    görünür. `_cleared` DIŞINDAKİ HER tile (su/maden dahil).
///  • [_forestDepth] = sis derinliği (açık kenardan BFS) → kenar feather'ı.
///  • [_revealAnim] = yeni açılan tile'ların dissolve (erime) animasyonu.
///
/// Dış call-site uyumu: [_openFrontierTile] (scene_tick felled + capture),
/// [_rebuildLandDerived] (scene_save), [_updateLandExpansion] (scene_tick),
/// [_isWilderness] (scene_placement) korunur — gövdeleri reveal'a göre.
///
/// part of main.dart — State'in tüm private alanlarına erişir.
extension _SceneLand on _VillageSceneState {
  // ── Ayarlar ─────────────────────────────────────────────────────────────────

  /// Bir tile açıldığında sisinin eriyip kaybolması (saniye).
  static const double _kRevealDissolve = 1.6;

  /// Organik reveal: boş (inşasız) açık tile bunun altına düşünce sis bir sonraki
  /// halkayı bırakır → köy hep ihtiyacının biraz önünde açılır.
  static const int _kRevealComfortBuffer = 90;

  /// Organik tetiklemede bir kerede açılan tile sayısı (tempo yumuşak kalsın).
  static const int _kRevealBatch = 16;

  // ── Sorgular ────────────────────────────────────────────────────────────────

  /// Açılmamış (sisli) tile mı? — placement gate + yol döşeme bunu kullanır.
  bool _isWilderness(int c, int r) => _wilderness.contains((c, r));

  bool _bordersCleared(int c, int r) =>
      _cleared.contains((c, r - 1)) ||
      _cleared.contains((c, r + 1)) ||
      _cleared.contains((c - 1, r)) ||
      _cleared.contains((c + 1, r));

  // ── Kurulum ─────────────────────────────────────────────────────────────────

  /// Yeni harita: ocak çevresinde küçük bir açık çember, gerisi sis. Gen içeriği
  /// (ağaç/dekor/su/maden) OLDUĞU GİBİ durur — sadece sisle gizli, açıldıkça
  /// görünür. `_generateWorld` içinde içerik yüklendikten SONRA çağrılır.
  void _initLand() {
    // DEVRE DIŞI (kullanıcı: "sil, benim fikrim var"). Land setleri boş → sis
    // çizilmez, placement/obstacle/organik hepsi susar, harita normal/açık kalır.
    // Reveal API (aşağıda) dormant bekliyor; yeni fikir gelince ya kullanılır ya
    // komple sökülür.
    _cleared.clear();
    _wilderness.clear();
    _wildTreeTiles.clear();
    _forestDepth.clear();
    _revealAnim.clear();
    _revealOrganic = false;
  }

  /// Merkez (cx,cy) yarıçap r içindeki tile'ları [into]'ya ekler (su/maden dahil
  /// — açılan göl/maden görünsün). Yumuşak organik kenar için köşeler kırpılır.
  void _revealBlobInto(double cx, double cy, double r, Set<(int, int)> into) {
    final r2 = r * r;
    final c0 = (cx - r - 1).floor().clamp(0, kCols - 1);
    final c1 = (cx + r + 1).ceil().clamp(0, kCols - 1);
    final r0 = (cy - r - 1).floor().clamp(0, kRows - 1);
    final r1 = (cy + r + 1).ceil().clamp(0, kRows - 1);
    for (int c = c0; c <= c1; c++) {
      for (int rr = r0; rr <= r1; rr++) {
        final dx = c - cx, dy = rr - cy;
        if (dx * dx + dy * dy <= r2) into.add((c, rr));
      }
    }
  }

  /// [_cleared] (açık) DIŞINDAKİ her tile'ı [_wilderness]'e (sis) koyar; sonra
  /// sis derinliğini tazeler. Kayıt yüklemede de kullanılır (kaydedilen `cleared`
  /// yeterli; gerisi buradan türetilir).
  void _rebuildLandDerived() {
    _wilderness.clear();
    for (int c = 0; c < kCols; c++) {
      for (int r = 0; r < kRows; r++) {
        if (_cleared.contains((c, r))) continue;
        _wilderness.add((c, r)); // su/maden dahil: hepsi sisle gizli
      }
    }
    _rebuildForestDepth();
    _forestVersion++;
  }

  /// Sis derinliği: açık kenara komşu her sisli tile derinlik 1; içeri gittikçe
  /// artar. Render kenarı buradan feather'lar (kenar seyrek/şeffaf → iç dolu).
  /// O(sisli tile); yalnız reveal değişince çalışır → per-frame değil.
  void _rebuildForestDepth() {
    _forestDepth.clear();
    var frontier = <(int, int)>[];
    for (final (c, r) in _wilderness) {
      if (_bordersCleared(c, r)) {
        _forestDepth[(c, r)] = 1;
        frontier.add((c, r));
      }
    }
    int depth = 1;
    while (frontier.isNotEmpty) {
      final next = <(int, int)>[];
      for (final (c, r) in frontier) {
        for (final (nc, nr) in [(c, r - 1), (c, r + 1), (c - 1, r), (c + 1, r)]) {
          if (!_wilderness.contains((nc, nr))) continue;
          if (_forestDepth.containsKey((nc, nr))) continue;
          _forestDepth[(nc, nr)] = depth + 1;
          next.add((nc, nr));
        }
      }
      frontier = next;
      depth++;
    }
  }

  // ── Reveal (sis çekilmesi) ───────────────────────────────────────────────────

  /// Verilen sisli tile'ları açar: [_cleared]'a taşır + dissolve animasyonu
  /// başlatır (sis erisin, pop olmasın). En az bir tile açıldıysa derived +
  /// engel cache'i tazelenir. Hem hikâye beat'leri hem organik sürücü çağırır.
  bool _revealTiles(Iterable<(int, int)> tiles) {
    bool any = false;
    for (final (c, r) in tiles) {
      if (!_wilderness.contains((c, r))) continue;
      _cleared.add((c, r));
      _revealAnim[(c, r)] = _kRevealDissolve;
      any = true;
    }
    if (any) {
      _rebuildLandDerived();
      _spatialTimer = 0; // engel/land cache'i ilk tick'te tazele
    }
    return any;
  }

  /// Merkez çevresinde bir yarıçapı açar (hikâye beat'i: "sis bir halka çekildi").
  bool _revealRadius(double cx, double cy, double r) {
    final blob = <(int, int)>{};
    _revealBlobInto(cx, cy, r, blob);
    return _revealTiles(blob);
  }

  /// Tek tile aç (scene_tick felled uyumu + capture harness). Yeni modelde
  /// ağaç kesimi sis açmaz; bu yalnız uyum/araç amaçlı tekil reveal'dır.
  bool _openFrontierTile(int c, int r) => _revealTiles([(c, r)]);

  // ── Organik sürücü (hikâye pasifleştikten sonra) ─────────────────────────────

  /// İnşa/tarla ile DOLU olmayan açık tile sayısı (köyün "nefes payı").
  int _freeClearedCount() {
    final farm = <(int, int)>{for (final f in _farmTiles) (f.col, f.row)};
    int free = 0;
    for (final t in _cleared) {
      if (_waterTiles.contains(t)) continue; // göl inşa edilemez
      if (_obstacles.contains(t)) continue;  // bina ayak izi / ağaç
      if (farm.contains(t)) continue;         // tarla
      free++;
    }
    return free;
  }

  /// Her frame çağrılır (scene_tick). İki iş: (1) dissolve animasyonlarını
  /// yaşlandır; (2) organik reveal açıksa ve köyün nefes payı azaldıysa sisi bir
  /// sonraki halka kadar (köyün büyüdüğü yöne) çek.
  void _updateLandExpansion(double dt) {
    // (0) Kamera REACH büyümesi — köy büyüdükçe ulaşılabilir bölge (dolayısıyla
    // izin verilen zoom-out + pan) yumuşakça genişler → dünya "açılır", hiç
    // gerçek kenar göstermeden. Hikâye beat'leri ayrıca sıçratabilir (Faz 2).
    final target = (_VillageSceneState._kReachStart + _buildings.length * 0.8)
        .clamp(_VillageSceneState._kReachStart, _VillageSceneState._kReachMax);
    if (_reachRadius < target) {
      _reachRadius = (_reachRadius + dt * 1.2).clamp(0.0, target); // ~1.2 tile/sn
    }

    // (1) Dissolve yaşlandırma — her frame.
    if (_revealAnim.isNotEmpty) {
      _revealAnim.updateAll((_, v) => v - dt);
      _revealAnim.removeWhere((_, v) => v <= 0);
    }

    // (2) Organik reveal — throttle'lı.
    _landExpandTimer -= dt;
    if (_landExpandTimer > 0) return;
    _landExpandTimer = 3.0; // ~3sn'de bir değerlendir (cozy tempo)

    if (!_revealOrganic) return;             // hikâye hâlâ sürüyor
    if (_wilderness.isEmpty) return;          // dünya tümüyle açık
    if (_freeClearedCount() >= _kRevealComfortBuffer) return; // bol yer var

    _revealNextRing(_kRevealBatch);
  }

  /// Köyün ağırlık merkezine en yakın sis-kenarı (derinlik 1) tile'larından
  /// [count] tanesini açar → reveal köyün büyüdüğü yöne doğru, doğal ve kompakt.
  void _revealNextRing(int count) {
    double sx = 0, sy = 0;
    int n = 0;
    for (final b in _buildings) {
      sx += b.col + 0.5;
      sy += b.row + 0.5;
      n++;
    }
    if (n == 0) {
      for (final (c, r) in _cleared) {
        sx += c + 0.5;
        sy += r + 0.5;
        n++;
      }
    }
    if (n == 0) return;
    final cx = sx / n, cy = sy / n;

    final cands = <(double, (int, int))>[];
    for (final entry in _forestDepth.entries) {
      if (entry.value != 1) continue; // yalnız sis kenarı (revealed'a komşu)
      final (c, r) = entry.key;
      final dx = c + 0.5 - cx, dy = r + 0.5 - cy;
      cands.add((dx * dx + dy * dy, entry.key));
    }
    if (cands.isEmpty) return;
    cands.sort((a, b) => a.$1.compareTo(b.$1));
    _revealTiles([for (int i = 0; i < count && i < cands.length; i++) cands[i].$2]);
  }
}
