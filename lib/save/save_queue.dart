import 'dart:async';

/// Kayıtları sırayla koşturur. Çalışan bir yazım varken istenen kayıt atılmaz:
/// bitmesini bekler, sonra BAŞLARKEN dünyayı yakalar. Böylece "Kaydet ve Çık"
/// ve defter mührü, önceki yazımın eski görüntüsüyle yetinmez.
class SaveQueue {
  Future<void> _tail = Future<void>.value();
  int _pending = 0;

  /// Koşan ya da sırada bekleyen bir yazım var mı (otomatik kayıt buna bakıp atlar).
  bool get busy => _pending > 0;

  /// [job] öncekilerin ardından koşar. Hata sırayı bozmaz; çağırana döner.
  Future<void> run(Future<void> Function() job) {
    _pending++;
    final done = _tail.then((_) async {
      try {
        await job();
      } finally {
        _pending--;
      }
    });
    _tail = done.then<void>((_) {}, onError: (_) {});
    return done;
  }
}
