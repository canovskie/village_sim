part of '../../main.dart';

// Gerçek yayın akışını capture muafiyetinden çıkaran prova kapısı.
bool kProbeNewsArmed = false;
bool kProbeNewsReset = false;
final List<String> kProbeNewsMessages = [];

extension _SceneNews on _VillageSceneState {
  bool get _newsWindowOpen =>
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      _newsForeground &&
      !_panelFocusOpen &&
      _imperialBattle == null &&
      _activeCutscene == null &&
      _activeLesson == null &&
      _activeEvent == null;

  void _tickNotifications(double realSeconds) {
    if (kCaptureMode && !kProbeNewsArmed) return;
    if (kProbeNewsArmed) {
      if (kProbeNewsReset) {
        kProbeNewsReset = false;
        _notificationFeed.clear();
        _feedbackFeed.clear();
      }
      final messages = List<String>.of(kProbeNewsMessages);
      kProbeNewsMessages.clear();
      for (final message in messages) {
        _showNotification(message);
      }
    }
    if (!_newsForeground) return;
    // İlk dönüş karesinin aralığı uygulamanın gizli kaldığı süreyi içerir.
    if (_newsSkipFrame) {
      _newsSkipFrame = false;
      return;
    }
    _notificationFeed.advance(realSeconds, visible: _newsWindowOpen);
    _feedbackFeed.advance(realSeconds, visible: _newsWindowOpen);
  }

  void _showNotification(
    String msg, {
    String? headline,
    VillageNewsTopic? topic,
    VillageNewsTone? tone,
    VillageNewsPriority? priority,
    String? eventKey,
  }) {
    logDev(msg, tag: '📣');
    final news = VillageNews.fromMessage(
      msg,
      headline: headline,
      topic: topic,
      tone: tone,
      priority: priority,
      eventKey: eventKey,
      stamp: '${_season.label.toUpperCase()} · GÜN $_dayCount',
    );
    // İşlem cevabı kriz kuyruğunun arkasında eskimez. Son tıklamanın cevabı
    // küçük fişte görünür; alttaki köy haberini kesmez veya kaybettirmez.
    if (news.topic == VillageNewsTopic.system) {
      _feedbackFeed.replace(news);
    } else if (kCaptureMode && !kProbeNewsArmed) {
      _notificationFeed.replace(news);
    } else if (!_notificationFeed.add(news).accepted) {
      return;
    }
    setStateHere(() {});
  }
}
