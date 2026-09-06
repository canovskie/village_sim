# Devam notu

## Nerede kaldık?

- Eski rastgele olay örnekleri kaldırıldı; olay motoru ve UI altyapısı duruyor,
  katalog `lib/systems/events/event_catalog.dart` içinde bilinçli olarak boş.
- İlk kişisel Divan fikri `personalStyle` olarak tamamlandı. Beş başka gündelik
  ikilemle birlikte `lib/systems/governance/petitions/personal_petitions.dart` içinde.
- Suç, fidye, ateş ve düğün akışlarının ihtiyaç duyduğu altı karar yeniden
  katalog sözleşmesine alındı; sahne çağrıları artık eksik id'yi sessizce yutmaz.
- Olay seçicinin `canFire` hatası düzeltildi; katalog ve merkezi karar kuyruğu
  testlerle korunuyor.

## Sonraki en anlamlı iş

İçerik yönünü seç:

1. Rastgele olaylar geri gelecekse ilk küçük paketi
   `lib/systems/events/` altında kur. Motoru büyütme; her olayın koşulu,
   zaman-aşımı kolu, dünya karşılığı ve testi aynı pakette düşünülmeli.
2. Olay kataloğu boş kalacaksa Divan'ı derinleştir. Sıradaki paket gündelik
   kişisel mesele değil, 8+ nüfus için `communal` gündem olmalı.

İki yolu aynı anda genişletme; önce bir içerik dilini birkaç gerçek örnekle
oynanabilir hâle getirip ritmini ölç.

## Doğrulama

```bash
flutter analyze
flutter test test/event_system_test.dart test/petition_catalog_test.dart
flutter test test/decision_queue_probe_test.dart
flutter test --exclude-tags probe
flutter test --tags probe
```
