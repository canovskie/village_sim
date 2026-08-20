/// Ağır karar yüzeylerinin ortak ritim otoritesi.
///
/// Flutter, sahne ve içerik bilmez. Yalnız dilekçe, seçimli olay, suç hükmü ve
/// imparatorluk görüşmesinin aynı oyuncu dikkatini kullandığını bilir. Hafif
/// bildirimler bu sisteme hiç girmez ve simülasyonu bloke etmez.
library;

/// Oyuncudan anlamlı bir hüküm isteyen ağır karar türleri.
enum HeavyDecisionKind { petition, majorEvent, imperial, crimeVerdict }

/// Normal kararlar sırayla bekler. Gerçek aciller yalnız normal bir kararın
/// bıraktığı sessizliği aşabilir; aktif kararı veya bir acilin sessizliğini
/// asla aşamaz.
enum DecisionUrgency { normal, urgent }

class DecisionRequest {
  final String id;
  final HeavyDecisionKind kind;
  final DecisionUrgency urgency;
  final double requestedAtDay;

  const DecisionRequest({
    required this.id,
    required this.kind,
    required this.urgency,
    required this.requestedAtDay,
  });

  bool get urgent => urgency == DecisionUrgency.urgent;

  Map<String, Object> toJson() => {
    'id': id,
    'kind': kind.name,
    'urgency': urgency.name,
    'requestedAtDay': requestedAtDay,
  };

  static DecisionRequest? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final kindName = raw['kind'];
    if (id is! String || kindName is! String) return null;
    final kind = HeavyDecisionKind.values
        .where((value) => value.name == kindName)
        .firstOrNull;
    if (kind == null) return null;
    final urgencyName = raw['urgency'];
    final urgency = DecisionUrgency.values
        .where((value) => value.name == urgencyName)
        .firstOrNull;
    return DecisionRequest(
      id: id,
      kind: kind,
      urgency: urgency ?? DecisionUrgency.normal,
      requestedAtDay: (raw['requestedAtDay'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DecisionAdmission {
  final DecisionRequest request;
  final bool activated;

  const DecisionAdmission(this.request, {required this.activated});
}

/// Koşu boyunca biriken ritim ölçümleri.
class DecisionPacingMetrics {
  final int heavyDecisionStarts;
  final int resolvedDecisions;
  final int deferredDecisions;
  final int emergencyBypasses;
  final double totalQueueWaitDays;
  final double maxQueueWaitDays;
  final double? lastGapDays;
  final double? minGapDays;

  const DecisionPacingMetrics({
    required this.heavyDecisionStarts,
    required this.resolvedDecisions,
    required this.deferredDecisions,
    required this.emergencyBypasses,
    required this.totalQueueWaitDays,
    required this.maxQueueWaitDays,
    required this.lastGapDays,
    required this.minGapDays,
  });

  double get averageQueueWaitDays =>
      heavyDecisionStarts == 0 ? 0 : totalQueueWaitDays / heavyDecisionStarts;
}

/// Merkezi ve deterministik ağır-karar kuyruğu.
class DecisionPacing {
  /// Hedef nefes payının ortası: 0,55–0,75 gün bandının merkezi.
  static const double defaultQuietDays = 0.65;

  final double quietDays;
  final List<DecisionRequest> _queue = [];
  DecisionRequest? _active;
  double _nowDay = 0;
  double _quietUntilDay = 0;
  bool _lastResolutionWasUrgent = false;
  int _nextRequestNumber = 1;

  int _starts = 0;
  int _resolved = 0;
  int _deferred = 0;
  int _bypasses = 0;
  double _totalWait = 0;
  double _maxWait = 0;
  double? _lastStartedAt;
  double? _lastGap;
  double? _minGap;

  DecisionPacing({this.quietDays = defaultQuietDays});

  DecisionRequest? get active => _active;
  List<DecisionRequest> get queued => List.unmodifiable(_queue);
  int get queueLength => _queue.length;
  double get nowDay => _nowDay;
  double get quietUntilDay => _quietUntilDay;

  DecisionPacingMetrics get metrics => DecisionPacingMetrics(
    heavyDecisionStarts: _starts,
    resolvedDecisions: _resolved,
    deferredDecisions: _deferred,
    emergencyBypasses: _bypasses,
    totalQueueWaitDays: _totalWait,
    maxQueueWaitDays: _maxWait,
    lastGapDays: _lastGap,
    minGapDays: _minGap,
  );

  /// Kararı kaybetmeden sıraya alır. Aynı anda yalnız bir aktif karar vardır.
  DecisionAdmission request(
    HeavyDecisionKind kind, {
    required double atDay,
    DecisionUrgency urgency = DecisionUrgency.normal,
  }) {
    advanceTo(atDay);
    final request = DecisionRequest(
      id: 'decision.${_nextRequestNumber++}',
      kind: kind,
      urgency: urgency,
      requestedAtDay: _nowDay,
    );
    if (_canActivate(request)) {
      _activate(request, bypassed: _insideQuiet && request.urgent);
      return DecisionAdmission(request, activated: true);
    }
    _queue.add(request);
    _deferred++;
    return DecisionAdmission(request, activated: false);
  }

  /// Saati ilerletir ve kapı açıldıysa sıradaki kararı döndürür.
  DecisionRequest? advanceTo(double atDay) {
    if (atDay > _nowDay) _nowDay = atDay;
    if (_active != null || _queue.isEmpty) return null;
    final nextIndex = _nextQueueIndex();
    final next = _queue[nextIndex];
    if (!_canActivate(next)) return null;
    _queue.removeAt(nextIndex);
    _activate(next, bypassed: _insideQuiet && next.urgent);
    return next;
  }

  /// Aktif karar çözüldüğünde her tür için aynı sessizliği başlatır.
  bool resolve(String requestId, {required double atDay}) {
    advanceTo(atDay);
    final current = _active;
    if (current == null || current.id != requestId) return false;
    _active = null;
    _resolved++;
    _lastResolutionWasUrgent = current.urgent;
    _quietUntilDay = _nowDay + quietDays;
    return true;
  }

  bool get _insideQuiet => _nowDay + 1e-9 < _quietUntilDay;

  bool _canActivate(DecisionRequest request) {
    if (_active != null) return false;
    if (!_insideQuiet) return true;
    // Belgelenmiş acil kapısı: normal kararın bıraktığı sessizlik aşılabilir;
    // acilin bıraktığı sessizlik aşılamaz (ikinci ağır karar üstüne binmesin).
    return request.urgent && !_lastResolutionWasUrgent;
  }

  int _nextQueueIndex() {
    // Aciller FIFO sıralarını kendi aralarında koruyarak normal kuyruğun önüne
    // geçer. Aktif karar hiçbir koşulda gasp edilmez.
    for (var i = 0; i < _queue.length; i++) {
      if (_queue[i].urgent) return i;
    }
    return 0;
  }

  void _activate(DecisionRequest request, {required bool bypassed}) {
    _active = request;
    _starts++;
    if (bypassed) _bypasses++;
    final wait = (_nowDay - request.requestedAtDay).clamp(0.0, double.infinity);
    _totalWait += wait;
    if (wait > _maxWait) _maxWait = wait;
    final previous = _lastStartedAt;
    if (previous != null) {
      final gap = _nowDay - previous;
      _lastGap = gap;
      if (_minGap == null || gap < _minGap!) _minGap = gap;
    }
    _lastStartedAt = _nowDay;
  }

  Map<String, Object?> toJson() => {
    'quietDays': quietDays,
    'nowDay': _nowDay,
    'quietUntilDay': _quietUntilDay,
    'lastResolutionWasUrgent': _lastResolutionWasUrgent,
    'nextRequestNumber': _nextRequestNumber,
    'active': _active?.toJson(),
    'queue': [for (final request in _queue) request.toJson()],
    'starts': _starts,
    'resolved': _resolved,
    'deferred': _deferred,
    'bypasses': _bypasses,
    'totalWait': _totalWait,
    'maxWait': _maxWait,
    'lastStartedAt': _lastStartedAt,
    'lastGap': _lastGap,
    'minGap': _minGap,
  };

  static DecisionPacing fromJson(Object? raw) {
    if (raw is! Map) return DecisionPacing();
    final pacing = DecisionPacing(
      quietDays: (raw['quietDays'] as num?)?.toDouble() ?? defaultQuietDays,
    );
    pacing._nowDay = (raw['nowDay'] as num?)?.toDouble() ?? 0;
    pacing._quietUntilDay =
        (raw['quietUntilDay'] as num?)?.toDouble() ?? pacing._nowDay;
    pacing._lastResolutionWasUrgent = raw['lastResolutionWasUrgent'] == true;
    pacing._nextRequestNumber = (raw['nextRequestNumber'] as int?) ?? 1;
    pacing._active = DecisionRequest.fromJson(raw['active']);
    final queue = raw['queue'];
    if (queue is List) {
      for (final item in queue) {
        final request = DecisionRequest.fromJson(item);
        if (request != null) pacing._queue.add(request);
      }
    }
    pacing._starts = (raw['starts'] as int?) ?? 0;
    pacing._resolved = (raw['resolved'] as int?) ?? 0;
    pacing._deferred = (raw['deferred'] as int?) ?? 0;
    pacing._bypasses = (raw['bypasses'] as int?) ?? 0;
    pacing._totalWait = (raw['totalWait'] as num?)?.toDouble() ?? 0;
    pacing._maxWait = (raw['maxWait'] as num?)?.toDouble() ?? 0;
    pacing._lastStartedAt = (raw['lastStartedAt'] as num?)?.toDouble();
    pacing._lastGap = (raw['lastGap'] as num?)?.toDouble();
    pacing._minGap = (raw['minGap'] as num?)?.toDouble();
    return pacing;
  }
}
