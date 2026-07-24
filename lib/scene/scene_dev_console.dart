part of '../main.dart';

/// Geliştirici komut konsolu — sahne tarafı. Buton-başına-closure modelini
/// (buildDevPanel) tek bir kayıt defterine taşır: her dev aksiyonu artık
/// listedeki bir [DevCommand]. Konsol backtick (`) ile açılır; arama/parametre/
/// kayıt-oynatma orada. Yeni aksiyon = bu listeye 1 giriş.
///
/// [[dev_command]] saf modeli, [[dev_console]] UI'ı; burası ikisini sahneye
/// (setStateHere + tüm _dev* yardımcıları) bağlayan yer.
extension _SceneDevConsole on _VillageSceneState {
  // ── Komut kayıt defteri ─────────────────────────────────────────────────
  /// Konsolun listelediği tüm dev komutları. Her build'de yeniden kurulur —
  /// closure'lar sahne state'ini yakalar (buildDevPanel'in yaptığı gibi).
  List<DevCommand> _buildDevCommands() {
    final petitionChoices = <(String, String)>[
      for (final p in PetitionSystem.all) (p.id, '${p.icon} ${p.title}'),
    ];
    final resourceChoices = <(String, String)>[
      for (final k in ResourceKind.values) (k.name, '${k.icon} ${k.label}'),
    ];

    return [
      // ── NÜFUS ──────────────────────────────────────────────────────────
      DevCommand(
        id: 'spawn.villager',
        label: 'Köylü Spawnla',
        category: DevCat.nufus,
        hint: 'Ateş başında N yetişkin köylü',
        params: const [
          DevParam.integer('count', 'Adet', intDefault: 1, intMin: 1, intMax: 20),
        ],
        run: (a) {
          final fp = _firepitBuilding;
          if (fp == null) return;
          setStateHere(() {
            for (var i = 0; i < a.getInt('count', 1); i++) {
              _spawnGrownVillager(fp);
            }
          });
        },
      ),
      DevCommand(
        id: 'spawn.migrant',
        label: 'Göçmen Çağır',
        category: DevCat.nufus,
        hint: 'Dışarıdan yeni hane',
        params: const [
          DevParam.integer('count', 'Adet', intDefault: 1, intMin: 1, intMax: 10),
        ],
        run: (a) => setStateHere(() {
          for (var i = 0; i < a.getInt('count', 1); i++) {
            _spawnMigrant();
          }
        }),
      ),
      DevCommand(
        id: 'kill.random',
        label: 'Rastgele Köylüyü Öldür',
        category: DevCat.nufus,
        hint: 'Cenaze/mezarlık akışını test et',
        run: (a) {
          if (_villagers.isEmpty) return;
          setStateHere(() {
            final v = _villagers[_rng.nextInt(_villagers.length)];
            v.ageDays = v.lifespanDays + 1;
          });
        },
      ),
      DevCommand(
        id: 'make.sage',
        label: 'Bilge Ata',
        category: DevCat.nufus,
        hint: 'Bir yaşlıyı köyün bilgesi yap',
        run: (a) => setStateHere(_devMakeSage),
      ),

      // ── YÖNETİŞİM ──────────────────────────────────────────────────────
      DevCommand(
        id: 'imperial.summon',
        label: 'İmparatorluk Çağır',
        category: DevCat.yonetisim,
        hint: 'Vergi heyeti kolonunu yürüt (rutin: filmsiz, doğrudan modal)',
        run: (a) {
          setStateHere(() => _devConsoleOpen = false); // sinematik görünsün
          _devSummonImperial();
        },
      ),
      DevCommand(
        id: 'imperial.summonFilm',
        label: 'İmparatorluk Çağır (kinli)',
        category: DevCat.yonetisim,
        hint: 'Ton değişmiş ziyaret — geliş sinematiğini zorlar',
        run: (a) {
          setStateHere(() {
            _devConsoleOpen = false;
            _impGrudge = true; // merdiveni tetikler (bkz. _startImperialParley)
          });
          _devSummonImperial();
        },
      ),
      DevCommand(
        id: 'anim.room',
        label: 'Animasyon Odası',
        category: DevCat.yonetisim,
        hint: 'Sinematik + karakter animasyonlarını canlı dene',
        run: (a) {
          setStateHere(() => _devConsoleOpen = false);
          openAnimationRoom(context);
        },
      ),
      DevCommand(
        id: 'petition.force',
        label: 'Dilekçe Getir',
        category: DevCat.yonetisim,
        hint: 'Rastgele bekleyen dilekçe',
        run: (a) => _forcePetition(),
      ),
      DevCommand(
        id: 'petition.forceId',
        label: 'Belirli Dilekçe Getir',
        category: DevCat.yonetisim,
        hint: 'İsimle seç',
        params: [DevParam.choice('id', 'Dilekçe', petitionChoices)],
        run: (a) => _forcePetitionById(a.getStr('id')),
      ),
      DevCommand(
        id: 'petition.shortFuse',
        label: 'Dilekçe: Kısa Mühlet',
        category: DevCat.yonetisim,
        hint: 'Mühleti kısalt (mühür/modal görünür)',
        run: (a) {
          setStateHere(() => _devConsoleOpen = false);
          _forcePetitionShortFuse();
        },
      ),
      DevCommand(
        id: 'policies.sealGecim',
        label: 'Geçim Yasalarını Mühürle',
        category: DevCat.yonetisim,
        hint: 'GEÇİM kolunun uygun tüm hükümleri',
        run: (a) => setStateHere(() {
          for (final l in LawBook.ofBranch(LawBranch.gecim)) {
            if (LawBook.available(l, _policies.sealed, _lawContext)) {
              _policies.seal(l);
            }
          }
          _policies.inkDryUntilSim = 0;
          _applyPolicySideChannels();
        }),
      ),
      // ── REJİM (scene_regime) ──
      DevCommand(
        id: 'regime.status',
        label: 'Rejim Durumu',
        category: DevCat.yonetisim,
        hint: 'Kimlik + yetki + huzursuzluk',
        run: (a) {
          final p = _compassPos;
          final id = _regimeIdentity;
          final r = _regimeRule;
          logDev('⚑ ${id.icon} ${id.title} — ${r.powerTitle} '
              '${id.committed ? '(kökleşti)' : '(eğilim)'}'
              '${_oathRegime != null ? ' · YEMİNLİ' : ''}');
          logDev('⚑ otorite ${p.authority.toStringAsFixed(2)} · '
              'iktisat ${p.economy.toStringAsFixed(2)} · '
              'iman ${p.faith.toStringAsFixed(2)} · '
              'mühür ${p.lawCount}');
          logDev('⚑ huzursuzluk ${(_unrest * 100).round()}% '
              '(${Regime.unrestLabel(_unrest)}) · kriz ${r.crisis.name} · '
              'mürekkep ×${r.inkDryMul} · '
              'meclis ${r.councilDecides ? 'karar verir' : 'karar vermez'}');
        },
      ),
      DevCommand(
        id: 'regime.unrest',
        label: 'Huzursuzluk Ayarla',
        category: DevCat.yonetisim,
        hint: 'Krizi hemen kaynatmak için',
        params: [
          DevParam.integer('v', 'Değer (%)', intDefault: 90, intMax: 100),
        ],
        run: (a) => setStateHere(() {
          _unrest = (a.getInt('v', 90) / 100).clamp(0.0, 1.0);
          _crisisCooldown = 0;
        }),
      ),
      DevCommand(
        id: 'regime.oath',
        label: 'Köyün Yeminini Ettir',
        category: DevCat.yonetisim,
        hint: 'Kararlılık eşiğini atlar (rejim fermanlarını açar)',
        run: (a) {
          final id = _regimeIdentity;
          if (id.regime == VillageRegime.moderate) {
            logDev('⚑ Ilımlı köy yemin edemez — önce bir yöne yat.');
            return;
          }
          setStateHere(() => _villageMemory.add(Regime.oathFlag(id.regime)));
          _lawCtxCache = null;
          logDev('⚑ ${id.title} yemini edildi (dev).');
        },
      ),
      // Kademeli açılımı canlı denerken: hangi hüküm neden kapalı? Bildirim
      // beklemeden defterin o anki hâlini olay günlüğüne döker.
      DevCommand(
        id: 'policies.gates',
        label: 'Kanunname Kapıları',
        category: DevCat.yonetisim,
        hint: 'Açık/kapalı hükümler + gerekçe',
        run: (a) {
          final ctx = _lawContext;
          final open = LawBook.openAgenda(_policies.sealed, ctx);
          logDev('📜 KAPILAR — nüfus ${ctx.population} · gün ${ctx.dayCount} · '
              'hane ${ctx.households} · tarla ${ctx.farmTiles} · '
              'hayvan ${ctx.animals} · mezar ${ctx.deaths} · '
              'suç ${ctx.crimesSeen} · zanaat ${ctx.knownCrafts.length}');
          logDev('📜 AÇIK (${open.length}/${kLawBook.length}): '
              '${open.map((l) => l.title).join(', ')}');
          for (final l in kLawBook) {
            if (_policies.sealed.contains(l.id)) continue;
            if (!LawBook.gateLocked(l, ctx)) continue;
            logDev('🔒 ${l.title} — ${l.gateReason}');
          }
        },
      ),
      DevCommand(
        id: 'policies.clear',
        label: 'Tüm Yasaları Sil',
        category: DevCat.yonetisim,
        run: (a) => setStateHere(() {
          _policies.restoreSealed(const []);
          _policies.inkDryUntilSim = 0;
          _applyPolicySideChannels();
        }),
      ),

      // ── OLAYLAR / AKTİVİTE ─────────────────────────────────────────────
      DevCommand(
        id: 'feud.ignite',
        label: 'Kan Davası Başlat',
        category: DevCat.olay,
        hint: 'İki uygun köylü arası vendetta',
        run: (a) => setStateHere(() {
          if (!_devIgniteFeud()) {
            _showNotification('Kan davası için 2 uygun köylü bulunamadı');
          }
        }),
      ),
      DevCommand(
        id: 'crime.random',
        label: 'Rastgele Suç',
        category: DevCat.olay,
        run: (a) => setStateHere(() {
          if (!_devRandomCrime()) {
            _showNotification(_activeCrime != null
                ? 'Zaten bir suç işleniyor'
                : 'Uygun fail/hedef bulunamadı');
          }
        }),
      ),
      DevCommand(
        id: 'meteor.shower',
        label: 'Meteor Yağmuru',
        category: DevCat.olay,
        run: (a) => setStateHere(_startMeteorShower),
      ),
      DevCommand(
        id: 'activity.dance',
        label: 'Dans Başlat',
        category: DevCat.aktivite,
        run: (a) {
          if (!_devStartDance()) {
            _showNotification('Yan yana iki yetişkin NPC bulunamadı');
          }
        },
      ),
      DevCommand(
        id: 'activity.chat',
        label: 'Sohbet Başlat',
        category: DevCat.aktivite,
        run: (a) {
          if (!_devStartChat()) {
            _showNotification('Yan yana iki yetişkin NPC bulunamadı');
          }
        },
      ),
      DevCommand(
        id: 'activity.music',
        label: 'Müzik Başlat',
        category: DevCat.aktivite,
        run: (a) {
          if (!_devStartMusic()) _showNotification('Uygun NPC yok');
        },
      ),
      DevCommand(
        id: 'activity.conflict',
        label: 'Çekişme Başlat',
        category: DevCat.aktivite,
        run: (a) {
          if (!_devStartConflict()) {
            _showNotification('Yan yana iki uygun yetişkin NPC bulunamadı');
          }
        },
      ),
      DevCommand(
        id: 'activity.clear',
        label: 'Aktiviteleri Temizle',
        category: DevCat.aktivite,
        run: (a) => setStateHere(_devClearActivities),
      ),

      // ── ZAMAN & HAVA ───────────────────────────────────────────────────
      DevCommand(
        id: 'time.set',
        label: 'Saati Ayarla',
        category: DevCat.zaman,
        params: const [
          DevParam.choice('phase', 'Vakit', [
            ('dawn', '🌅 Şafak'),
            ('noon', '☀ Öğle'),
            ('dusk', '🌆 Akşam'),
            ('night', '🌙 Gece'),
          ], choiceDefault: 'noon'),
        ],
        run: (a) => setStateHere(() {
          _cycle.timeOfDay = switch (a.getStr('phase', 'noon')) {
            'dawn' => 0.22,
            'dusk' => 0.78,
            'night' => 0.92,
            _ => 0.50,
          };
        }),
      ),
      DevCommand(
        id: 'rain.set',
        label: 'Yağmuru Ayarla',
        category: DevCat.zaman,
        params: const [
          DevParam.choice('level', 'Şiddet', [
            ('off', 'Kapalı'),
            ('light', 'Hafif'),
            ('heavy', 'Sağanak'),
          ], choiceDefault: 'off'),
        ],
        run: (a) => setStateHere(() {
          _cycle.rainIntensity = switch (a.getStr('level', 'off')) {
            'light' => 0.4,
            'heavy' => 0.85,
            _ => 0.0,
          };
        }),
      ),

      // ── EKONOMİ ────────────────────────────────────────────────────────
      DevCommand(
        id: 'resource.add',
        label: 'Kaynak Ekle',
        category: DevCat.ekonomi,
        params: [
          DevParam.choice('kind', 'Kaynak', resourceChoices),
          const DevParam.integer('amount', 'Miktar',
              intDefault: 50, intMin: 1, intMax: 999),
        ],
        run: (a) {
          final kind = ResourceKind.values
              .firstWhere((k) => k.name == a.getStr('kind'), orElse: () => ResourceKind.wood);
          setStateHere(() {
            _stockpile.add(kind, a.getInt('amount', 50));
            final cur = _stockpile.get(kind);
            if (cur < 0) _stockpile.add(kind, -cur);
          });
        },
      ),
      DevCommand(
        id: 'crafts.unlockAll',
        label: 'Tüm Zanaatları Aç',
        category: DevCat.ekonomi,
        run: (a) => setStateHere(() {
          _knownCrafts.addAll(Craft.all);
          _showNotification('⚒ Tüm zanaatlar açıldı');
        }),
      ),

      // ── KÖY KURULUMU ───────────────────────────────────────────────────
      DevCommand(
        id: 'village.seedLiving',
        label: 'Canlı Köy Kur',
        category: DevCat.koy,
        hint: 'Dengeli, oynanabilir başlangıç köyü',
        run: (a) {
          _buildLivingVillage();
          setStateHere(() {});
        },
      ),
      DevCommand(
        id: 'village.showcase',
        label: 'Showcase Köyü',
        category: DevCat.koy,
        hint: 'Her sistemden örnek — vitrin köyü',
        run: (a) {
          _buildShowcaseVillage();
          setStateHere(() {
            _devConsoleOpen = false;
            _godMode = true;
          });
        },
      ),
    ];
  }

  /// onMakeSage'in inline mantığı (buldDevPanel'den taşındı).
  void _devMakeSage() {
    for (final v in _villagers) {
      v.isSage = false;
    }
    var elders = _villagers.where((v) => v.lifeStage == LifeStage.elder).toList();
    if (elders.isEmpty) {
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
  }

  // ── Built-in senaryolar (kodda gömülü, silinemez) ────────────────────────
  /// Kayıt yapmadan bile tek tıkla bir DURUMU kuran hazır diziler.
  List<DevScript> _devBuiltinScripts() => const [
        DevScript(
          '⚔ Politik Fırtına',
          [
            DevInvocation('feud.ignite'),
            DevInvocation('crime.random'),
            DevInvocation('petition.force'),
          ],
          builtin: true,
        ),
        DevScript(
          '🏛 İmparatorluk Baskını',
          [DevInvocation('imperial.summon')],
          builtin: true,
        ),
        DevScript(
          '🌾 Canlı Köy + Göç',
          [
            DevInvocation('village.seedLiving'),
            DevInvocation('spawn.migrant', {'count': 3}),
          ],
          builtin: true,
        ),
        DevScript(
          '🌙 Gece Hayatı',
          [
            DevInvocation('time.set', {'phase': 'night'}),
            DevInvocation('activity.music'),
            DevInvocation('activity.dance'),
          ],
          builtin: true,
        ),
      ];

  /// Built-in + oturumda kaydedilmiş senaryolar birlikte.
  List<DevScript> get _devAllScripts =>
      [..._devBuiltinScripts(), ..._devUserScripts];

  // ── Çalıştırma & oynatma ─────────────────────────────────────────────────
  /// Konsoldan tek komut çalıştır + kayıt açıksa adımı yakala.
  void _runDevCommand(DevCommand cmd, DevArgs args) {
    cmd.run(args);
    _devRecorder.capture(cmd.id, args.values);
  }

  /// Bir senaryoyu baştan sona oynat (kayıt YAPMAZ — replay adımları
  /// tekrar tampona düşmesin).
  void _replayDevScript(DevScript script) {
    final byId = {for (final c in _buildDevCommands()) c.id: c};
    for (final step in script.steps) {
      final cmd = byId[step.commandId];
      if (cmd != null) cmd.run(DevArgs(step.args));
    }
    _showNotification('▶ "${script.name}" oynatıldı (${script.steps.length} adım)');
  }

  // ── Kalıcılık ────────────────────────────────────────────────────────────
  /// Açılışta diskteki senaryoları listeye al (initState'ten çağrılır).
  Future<void> _loadDevScripts() async {
    final saved = await DevScriptStore.instance.load();
    if (saved.isEmpty || !mounted) return;
    setStateHere(() {
      _devUserScripts
        ..clear()
        ..addAll(saved);
    });
  }

  /// Kullanıcı senaryolarını diske yaz (built-in'ler kodda, yazılmaz).
  void _persistDevScripts() => DevScriptStore.instance.save(_devUserScripts);

  /// Kaydedilmiş bir senaryoyu sil (built-in silinemez).
  void _deleteDevScript(DevScript script) {
    if (script.builtin) return;
    setStateHere(() => _devUserScripts.remove(script));
    _persistDevScripts();
    _showNotification('🗑 "${script.name}" senaryosu silindi');
  }

  // ── Overlay ──────────────────────────────────────────────────────────────
  Widget buildDevConsole() {
    return DevConsole(
      commands: _buildDevCommands(),
      recorder: _devRecorder,
      scripts: _devAllScripts,
      onRun: _runDevCommand,
      onRunScript: _replayDevScript,
      onSaveScript: (name) {
        final s = _devRecorder.freeze(name);
        setStateHere(() => _devUserScripts.add(s));
        _persistDevScripts();
        _showNotification('💾 "$name" senaryosu kaydedildi (kalıcı)');
      },
      onDeleteScript: _deleteDevScript,
      onClose: () {
        setStateHere(() => _devConsoleOpen = false);
        _devKeyFocus.requestFocus();
      },
    );
  }
}
