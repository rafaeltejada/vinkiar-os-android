import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'vinkiar_secure_database.dart';

class VinkiarTribusService {
  static final VinkiarTribusService _instance = VinkiarTribusService._internal();
  factory VinkiarTribusService() => _instance;
  VinkiarTribusService._internal();

  String get _baseUrl => ApiConfig.baseUrl.endsWith('/')
      ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
      : ApiConfig.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    return {'Content-Type': 'application/json'};
  }

  Future<String> _getActorHandle([String? overrideHandle]) async {
    if (overrideHandle != null && overrideHandle.trim().isNotEmpty) {
      final clean = overrideHandle.trim();
      return clean.startsWith('#') ? clean : '#$clean';
    }
    final db = VinkiarSecureDatabase();
    final avatar = await db.getAvatarSheet("LOCAL_USER");
    final stats = avatar?['stats'] as Map<String, dynamic>? ?? {};
    final alias = stats['alias']?.toString() ?? avatar?['alias']?.toString() ?? "Pionero";
    return alias.startsWith("#") ? alias : "#$alias";
  }

  /// 1. Sincroniza el estado de la Tribu / Bolsa Común
  Future<Map<String, dynamic>?> fetchTribuBolsa(
    String guildId, {
    String? guildName,
    String? memberHandle,
  }) async {
    try {
      final actor = await _getActorHandle(memberHandle);
      final queryParams = <String, String>{
        'member_handle': actor,
        if (guildName != null && guildName.trim().isNotEmpty) 'nombre': guildName.trim(),
      };
      final uri = Uri.parse('$_baseUrl/api/v1/tribus/$guildId/bolsa').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: await _getHeaders()).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data['tribu'] as Map);
      }
    } catch (e) {
      debugPrint(">>> [TRIBUS_SVC] Error fetchTribuBolsa: $e");
    }
    return null;
  }

  /// Consulta el saldo personal de Vinks en la Bóveda local SQLCipher
  Future<int> getLocalVinksBalance() async {
    final db = VinkiarSecureDatabase();
    final avatar = await db.getAvatarSheet("LOCAL_USER");
    final stats = avatar?['stats'] as Map<String, dynamic>? ?? {};
    return (stats['vinks'] as num?)?.toInt() ?? 150;
  }

  /// 2. Realizar aportación voluntaria de Vinks a la Bolsa Común
  Future<Map<String, dynamic>?> aportarVinks(
    String guildId,
    int amount,
    String concepto, {
    String? memberHandle,
  }) async {
    try {
      final actor = await _getActorHandle(memberHandle);

      final db = VinkiarSecureDatabase();
      final int currentVinks = await getLocalVinksBalance();

      if (currentVinks < amount) {
        return {"error": "Saldo insuficiente en tu Bóveda local ($currentVinks Ѵ disponibles)."};
      }

      final url = Uri.parse('$_baseUrl/api/v1/tribus/$guildId/bolsa/aportar');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'member_handle': actor,
          'monto_vinks': amount,
          'concepto': concepto,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final int updatedVinks = (currentVinks - amount).clamp(0, 999999);
        await db.updateAvatarData({'vinks': updatedVinks});

        final data = jsonDecode(response.body);
        final tribuMap = Map<String, dynamic>.from(data['tribu'] as Map);
        tribuMap['_local_vinks_after'] = updatedVinks;
        return tribuMap;
      } else {
        final err = jsonDecode(response.body);
        return {"error": err['detail'] ?? "Error al aportar Vinks."};
      }
    } catch (e) {
      debugPrint(">>> [TRIBUS_SVC] Error aportarVinks: $e");
      return {"error": "Fallo de conexión con el Servidor ZKA."};
    }
  }

  /// 2B. Proponer gasto desde la Bolsa Común (sujeto a quórum o veto SSC)
  Future<Map<String, dynamic>?> proponerGasto({
    required String guildId,
    required int amount,
    required String concepto,
    String beneficiaryHandle = '',
    String? proposerHandle,
  }) async {
    try {
      final actor = await _getActorHandle(proposerHandle);
      final url = Uri.parse('$_baseUrl/api/v1/tribus/$guildId/bolsa/proponer-gasto');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'proposer_handle': actor,
          'beneficiary_handle': beneficiaryHandle,
          'monto_vinks': amount,
          'concepto': concepto,
        }),
      ).timeout(const Duration(seconds: 8));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Map<String, dynamic>.from(data['tribu'] as Map);
      }
      return {"error": data['detail'] ?? "No se pudo registrar la propuesta."};
    } catch (e) {
      debugPrint(">>> [TRIBUS_SVC] Error proponerGasto: $e");
      return {"error": "Fallo de conexión con el Servidor ZKA."};
    }
  }

  /// 2C. Votar propuesta de gasto en la Bolsa Común
  Future<Map<String, dynamic>?> votarGasto({
    required String guildId,
    required String movimientoId,
    required String decision, // APPROVE | REJECT | VETO_ROJO
    String? voterHandle,
  }) async {
    try {
      final actor = await _getActorHandle(voterHandle);
      final url = Uri.parse('$_baseUrl/api/v1/tribus/$guildId/bolsa/votar');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'movimiento_id': movimientoId,
          'voter_handle': actor,
          'decision': decision,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data['tribu'] as Map);
      }
    } catch (e) {
      debugPrint(">>> [TRIBUS_SVC] Error votarGasto: $e");
    }
    return null;
  }

  /// 3. Crear Decisión Colectiva (Quórum, Mínima Miseria, Subasta Ciega, Cremallera)
  Future<Map<String, dynamic>?> crearDecisionColectiva({
    required String guildId,
    required String titulo,
    required String descripcion,
    required String modo, // LEAST_MISERY | QUORUM | ZIPPER | BLIND_AUCTION
    required int quorumPct,
    required List<String> opciones,
    String? creatorHandle,
  }) async {
    try {
      final actor = await _getActorHandle(creatorHandle);
      final url = Uri.parse('$_baseUrl/api/v1/decisiones/crear');

      final ops = opciones.asMap().entries.map((e) => {
        "id": "OPT_${e.key + 1}",
        "label": e.value,
      }).toList();

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'guild_id': guildId,
          'titulo': titulo,
          'descripcion': descripcion,
          'modo': modo,
          'creator_handle': actor,
          'quorum_pct': quorumPct,
          'opciones': ops,
          'participantes': [],
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data['decision'] as Map);
      }
    } catch (e) {
      debugPrint(">>> [TRIBUS_SVC] Error crearDecision: $e");
    }
    return null;
  }

  /// 4. Listar decisiones activas e históricas de la Tribu
  Future<List<Map<String, dynamic>>> listarDecisiones(String guildId) async {
    try {
      final url = Uri.parse('$_baseUrl/api/v1/decisiones/$guildId');
      final response = await http.get(url, headers: await _getHeaders()).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['decisiones']);
      }
    } catch (e) {
      debugPrint(">>> [TRIBUS_SVC] Error listarDecisiones: $e");
    }
    return [];
  }

  /// 4B. Obtener el estado actualizado de una decisión concreta por su ID
  Future<Map<String, dynamic>?> fetchDecisionDetail(String decisionId) async {
    try {
      final url = Uri.parse('$_baseUrl/api/v1/decisiones/detalle/$decisionId');
      final response = await http.get(url, headers: await _getHeaders()).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data['decision'] as Map);
      }
    } catch (e) {
      debugPrint(">>> [TRIBUS_SVC] Error fetchDecisionDetail: $e");
    }
    return null;
  }

  /// 5. Emitir Voto en Decisión
  Future<Map<String, dynamic>?> votarDecision({
    required String decisionId,
    String? optionId,
    int? bidVinks,
    Map<String, dynamic>? ratings,
    String? voterHandle,
  }) async {
    try {
      final actor = await _getActorHandle(voterHandle);
      final url = Uri.parse('$_baseUrl/api/v1/decisiones/$decisionId/votar');

      final payload = <String, dynamic>{
        'voter_handle': actor,
      };

      if (optionId != null) payload['option_id'] = optionId;
      if (bidVinks != null) payload['bid_vinks'] = bidVinks;
      if (ratings != null) payload['ratings'] = ratings;

      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data['decision'] as Map);
      }
    } catch (e) {
      debugPrint(">>> [TRIBUS_SVC] Error votarDecision: $e");
    }
    return null;
  }

  /// 6. Resolver Decisión Colectiva (Trigger Manual / Timeout)
  Future<Map<String, dynamic>?> resolverDecision(
    String decisionId, {
    String? resolverHandle,
  }) async {
    try {
      final actor = await _getActorHandle(resolverHandle);
      final url = Uri.parse('$_baseUrl/api/v1/decisiones/$decisionId/resolver');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'resolver_handle': actor}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(data['decision'] as Map);
      }
    } catch (e) {
      debugPrint(">>> [TRIBUS_SVC] Error resolverDecision: $e");
    }
    return null;
  }
}
