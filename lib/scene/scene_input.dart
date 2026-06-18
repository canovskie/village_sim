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
    _frame.value = _frame.value + 1;
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
      _frame.value = _frame.value + 1;
    }
  }

  void _onCanvasScaleEnd(ScaleEndDetails _) {
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
          setStateHere(() {
            _selectedVillager = v;
            _selectedBuilding = null;
          });
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
    // Yerleştirme modunda: ghost önizlemesi (hover etiketi gösterme).
    if (_placing != null) {
      final tile = _toTile(e.localPosition);
      if (tile != _ghost) {
        _ghost = tile;
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
