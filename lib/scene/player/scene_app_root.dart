part of '../../main.dart';

/// UYGULAMA KÖKÜ — ana menü ↔ oyun geçişi, slot seçimi, referans köy başlatma.
class VillageSimApp extends StatelessWidget {
  const VillageSimApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    title: 'Luw',
    debugShowCheckedModeBanner: false,
    home: _AppRoot(),
  );
}

/// Ana menüden oyuna ve geri geçişi yöneten kök widget.
/// Sahne değişimini state ile yapıyoruz; böylece oyundan çıkış doğrudan
/// menüye döner ve oyun durumu yeni başladığında temiz olur.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _inGame = false;
  int _gameKey = 0; // Her yeni oyun için VillageScene'i yeniden oluşturur

  // Aktif oyunun slot kimliği + adı + (varsa) yüklenecek dünya. _loadWorld
  // null ise taze köy üretilir; doluysa o slottan kaldığı yerden devam edilir.
  Map<String, dynamic>? _loadWorld;
  String _slotId = '';
  String _slotName = 'Köy';

  /// Bu oturum referans köy mü (sabit test zemini) — bkz. scene_reference_village.
  bool _reference = false;

  void _startNew() {
    setState(() {
      _loadWorld = null;
      _reference = false;
      _slotId = SaveManager.instance.newSlotId();
      _slotName = 'Köy';
      _inGame = true;
      _gameKey++;
    });
  }

  /// Referans köy — testlerin ortak zemini. Her girişte SIFIRDAN, birebir aynı
  /// kurulur ve sabit slota ([kReferenceSlotId]) yazılır; yani o slottaki önceki
  /// oturum tazelenir. Kaldığı yerden devam istenirse Kayıtlı Köyler'den açılır
  /// (o zaman normal bir kayıt gibi davranır, yeniden kurulmaz).
  void _startReference() {
    setState(() {
      _loadWorld = null;
      _reference = true;
      _slotId = kReferenceSlotId;
      _slotName = kReferenceSlotName;
      _inGame = true;
      _gameKey++;
    });
  }

  Future<void> _continue(SaveSlotMeta meta) async {
    final data = await SaveManager.instance.readSlot(meta.id);
    final world = data?['world'];
    if (world is! Map) {
      _startNew();
      return;
    }
    if (!mounted) return;
    setState(() {
      _loadWorld = Map<String, dynamic>.from(world);
      _reference = false; // kayıttan devam → yeniden kurma, olduğu gibi yükle
      _slotId = meta.id;
      _slotName = meta.name;
      _inGame = true;
      _gameKey++;
    });
  }

  void _exitGame() => setState(() => _inGame = false);

  @override
  Widget build(BuildContext context) {
    if (_inGame) {
      return VillageScene(
        key: ValueKey(_gameKey),
        onExitToMenu: _exitGame,
        initialWorld: _loadWorld,
        slotId: _slotId,
        slotName: _slotName,
        referenceVillage: _reference,
      );
    }
    return MainMenuScreen(
      onNewGame: _startNew,
      onContinue: _continue,
      onReferenceVillage: _startReference,
    );
  }
}
