import 'package:flutter/material.dart';

import '../dev/animation_room.dart';

/// Animasyon odasının BAĞIMSIZ girişi — köy yüklemeden, ana menüden geçmeden
/// doğrudan açılır. Animasyon üstünde çalışırken en hızlı döngü bu:
///
///   flutter run -d macos -t lib/tools/animation_room_main.dart
///
/// Hot reload çalışır → sinematik/karakter kodunda yaptığın değişiklik saniyeler
/// içinde ekranda. (Oyun içinden açmak için: backtick konsolu → `anim.room`,
/// ya da ana menüdeki ANİMASYONLAR satırı.)
void main() {
  runApp(const AnimationRoomApp());
}
