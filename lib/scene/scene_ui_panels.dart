part of '../main.dart';

/// SAHNE ARAYÜZÜ — yargı onayı, olay modali, dev paneli, olay bandı, künye.
///
/// scene_ui.dart 2245 satırdı; tek uzantı üç parçaya bölündü. Uzantı adı
/// farklı ama hedef aynı ([_VillageSceneState]) — çağıranlar için hiçbir
/// şey değişmez, metotlar aynen taşındı.
extension _SceneUiPanels on _VillageSceneState {
  Widget buildJudgmentConfirm() {
    final (v, lethal) = _pendingJudgment!;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setStateHere(() => _pendingJudgment = null),
              child: Container(color: const Color(0x99000000)),
            ),
          ),
          Center(
            child: AppPanel(
              width: 340,
              accent: AppUi.rust,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lethal ? '⚖️ İdam kararı' : '🚷 Sürgün kararı',
                    style: AppUi.title,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lethal
                        ? '${v.name} halkın önünde idam edilecek. Kan davası kanla '
                              'kapanır ama köyü dehşet sarar. Bu karar geri alınamaz.'
                        : '${v.name} köyden sürülecek. Kan davası uzaklaştırmayla '
                              'diner. Bu karar geri alınamaz.',
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
                              setStateHere(() => _pendingJudgment = null),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          label: lethal ? 'İdam et' : 'Sürgün et',
                          kind: AppButtonKind.filled,
                          tint: AppUi.rust,
                          onTap: () {
                            setStateHere(() {
                              _pendingJudgment = null;
                              _selectedVillager = null;
                              if (lethal) {
                                _executeVillager(v);
                              } else {
                                _exileVillager(v);
                              }
                            });
                          },
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

  // ── NPC etkileşim eylemleri (Takip et) ────────────────────────────────────

  void _toggleFollowVillager(VillagerEntity v) {
    setStateHere(() {
      if (_followedVillager == v) {
        _followedVillager = null;
        _showNotification('🎥 Takip bırakıldı');
      } else {
        _followedVillager = v;
        // "İzle" kilidi varsa düşür — iki kamera kanalı aynı kareyi
        // çekiştirirse ikisi de titrer (bkz. _tickWatchCamera).
        _watchLeft = 0;
        _showNotification('🎥 ${v.name} takip ediliyor');
      }
    });
  }

  // ── Event modal (karar bekleyen olay) ──────────────────────────────────────

  Widget buildEventChoiceModal() {
    return Positioned.fill(
      child: EventChoiceModal(
        event: _pendingChoice!,
        onChoose: (c) => _applyEventChoice(_pendingChoice!, c),
      ),
    );
  }

  // ── Dev panel — sağdan slide-in ────────────────────────────────────────────

  Widget buildDevPanel() {
    return Positioned.fill(
      child: ListenableBuilder(
        listenable: _frame,
        builder: (_, _) => DevPanel(
          godMode: _godMode,
          rainIntensity: _cycle.rainIntensity,
          timeOfDay: _cycle.timeOfDay,
          villagerCount: _villagers.length,
          buildingCount: _buildings.length,
          onClose: () => setStateHere(() => _devPanelOpen = false),
          onOpenConsole: () => setStateHere(() {
            _devPanelOpen = false;
            _devConsoleOpen = true;
          }),
          onToggleGod: () => setStateHere(() => _godMode = !_godMode),
          onSetRain: (v) => setStateHere(() => _cycle.rainIntensity = v),
          season: _season,
          snowOn: kDevForceSnowfall,
          onToggleSnow: () =>
              setStateHere(() => kDevForceSnowfall = !kDevForceSnowfall),
          onJumpSeason: (s) => setStateHere(() => jumpToSeason(s)),
          // Mevsimlik referans köy: kur → KENDİ slotuna yaz → paneli kapat.
          // Sahnenin `_slotId`'si final olduğu için kayıt açık hedefle yazılır;
          // aksi hâlde dört varyant birbirinin üstüne biner.
          onSeedReference: (s) {
            buildReferenceVillage(season: s); // kendi setState'ini yapar
            _saveNow(
              asSlot: kReferenceSlotIdFor(s),
              asName: kReferenceSlotNameFor(s),
            );
            setStateHere(() => _devPanelOpen = false);
            _showNotification(
              '${s.icon} Referans köy kuruldu — ${s.label} '
              '(${kReferenceSlotNameFor(s)} olarak kaydedildi)',
            );
          },
          onSetTimeOfDay: (v) => setStateHere(() => _cycle.timeOfDay = v),
          onTriggerEvent: (e) {
            setStateHere(() {
              if (e.needsChoice) {
                _pendingChoice = e;
                _showNotification('${e.icon} ${e.title}. Köy karar bekliyor.');
              } else {
                _applyEventAutomatic(e);
              }
              _devPanelOpen = false;
            });
          },
          onAddResource: (k, n) => setStateHere(() {
            _stockpile.add(k, n);
            final cur = _stockpile.get(k);
            if (cur < 0) _stockpile.add(k, -cur);
          }),
          onSpawnVillager: () {
            final fp = _firepitBuilding;
            if (fp != null) setStateHere(() => _spawnGrownVillager(fp));
          },
          onKillRandomVillager: () {
            if (_villagers.isEmpty) return;
            setStateHere(() {
              final v = _villagers[_rng.nextInt(_villagers.length)];
              v.ageDays = v.lifespanDays + 1; // bir sonraki tick ölür
            });
          },
          onClearEffects: () => setStateHere(() {
            _activeFx.clear();
            _eventMorale = 0;
            _eventMoraleLeft = 0;
            _eventLabel = null;
            _activeEvent = null;
            _activeEventLeft = 0;
          }),
          onNewMap: () => setStateHere(_generateWorld),
          onWakeAll: () => setStateHere(() {
            for (final v in _villagers) {
              v.isInsideBuilding = false;
              v.sleepTarget = null;
              v.sleepIsHome = false;
            }
          }),
          onSeedLivingVillage: () {
            _buildLivingVillage();
            setStateHere(() => _devPanelOpen = false);
          },
          onUnlockAllCrafts: () => setStateHere(() {
            _knownCrafts.addAll(Craft.all);
            _showNotification('⚒ Tüm zanaatlar açıldı');
          }),
          onSeedShowcase: () {
            _buildShowcaseVillage();
            setStateHere(() {
              _godMode = true;
              _devPanelOpen = false;
            });
          },
          // ── Görsel test hızlı aksiyonlar ───────────────────────────────
          onSetDawn: () => setStateHere(() => _cycle.timeOfDay = 0.22),
          onSetNoon: () => setStateHere(() => _cycle.timeOfDay = 0.50),
          onSetDusk: () => setStateHere(() => _cycle.timeOfDay = 0.78),
          onSetNight: () => setStateHere(() => _cycle.timeOfDay = 0.92),
          onToggleRain: () => setStateHere(() {
            _cycle.rainIntensity = _cycle.rainIntensity > 0.05 ? 0.0 : 0.7;
          }),
          // DEV: defteri tek hamlede doldur (GEÇİM kolu) / defteri yak.
          // Mühür geri alınmaz — ama dev paneli oyunun kuralına tabi değil.
          onAllPolicies: () => setStateHere(() {
            for (final l in LawBook.ofBranch(LawBranch.gecim)) {
              if (LawBook.available(l, _policies.sealed, _lawContext)) {
                _policies.seal(l);
              }
            }
            _policies.inkDryUntilSim = 0;
            _applyPolicySideChannels();
          }),
          onClearPolicies: () => setStateHere(() {
            _policies.restoreSealed(const []);
            _policies.inkDryUntilSim = 0;
            _applyPolicySideChannels();
          }),

          onMakeSage: () => setStateHere(() {
            // Zaten varsa flag'i temizle ki yeni biri olabilsin
            for (final v in _villagers) {
              v.isSage = false;
            }
            var elders = _villagers
                .where((v) => v.lifeStage == LifeStage.elder)
                .toList();
            if (elders.isEmpty) {
              // Yaşlı yok → bir yaşlı doğur
              final fp = _firepitBuilding;
              if (fp != null) {
                _spawnGrownVillager(fp);
                _villagers.last.ageDays = kElderStartDay + 1.0;
                elders = [_villagers.last];
              }
            }
            if (elders.isNotEmpty) {
              final sage = elders[_rng.nextInt(elders.length)];
              sage.isSage = true;
              _showNotification('👵 ${sage.name} köyün bilgesi yapıldı (test)');
            }
          }),
          onSpawnMigrant: () => setStateHere(_spawnMigrant),
          onSummonImperial: () {
            setStateHere(
              () => _devPanelOpen = false,
            ); // yaklaşan kolon görünsün
            _devSummonImperial();
          },
          onForcePetition: _forcePetition,
          onForcePetitionShortFuse: () {
            setStateHere(() => _devPanelOpen = false); // mühür/modal görünsün
            _forcePetitionShortFuse();
          },
          onForcePetitionAudience: () {
            setStateHere(() => _devPanelOpen = false); // zorla modal görünsün
            _forcePetitionAudienceNow();
          },
          petitions: [
            for (final p in PetitionSystem.all) (p.id, '${p.icon} ${p.title}'),
          ],
          onForcePetitionId: _forcePetitionById,
          perfMode: _perfMode,
          onTogglePerf: () => setStateHere(() => _perfMode = !_perfMode),
          devLogOn: _devLogOn,
          onToggleDevLog: () => setStateHere(() {
            _devLogOn = !_devLogOn;
            if (!_devLogOn) _devLog.clear();
          }),
          simSpeedBoost: _devSpeedBoost,
          simHistory: [
            for (final s in _simHistory)
              SimSnapshot(
                simTime: s.simTime,
                day: s.day,
                population: s.population,
                buildings: s.buildings,
                wood: s.wood,
                stone: s.stone,
                iron: s.iron,
                coal: s.coal,
                food: s.food,
                gold: s.gold,
              ),
          ],
          onSetSimSpeed: (v) => setStateHere(() => _devSpeedBoost = v),
          onClearSimHistory: () => setStateHere(_simHistory.clear),
          activeScenario: _scenarioName,
          scenarioProgress: _scenarioProgress,
          lastReport: _lastReport == null
              ? null
              : ScenarioReport(
                  name: _lastReport!.name,
                  durationSec: _lastReport!.durationSec,
                  popStart: _lastReport!.popStart,
                  popEnd: _lastReport!.popEnd,
                  resources: _lastReport!.resources,
                  verdict: _lastReport!.verdict,
                  warnings: _lastReport!.warnings,
                ),
          onScenarioBaseline: _scenarioBaseline,
          onScenarioPlague: _scenarioPlague,
          onScenarioDrought: _scenarioDrought,
          onScenarioFire: _scenarioFire,
          onPlayMusic: () {
            if (!_devStartMusic()) {
              _showNotification('Uygun NPC yok');
            }
          },
          onStartDance: () {
            if (!_devStartDance()) {
              _showNotification('Yan yana iki yetişkin NPC bulunamadı');
            }
          },
          onStartChat: () {
            if (!_devStartChat()) {
              _showNotification('Yan yana iki yetişkin NPC bulunamadı');
            }
          },
          onStartConflict: () {
            if (!_devStartConflict()) {
              _showNotification('Yan yana iki uygun yetişkin NPC bulunamadı');
            }
          },
          onIgniteFeud: () => setStateHere(() {
            if (!_devIgniteFeud()) {
              _showNotification('Kan davası için 2 uygun köylü bulunamadı');
            }
          }),
          onStartCrime: () => setStateHere(() {
            if (!_devRandomCrime()) {
              _showNotification(
                _activeCrime != null
                    ? 'Zaten bir suç işleniyor'
                    : 'Uygun fail/hedef bulunamadı',
              );
            }
          }),
          onClearActivities: () => setStateHere(_devClearActivities),
          onMeteorShower: () => setStateHere(_startMeteorShower),
        ),
      ),
    );
  }

  // ── Event banner ───────────────────────────────────────────────────────────

  Widget buildEventBanner() {
    return Positioned(
      top: 90,
      left: 0,
      right: 0,
      child: Center(
        child: RepaintBoundary(
          child: ListenableBuilder(
            listenable: _frame,
            builder: (_, _) {
              final e = _activeEvent;
              if (e == null) return const SizedBox.shrink();
              // "İzle" yalnız BU olayın vinyeti hâlâ sahnedeyse çıkar —
              // bittiyse (ya da kadro bulunamadıysa) düğme de yok: oyuncuyu
              // boş bir tarlaya götürmek, hiç göndermemekten kötüdür.
              final vg = _vignette;
              final canWatch = vg != null && vg.eventId == e.id;
              return EventBanner(
                event: e,
                timeLeft: _activeEventLeft,
                duration: kEventBannerDuration,
                watchLabel: canWatch ? vg.title : null,
                onWatch: canWatch ? _watchVignette : null,
                onClose: () => setStateHere(() {
                  _activeEvent = null;
                  _activeEventLeft = 0;
                }),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Geçici bildirim balonu ─────────────────────────────────────────────────

  // Hover künyesi — DÜNYA-uzayı: imleci değil hedefi takip eder, köylü
  // yürüdükçe onunla gider. _frame'e bağlı (60fps) olduğu için hover olayının
  // kendisi hiçbir şey tetiklemez; input yalnız _hoverVillager/_hoverBuilding
  // alanlarını yazar. IgnorePointer: hover olaylarını yemez.
  Widget buildHoverLabel() {
    return Positioned.fill(
      child: IgnorePointer(
        child: ListenableBuilder(
          listenable: _frame,
          builder: (_, _) {
            // Sürükleme/seçim sırasında künye susar (iki bilgi katmanı çakışır).
            if (_draggedVillager != null) return const SizedBox.shrink();
            final v = _hoverVillager;
            final b = _hoverBuilding;
            final g = _hoverGrave;
            if (v == null && b == null && g == null) {
              return const SizedBox.shrink();
            }
            // 140ms beliriş — anlık pat diye çıkmasın, gecikmeli de hissetmesin.
            final fade = ((_time - _hoverSince) / 0.14).clamp(0.0, 1.0);
            final center = Offset(_viewSize.width / 2, _viewSize.height / 2);
            Offset toScreen(double gx, double gy) {
              final world = gridToScreen(gx, gy, _viewSize, _camera);
              return (world - center) * _zoom + center;
            }

            if (v != null) {
              final sc = kCharScale * v.lifeStage.renderScale * _zoom;
              final feet = toScreen(v.renderX, v.renderY);
              // Fare sabitken köylü yürüyüp gidebilir. O zaman künye onun
              // peşine takılıp ekranda gezmesin: gövde kutusundan çıktıysa
              // sadece ÇİZME (state'i temizleme — geri gelirse yine belirir).
              // Kutu geometrisi hit-test ile birebir (scene_world).
              final probe = _hoverProbe;
              if (probe != null) {
                final dx = (probe.dx - feet.dx).abs();
                final dy = (probe.dy - (feet.dy - 36 * sc)).abs();
                if (dx > (16.0 * sc).clamp(15.0, 60.0) ||
                    dy > (42.0 * sc).clamp(20.0, 90.0)) {
                  return const SizedBox.shrink();
                }
              }
              // Sprite tepesi ayak noktasından ~126 birim yukarıda (şapka
              // dahil; ui_gallery world_tag karesinden ölçüldü). DİKKAT:
              // _villagerAtScreen'deki 36/42 değerleri hit-test KUTUSUdur,
              // sprite boyu değil — künyeyi ondan türetmek şapkanın içine
              // yazar (ilk sürümün hatası).
              final top = feet.dy - 126 * sc;
              return Stack(
                children: [
                  WorldTagRing(
                    feet: feet,
                    radius: (14.0 * sc).clamp(11.0, 40.0),
                    opacity: fade,
                  ),
                  WorldTag(
                    anchor: Offset(
                      _tagX(feet.dx),
                      (top - 8).clamp(46.0, _viewSize.height),
                    ),
                    title: v.name,
                    line2: _tagIdentity(v),
                    line3: '${_tagDoing(v)} · ${_tagMood(v)}',
                    opacity: fade,
                  ),
                ],
              );
            }
            if (b != null) {
              final feet = toScreen(
                b.col + (b.cols - 1) / 2.0,
                b.row + (b.rows - 1) / 2.0,
              );
              // Çatı yüksekliği kabaca satır sayısından türer (bina sprite'ları
              // taban derinliğiyle birlikte uzar).
              final top = feet.dy - (44 + 20 * b.rows) * _zoom;
              return Stack(
                children: [
                  WorldTag(
                    anchor: Offset(
                      _tagX(feet.dx),
                      (top - 6).clamp(46.0, _viewSize.height),
                    ),
                    title: kBuildingMeta[b.type]?.label ?? '—',
                    line2: _buildingHoverSub(b),
                    line3: '',
                    opacity: fade,
                  ),
                ],
              );
            }
            final feet = toScreen(g!.col, g.row);
            return Stack(
              children: [
                WorldTag(
                  anchor: Offset(
                    _tagX(feet.dx),
                    (feet.dy - 34 * _zoom).clamp(46.0, _viewSize.height),
                  ),
                  title: g.name,
                  line2: 'huzur içinde yatıyor',
                  line3: '',
                  opacity: fade,
                  accent: const Color(0xFF7E86A0),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Künye ekran kenarından taşmasın — genişliği bilinmediği için kaba pay.
  double _tagX(double x) =>
      _viewSize.width < 220 ? x : x.clamp(96.0, _viewSize.width - 96.0);

  /// Künye 2. satırı: kim. Meslek + hangi hane (haneler sistemi ön planda —
  /// "kim kimin adamı" bir bakışta okunmalı).
  String _tagIdentity(VillagerEntity v) {
    final craft = v.hasProfession ? v.type.displayName : 'köylü';
    if (v.surname.isNotEmpty) return '$craft · ${v.surname} Hanesi';
    return v.homeBuilding == null ? '$craft · evsiz' : craft;
  }

  /// Künye 3. satırı, ilk yarısı: şu an ne yapıyor. Durum bozucular (hasta/
  /// yaralı/ceza) her şeyin önünde — oyuncunun görmesi gereken ilk şey o.
  String _tagDoing(VillagerEntity v) {
    if (v.activity == VillagerActivity.abducted) return 'kaçırıldı';
    if (v.laborDays > 0) return 'kürek çekiyor';
    if (v.sickDays > 0) return 'hasta';
    if (v.injuryDays > 0) return 'yaralı';
    switch (v.activity) {
      case VillagerActivity.chat:
        return 'sohbet ediyor';
      case VillagerActivity.music:
        return 'çalıyor';
      case VillagerActivity.dance:
        return 'oynuyor';
      case VillagerActivity.warm:
        return 'ısınıyor';
      case VillagerActivity.storytelling:
        return 'hikâye anlatıyor';
      case VillagerActivity.listening:
        return 'dinliyor';
      case VillagerActivity.arguing:
        return 'atışıyor';
      case VillagerActivity.brawling:
        return 'kavgada';
      case VillagerActivity.prowling:
        return 'sinsice dolaşıyor';
      case VillagerActivity.committing:
        return 'suçüstü';
      case VillagerActivity.fleeing:
        return 'kaçıyor';
      case VillagerActivity.chasing:
        return 'peşinde';
      case VillagerActivity.playing:
        return 'oyunda';
      case VillagerActivity.none:
      case VillagerActivity.abducted:
        break;
    }
    if (v.isSleeping) return 'uyuyor';
    if (v.isSeatedAtFire) return 'ateş başında';
    if (v.isCarrying) return 'yük taşıyor';
    switch (v.job?.role) {
      case JobRole.builder:
        return 'inşaatta';
      case JobRole.farmer:
        return 'tarlada';
      case JobRole.miner:
        return 'ocakta';
      case JobRole.fisher:
        return 'balıkta';
      case JobRole.florist:
        return 'çiçek topluyor';
      case JobRole.shepherd:
        return 'sürünün başında';
      case JobRole.woodcutter:
        return 'odun kesiyor';
      case JobRole.forager:
        return 'böğürtlen topluyor';
      case JobRole.cook:
        return 'yemek pişiriyor';
      case JobRole.weaver:
        return 'dokuma tezgâhında';
      case JobRole.none:
      case null:
        break;
    }
    return v.isWalking ? 'yolda' : 'boşta';
  }

  /// Künye 3. satırı, ikinci yarısı: ruh hâli. Sayı/yüzde YOK, tek kelime öbeği
  /// (baş üstü sayısal refleksiyon oyunun dilini bozar).
  String _tagMood(VillagerEntity v) {
    final m = v.morale;
    if (m >= 0.82) return 'neşesi yerinde';
    if (m >= 0.62) return 'keyfi iyi';
    if (m >= 0.45) return 'idare eder';
    if (m >= 0.30) return 'keyifsiz';
    if (m >= 0.16) return 'kırgın';
    return 'bezgin';
  }
}
