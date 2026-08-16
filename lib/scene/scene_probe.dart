part of '../main.dart';

/// PROVA — köyün yaşadığının SAYIYLA kanıtı.
///
/// "Tek tek NPC izleyemem" sorununun cevabı. Bu extension köyün o anki
/// davranış durumunu tek bir okunur metne indirger: niyet dağılımı, elde
/// taşınan nesneler, dürtü ortalamaları, algı/dedikodu/ihbar sayaçları, köyün
/// hâli. Harness ([lib/tools/living_probe_main.dart]) bunu hızlandırılmış
/// simülasyonda periyodik basar → köyün dört fazının uçtan uca çalıştığı
/// ekranda bir köylüye bakmadan görülür.
///
/// Salt okunur: hiçbir şeyi değiştirmez, yalnız durumu özetler.
extension _SceneProbe on _VillageSceneState {
  /// Prova tick — harness açıkken periyodik rapor üretir + istenirse suç
  /// tetikler. Rapor gün-içi değil GÜN eşiğinde değil, sabit sim-saniye
  /// aralığıyla basılır ki hızlandırmadan bağımsız düzenli akış olsun.
  void _tickProbe(double dt) {
    // FAZ 4 TELEMETRİSİ — hırsızlık sahnesinin ânları HER TICK dışarı yazılır.
    // Rapor metnine bakmak yetmez: "içeride" penceresi birkaç saniyedir ve
    // yarım günlük rapor aralığında görünmez. Test bunları her pump'ta okur.
    final ac = _activeCrime;
    kProbeTheftInside = ac?.inside ?? false;
    kProbeTheftSack = ac?.culprit.prop == PropKind.sack;
    kProbeLootCount = _lootCaches.length;
    kProbeLootTotal = _lootCaches.fold<int>(0, (a, l) => a + l.amount);
    kProbeStockTotal = _stockpile.food + _stockpile.wood + _stockpile.stone;

    // GÖVDE DİLİ — selam gövdede mi oynuyor, baş üstüne emoji geri sızdı mı.
    // İkisi de YAPIŞKAN: jest 1,6 saniyelik, örnekleme aralığına denk gelmesi
    // şansa kalırdı (bkz. CLAUDE.md §4 "ölçüm aralığı" tuzağı).
    for (final v in _villagers) {
      if (v.waveTime > 0) kProbeWaveSeen = true;
      if (const {'👋', '📖', '🌠'}.contains(v.chatBubbleIcon)) {
        kProbeBannedBubble = v.chatBubbleIcon;
      }
    }

    if (kProbePlantLoot) {
      kProbePlantLoot = false;
      _devPlantLoot();
    }

    // Heyeti çağır — buradan sonrası simde değil MODALDE geçer (sim durur),
    // o yüzden çağrı tek seferlik: sahne bayrağı hemen tüketir.
    if (kProbeSummonImperial) {
      kProbeSummonImperial = false;
      _devSummonImperial();
    }

    // KARAR İZİ — güncedeki karar satırları. En sinsi hata "kod var ama hiç
    // tetiklenmiyor": dilekçe kararının kroniğe düşmesi ancak GERÇEK sahnede,
    // gerçek bir kararla görülür (bkz. test/decision_trace_probe_test.dart).
    var decisions = 0;
    for (final e in _storyLog) {
      if (e.kind != ChronicleKind.decision) continue;
      decisions++;
      kProbeLastDecision = e.text;
    }
    kProbeDecisionLines = decisions;

    // Harness karar istiyorsa: bekleyen dilekçe varsa İLK şıkkı seç (oyuncu
    // gibi), yoksa kuyruğu hemen aç.
    // KAYIT GİDİŞ-DÖNÜŞÜ — kaydet ve hemen geri yükle (bkz. kProbeSaveRoundtrip).
    if (kProbeSaveRoundtrip) {
      kProbeSaveRoundtrip = false;
      try {
        final encoded = jsonEncode(captureWorld());
        kProbeWorldJson = encoded;
        restoreWorld(Map<String, dynamic>.from(
            jsonDecode(encoded) as Map<String, dynamic>));
        kProbeSaveError = '';
      } catch (e) {
        kProbeSaveError = '$e';
      }
    }

    // Harness belirli bir kaydı açmak istiyorsa (ör. alanları silinmiş ESKİ
    // sürüm kaydı) onu yükle.
    if (kProbeRestoreJson.isNotEmpty) {
      final raw = kProbeRestoreJson;
      kProbeRestoreJson = '';
      try {
        restoreWorld(Map<String, dynamic>.from(
            jsonDecode(raw) as Map<String, dynamic>));
        kProbeSaveError = '';
      } catch (e) {
        kProbeSaveError = '$e';
      }
    }

    kProbePendingPetition = _pendingPetition?.id ?? '';
    if (kProbeDecideNow) {
      final p = _pendingPetition;
      if (p != null && p.options.isNotEmpty) {
        kProbeDecideNow = false;
        _resolvePetition(p, p.options.first);
      } else {
        _petitionTimer = 0; // kuyruk hemen açılsın (yönetişim uyanıksa)
      }
    }

    // Harness suç istediyse tüket (aktif suç yoksa ve nüfus yeterse).
    if (kProbeTriggerCrime && _activeCrime == null && _villagers.length >= 5) {
      kProbeTriggerCrime = false;
      for (final v in _villagers) {
        v.crimeCooldown = 0;
      }
      // Harness belirli bir suç istediyse onu kur. İzleme dökümünde hırsızlığın
      // Faz 4 sahnesi (gir → çuval → göm) ancak böyle görünür oluyor: rastgele
      // seçimde 10 suç türü içinden nadiren çıkıyor ve özellik "yazıldı ama
      // kimse görmedi" hâlinde kalıyordu.
      final forced = kCaptureCrimeKind;
      if (forced != null) {
        _devStartCrime(forced);
      } else {
        _devRandomCrime();
      }
    }

    _probeTimer += dt;
    if (_probeTimer < _kProbeInterval) return;
    _probeTimer = 0;
    kProbeReport = probeReport();
    kProbeReportSeq++;
  }

  /// Rapor aralığı (sim sn). Hızlandırmayla wall-clock saniyeler mertebesine
  /// iner.
  ///
  /// TUZAK — ÖLÇÜM TAKMASI: bu değer YARIM GÜNDÜ (0.5). Gün uzunluğunun tam
  /// böleni olduğu için her örnek saatin AYNI iki noktasına düşüyordu (~08 ve
  /// ~20) ve prova saatin geri kalanını hiç göremiyordu. Gecenin ortası hiç
  /// örneklenmediği için "20:00'de kimse uyumuyor" gibi yanıltıcı bir tablo
  /// çıkıyordu — oysa 20:00 herkesin yatağa YÜRÜDÜĞÜ andı (walkingToSleep
  /// "yürüyen" sayılır). 0.43 günle örnek noktası her turda kayar, birkaç
  /// günde saatin tamamı taranır; rapor sayısı yaklaşık aynı kalır.
  static const double _kProbeInterval = 0.43 * kGameDaySeconds;

  /// Köyün o anki davranış özeti — çok satırlı, okunur.
  String probeReport() {
    final sb = StringBuffer();
    final day = _dayCount;
    final tod = (_cycle.timeOfDay * 24).toStringAsFixed(0).padLeft(2, '0');
    final phase = _cycle.dayLight < 0.35
        ? 'gece'
        : _cycle.dayLight < 0.6
            ? 'alacakaranlık'
            : 'gündüz';
    sb.writeln('─── GÜN $day · saat ~$tod ($phase) · ${_season.label} · '
        '${_regimeIdentity.title} ───');

    // ── NİYET DAĞILIMI — kim ne yapıyor (Faz 1) ────────────────────────────
    final intents = <IntentKind, int>{};
    final props = <PropKind, int>{};
    var walking = 0, asleep = 0, acting = 0;
    final driveSum = <Drive, double>{for (final d in Drive.values) d: 0};
    for (final v in _villagers) {
      intents[v.mind.intent.kind] = (intents[v.mind.intent.kind] ?? 0) + 1;
      if (v.prop != PropKind.none) {
        props[v.prop] = (props[v.prop] ?? 0) + 1;
      }
      if (v.isWalking) walking++;
      if (v.isSleeping) asleep++;
      if (v.act != null) acting++;
      for (final d in Drive.values) {
        driveSum[d] = driveSum[d]! + v.mind.drive(d);
      }
    }
    final n = _villagers.length;
    sb.writeln('nüfus $n · yürüyen $walking · uyuyan $asleep · sahnede $acting');
    final intentCounts =
        intents.map((k, v) => MapEntry(intentLabel(k), v));
    sb.writeln('NİYET: ${_fmtCounts(intentCounts)}');

    // ── ELDE NE VAR (Faz 3) ────────────────────────────────────────────────
    final propCounts = props.map((k, v) => MapEntry(propLabel(k), v));
    sb.writeln('ELDE: ${props.isEmpty ? '—' : _fmtCounts(propCounts)}');

    // ── DÜRTÜ ORTALAMALARI (Faz 1) ─────────────────────────────────────────
    if (n > 0) {
      final parts = <String>[];
      for (final d in Drive.values) {
        final avg = driveSum[d]! / n;
        if (avg >= 0.12) parts.add('${driveLabel(d)} ${(avg * 100).round()}');
      }
      sb.writeln('DÜRTÜ (ort): ${parts.isEmpty ? 'hepsi düşük' : parts.join(' · ')}');
    }

    // ── ALGI / HAFIZA / DEDİKODU / İHBAR (Faz 2) ───────────────────────────
    var withMemory = 0, totalRecoll = 0, withOpinion = 0, suspecting = 0;
    for (final v in _villagers) {
      if (!v.memory.isEmpty) withMemory++;
      totalRecoll += v.memory.recollections.length;
      if (v.memory.opinion.isNotEmpty) withOpinion++;
      for (final o in _villagers) {
        if (!identical(o, v) && v.memory.suspects(o)) {
          suspecting++;
          break;
        }
      }
    }
    sb.writeln('HAFIZA: $withMemory köylü bir şey hatırlıyor '
        '($totalRecoll anı) · $withOpinion köylünün kanaati var · '
        '$suspecting köylü birinden şüpheleniyor');
    sb.writeln('SAYAÇ (kümülatif): tanıklık $_probeWitnessed · '
        'dedikodu $_probeGossip · ihbar $_probeInformed · '
        'işlenen suç $_crimesSeen · meçhul şüphe $_crimeSuspicion');

    // ── KÖYÜN HÂLİ (Faz 0) ─────────────────────────────────────────────────
    final pr = _pressure.readout;
    if (pr.isNotEmpty) {
      sb.writeln('KÖYÜN HÂLİ: ${pr.join(' · ')}');
    }
    final duty = _villagers.where((v) => v.nightDuty).length;
    final paused = _villagers.where((v) => v.workPause > 0).length;
    if (duty > 0 || paused > 0) {
      sb.writeln('nöbetçi $duty · paydosta $paused');
    }

    // ── AKTİF SUÇ (Faz 2/4) ────────────────────────────────────────────────
    if (_activeCrime case final c?) {
      // Hırsızlığın Faz 4 sahnesi evre adından okunmaz (girme/çuval/gömme
      // hepsi act+flee içinde geçer) → nerede olduğunu açıkça yaz.
      final beat = c.kind != CrimeKind.theft
          ? ''
          : c.inside
              ? ' [İÇERİDE]'
              : c.buried
                  ? ' [GÖMDÜ]'
                  : c.lootAmount > 0
                      ? ' [ÇUVALLA: ${c.lootAmount} ${c.lootKind?.label ?? ''}]'
                      : '';
      sb.writeln('⚠ SUÇ YÜRÜYOR: ${c.culprit.name} — '
          '${c.def.label} (${c.phase.name})$beat @ ${c.place}');
    }
    if (_lootCaches.isNotEmpty) {
      final total = _lootCaches.fold<int>(0, (a, l) => a + l.amount);
      sb.writeln('ZULA: ${_lootCaches.length} gömü · $total mal toprakta');
    }

    return sb.toString();
  }

  /// Sıralı sayaç dökümü (en çoktan aza).
  String _fmtCounts(Map<String, int> m) {
    if (m.isEmpty) return '—';
    final entries = m.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => '${e.key} ${e.value}').join(' · ');
  }
}
