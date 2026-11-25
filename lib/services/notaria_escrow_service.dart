import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../config/api_config.dart';
import 'vinkiar_secure_database.dart';

typedef JsonMap = Map<String, dynamic>;

class NotariaEscrowService {
  static final NotariaEscrowService _instance = NotariaEscrowService._internal();
  factory NotariaEscrowService() => _instance;
  NotariaEscrowService._internal();

  // ⚡ Notificador global para cristalización en tiempo real
  final ValueNotifier<String?> escrowSettledNotifier = ValueNotifier<String?>(null);

  String get _baseUrl {
    return ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
  }

  Future<File> _getLedgerFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/vinkiar_escrow_ledger.json');
  }

  Future<JsonMap> _readLedger() async {
    try {
      final file = await _getLedgerFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          return jsonDecode(content) as JsonMap;
        }
      }
    } catch (_) {}
    return {};
  }

  Future<void> _writeLedger(JsonMap ledger) async {
    try {
      final file = await _getLedgerFile();
      await file.writeAsString(jsonEncode(ledger));
    } catch (_) {}
  }

  /// Congela los Vinks en Escrow local para garantizar compromiso sin doble gasto
  Future<bool> freezeEscrow({
    required String questId,
    required int vinksAmount,
    required String santuarioId,
    required String santuarioAlias,
    required String horaEstimada,
    required String targetHandle,
  }) async {
    final ledger = await _readLedger();
    final key = 'escrow_contract_$questId';

    if (ledger.containsKey(key)) return true;

    // Descuenta temporalmente los Vinks bloqueados de la Bóveda disponible
    await VinkiarSecureDatabase().addAvatarRewards(-vinksAmount, 0);

    ledger[key] = {
      'quest_id': questId,
      'vinks_frozen': vinksAmount,
      'santuario_id': santuarioId,
      'santuario_alias': santuarioAlias,
      'hora_estimada': horaEstimada,
      'target_handle': targetHandle,
      'status': 'FROZEN',
      'my_signed': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    await _writeLedger(ledger);
    return true;
  }

  Future<JsonMap?> getLocalEscrow(String questId) async {
    final ledger = await _readLedger();
    final entry = ledger['escrow_contract_$questId'];
    if (entry is JsonMap) return entry;
    return null;
  }

  /// Genera firma SHA-256 notarial y la envía a /api/v1/quests/sign
  Future<JsonMap> signContract2of2({
    required String questId,
    required String signerHandle,
    required String targetHandle,
    String role = 'CREATOR',
  }) async {
    final payloadToHash = '$questId|$signerHandle|$role|${DateTime.now().millisecondsSinceEpoch}';
    final signatureHash = sha256.convert(utf8.encode(payloadToHash)).toString();

    final ledger = await _readLedger();
    final key = 'escrow_contract_$questId';
    if (ledger[key] is JsonMap) {
      final local = ledger[key] as JsonMap;
      local['my_signed'] = true;
      local['my_signature'] = signatureHash;
      ledger[key] = local;
      await _writeLedger(ledger);
    }

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/v1/quests/sign'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'quest_id': questId,
          'signer_id': signerHandle,
          'target_id': targetHandle,
          'role': role,
          'signature': signatureHash,
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as JsonMap;
        if (data['status'] == 'MUTUAL_SETTLED' && data['can_release_escrow'] == true) {
          await _settleAndReleaseEscrow(questId);
        }
        return data;
      }
    } catch (_) {}

    return {'status': 'ERROR', 'can_release_escrow': false};
  }

  /// Consulta el estado de la contra-firma remota
  Future<JsonMap> pollContractStatus(String questId) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/v1/quests/status/$questId'),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as JsonMap;
        if (data['status'] == 'MUTUAL_SETTLED' && data['can_release_escrow'] == true) {
          await _settleAndReleaseEscrow(questId);
        }
        return data;
      }
    } catch (_) {}
    return {'status': 'PENDING'};
  }

  /// Libera los Vinks retenidos + bonificación Phygital al completarse ambas firmas
  Future<void> _settleAndReleaseEscrow(String questId) async {
    final ledger = await _readLedger();
    final key = 'escrow_contract_$questId';
    final entry = ledger[key];

    if (entry is JsonMap && entry['status'] != 'SETTLED') {
      final int frozen = (entry['vinks_frozen'] as num?)?.toInt() ?? 20;
      final bool isP2PTask = entry['santuario_id'] == 'TAREA_DOMESTICA';

      if (isP2PTask) {
        // En subasta P2P el creador paga el Escrow a la contraparte y obtiene XP
        await VinkiarSecureDatabase().addAvatarRewards(0, 100);
      } else {
        // En encuentro de Santuario se libera el depósito + 25 Ѵ de cortesía Phygital
        await VinkiarSecureDatabase().addAvatarRewards(frozen + 25, 150);
      }

      entry['status'] = 'SETTLED';
      entry['settled_at'] = DateTime.now().toIso8601String();
      ledger[key] = entry;
      await _writeLedger(ledger);

      // ⚡ Dispara la cristalización en toda la app
      escrowSettledNotifier.value = questId;
    }
  }
}