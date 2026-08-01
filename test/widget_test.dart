// Smoke test — uygulama açılınca crash etmiyor mu?
//
// Detaylı testler test/ altındaki diğer dosyalarda:
//   - resource_bundle_test.dart     ekonomi
//   - hay_processor_test.dart       saman → balya zinciri
//   - woodcutter_state_test.dart    state machine geçişleri
//   - lumber_camp_test.dart         territory yönetimi + fidan
//   - separation_system_test.dart   spatial hash ayrışma

import 'package:flutter_test/flutter_test.dart';

import 'package:village_sim/main.dart';

void main() {
  testWidgets('App boots without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const VillageSimApp());
    // Ana menü kelime işaretini gösterir (başlık 'VILLAGE SIM' değil 'LUW').
    expect(find.text('LUW'), findsWidgets);
  });
}
