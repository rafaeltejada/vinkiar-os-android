
class Glitch {
  final String id;
  final String title;
  final String description;
  final String category;
  final String level;
  final int energyCost;
  final String keyMechanic;
  final Map<String, dynamic> metadata;

  Glitch({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.level,
    required this.energyCost,
    required this.keyMechanic,
    required this.metadata,
  });

  factory Glitch.fromJson(Map<String, dynamic> json) {
    return Glitch(
      id: json['id_glitch'] ?? json['id'] ?? '',
      title: json['titulo'] ?? json['title'] ?? '',
      description: json['descripcion'] ?? json['description'] ?? '',
      category: json['categoria'] ?? json['category'] ?? '',
      level: json['nivel_asociado'] ?? json['level'] ?? 'VERDE',
      energyCost: json['consumo_energia'] ?? json['energy_cost'] ?? 0,
      keyMechanic: json['mecanica_clave'] ?? json['key_mechanic'] ?? '',
      metadata: json,
    );
  }

  Map<String, dynamic> toJson() => metadata;
}

class GlitchManager {
  static final GlitchManager _instance = GlitchManager._internal();
  factory GlitchManager() => _instance;
  GlitchManager._internal();

  final List<Glitch> _glitches = [
    Glitch(
      id: "GL_RUST_001",
      title: "La Subasta Inversa del Sindicato",
      description: "El Sindicato de Mercaderes de Óxido ha interceptado vuestra red. Negociad una tarea real y pujad Vinks en secreto para libraros de hacerla. El perdedor ejecuta la tarea y gana XP.",
      category: "Desgaste Cotidiano",
      level: "VERDE",
      energyCost: 15,
      keyMechanic: "REVERSE_AUCTION_CHORE",
      metadata: {
        "recompensa_xp_ejecutor": 150,
        "coste_vinks_salvacion_min": 20
      }
    ),
    Glitch(
      id: "GL_RUST_002",
      title: "El Protocolo del Silencio Sincrónico",
      description: "Queda prohibido hablar durante 5 minutos. Comunicaros únicamente por gestos o trazando letras con el dedo en la piel. Pronunciar palabras drena 10 Vinks por infracción.",
      category: "Privación Comunicación",
      level: "AZUL",
      energyCost: 20,
      keyMechanic: "SILENT_TELEGRAPH",
      metadata: {
        "duracion_segundos": 300,
        "multa_vinks_por_infraccion": 10,
        "destinatario_multa": "BANCA_GREMIO"
      }
    ),
    Glitch(
      id: "GL_RUST_003",
      title: "Fuga de Datos (Dilema de Cortafuegos)",
      description: "Un secreto o límite no resuelto de tu Hoja de Alma va a ser filtrado. Paga 50 Vinks para encriptarlo de nuevo o confiesa con honestidad para ganar 100 XP gratis.",
      category: "Dilema Moral",
      level: "AZUL",
      energyCost: 10,
      keyMechanic: "RADICAL_HONESTY_DILEMMA",
      metadata: {
        "coste_vinks_encriptacion": 50,
        "recompensa_xp_vulnerabilidad": 100
      }
    ),
    Glitch(
      id: "GL_RUST_004",
      title: "Secuestro de Frecuencia (Aftercare Forzado)",
      description: "Los sensores detectan estrés o fatiga relacional. Las misiones normales quedan suspendidas temporalmente. Debéis reposar juntos, sincronizar la respiración o daros un masaje de manos durante 3 minutos.",
      category: "Aftercare Obligatorio",
      level: "ROJO",
      energyCost: 0,
      keyMechanic: "BURNOUT_PREVENTION",
      metadata: {
        "duracion_segundos": 180,
        "bloquea_subastas": true,
        "trigger_burnout_prevention": true
      }
    )
  ];

  List<Glitch> get allGlitches => _glitches;

  Glitch getRandomGlitchByLevel(String level) {
    final filtered = _glitches.where((g) => g.level == level).toList();
    if (filtered.isEmpty) return _glitches.first;
    return filtered[DateTime.now().millisecond % filtered.length];
  }
}
