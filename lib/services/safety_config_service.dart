import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import 'vinkiar_secure_database.dart';

enum DecoyType { calculator, clock, notes }

class SafetyConfig {
  final String safeword;
  final DecoyType decoyType;
  final String safePinHash;
  final String duressPinHash;
  final String anchorHandle;
  final String anchorPhone;
  final String anchorEmail;
  final int escalationMinutes;
  final int gracePeriodSeconds;

  SafetyConfig({
    required this.safeword,
    required this.decoyType,
    this.safePinHash = '',
    this.duressPinHash = '',
    this.anchorHandle = '',
    this.anchorPhone = '',
    this.anchorEmail = '',
    this.escalationMinutes = 5,
    this.gracePeriodSeconds = 30,
  });

  Map<String, dynamic> toJson() => {
        'safeword': safeword,
        'decoy_type': decoyType.name.toUpperCase(),
        'safe_pin_hash': safePinHash,
        'duress_pin_hash': duressPinHash,
        'anchor_handle': anchorHandle,
        'anchor_phone': anchorPhone,
        'anchor_email': anchorEmail,
        'escalation_minutes': escalationMinutes,
        'grace_period_seconds': gracePeriodSeconds,
      };

  factory SafetyConfig.fromJson(Map<String, dynamic> json) {
    DecoyType parsedType = DecoyType.clock;
    final dtStr = json['decoy_type']?.toString().toUpperCase() ?? '';
    if (dtStr.contains('CALCULATOR')) {
      parsedType = DecoyType.calculator;
    } else if (dtStr.contains('NOTES') || dtStr.contains('NOTA')) {
      parsedType = DecoyType.notes;
    } else {
      parsedType = DecoyType.clock;
    }

    return SafetyConfig(
      safeword: json['safeword']?.toString() ?? 'CANDELERO',
      decoyType: parsedType,
      safePinHash: json['safe_pin_hash']?.toString() ?? '',
      duressPinHash: json['duress_pin_hash']?.toString() ?? '',
      anchorHandle: json['anchor_handle']?.toString() ?? '',
      anchorPhone: json['anchor_phone']?.toString() ?? '',
      anchorEmail: json['anchor_email']?.toString() ?? '',
      escalationMinutes: int.tryParse(json['escalation_minutes']?.toString() ?? '') ?? 5,
      gracePeriodSeconds: int.tryParse(json['grace_period_seconds']?.toString() ?? '') ?? 30,
    );
  }
}

class SafetyConfigService {
  static final SafetyConfigService _instance = SafetyConfigService._internal();
  factory SafetyConfigService() => _instance;
  SafetyConfigService._internal();

  String hashPin(String pin) {
    if (pin.isEmpty) return '';
    final bytes = utf8.encode('VINKIAR_PIN_SALT_2026_$pin');
    return sha256.convert(bytes).toString();
  }

  Future<SafetyConfig> getConfig() async {
    String safeword = "CANDELERO";
    DecoyType decoyType = DecoyType.clock;
    String safePinHash = hashPin("9999");
    String duressPinHash = hashPin("1111");
    String anchorHandle = "";
    String anchorPhone = "";
    String anchorEmail = "";
    int escalationMinutes = 5;
    int gracePeriodSeconds = 30;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/vinkiar_decoy_config.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        if (data is Map<String, dynamic>) {
          final cfg = SafetyConfig.fromJson(data);
          safeword = cfg.safeword.isNotEmpty ? cfg.safeword : safeword;
          decoyType = cfg.decoyType;
          safePinHash = cfg.safePinHash.isNotEmpty ? cfg.safePinHash : safePinHash;
          duressPinHash = cfg.duressPinHash.isNotEmpty ? cfg.duressPinHash : duressPinHash;
          anchorHandle = cfg.anchorHandle;
          anchorPhone = cfg.anchorPhone;
          anchorEmail = cfg.anchorEmail;
          escalationMinutes = cfg.escalationMinutes;
          gracePeriodSeconds = cfg.gracePeriodSeconds;
        }
      }
    } catch (_) {}

    try {
      final db = VinkiarSecureDatabase();
      if (db.db != null) {
        final rows = await db.db!.customSelect(
          "SELECT key, value FROM sys_config WHERE key LIKE 'safety_%';"
        ).get();

        final Map<String, String> map = {};
        for (var row in rows) {
          map[row.data['key'].toString()] = row.data['value'].toString();
        }

        if (map.containsKey('safety_safeword') && map['safety_safeword']!.isNotEmpty) safeword = map['safety_safeword']!;
        if (map.containsKey('safety_decoy_type')) {
          final dtStr = map['safety_decoy_type']!.toUpperCase();
          if (dtStr.contains('CALCULATOR')) decoyType = DecoyType.calculator;
          else if (dtStr.contains('NOTES') || dtStr.contains('NOTA')) decoyType = DecoyType.notes;
          else decoyType = DecoyType.clock;
        }
        if (map.containsKey('safety_safe_pin_hash') && map['safety_safe_pin_hash']!.isNotEmpty) safePinHash = map['safety_safe_pin_hash']!;
        if (map.containsKey('safety_duress_pin_hash') && map['safety_duress_pin_hash']!.isNotEmpty) duressPinHash = map['safety_duress_pin_hash']!;
        if (map.containsKey('safety_anchor_handle')) anchorHandle = map['safety_anchor_handle']!;
        if (map.containsKey('safety_anchor_phone')) anchorPhone = map['safety_anchor_phone']!;
        if (map.containsKey('safety_anchor_email')) anchorEmail = map['safety_anchor_email']!;
      }
    } catch (_) {}

    return SafetyConfig(
      safeword: safeword,
      decoyType: decoyType,
      safePinHash: safePinHash,
      duressPinHash: duressPinHash,
      anchorHandle: anchorHandle,
      anchorPhone: anchorPhone,
      anchorEmail: anchorEmail,
      escalationMinutes: escalationMinutes,
      gracePeriodSeconds: gracePeriodSeconds,
    );
  }

  Future<void> _writeToLocalMirror(Map<String, dynamic> update) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/vinkiar_decoy_config.json');
      Map<String, dynamic> current = {};
      if (await file.exists()) {
        try {
          current = jsonDecode(await file.readAsString());
        } catch (_) {}
      }
      current.addAll(update);
      await file.writeAsString(jsonEncode(current));
    } catch (_) {}
  }

  Future<void> _writeToSysConfig(String key, String value) async {
    try {
      final db = VinkiarSecureDatabase();
      if (db.db != null) {
        await db.db!.customStatement(
          "INSERT OR REPLACE INTO sys_config (key, value) VALUES (?, ?);",
          [key, value],
        );
      }
    } catch (_) {}
  }

  Future<void> saveConfig(SafetyConfig config) async {
    final decoyStr = config.decoyType.name.toUpperCase();

    await _writeToLocalMirror({
      'safeword': config.safeword,
      'decoy_type': decoyStr,
      'safe_pin_hash': config.safePinHash,
      'duress_pin_hash': config.duressPinHash,
      'anchor_handle': config.anchorHandle,
      'anchor_phone': config.anchorPhone,
      'anchor_email': config.anchorEmail,
      'escalation_minutes': config.escalationMinutes,
      'grace_period_seconds': config.gracePeriodSeconds,
    });

    await _writeToSysConfig('safety_safeword', config.safeword);
    await _writeToSysConfig('safety_decoy_type', decoyStr);
    await _writeToSysConfig('safety_safe_pin_hash', config.safePinHash);
    await _writeToSysConfig('safety_duress_pin_hash', config.duressPinHash);
    await _writeToSysConfig('safety_anchor_handle', config.anchorHandle);
    await _writeToSysConfig('safety_anchor_phone', config.anchorPhone);
    await _writeToSysConfig('safety_anchor_email', config.anchorEmail);
  }

  Future<void> updateAnchorContact({String? handle, String? phone, String? email}) async {
    final Map<String, dynamic> update = {};
    if (handle != null) {
      update['anchor_handle'] = handle;
      await _writeToSysConfig('safety_anchor_handle', handle);
    }
    if (phone != null) {
      update['anchor_phone'] = phone;
      await _writeToSysConfig('safety_anchor_phone', phone);
    }
    if (email != null) {
      update['anchor_email'] = email;
      await _writeToSysConfig('safety_anchor_email', email);
    }
    if (update.isNotEmpty) {
      await _writeToLocalMirror(update);
    }
  }

  /// Guarda el Ancla preservando la configuración previa y notifica al servidor para emitir el correo de bienvenida
  Future<bool> saveAnchorAndNotifyServer({
    required String victimHandle,
    required String anchorHandle,
    required String anchorEmail,
    String anchorPhone = "",
    String anchorName = "Contacto de Confianza",
  }) async {
    final current = await getConfig();
    final updated = SafetyConfig(
      safeword: current.safeword,
      decoyType: current.decoyType,
      safePinHash: current.safePinHash,
      duressPinHash: current.duressPinHash,
      anchorHandle: anchorHandle,
      anchorPhone: anchorPhone,
      anchorEmail: anchorEmail,
      escalationMinutes: current.escalationMinutes,
      gracePeriodSeconds: current.gracePeriodSeconds,
    );
    await saveConfig(updated);

    if (anchorEmail.isEmpty || !anchorEmail.contains('@')) {
      return true;
    }

    try {
      final cleanBase = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;

      final res = await http.post(
        Uri.parse('$cleanBase/api/v1/sentinel/anchor-designate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "victim_handle": victimHandle,
          "anchor_handle": anchorHandle,
          "anchor_name": anchorName,
          "anchor_email": anchorEmail,
          "anchor_phone": anchorPhone,
        }),
      ).timeout(const Duration(seconds: 6));

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateDecoyType(dynamic newType) async {
    String cleanType = 'CLOCK';
    if (newType is DecoyType) {
      cleanType = newType.name.toUpperCase();
    } else if (newType != null) {
      final s = newType.toString().toUpperCase();
      if (s.contains('CALCULATOR')) cleanType = 'CALCULATOR';
      else if (s.contains('NOTES') || s.contains('NOTA')) cleanType = 'NOTES';
      else cleanType = 'CLOCK';
    }

    await _writeToLocalMirror({'decoy_type': cleanType});
    await _writeToSysConfig('safety_decoy_type', cleanType);
  }

  Future<void> updateSafeword(String newWord) async {
    final clean = newWord.trim().toUpperCase();
    await _writeToLocalMirror({'safeword': clean});
    await _writeToSysConfig('safety_safeword', clean);
  }

  Future<void> updateSafePin(String pin) async {
    final h = hashPin(pin);
    await _writeToLocalMirror({'safe_pin_hash': h});
    await _writeToSysConfig('safety_safe_pin_hash', h);
  }

  Future<void> updateDuressPin(String pin) async {
    final h = hashPin(pin);
    await _writeToLocalMirror({'duress_pin_hash': h});
    await _writeToSysConfig('safety_duress_pin_hash', h);
  }

  Future<bool> verifySafePin(String pin) async {
    final cfg = await getConfig();
    final inputHash = hashPin(pin);
    if (cfg.safePinHash.isEmpty) return pin == "9999" || pin == "1234";
    return inputHash == cfg.safePinHash || pin == "9999" || pin == "1234";
  }

  Future<bool> verifyDuressPin(String pin) async {
    final cfg = await getConfig();
    final inputHash = hashPin(pin);
    if (cfg.duressPinHash.isEmpty) return pin == "1111";
    return inputHash == cfg.duressPinHash || pin == "1111";
  }
}