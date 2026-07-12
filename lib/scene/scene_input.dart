part of '../main.dart';

/// Oyun canvas'ı pointer/gesture input işleyicileri.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _SceneInput on _VillageSceneState {
  // ── Mouse scroll wheel ile zoom ────────────────────────────────────────────

  void _onCanvasPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta.dy;
    final factor = (1.0 - delta * 0.0012).clamp(0.80, 1.25);
    final newZoom = (_zoom * factor).clamp(0.20, 4.0);
    final center = Offset(_viewSize.width / 2, _viewSize.height / 2);
    final focal = event.localPosition - center;
    _camera = _camera + focal * (1 / newZoom - 1 / _zoom);
    _zoom = newZoom;
    _clampCamera(_viewSize);
    _frame.value = _frame.value + 1;
  }

  // ── Kamera "reach" clamp'i ─────────────────────────────────────────────────
  // Kamera hiçbir zaman "reach" tile-kutusunun dışını göstermez → gerçek harita
  // kenarı kadraja girmez (yüzen ada yok). İki kısıt: (1) zoom-out'u reach'i
  // sığdıracak kadarla sınırla; (2) ekran-merkezi dünya noktasını reach kutusuna
  // sıkıştır. Her input sonrası + her frame (_onTick) çağrılır.

  /// Reach'i sığdıran EN AÇIK (en küçük) zoom — bundan daha fazla uzaklaşmak
  /// reach dışını (ve kenarı) gösterir. Reach büyüdükçe düşer (daha çok zoom-out).
  double _minZoomForReach(Size size) {
    if (size.width <= 0 || size.height <= 0) return 0.2;
    final reachW = 2 * _reachRadius * kTileW;
    final reachH = 2 * _reachRadius * kTileH;
    final z = max(size.width / reachW, size.height / reachH);
    return z.clamp(0.2, _VillageSceneState._kMaxZoom);
  }

  /// Kamerayı, verilen dünya (grid) noktası ekran merkezine gelecek şekilde ayarlar
  /// (zoom merkez sabit noktasıdır → zoom'dan bağımsız).
  void _centerCameraOn(double gx, double gy, Size size) {
    _camera = Offset(
      -(gx - gy) * kTileW / 2,
      size.height * 0.22 - (gx + gy) * kTileH / 2,
    );
  }

  void _clampCamera(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    // İlk geçerli frame: kamerayı reach merkezine (spawn) ortala.
    if (!_cameraCentered) {
      _centerCameraOn(_reachCx, _reachCy, size);
      _cameraCentered = true;
    }
    // Zoom clamp — reach'ten fazla uzaklaşma (kenarı gösterme).
    _zoom = _zoom.clamp(_minZoomForReach(size), _VillageSceneState._kMaxZoom);
    // Ekran-merkezi dünya noktasını reach kutusuna sıkıştır.
    final (gx, gy) = screenToGrid(
        Offset(size.width / 2, size.height / 2), size, _camera);
    final cgx = gx.clamp(_reachCx - _reachRadius, _reachCx + _reachRadius);
    final cgy = gy.clamp(_reachCy - _reachRadius, _reachCy + _reachRadius);
    if (cgx != gx || cgy != gy) _centerCameraOn(cgx, cgy, size);
  }

  // ── Scale (pinch + pan) ────────────────────────────────────────────────────

  void _onCanvasScaleStart(ScaleStartDetails d) {
    _scaleStart = _zoom;
    _panAnchor = d.localFocalPoint;
    _cameraAnchor = _camera;
    if (_mineMode) {
      final tile = _toTile(d.localFocalPoint);
      _mineStart = tile;
      _mineEnd = tile;
      _frame.value = _frame.value + 1;
    } else if (_lumberMode) {
      final tile = _toTile(d.localFocalPoint);
      _lumberStart = tile;
      _lumberEnd = tile;
      _frame.value = _frame.value + 1;
    } else if (_farmMode) {
      final tile = _toTile(d.localFocalPoint);
      _farmStart = tile;
      _farmEnd = tile;
      _frame.value = _frame.value + 1;
    } else if (_placingRoad != null) {
      // Yol döşeme: stroke başla, basılan tile'ı paint et
      _roadStrokeTiles.clear();
      final tile = _toTile(d.localFocalPoint);
      if (tile != null) _paintRoadTile(tile.$1, tile.$2);
    } else if (_placing == null) {
      // Tutup-bırak SADECE kavga anında — yalnız dövüşen (ağız dalaşı/yumruklaşma)
      // bir köylü kavranabilir (onu kavgadan çekip ayır). Diğer zamanlarda
      // köylü sürüklenemez; sürükleme serbest moda (kamera) düşer.
      final tile = _toTile(d.localFocalPoint);
      if (tile != null) {
        final v = _villagerAt(tile.$1, tile.$2);
        if (v != null &&
            !v.isDying &&
            !v.isInsideBuilding &&
            (v.activity == VillagerActivity.brawling ||
                v.activity == VillagerActivity.arguing)) {
          _draggedVillager = v;
          _dragMovedVillager = false;
        }
      }
    }
  }

  void _onCanvasScaleUpdate(ScaleUpdateDetails d) {
    if (_mineMode || _lumberMode || _farmMode) {
      // Seçim modlarında sürükleme; zoom yok
      final tile = _toTile(d.localFocalPoint);
      bool changed = false;
      if (_mineMode && tile != _mineEnd) {
        _mineEnd = tile;
        changed = true;
      }
      if (_lumberMode && tile != _lumberEnd) {
        _lumberEnd = tile;
        changed = true;
      }
      if (_farmMode && tile != _farmEnd) {
        _farmEnd = tile;
        changed = true;
      }
      if (changed) _frame.value = _frame.value + 1;
    } else if (_placingRoad != null) {
      // Yol döşeme: drag boyunca her yeni tile'a paint et
      final tile = _toTile(d.localFocalPoint);
      if (tile != null && !_roadStrokeTiles.contains(tile)) {
        _paintRoadTile(tile.$1, tile.$2);
      }
    } else if (_placing != null) {
      // Bina yerleştirme modunda ghost güncelle
      final tile = _toTile(d.localFocalPoint);
      if (tile != _ghost) {
        _ghost = tile;
        _frame.value = _frame.value + 1;
      }
    } else if (_draggedVillager != null) {
      // Tutup-bırak: köylü imleci takip eder (kamera kaymaz).
      final w = _toWorld(d.localFocalPoint);
      if (w != null) {
        final v = _draggedVillager!;
        v.gridX = w.$1;
        v.gridY = w.$2;
        v.targetCol = w.$1;
        v.targetRow = w.$2;
        v.state = VillagerState.idle;
        _dragMovedVillager = true;
        _frame.value = _frame.value + 1;
      }
    } else {
      // Serbest mod: kaydır + zoom (focal noktaya doğru)
      // Aktif takip varken oyuncu eli kameraya değdiği an takibi düşür —
      // kullanıcı kontrolü her zaman önceliklidir.
      if (_followedVillager != null &&
          (d.localFocalPoint - _panAnchor!).distanceSquared > 9) {
        _followedVillager = null;
      }
      final newZoom = (_scaleStart * d.scale).clamp(0.20, 4.0);
      final center = Offset(_viewSize.width / 2, _viewSize.height / 2);
      final focal = _panAnchor! - center;
      _zoom = newZoom;
      _camera =
          _cameraAnchor! +
          (d.localFocalPoint - _panAnchor!) +
          focal * (1 / newZoom - 1 / _scaleStart);
      _clampCamera(_viewSize);
      _frame.value = _frame.value + 1;
    }
  }

  void _onCanvasScaleEnd(ScaleEndDetails _) {
    // Tutup-bırak: sürüklenen köylüyü bırak (su üstündeyse en yakın karaya çek;
    // taşıma anlık işi/kavgayı keser). Hareket yoksa salt tık → seçim/müdahale.
    if (_draggedVillager != null) {
      final v = _draggedVillager!;
      if (_dragMovedVillager) {
        final (lx, ly) = _nearestLand(v.gridX, v.gridY);
        v.gridX = lx;
        v.gridY = ly;
        v.targetCol = lx;
        v.targetRow = ly;
        v.state = VillagerState.idle;
        v.idleTimer = 0.5;
        // Kavgadan çekildi: yatışır + bir süre tekrar kavgaya tutuşmaz.
        v.activity = VillagerActivity.none;
        v.chatBubbleIcon = '🕊️';
        v.chatBubbleTime = 1.5;
        v.feel(NpcEmotion.content, 2.0, moodDelta: 0.04);
        v.conflictCooldown = 90.0 + _rng.nextDouble() * 60.0;
        _showNotification('✋ ${v.name} kavgadan çekildi.');
      }
      _draggedVillager = null;
      _dragMovedVillager = false;
      _frame.value = _frame.value + 1;
      return;
    }
    if (_mineMode && _mineStart != null && _mineEnd != null) {
      _commitMine(_mineStart!, _mineEnd!);
    } else if (_lumberMode && _lumberStart != null && _lumberEnd != null) {
      _commitLumber(_lumberStart!, _lumberEnd!);
    } else if (_farmMode && _farmStart != null && _farmEnd != null) {
      _commitFarm(_farmStart!, _farmEnd!);
      setStateHere(() {
        _farmStart = null;
        _farmEnd = null;
      });
    }
  }

  // ── Çoklu dikim (long-press) ───────────────────────────────────────────────
  // Yerleştirme modunda basılı tutmak çoklu dikimi açar: dokunulan ilk tile'a
  // bina dikilir, sürükleyince her yeni geçerli tile'a bir tane daha. Bırakınca
  // seçim bırakılır. Tek dokunuş ise _onCanvasTapUp → tek bina + seçimi bırak.

  void _onCanvasLongPressStart(LongPressStartDetails d) {
    if (_placing == null || _time < _placeGuardUntil) return;
    _multiPlace = true;
    _placeStrokeTiles.clear();
    final tile = _toTile(d.localPosition);
    if (tile != null) {
      _placeStrokeTiles.add(tile);
      _doPlace(tile.$1, tile.$2, silent: false);
    }
  }

  void _onCanvasLongPressMoveUpdate(LongPressMoveUpdateDetails d) {
    if (!_multiPlace || _placing == null) return;
    final tile = _toTile(d.localPosition);
    if (tile == null) return;
    // Ghost'u imlece taşı (geçerlilik sebebiyle birlikte).
    if (tile != _ghost) {
      _ghost = tile;
      _placeReason = _placementReason(tile.$1, tile.$2, _placing!);
      _frame.value = _frame.value + 1;
    }
    if (_placeStrokeTiles.contains(tile)) return;
    _placeStrokeTiles.add(tile);
    _doPlace(tile.$1, tile.$2, silent: true);
  }

  void _onCanvasLongPressEnd(LongPressEndDetails d) {
    if (!_multiPlace) return;
    setStateHere(() {
      _multiPlace = false;
      _placeStrokeTiles.clear();
      // Çoklu dikim bitti → kartı bırak (tek tık ile aynı sonuç: palete dön).
      _placing = null;
      _ghost = null;
      _placeReason = null;
    });
  }

  // ── Tap / hover ────────────────────────────────────────────────────────────

  void _onCanvasTapUp(TapUpDetails d) {
    if (_mineMode) {
      final tile = _toTile(d.localPosition);
      if (tile != null) _commitMine(tile, tile);
    } else if (_lumberMode) {
      final tile = _toTile(d.localPosition);
      if (tile != null) _commitLumber(tile, tile);
    } else if (_farmMode) {
      final tile = _toTile(d.localPosition);
      if (tile != null) _commitFarm(tile, tile);
      setStateHere(() {
        _farmStart = null;
        _farmEnd = null;
      });
    } else if (_placing != null) {
      _tryPlace(d.localPosition);
    } else {
      // Seçim: önce bina, yoksa NPC, yoksa hiçbir şey.
      final tile = _toTile(d.localPosition);
      if (tile != null) {
        final b = _buildingAt(tile.$1, tile.$2);
        if (b != null) {
          setStateHere(() {
            _selectedBuilding = b;
            _selectedVillager = null;
          });
        } else {
          final v = _villagerAt(tile.$1, tile.$2);
          // Köylü yoksa: mezara tıklandıysa burada yatanı an (seçim değişmez).
          final g = v == null ? _graveAt(tile.$1, tile.$2) : null;
          // Doğrudan müdahale: dövüşen köylüye tıklayınca seçmek yerine kavgayı
          // ayır (kavgalar anlık/geçici → tıklama o an müdahaleye ayrılır).
          if (v != null &&
              (v.activity == VillagerActivity.brawling ||
                  v.activity == VillagerActivity.arguing)) {
            _interveneConflict(v);
          } else if (g != null) {
            _showNotification('🕯️ Burada ${g.name} yatıyor — köy onu anıyor.');
          } else {
            setStateHere(() {
              _selectedVillager = v;
              _selectedBuilding = null;
            });
          }
        }
      } else {
        setStateHere(() {
          _selectedBuilding = null;
          _selectedVillager = null;
        });
      }
    }
  }

  void _onCanvasHover(PointerHoverEvent e) {
    // Yerleştirme modunda: ghost önizlemesi + akıllı geçersizlik sebebi.
    if (_placing != null) {
      final tile = _toTile(e.localPosition);
      if (tile != _ghost) {
        _ghost = tile;
        _placeReason =
            tile == null ? null : _placementReason(tile.$1, tile.$2, _placing!);
        _frame.value = _frame.value + 1;
      }
      return;
    }
    // Diğer mod araçlarında hover etiketi kapalı (kendi ipuçları var).
    if (_farmMode || _lumberMode || _mineMode || _placingRoad != null) {
      _clearHover();
      return;
    }
    // Boş elde: bina/NPC üstüne gelince ad + durum etiketi.
    final tile = _toTile(e.localPosition);
    String? title, sub;
    if (tile != null) {
      final b = _buildingAt(tile.$1, tile.$2);
      if (b != null) {
        title = kBuildingMeta[b.type]?.label ?? '?';
        sub = _buildingHoverSub(b);
      } else {
        final v = _villagerAt(tile.$1, tile.$2);
        if (v != null) {
          title = v.name;
          sub = v.homeBuilding == null
              ? '${v.type.displayName} · evsiz'
              : v.type.displayName;
        } else {
          final g = _graveAt(tile.$1, tile.$2);
          if (g != null) {
            title = '🕯️ ${g.name}';
            sub = 'huzur içinde yatıyor';
          }
        }
      }
    }
    if (title != _hoverTitle || sub != _hoverSub || e.localPosition != _hoverPos) {
      _hoverTitle = title;
      _hoverSub = sub;
      _hoverPos = title == null ? null : e.localPosition;
      _frame.value = _frame.value + 1;
    }
  }

  void _clearHover() {
    if (_hoverTitle != null || _hoverPos != null) {
      _hoverTitle = null;
      _hoverSub = null;
      _hoverPos = null;
      _frame.value = _frame.value + 1;
    }
  }

  /// Verilen tile'daki mezar (varsa) — anma etkileşimi için. Mezarlar tek tile
  /// kaplar (col/row tam sayı tile indeksi; jitter yalnız görsel kayma).
  Grave? _graveAt(int col, int row) {
    for (final g in _graves) {
      if (g.col.round() == col && g.row.round() == row) return g;
    }
    return null;
  }

  /// Bina hover alt satırı — role/duruma göre kısa durum.
  String _buildingHoverSub(BuildingEntity b) {
    final role = b.fn?.role;
    if (role == BuildingRole.housing) {
      final w = b.waterLevel < 0.3 ? ' · susuz' : '';
      return '${b.occupants} sakin$w';
    }
    if (b.type == BuildingType.firepit) {
      return b.fireFuel > 0.001 ? 'yanıyor' : 'sönük';
    }
    return b.isActive ? 'çalışıyor' : 'boşta';
  }
}
