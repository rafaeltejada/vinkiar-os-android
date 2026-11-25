import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class SantuarioNode {
  final String id;
  final String alias;
  final String tipoSantuario; // 'FIJO' o 'MOVIL'
  final String categoria;
  final String iconoMapa; // CAFE | BAR_PUB | CULTURA_LIBRERIA | TERAPIA_SALUD | COWORKING | OCIO_AIRE_LIBRE
  final String imagenUrl;
  final double latitud;
  final double longitud;
  final bool jitterApplied;
  final int misionesCount;
  final String? contacto;
  final String localDireccion;
  final String localCiudad;
  final String redesSociales;
  final List<String> medallas;
  final Map<String, dynamic>? senuelo;
  final List<String> glifosAceptados;

  SantuarioNode({
    required this.id,
    required this.alias,
    required this.tipoSantuario,
    required this.categoria,
    this.iconoMapa = 'CAFE',
    this.imagenUrl = '',
    required this.latitud,
    required this.longitud,
    this.jitterApplied = false,
    this.misionesCount = 0,
    this.contacto,
    this.localDireccion = '',
    this.localCiudad = '',
    this.redesSociales = '',
    this.medallas = const [],
    this.senuelo,
    this.glifosAceptados = const [],
  });

  factory SantuarioNode.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    return SantuarioNode(
      id: json['id']?.toString() ?? '',
      alias: json['alias']?.toString() ?? 'Santuario ZKA',
      tipoSantuario: json['tipo_santuario']?.toString().toUpperCase() ?? 'FIJO',
      categoria: json['categoria']?.toString().toUpperCase() ?? 'GENERAL',
      iconoMapa: json['icono_mapa']?.toString().toUpperCase() ?? 'CAFE',
      imagenUrl: json['imagen_url']?.toString() ?? '',
      latitud: parseDouble(json['latitud'] ?? json['lat'], 37.389091),
      longitud: parseDouble(json['longitud'] ?? json['lng'], -5.984459),
      jitterApplied: json['jitter_applied'] == true,
      misionesCount: int.tryParse(json['misiones_count']?.toString() ?? '0') ?? 0,
      contacto: json['contacto']?.toString(),
      localDireccion: json['local_direccion']?.toString() ?? '',
      localCiudad: json['local_ciudad']?.toString() ?? '',
      redesSociales: json['redes_sociales']?.toString() ?? '',
      medallas: (json['medallas'] as List? ?? []).map((e) => e.toString()).toList(),
      senuelo: json['senuelo'] is Map<String, dynamic> ? json['senuelo'] : null,
      glifosAceptados: (json['glifos_aceptados'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class EphemeralTokenResponse {
  final String token;
  final int ttlSeconds;
  final double expiresAt;
  final String santuarioId;
  final String santuarioAlias;
  final String promoTitulo;
  final int vinksReward;
  final int xpReward;

  EphemeralTokenResponse({
    required this.token,
    required this.ttlSeconds,
    required this.expiresAt,
    required this.santuarioId,
    required this.santuarioAlias,
    required this.promoTitulo,
    required this.vinksReward,
    required this.xpReward,
  });

  factory EphemeralTokenResponse.fromJson(Map<String, dynamic> json) {
    return EphemeralTokenResponse(
      token: json['token'] ?? '',
      ttlSeconds: json['ttl_seconds'] ?? 90,
      expiresAt: (json['expires_at'] as num).toDouble(),
      santuarioId: json['santuario_id'] ?? '',
      santuarioAlias: json['santuario_alias'] ?? '',
      promoTitulo: json['promo_titulo'] ?? '',
      vinksReward: json['vinks_reward'] ?? 50,
      xpReward: json['xp_reward'] ?? 120,
    );
  }
}

class SantuariosService {
  static final SantuariosService _instance = SantuariosService._internal();
  factory SantuariosService() => _instance;
  SantuariosService._internal();

  String get _baseUrl {
    return ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
  }

  /// Sincroniza la ubicación GPS del usuario si tiene un Santuario Móvil enlazado
  Future<void> syncLinkedMobileSantuarioLocation({
    required String userHandle,
    required double lat,
    required double lng,
  }) async {
    if (userHandle.trim().isEmpty) return;
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/v1/santuarios/sync-mobile-location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_handle': userHandle.trim(),
          'latitud': lat,
          'longitud': lng,
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<List<SantuarioNode>> fetchRadarNodes({double? lat, double? lng}) async {
    try {
      final query = (lat != null && lng != null) ? '?lat=$lat&lng=$lng' : '';
      final url = Uri.parse('$_baseUrl/api/v1/santuarios/radar$query');
      final res = await http.get(url).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['nodes'] as List? ?? [];
        return list.map((n) => SantuarioNode.fromJson(n)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<EphemeralTokenResponse?> generarTokenEfimero({
    required String userId,
    required String glifoId,
    String santuarioId = "ST-LOCAL-01",
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/v1/santuarios/generar-token-efimero');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'glifo_id': glifoId,
          'santuario_id': santuarioId,
        }),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 201 || res.statusCode == 200) {
        return EphemeralTokenResponse.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  Future<String> checkTokenStatus(String token) async {
    try {
      final url = Uri.parse('$_baseUrl/api/v1/santuarios/token-status/$token');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['status'] ?? 'NOT_FOUND';
      }
    } catch (_) {}
    return 'PENDING';
  }
}

class SantuarioMedallasWrap extends StatelessWidget {
  final List<String> medallas;
  const SantuarioMedallasWrap({super.key, required this.medallas});

  static Map<String, dynamic> _metaMedalla(String id) {
    switch (id.toUpperCase()) {
      case 'JUEGO_SEGURO':
        return {'label': '🛡️ Juego Seguro', 'color': const Color(0xFF39FF14)};
      case 'TRATO_EXCEPCIONAL':
        return {'label': '⭐ Trato Excepcional', 'color': const Color(0xFFE5B869)};
      case 'LOCAL_ROMANTICO':
        return {'label': '💜 Local Romántico', 'color': const Color(0xFFF472B6)};
      case 'COMERCIO_ECOLOGICO':
        return {'label': '🌱 Comercio Ecológico', 'color': const Color(0xFF34D399)};
      case 'TERRITORIO_SOBERANO':
        return {'label': '📵 Libre de Pantallas', 'color': const Color(0xFF00E5FF)};
      case 'ACCESIBLE_PMR':
        return {'label': '♿ Accesible', 'color': const Color(0xFFC084FC)};
      default:
        return {'label': '🏅 $id', 'color': const Color(0xFFE5B869)};
    }
  }

  @override
  Widget build(BuildContext context) {
    if (medallas.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: medallas.map((m) {
        final meta = _metaMedalla(m);
        final Color color = meta['color'] as Color;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            meta['label'] as String,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }).toList(),
    );
  }
}