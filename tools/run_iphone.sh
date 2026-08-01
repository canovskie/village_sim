#!/usr/bin/env bash
# Telefonda AÇ — derle · kur · başlat, tek komut.
#
# Neden ayrı script: bu projede `flutter run -d <iphone>` iki ayrı yerde
# takılıyor ve ikisi de Flutter'ın kendi hatası:
#   1. Başlatmayı Xcode otomasyonuyla yapıyor ("Xcode is taking longer than
#      expected...") ve orada asılı kalıyor. devicectl doğrudan başlatır.
#   2. Xcode paketi `build/ios/Release-iphoneos/` altına üretiyor ama Flutter
#      `build/ios/iphoneos/` sembolik bağını her zaman kurmuyor → "Build
#      succeeded but the expected app ... not found".
#
# Ayrıca RELEASE derliyoruz: iOS'ta debug (JIT) derlemesi hata ayıklayıcı
# bağlı değilken çalışmıyor — devicectl ile başlatınca bağlı olmuyor.
# Yan fayda: gerçek performans görünür (debug'da kasma yanıltıcı).
#
# Kullanım:  tools/run_iphone.sh
# Env:       DEVICE=<devicectl UUID>   (varsayılan: Can iPhone'u)
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE=com.cankaynar.villageSim
DEVICE=${DEVICE:-799FAFAE-FCD0-5CC0-9FAB-6D76D326F80D}

echo "▸ Derleniyor (release)…"
flutter build ios --release

APP=build/ios/Release-iphoneos/Runner.app
if [[ ! -d $APP ]]; then
  echo "HATA: paket bulunamadı: $APP" >&2
  exit 1
fi

echo "▸ Kuruluyor…"
xcrun devicectl device install app --device "$DEVICE" "$APP" >/dev/null

echo "▸ Açılıyor…"
xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE" >/dev/null

echo "✓ Telefonda açıldı."
