import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../ui/theme.dart';

// =========================================================================
// SECCIÓN 1: MODELO DE EVENTO PHYGITAL DE LA TABERNA
// =========================================================================

class EventoTabernaItem {
  final String id;
  final String titulo;
  final String descripcion;
  final String tipoEvento;
  final String faccionObjetivo;
  final String gremioId;
  final String pais;
  final String comunidadAutonoma;
  final String provincia;
  final String municipios;
  final String codigosPostales;
  final String zona;
  final String categoria;
  final String fechaInicio;
  final String fechaFin;
  final String horaInicio;
  final String horaFin;
  final String fechaEvento;
  final String horario;
  final int recompensaVinks;
  final int xpReward;
  final String santuarioId;
  final String santuarioAlias;
  final double latitud;
  final double longitud;
  final int aforoMax;
  final int asistentesCount;
  final List<String> asistentes;
  final bool inscrito;
  final String imagenUrl;
  final String enlaceExterno;

  const EventoTabernaItem({
    required this.id,
    required this.titulo,
    required this.descripcion,
    this.tipoEvento = 'ZONA_LOCAL',
    this.faccionObjetivo = 'TODAS',
    this.gremioId = '',
    this.pais = 'España',
    this.comunidadAutonoma = '',
    this.provincia = '',
    this.municipios = '',
    this.codigosPostales = '',
    this.zona = 'GLOBAL',
    this.categoria = 'SOCIAL',
    this.fechaInicio = '',
    this.fechaFin = '',
    this.horaInicio = '00:00',
    this.horaFin = '23:59',
    this.fechaEvento = 'Hoy',
    this.horario = 'Todo el día',
    this.recompensaVinks = 50,
    this.xpReward = 150,
    this.santuarioId = '',
    this.santuarioAlias = '',
    this.latitud = 37.389091,
    this.longitud = -5.984459,
    this.aforoMax = 0,
    this.asistentesCount = 0,
    this.asistentes = const [],
    this.inscrito = false,
    this.imagenUrl = '',
    this.enlaceExterno = '',
  });

  factory EventoTabernaItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val, double fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? fallback;
    }

    int parseInt(dynamic val, int fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? fallback;
    }

    final rawAsistentes = (json['asistentes'] as List? ?? []).map((e) => e.toString()).toList();

    return EventoTabernaItem(
      id: json['id']?.toString() ?? '',
      titulo: json['titulo']?.toString() ?? 'Evento de La Taberna',
      descripcion: json['descripcion']?.toString() ?? '',
      tipoEvento: json['tipo_evento']?.toString() ?? 'ZONA_LOCAL',
      faccionObjetivo: json['faccion_objetivo']?.toString() ?? 'TODAS',
      gremioId: json['gremio_id']?.toString() ?? '',
      pais: json['pais']?.toString() ?? 'España',
      comunidadAutonoma: json['comunidad_autonoma']?.toString() ?? '',
      provincia: json['provincia']?.toString() ?? '',
      municipios: json['municipios']?.toString() ?? '',
      codigosPostales: json['codigos_postales']?.toString() ?? '',
      zona: json['zona']?.toString() ?? 'GLOBAL',
      categoria: json['categoria']?.toString().toUpperCase() ?? 'SOCIAL',
      fechaInicio: json['fecha_inicio']?.toString() ?? '',
      fechaFin: json['fecha_fin']?.toString() ?? '',
      horaInicio: json['hora_inicio']?.toString() ?? '00:00',
      horaFin: json['hora_fin']?.toString() ?? '23:59',
      fechaEvento: json['fecha_evento']?.toString() ?? 'Hoy',
      horario: json['horario']?.toString() ?? 'Todo el día',
      recompensaVinks: parseInt(json['recompensa_vinks'], 50),
      xpReward: parseInt(json['xp_reward'], 150),
      santuarioId: json['santuario_id']?.toString() ?? '',
      santuarioAlias: json['santuario_alias']?.toString() ?? '',
      latitud: parseDouble(json['latitud'], 37.389091),
      longitud: parseDouble(json['longitud'], -5.984459),
      aforoMax: parseInt(json['aforo_max'], 0),
      asistentesCount: parseInt(json['asistentes_count'], rawAsistentes.length),
      asistentes: rawAsistentes,
      inscrito: json['inscrito'] == true,
      imagenUrl: json['imagen_url']?.toString() ?? '',
      enlaceExterno: json['enlace_externo']?.toString() ?? '',
    );
  }
}

// =========================================================================
// SECCIÓN 2: SERVICIO HTTP PARA EVENTOS E INSCRIPCIONES EN LA TABERNA
// =========================================================================

class TabernaEventosService {
  static final TabernaEventosService _instance = TabernaEventosService._internal();
  factory TabernaEventosService() => _instance;
  TabernaEventosService._internal();

  String get _cleanBaseUrl => ApiConfig.baseUrl.endsWith('/')
      ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
      : ApiConfig.baseUrl;

  Future<List<EventoTabernaItem>> fetchEventos({
    String? zona,
    String? cp,
    String? faccion,
    String? gremioId,
    String? categoria,
    String memberHandle = '',
  }) async {
    try {
      final params = <String, String>{};
      if (zona != null && zona.trim().isNotEmpty) params['zona'] = zona.trim();
      if (cp != null && cp.trim().isNotEmpty) params['cp'] = cp.trim();
      if (faccion != null && faccion.trim().isNotEmpty) params['faccion'] = faccion.trim();
      if (gremioId != null && gremioId.trim().isNotEmpty) params['gremio_id'] = gremioId.trim();
      if (categoria != null && categoria.trim().isNotEmpty && categoria != 'ALL') {
        params['categoria'] = categoria.trim();
      }
      if (memberHandle.trim().isNotEmpty) {
        params['member_handle'] = memberHandle.trim();
      }

      final uri = Uri.parse('$_cleanBaseUrl/api/v1/taberna/eventos').replace(
        queryParameters: params.isEmpty ? null : params,
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 7));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final rawList = data['eventos'] as List? ?? [];
        return rawList
            .map((e) => EventoTabernaItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<EventoTabernaItem?> inscribirseEvento({
    required String eventoId,
    required String memberHandle,
  }) async {
    try {
      final uri = Uri.parse('$_cleanBaseUrl/api/v1/taberna/eventos/${Uri.encodeComponent(eventoId)}/inscribirse');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'member_handle': memberHandle}),
      ).timeout(const Duration(seconds: 7));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['evento'] is Map<String, dynamic>) {
          return EventoTabernaItem.fromJson(Map<String, dynamic>.from(data['evento']));
        }
      }
    } catch (_) {}
    return null;
  }
}

// =========================================================================
// SECCIÓN 3: TARJETA VISUAL DE EVENTO PHYGITAL EN LA TABERNA
// =========================================================================

class EventoTabernaCard extends StatelessWidget {
  final EventoTabernaItem evento;
  final VoidCallback onAceptar;
  final VoidCallback? onVerEnMapa;
  final VoidCallback? onAbrirDecision;

  const EventoTabernaCard({
    super.key,
    required this.evento,
    required this.onAceptar,
    this.onVerEnMapa,
    this.onAbrirDecision,
  });

  Color _categoryColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'TALLER':
        return VinkiarColors.aegisCyan;
      case 'RAID':
        return VinkiarColors.panicRed;
      case 'TRIBU':
        return VinkiarColors.vertigoGold;
      case 'SOCIAL':
      default:
        return VinkiarColors.hackingGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _categoryColor(evento.categoria);
    final String aforoText = evento.aforoMax > 0
        ? "${evento.asistentesCount}/${evento.aforoMax} plazas"
        : "${evento.asistentesCount} inscritos";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141923), Color(0xFF0B0E14)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.65), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (evento.imagenUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              child: Image.network(
                evento.imagenUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera de insignias
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: accent.withOpacity(0.75)),
                            ),
                            child: Text(
                              "⚡ EVENTO · ${evento.categoria}",
                              style: GoogleFonts.jetBrainsMono(
                                color: accent,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (evento.gremioId.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: VinkiarColors.vertigoGold.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.6)),
                              ),
                              child: Text(
                                "🛡️ ${evento.gremioId}",
                                style: GoogleFonts.jetBrainsMono(
                                  color: VinkiarColors.vertigoGold,
                                  fontSize: 8.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: VinkiarColors.abyssBlack,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        "👥 $aforoText",
                        style: GoogleFonts.jetBrainsMono(
                          color: Colors.white70,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),

                // Título y Descripción
                Text(
                  evento.titulo,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  evento.descripcion,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: VinkiarColors.textDim,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),

                // Metadatos Phygital (Ubicación + Fecha/Hora + Recompensas)
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: VinkiarColors.abyssBlack,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: VinkiarColors.vertigoGold, size: 14),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              evento.santuarioAlias.isNotEmpty
                                  ? "${evento.santuarioAlias} (${evento.zona})"
                                  : evento.zona,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.jetBrainsMono(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.schedule, color: VinkiarColors.aegisCyan, size: 13),
                              const SizedBox(width: 5),
                              Text(
                                "${evento.fechaEvento} · ${evento.horario}",
                                style: GoogleFonts.jetBrainsMono(
                                  color: VinkiarColors.aegisCyan,
                                  fontSize: 9.0,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            "+${evento.recompensaVinks} Ѵ | +${evento.xpReward} XP",
                            style: GoogleFonts.jetBrainsMono(
                              color: VinkiarColors.vertigoGold,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 11),

                // Botonera de Acción (Mapa + Decidir AVM + Inscripción)
                Row(
                  children: [
                    if (onVerEnMapa != null) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: VinkiarColors.aegisCyan),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          minimumSize: Size.zero,
                        ),
                        icon: const Icon(Icons.map_outlined, size: 14, color: VinkiarColors.aegisCyan),
                        label: Text(
                          "MAPA",
                          style: GoogleFonts.jetBrainsMono(
                            color: VinkiarColors.aegisCyan,
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: onVerEnMapa,
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (onAbrirDecision != null) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: VinkiarColors.vertigoGold),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          minimumSize: Size.zero,
                        ),
                        icon: const Icon(Icons.balance, size: 14, color: VinkiarColors.vertigoGold),
                        label: Text(
                          "AVM",
                          style: GoogleFonts.jetBrainsMono(
                            color: VinkiarColors.vertigoGold,
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: onAbrirDecision,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: evento.inscrito
                              ? VinkiarColors.hackingGreen.withOpacity(0.25)
                              : accent,
                          foregroundColor: evento.inscrito
                              ? VinkiarColors.hackingGreen
                              : Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        ),
                        icon: Icon(
                          evento.inscrito ? Icons.check_circle : Icons.bolt,
                          size: 15,
                        ),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            evento.inscrito ? "INSCRITO · VER EN PROGRESO" : "UNIRME AL EVENTO",
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                        onPressed: onAceptar,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
