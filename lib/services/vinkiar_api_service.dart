import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

typedef JsonMap = Map<String, dynamic>;

class VinkiarApiService {
  static final VinkiarApiService _instance = VinkiarApiService._internal();
  factory VinkiarApiService() => _instance;
  VinkiarApiService._internal();

  final String baseUrl = ApiConfig.baseUrl;

  /// Envío del token de calibración para la forja
  Future<bool> sendCalibrationToken(String hiddenType) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/forja/calibrar/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token_abstracto': hiddenType, 'fase': 1}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("VINKIAR_API_ERROR: Falla de transmisión - $e");
      return false;
    }
  }

  /// Genera un token efímero ZKA (VNK-XXXX) con TTL de 90 segundos al escanear el QR físico
  Future<JsonMap?> generarTokenEfimero({
    required String glifoId,
    required String userId,
    String santuarioId = "ST-LOCAL-01",
  }) async {
    final payload = {
      'user_id': userId,
      'glifo_id': glifoId,
      'santuario_id': santuarioId,
    };

    // 1. Conexión directa a FastAPI
    try {
      final uri = Uri.parse('$baseUrl/api/v1/santuarios/generar-token-efimero');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body) as JsonMap;
      }
    } catch (_) {}

    // 2. Fallback táctico BFF
    try {
      final bffUri = Uri.parse('https://vinkiar.com/api/v1/santuarios/generar-token-efimero');
      final bffRes = await http.post(
        bffUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));

      if (bffRes.statusCode == 200 || bffRes.statusCode == 201) {
        return jsonDecode(bffRes.body) as JsonMap;
      }
    } catch (e) {
      print("VINKIAR_TOKEN_ERROR: No se pudo generar token efímero ($e)");
    }

    return null;
  }

  /// Sondeo de verificación de canje en barra
  Future<String> checkTokenStatus(String token) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/santuarios/token-status/$token');
      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['status'] ?? 'PENDING';
      }
    } catch (_) {}
    return 'PENDING';
  }

  /// Recupera los Santuarios activos con baliza phygital y señuelos
  Future<List<JsonMap>> fetchSantuariosRadar({
    double? lat,
    double? lng,
  }) async {
    final queryParams = (lat != null && lng != null) ? '?lat=$lat&lng=$lng' : '';

    // 1. Intento primario contra la API configurada en ApiConfig
    try {
      final uri = Uri.parse('$baseUrl/api/v1/santuarios/radar$queryParams');
      final res = await http.get(uri, headers: {
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final List nodes = data['nodes'] ?? [];
        if (nodes.isNotEmpty) {
          return List<JsonMap>.from(nodes);
        }
      }
    } catch (_) {}

    // 2. Puente táctico: si la API central no responde o está vacía, consulta el BFF de Next.js en producción
    try {
      final bffUri = Uri.parse('https://vinkiar.com/api/v1/santuarios/radar$queryParams');
      final bffRes = await http.get(bffUri, headers: {
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 4));

      if (bffRes.statusCode == 200) {
        final data = jsonDecode(bffRes.body);
        final List nodes = data['nodes'] ?? [];
        return List<JsonMap>.from(nodes);
      }
    } catch (e) {
      print("VINKIAR_RADAR_ERROR: Imposible alcanzar balizas de Santuario ($e)");
    }

    return [];
  }
}