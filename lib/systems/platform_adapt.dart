import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// MOBİL UYARLAMA — telefon/tablette oyunu doğru ortama oturtur.
///
/// Oyun geniş bir izometrik dünya + yatay HUD şeridi. Bu yüzden mobilde:
///  • YATAY kilit — dikey mod HUD'ı ezer, oyun alanını yarılar.
///  • TAM EKRAN (immersive) — durum/gezinme çubukları oyunun üstüne binmesin;
///    parmak kenardan içeri sürünce geçici belirir (sticky), sonra kaybolur.
///  • KENARDAN KENARA — çentik/ada bölgesini SafeArea okuyabilsin diye pencere
///    tüm ekrana yayılır (HUD zaten SafeArea ile içeri çekiliyor).
///
/// Masaüstünde (macOS) hiçbir şey yapmaz — pencere serbest kalır.
abstract final class PlatformAdapt {
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// main() içinde runApp'ten ÖNCE bir kez çağrılır (binding hazır olmalı).
  static Future<void> applyMobileChrome() async {
    if (!isMobile) return;
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await restoreMobileChrome();
  }

  /// Klavye, uygulama değiştirici veya sistem izni tam ekran görünümünü geçici
  /// olarak bozabilir. Uygulama yeniden öne geldiğinde oyun alanını tekrar
  /// kenardan kenara kurmak için yaşam döngüsünden çağrılır.
  static Future<void> restoreMobileChrome() async {
    if (!isMobile) return;
    // Kenardan kenara + tam ekran. Sticky: kenar kaydırmada UI geçici döner,
    // oyunu bölmez.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
}
