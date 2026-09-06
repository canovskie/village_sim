part of '../main.dart';

/// Saf [DecisionPacing] kuyruğundaki bir dilekçenin sahne payload'u.
class _PacedPetition {
  final String requestId;
  final Petition petition;
  final VillagerEntity? author;
  final Map<String, String> extra;

  const _PacedPetition({
    required this.requestId,
    required this.petition,
    required this.author,
    required this.extra,
  });
}

/// Saf kuyruktaki seçimli olayın katalog nesnesi.
class _PacedChoice {
  final String requestId;
  final EventOutcome event;

  const _PacedChoice({required this.requestId, required this.event});
}

extension _SceneDecisionPacing on _VillageSceneState {
  double get _decisionDay => _time / kGameDaySeconds;

  /// Dilekçeyi ağır-karar bütçesine teslim eder. Suç hükmü belgelenmiş acildir:
  /// aktif kararı gasp etmez, fakat normal bir kararın sessizliğini aşabilir.
  void _requestPacedPetition(
    Petition petition, {
    VillagerEntity? author,
    Map<String, String> extra = const {},
  }) {
    final crime = petition.id == 'crimeVerdict';
    final admission = _decisionPacing.request(
      crime ? HeavyDecisionKind.crimeVerdict : HeavyDecisionKind.petition,
      atDay: _decisionDay,
      urgency: crime ? DecisionUrgency.urgent : DecisionUrgency.normal,
    );
    _pacedPetitions.add(
      _PacedPetition(
        requestId: admission.request.id,
        petition: petition,
        author: author,
        extra: Map.unmodifiable(extra),
      ),
    );
    // request() aynı anda daha eski bir queued kararı da terfi ettirebilir.
    _dispatchActiveDecision();
  }

  /// Seçimli olay ağırdır; seçimsiz olaylar buraya uğramadan uygulanır.
  void _requestPacedChoice(EventOutcome event) {
    final admission = _decisionPacing.request(
      HeavyDecisionKind.majorEvent,
      atDay: _decisionDay,
    );
    _pacedChoices.add(
      _PacedChoice(requestId: admission.request.id, event: event),
    );
    _dispatchActiveDecision();
  }

  /// Köy eşiğine varmış heyet gerçek acildir. Başka karar açıksa askerler
  /// eşikte bekler ve sim akar; sırayı aldığında modal kurulur.
  void _requestPacedImperial(ImperialDemand demand) {
    final admission = _decisionPacing.request(
      HeavyDecisionKind.imperial,
      atDay: _decisionDay,
      urgency: DecisionUrgency.urgent,
    );
    _pacedImperialDemand = demand;
    _pacedImperialRequestId = admission.request.id;
    _dispatchActiveDecision();
  }

  /// Her sim tick'inde çözülmüş yüzeyi kapatır, saati ilerletir ve uygun sırayı
  /// açar. Yalnız imparatorluk modalı simi durdurur; kuyruk bekleyişi durdurmaz.
  void _tickDecisionPacing() {
    final active = _decisionPacing.active;
    if (active != null &&
        !_hasDecisionPayload(active.id) &&
        !_hasDecisionSurface(active.kind)) {
      _decisionPacing.resolve(active.id, atDay: _decisionDay);
    }
    _decisionPacing.advanceTo(_decisionDay);
    _dispatchActiveDecision();
  }

  bool _hasDecisionPayload(String requestId) =>
      _pacedPetitions.any((payload) => payload.requestId == requestId) ||
      _pacedChoices.any((payload) => payload.requestId == requestId) ||
      _pacedImperialRequestId == requestId;

  bool _hasDecisionSurface(HeavyDecisionKind kind) => switch (kind) {
    HeavyDecisionKind.petition ||
    HeavyDecisionKind.crimeVerdict => _pendingPetition != null,
    HeavyDecisionKind.majorEvent => _pendingChoice != null,
    HeavyDecisionKind.imperial => _imperialDemand != null,
  };

  void _dispatchActiveDecision() {
    final active = _decisionPacing.active;
    if (active == null || _hasDecisionSurface(active.kind)) return;
    switch (active.kind) {
      case HeavyDecisionKind.petition:
      case HeavyDecisionKind.crimeVerdict:
        final index = _pacedPetitions.indexWhere(
          (payload) => payload.requestId == active.id,
        );
        if (index < 0) return;
        final payload = _pacedPetitions.removeAt(index);
        _activatePetition(
          payload.petition,
          author: payload.author,
          extra: payload.extra,
        );
      case HeavyDecisionKind.majorEvent:
        final index = _pacedChoices.indexWhere(
          (payload) => payload.requestId == active.id,
        );
        if (index < 0) return;
        final payload = _pacedChoices.removeAt(index);
        _activateChoiceEvent(payload.event);
      case HeavyDecisionKind.imperial:
        if (_pacedImperialRequestId != active.id ||
            _pacedImperialDemand == null) {
          return;
        }
        final demand = _pacedImperialDemand!;
        _pacedImperialDemand = null;
        _pacedImperialRequestId = null;
        _activateImperialParley(demand);
    }
  }
}
