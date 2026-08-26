part of '../main.dart';

/// Oyun canvas'ı pointer/gesture input işleyicileri.
/// part of main.dart — State'in tüm private alanlarına erişim.
extension _SceneInput on _VillageSceneState {
  // ── Mezar başı + kavgadan çekme metinleri ([[lib/text/voice.dart]]) ────────

  static const _kGravePool = [
    '🕯️ Burada {merhum} yatıyor.',
    '🕯️ {merhum-in} taşı. Üstünde kurumuş bir demet var.',
    '🕯️ {merhum} bu toprakta. Köy adını unutmadı.',
  ];
  static const _kPulledFromFightPool = [
    '✋ {ad-i} kavgadan çekip aldın.',
    '✋ {ad} yumruğunu indirdi.',
    '✋ {ad} kavgadan koparıldı, hâlâ nefes nefese.',
  ];

  // ── Mouse scroll wheel ile zoom ────────────────────────────────────────────

  void _onCanvasPointerSignal(PointerSignalEvent event) {
    // Kuruluş yürüyüşü kendi kamera planına sahiptir. Bu birkaç saniyedeki
    // pinch/teker hareketi halkayı farklı bir ölçekte bırakmasın.
    if (_foundingCouncilPending) return;
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta.dy;
    final factor = (1.0 - delta * 0.0012).clamp(0.80, 1.25);
    final newZoom = (_zoom * factor).clamp(0.20, 4.0);
    final center = Offset(_viewSize.width / 2, _viewSize.height / 2);
    final focal = event.localPosition - center;
    _camera = _camera + focal * (1 / newZoom - 1 / _zoom);
    _zoom = newZoom;
    _cameraGuideSeen = true;
    _clampCamera(_viewSize);
    _clearHover(); // zoom altında hedef kayar — künye takılı kalmasın
    _frame.value = _frame.value + 1;
  }

  // ── Kamera "reach" clamp'i — EKRAN EKSENLERİNDE (u, v) ─────────────────────
  //
  // GEOMETRİ: tile ızgarası bir dikdörtgen → izometride ekranda bir ELMAS. Ama
  // viewport bir DİKDÖRTGEN. Dikdörtgeni elmasın sivri uç(lar)ına sokamazsın —
  // soktuğun an elmasın dışındaki void kadraja girer. Bu yüzden clamp'i tile
  // eksenlerinde değil, EKRAN eksenlerinde yaparız:
  //     u = c - r  (ekran X'i belirler),   v = c + r  (ekran Y'sini belirler)
  // Bu uzayda hem viewport hem de ulaşılabilir bölge EKSEN-HİZALI dikdörtgendir
  // → clamp TAM (exact) olur.
  //
  // Ulaşılabilir bölge = harita elmasına İÇTEN çizilmiş, ekran-hizalı dikdörtgen
  // (viewport en-boy oranında). Her noktası kadraja tam oturur → ÖLÜ BÖLGE YOK.
  // Elmasın sivri uçları israf değil, TAMPON'dur: void'i ekran dışında tutar.
  //
  // Kısıt: (c,r) haritada ⇔ 0 ≤ v+u ≤ 2(kCols-1) ve 0 ≤ v-u ≤ 2(kRows-1).
  // Merkezde duran bir dikdörtgen için bağlayıcı koşul: hu + hv ≤ min(kCols,kRows)-1.

  /// hu+hv'nin üst sınırı (harita elmasına sığması için) — tampon düşülmüş.
  double get _maxSpan =>
      (kCols < kRows ? kCols : kRows) - 1.0 - _VillageSceneState._kEdgeBuffer;

  /// Harita merkezinin ekran-ekseni koordinatları.
  double get _centerU => (kCols - 1) / 2 - (kRows - 1) / 2;
  double get _centerV => (kCols - 1) / 2 + (kRows - 1) / 2;

  /// Kamerayı, verilen (u,v) ekran-ekseni noktası ekran merkezine gelecek şekilde
  /// ayarlar (zoom merkez sabit noktası → zoom'dan bağımsız).
  void _centerCameraOnUV(double u, double v, Size size) {
    _camera = Offset(-u * kTileW / 2, size.height * 0.22 - v * kTileH / 2);
  }

  /// Kameranın şu anki ekran-merkezi (u,v) noktası (yukarıdakinin tersi).
  (double, double) _cameraUV(Size size) => (
    -2 * _camera.dx / kTileW,
    2 * (size.height * 0.22 - _camera.dy) / kTileH,
  );

  /// Reach span'ini viewport en-boy oranına göre (hu, hv)'ye böler.
  /// hu/hv = w/(2h) → reach dikdörtgeni ekranla aynı orana sahip olur, yani tam
  /// zoom-out'ta viewport reach'e birebir oturur (boşluk/taşma yok).
  (double, double) _reachHalfExtents(Size size) {
    final k = size.width / (2 * size.height); // hu/hv
    final hv = _reachSpan / (1 + k);
    return (_reachSpan - hv, hv);
  }

  /// Reach'i sığdıran EN AÇIK (en küçük) zoom — daha fazla uzaklaşmak reach
  /// dışını (ve void'i) gösterir. Reach büyüdükçe düşer → daha çok zoom-out.
  double _minZoomForReach(Size size) {
    if (size.width <= 0 || size.height <= 0) return 0.2;
    final (hu, hv) = _reachHalfExtents(size);
    if (hu <= 0 || hv <= 0) return 0.2;
    final z = max(size.width / (kTileW * hu), size.height / (kTileH * hv));
    return z.clamp(0.2, _VillageSceneState._kMaxZoom);
  }

  void _clampCamera(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final uc = _centerU, vc = _centerV;
    // İLK GEÇERLİ FRAME — kamerayı köyün kalbine ortala.
    //
    // Eskiden burada harita MERKEZİ (spawn noktası) kullanılıyordu. Kurucular
    // spawn çevresine SERPİLDİĞİ için köy kadrajda yana kayıyordu; oyuncunun
    // ilk gördüğü kare "senin insanların burada" demiyordu. Kalp = ocak varsa
    // ocak, yoksa köylülerin ortalaması (bkz. scene_flow `_villageHeart`).
    //
    // TUZAK — TEK SAHİP: kamerayı burası kurar. Boot'ta ayrıca ortalamayı
    // denedim, bu satır onu ilk karede eziyordu (aynı işi iki yerde yapmanın
    // klasik bedeli). Yeni bir "başlangıçta şuraya bak" isteği çıkarsa yine
    // BURAYA bağlanmalı.
    // SIRALAMA TUZAĞI: ilk kare, kurucular spawn olmadan ÖNCE çizilir (dünya
    // asset'ler hazır olunca kuruluyor). O karede kalp null olur; kamerayı
    // harita merkezine kilitlersen köy sonradan başka yerde doğar ve kadraj
    // bir daha düzelmez — ilk denememde tam olarak bu oldu. Bu yüzden kilit
    // (`_cameraCentered`) yalnız GERÇEKTEN köye ortalayabildiğimizde takılır;
    // o ana kadar harita merkezi geçici bir kadrajdır.
    if (!_cameraCentered) {
      final heart = _villageHeart();
      if (heart != null) {
        _centerCameraOnUV(heart.$1 - heart.$2, heart.$1 + heart.$2, size);
        _cameraCentered = true;
      } else {
        _centerCameraOnUV(uc, vc, size);
      }
    }
    // Zoom clamp — reach'ten fazla uzaklaşma.
    _zoom = _zoom.clamp(_minZoomForReach(size), _VillageSceneState._kMaxZoom);

    // Merkez clamp — VIEWPORT'un yarı-uzanımını da hesaba katarak (eski clamp
    // yalnız merkezi sıkıştırıyordu → kenarda viewport reach'i taşıp void'i
    // gösterebiliyordu; bu onu da düzeltir).
    final (hu, hv) = _reachHalfExtents(size);
    final halfU = size.width / (_zoom * kTileW); // viewport yarı-uzanımı (u)
    final halfV = size.height / (_zoom * kTileH); // viewport yarı-uzanımı (v)
    var (u, v) = _cameraUV(size);
    final uLo = uc - hu + halfU, uHi = uc + hu - halfU;
    final vLo = vc - hv + halfV, vHi = vc + hv - halfV;
    u = uLo <= uHi
        ? u.clamp(uLo, uHi)
        : uc; // viewport reach'ten genişse ortala
    v = vLo <= vHi ? v.clamp(vLo, vHi) : vc;
    _centerCameraOnUV(u, v, size);
  }

  // ── Scale (pinch + pan) ────────────────────────────────────────────────────

  void _onCanvasScaleStart(ScaleStartDetails d) {
    if (_foundingCouncilPending) return;
    _scaleStart = _zoom;
    _panAnchor = d.localFocalPoint;
    _cameraAnchor = _camera;
    _touchToolGestureMoved = false;
    // Bazı Flutter platformlarında aynı kısa dokunuş scale akışını da tap
    // akışını da haber verebilir. Yeni gesture başında sigortayı sıfırla;
    // scale-end dokunuşu sahiplenirse tap-up'ı tek seferlik yutacağız.
    _ignoreNextToolTapUp = false;
    // Kamera oynayınca hedef imlecin altından kayar; künye üstünde takılı
    // kalmasın (bina/mezar hareket etmez, kayan kameradır).
    _clearHover();
    // Oyuncu kamerayı ELİNE aldı → "İzle" kilidi düşer. Aksi hâlde her pan
    // hareketi lerp tarafından geri çekilir ve kamera oyuncuyla güreşirdi.
    _watchLeft = 0;
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
      // Telefonda ilk köşe daha önce dokunarak sabitlendiyse ikinci parmak
      // hareketi o köşeden devam eder; yeni drag başlangıcı anchor'ı ezmez.
      _farmStart =
          useTouchUi(context) && _farmTapAnchor != null && _farmStart != null
          ? _farmTapAnchor
          : tile;
      _farmEnd = tile;
      _frame.value = _frame.value + 1;
    } else if (_roadMode) {
      // Yol: sürükleme ÖNİZLEME başlatır — burada hiçbir şey harcanmaz.
      // Commit sürükleme bırakılınca (_onCanvasScaleEnd).
      final tile = _toTile(d.localFocalPoint);
      _roadDragStart =
          useTouchUi(context) &&
              _roadTapAnchor != null &&
              _roadDragStart != null
          ? _roadTapAnchor
          : tile;
      _roadDragEnd = tile;
      _rebuildRoadPreview();
      _frame.value = _frame.value + 1;
    } else if (_placing == null) {
      // Tutup-bırak SADECE kavga anında — yalnız dövüşen (ağız dalaşı/yumruklaşma)
      // bir köylü kavranabilir (onu kavgadan çekip ayır). Diğer zamanlarda
      // köylü sürüklenemez; sürükleme serbest moda (kamera) düşer.
      final v = _villagerAtScreen(d.localFocalPoint);
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

  void _onCanvasScaleUpdate(ScaleUpdateDetails d) {
    if (_foundingCouncilPending) return;
    if (useTouchUi(context) &&
        (_roadMode || _farmMode) &&
        _panAnchor != null &&
        (d.localFocalPoint - _panAnchor!).distanceSquared > 144) {
      // 12dp slop: parmak titremesi "drag" sayılmaz; gerçek sürükleme
      // akışıysa bırakınca doğrudan commit edilir.
      _touchToolGestureMoved = true;
    }
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
    } else if (_roadMode) {
      // Yol: sürükleme yalnız güzergâhın UCUNU taşır; ara noktalar dik "L"
      // ile türetilir (serbest el yok → el titremesi yola dönüşmez).
      final tile = _toTile(d.localFocalPoint);
      if (tile != null && tile != _roadDragEnd) {
        _roadDragEnd = tile;
        _roadDragStart ??= tile;
        _rebuildRoadPreview();
        _frame.value = _frame.value + 1;
      }
    } else if (_placing != null) {
      // Bina yerleştirme modunda ghost güncelle
      final tile = _toTile(d.localFocalPoint);
      if (tile != _ghost) {
        _ghost = tile;
        _refreshPlaceHints(tile);
        _frame.value = _frame.value + 1;
      }
    } else if (_draggedVillager != null) {
      // Tutup-bırak: köylü imleci takip eder (kamera kaymaz).
      final w = _toWorld(d.localFocalPoint);
      if (w != null) {
        final v = _draggedVillager!;
        // İlk gerçek sürüklemede, konumu ışınlamadan önce porter zincirini
        // kapat. Böylece alınmış yük eski pickup'a dönmez; köylünün son gerçek
        // konumuna düşer ve teslim slot'u yalnız bir kez salınır.
        if (!_dragMovedVillager) v.cancelCarryTask();
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
      if ((d.localFocalPoint - _panAnchor!).distanceSquared > 9 ||
          (d.scale - 1.0).abs() > 0.01) {
        _cameraGuideSeen = true;
      }
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
    if (_foundingCouncilPending) return;
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
        // Işınlandı — birikmiş hızı taşıma, yoksa bırakıldığı yerde eski
        // yönüne doğru bir kayış yapar.
        v.loco.reset();
        // Kavgadan çekildi: yatışır + bir süre tekrar kavgaya tutuşmaz.
        v.activity = VillagerActivity.none;
        v.chatBubbleIcon = '🕊️';
        v.chatBubbleTime = 1.5;
        v.feel(NpcEmotion.content, 2.0, moodDelta: 0.04);
        v.conflictCooldown = 90.0 + _rng.nextDouble() * 60.0;
        _showNotification(
          Voice.say(
            _kPulledFromFightPool,
            _voice(v, seed: _stableSeed('çek${v.name}', _dayCount)),
          ),
        );
      }
      _draggedVillager = null;
      _dragMovedVillager = false;
      _frame.value = _frame.value + 1;
      return;
    }
    if (_roadMode) {
      if (useTouchUi(context) && !_touchToolGestureMoved) {
        final tile = _roadDragEnd;
        if (tile != null) {
          _ignoreNextToolTapUp = true;
          _handleRoadTap(tile);
        }
        return;
      }
      // Önizlenen güzergâh burada gerçek olur — kaynak İLK KEZ şimdi harcanır.
      _commitRoadPreview();
      return;
    }
    if (_mineMode && _mineStart != null && _mineEnd != null) {
      _commitMine(_mineStart!, _mineEnd!);
    } else if (_lumberMode && _lumberStart != null && _lumberEnd != null) {
      _commitLumber(_lumberStart!, _lumberEnd!);
    } else if (_farmMode && _farmStart != null && _farmEnd != null) {
      if (useTouchUi(context) && !_touchToolGestureMoved) {
        _ignoreNextToolTapUp = true;
        _handleFarmTap(_farmEnd!);
        return;
      }
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
    if (_placing == null) return;
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
      _refreshPlaceHints(tile);
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
      _placingDesignManual = false;
      _ghost = null;
      _placeReason = null;
      _placeFacts = null;
    });
  }

  // ── Tap / hover ────────────────────────────────────────────────────────────

  void _onCanvasDoubleTapDown(TapDownDetails d) {
    _doubleTapLocalPosition = d.localPosition;
  }

  /// Çift tık yalnız NPC kimlik kartının kısa yoludur. Yerleştirme/alan/yol
  /// araçları aktifken onların iki dokunuşunu çalmaz.
  void _onCanvasDoubleTap() {
    final at = _doubleTapLocalPosition;
    _doubleTapLocalPosition = null;
    if (at == null ||
        _roadMode ||
        _mineMode ||
        _lumberMode ||
        _farmMode ||
        _placing != null) {
      return;
    }
    final v = _villagerAtScreen(at);
    if (v == null) return;
    setStateHere(() {
      _selectedVillager = v;
      _selectedBuilding = null;
      _selectedSiteId = null;
      _detailExpanded = true;
    });
  }

  void _onCanvasTapUp(TapUpDetails d) {
    if (_foundingCouncilPending) return;
    // Telefonda yol/tarla için sürükleme MECBURİ DEĞİL: birinci dokunuş ilk
    // noktayı sabitler, ikinci dokunuş bitişi seçip uygular. Drag hâlâ çalışır;
    // bu yol yalnız küçük izometrik karelerde parmak hassasiyetine alternatiftir.
    if (_roadMode) {
      if (_ignoreNextToolTapUp) {
        _ignoreNextToolTapUp = false;
        return;
      }
      final tile = _toTile(d.localPosition);
      if (tile != null && useTouchUi(context)) _handleRoadTap(tile);
      return;
    }
    if (_mineMode) {
      final tile = _toTile(d.localPosition);
      if (tile != null) _commitMine(tile, tile);
    } else if (_lumberMode) {
      final tile = _toTile(d.localPosition);
      if (tile != null) _commitLumber(tile, tile);
    } else if (_farmMode) {
      if (_ignoreNextToolTapUp) {
        _ignoreNextToolTapUp = false;
        return;
      }
      final tile = _toTile(d.localPosition);
      if (tile != null) {
        if (useTouchUi(context)) {
          _handleFarmTap(tile);
        } else {
          _commitFarm(tile, tile);
          setStateHere(() {
            _farmStart = null;
            _farmEnd = null;
          });
        }
      }
    } else if (_placing != null) {
      _tryPlace(d.localPosition);
    } else {
      // Seçim: önce NPC (ekran-uzayı sprite hit — bina önünde duran köylü
      // görsel olarak öndedir, tıklama ona gider), sonra bina, sonra mezar.
      final v = _villagerAtScreen(d.localPosition);
      final tile = _toTile(d.localPosition);
      if (v != null) {
        final spoken = villagerSpokenStatus(v);
        // SUÇÜSTÜ: suç işlemekte olan faile dokunmak onu yakalar (seçmez).
        // Sinsi yaklaşma/eylem/kaçış boyunca geçerli — pencere kaçarsa fail
        // meçhul kalır (bkz. scene_crime).
        if (_isCriminalInAct(v)) {
          _npcSpeak(v, spoken);
          _catchCriminal(v);
        } else if (v.activity == VillagerActivity.brawling ||
            v.activity == VillagerActivity.arguing) {
          // Doğrudan müdahale: dövüşen köylüye tıklayınca seçmek yerine kavgayı
          // ayır (kavgalar anlık/geçici → tıklama o an müdahaleye ayrılır).
          _npcSpeak(v, spoken);
          _interveneConflict(v);
        } else {
          setStateHere(() {
            _selectedVillager = v;
            _selectedBuilding = null;
            _selectedSiteId = null;
            _detailExpanded = false; // önce komuta çubuğunda kompakt görün
          });
          _npcSpeak(v, spoken);
        }
      } else if (tile != null) {
        final b = _buildingAt(tile.$1, tile.$2);
        // YAPISI OLMAYAN İŞ YERİ — tarla, böğürtlenlik, şantiye. Bina yoksa
        // bakılır: iş verme yere taşındığı için bu yerlerin de tıklanabilir
        // olması şart, yoksa toplayıcının ve inşaatçının yuvası hiçbir yerden
        // açılamazdı.
        final siteId = b == null ? _siteIdAt(tile.$1, tile.$2) : null;
        // Köylü/bina yoksa: mezara tıklandıysa burada yatanı an (seçim değişmez).
        final g = b == null && siteId == null
            ? _graveAt(tile.$1, tile.$2)
            : null;
        if (b != null) {
          setStateHere(() {
            _selectedBuilding = b;
            _selectedVillager = null;
            _selectedSiteId = null;
            // Bina dekor değil, dünya üstündeki yönetim kapısıdır. Özellikle
            // telefonda ikinci bir "Detay" dokunuşu etkileşimi saklıyordu;
            // binaya dokunmak artık doğrudan kendi masasını açar.
            _detailExpanded = true;
          });
        } else if (siteId != null) {
          setStateHere(() {
            _selectedSiteId = siteId;
            _selectedBuilding = null;
            _selectedVillager = null;
            _detailExpanded = false;
          });
        } else if (g != null) {
          _showNotification(
            Voice.say(
              _kGravePool,
              _voice(
                null,
                seed: _stableSeed('mezar${g.name}', _dayCount),
                extra: {'merhum': g.name},
              ),
            ),
          );
        } else {
          setStateHere(() {
            _selectedVillager = null;
            _selectedBuilding = null;
            _selectedSiteId = null;
          });
        }
      } else {
        setStateHere(() {
          _selectedBuilding = null;
          _selectedVillager = null;
          _selectedSiteId = null;
        });
      }
    }
  }

  /// Mobil yol aracı: ilk dokunuş başlangıç, ikinci dokunuş bitiş. İlk tile
  /// anında önizlenir ama kaynak ancak ikinci noktada harcanır.
  void _handleRoadTap((int, int) tile) {
    if (_roadTapAnchor == null || _roadDragStart == null) {
      _roadTapAnchor = tile;
      _roadDragStart = tile;
      _roadDragEnd = tile;
      _rebuildRoadPreview();
      _frame.value = _frame.value + 1;
      return;
    }
    _roadDragStart = _roadTapAnchor;
    _roadDragEnd = tile;
    _rebuildRoadPreview();
    _commitRoadPreview();
  }

  /// Mobil tarla aracı: dikdörtgenin iki köşesi ayrı ayrı dokunulabilir.
  /// Sürükleyebilen oyuncu aynı aracı eski biçimde tek harekette de kullanır.
  void _handleFarmTap((int, int) tile) {
    if (_farmTapAnchor == null || _farmStart == null) {
      _farmTapAnchor = tile;
      _farmStart = tile;
      _farmEnd = tile;
      _frame.value = _frame.value + 1;
      return;
    }
    _farmStart = _farmTapAnchor;
    _farmEnd = tile;
    _commitFarm(_farmStart!, _farmEnd!);
  }

  void _onCanvasHover(PointerHoverEvent e) {
    // Yerleştirme modunda: ghost önizlemesi + akıllı geçersizlik sebebi.
    if (_placing != null) {
      final tile = _toTile(e.localPosition);
      if (tile != _ghost) {
        _ghost = tile;
        _refreshPlaceHints(tile);
        _frame.value = _frame.value + 1;
      }
      return;
    }
    // Diğer mod araçlarında hover etiketi kapalı (kendi ipuçları var).
    if (_farmMode || _lumberMode || _mineMode || _roadMode) {
      _clearHover();
      return;
    }
    // Boş elde: NPC/bina/iş yeri/mezar üstüne gelince dünya-uzayı künye. NPC
    // önce — tıklama önceliğiyle tutarlı (sprite bina önünde görünür).
    //
    // PERF: imleç 3px'ten az oynadıysa hit-test'i hiç çalıştırma (trackpad
    // saniyede 100+ olay üretir; künye imleci takip etmediği için minik
    // titremelerin sonucu zaten değişmez).
    final probe = _hoverProbe;
    if (probe != null && (e.localPosition - probe).distanceSquared < 9.0) {
      return;
    }
    _hoverProbe = e.localPosition;

    final VillagerEntity? v = _villagerAtScreen(e.localPosition);
    BuildingEntity? b;
    String? siteId;
    Grave? g;
    if (v == null) {
      final tile = _toTile(e.localPosition);
      if (tile != null) {
        b = _buildingAt(tile.$1, tile.$2);
        if (b == null) siteId = _siteIdAt(tile.$1, tile.$2);
        if (b == null && siteId == null) g = _graveAt(tile.$1, tile.$2);
      }
    }
    // PERF: hedef değişmediyse hiçbir şey yazma — hover başına sıfır iş.
    if (identical(v, _hoverVillager) &&
        identical(b, _hoverBuilding) &&
        siteId == _hoverSiteId &&
        identical(g, _hoverGrave)) {
      return;
    }
    final wasEmpty =
        _hoverVillager == null &&
        _hoverBuilding == null &&
        _hoverSiteId == null &&
        _hoverGrave == null;
    _hoverVillager = v;
    _hoverBuilding = b;
    _hoverSiteId = siteId;
    _hoverGrave = g;
    // Hedeften hedefe geçerken künye yeniden doğmaz (fade tekrarı göz yorar);
    // yalnız boşluktan gelirken belirir.
    if (wasEmpty) _hoverSince = _time;
    // Target changes are sparse (not every pointer move), so repaint directly.
    // This also keeps hover feedback alive while the simulation is paused and
    // the game loop intentionally stops issuing identical canvas frames.
    _frame.value = _frame.value + 1;
  }

  void _clearHover() {
    final hadHover =
        _hoverVillager != null ||
        _hoverBuilding != null ||
        _hoverSiteId != null ||
        _hoverGrave != null;
    _hoverVillager = null;
    _hoverBuilding = null;
    _hoverSiteId = null;
    _hoverGrave = null;
    _hoverProbe = null;
    if (hadHover) _frame.value = _frame.value + 1;
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
      if (b.fireFuel <= 0.001) return 'sönük';
      // Kışın ocak hızlı yer — köre düşmeden önce künyeden de belli olsun.
      return b.fireFuel < 0.30 ? 'yanıyor · yakıt az' : 'yanıyor';
    }
    return b.isActive ? 'çalışıyor' : 'boşta';
  }
}
