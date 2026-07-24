import 'dart:convert';

/// Geliştirici komut konsolunun çekirdeği — sahneden BAĞIMSIZ saf veri/mantık.
///
/// Fikir: her dev aksiyonu artık DevPanel'e prop olarak geçen bir closure
/// DEĞİL, tek bir kayıt defterinde (registry) duran bir [DevCommand] nesnesi.
/// Konsol bu listenin üstünde arama/parametre/kayıt-oynatma yürütür. Yeni bir
/// test aksiyonu eklemek = registry'ye 1 satır (3 yerde bağlama derdi biter).
///
/// Bu dosya UI'a da sahneye de dokunmaz; sadece model + JSON serileştirme.

/// Komutların gruplandığı tematik kategori (konsolda başlık/filtre).
enum DevCat {
  nufus('Nüfus'),
  olay('Olaylar'),
  yonetisim('Yönetişim'),
  zaman('Zaman & Hava'),
  ekonomi('Ekonomi'),
  koy('Köy Kurulumu'),
  aktivite('Aktivite'),
  digerleri('Diğer');

  final String label;
  const DevCat(this.label);
}

/// Bir komut parametresinin tipi.
enum DevParamType { integer, choice }

/// Tek bir komut parametresinin tanımı (sabit buton yerine argümanlı komut).
class DevParam {
  final String key;
  final String label;
  final DevParamType type;

  // integer için:
  final int intDefault;
  final int intMin;
  final int intMax;

  // choice için: (değer, gösterilen etiket) çiftleri.
  final List<(String, String)> choices;
  final String choiceDefault;

  const DevParam.integer(
    this.key,
    this.label, {
    this.intDefault = 1,
    this.intMin = 1,
    this.intMax = 99,
  })  : type = DevParamType.integer,
        choices = const [],
        choiceDefault = '';

  const DevParam.choice(
    this.key,
    this.label,
    this.choices, {
    this.choiceDefault = '',
  })  : type = DevParamType.choice,
        intDefault = 0,
        intMin = 0,
        intMax = 0;

  /// Formu ilk açtığımız varsayılan değer.
  Object defaultValue() => switch (type) {
        DevParamType.integer => intDefault,
        DevParamType.choice =>
          choiceDefault.isNotEmpty ? choiceDefault : (choices.first.$1),
      };
}

/// Komut çalıştırılırken çözümlenmiş argümanlar. Kayıt/oynatmada birebir
/// aynı değerlerle tekrar çağrılabilmesi için serileştirilebilir.
class DevArgs {
  final Map<String, Object?> values;
  const DevArgs([this.values = const {}]);

  int getInt(String key, [int fallback = 0]) {
    final v = values[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  String getStr(String key, [String fallback = '']) {
    final v = values[key];
    return v == null ? fallback : v.toString();
  }
}

/// Tek bir çalıştırılabilir geliştirici aksiyonu.
class DevCommand {
  /// Kararlı kimlik — kayıt/oynatmada komutu bulmak için kullanılır. ASLA
  /// değiştirme (kayıtlı senaryolar id'ye referans verir).
  final String id;
  final String label;

  /// Konsolda etiketin altında görünen kısa açıklama (opsiyonel).
  final String? hint;
  final DevCat category;
  final List<DevParam> params;
  final void Function(DevArgs args) run;

  const DevCommand({
    required this.id,
    required this.label,
    required this.category,
    required this.run,
    this.hint,
    this.params = const [],
  });

  bool get hasParams => params.isNotEmpty;

  /// Parametre formunun başlangıç değerleri.
  Map<String, Object?> defaultArgs() {
    final m = <String, Object?>{};
    for (final p in params) {
      m[p.key] = p.defaultValue();
    }
    return m;
  }
}

/// Kaydedilmiş tek bir komut çağrısı (id + o anki argümanlar).
class DevInvocation {
  final String commandId;
  final Map<String, Object?> args;
  const DevInvocation(this.commandId, [this.args = const {}]);

  Map<String, Object?> toJson() => {'id': commandId, 'args': args};

  factory DevInvocation.fromJson(Map<String, Object?> j) => DevInvocation(
        j['id']! as String,
        (j['args'] as Map?)?.cast<String, Object?>() ?? const {},
      );
}

/// İsimlendirilmiş bir komut dizisi — bir DURUMU tek tıkla tekrar kurmak için.
class DevScript {
  final String name;
  final List<DevInvocation> steps;

  /// Kodda gömülü hazır senaryo mu (silinemez), yoksa oturumda kaydedilmiş mi.
  final bool builtin;

  const DevScript(this.name, this.steps, {this.builtin = false});

  Map<String, Object?> toJson() => {
        'name': name,
        'steps': [for (final s in steps) s.toJson()],
      };

  factory DevScript.fromJson(Map<String, Object?> j) => DevScript(
        j['name']! as String,
        [
          for (final s in (j['steps'] as List? ?? const []))
            DevInvocation.fromJson((s as Map).cast<String, Object?>()),
        ],
      );

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  static DevScript? tryDecode(String raw) {
    try {
      final j = jsonDecode(raw);
      if (j is Map<String, Object?>) return DevScript.fromJson(j);
    } catch (_) {}
    return null;
  }
}

/// Konsolun fire'ladığı komutları bir tampona yazan kaydedici. Değiştiğinde
/// dinleyicileri (konsol UI) uyarır.
class DevRecorder {
  bool recording = false;
  final List<DevInvocation> steps = [];
  final List<void Function()> _listeners = [];

  void addListener(void Function() fn) => _listeners.add(fn);
  void removeListener(void Function() fn) => _listeners.remove(fn);
  void _notify() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  void toggle() {
    recording = !recording;
    _notify();
  }

  /// Kayıt açıkken bir komut çalıştıysa adımı ekler.
  void capture(String commandId, Map<String, Object?> args) {
    if (!recording) return;
    steps.add(DevInvocation(commandId, Map.of(args)));
    _notify();
  }

  void clear() {
    steps.clear();
    _notify();
  }

  /// Kaydedilmişleri isimlendirilmiş bir senaryoya dondurur (kayıt kapanır).
  DevScript freeze(String name) {
    final s = DevScript(name, List.of(steps));
    steps.clear();
    recording = false;
    _notify();
    return s;
  }
}
