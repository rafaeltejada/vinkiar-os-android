import 'dart:math';

enum RelationshipLevel {
  VERDE,  // Sincronización / Rompehielos
  AZUL,   // Restauración / Intimidad Emocional
  ROJO    // Consecuencia / Pasión y Kink
}

enum DestinyEffect {
  NADA,
  DM,                // Dilema Moral / Exponer Secretos
  GIRO,            // Cambio de carta de objetivos
  OXIDO,          // Desgaste / Mecánica de Reparación
  EVENTO_ESPECIAL  // ¡Ronda libre o Reto Grupal Épico!
}

class VinkiarDestinyEngine {
  final int activationThreshold;
  final Random _random = Random();

  // Tablas de distribución de consecuencias en Fase 2 (d100)
  // Rangos acumulativos: (mínimo, máximo) para cada efecto
  static const Map<RelationshipLevel, Map<DestinyEffect, List<int>>> PROBABILITY_TABLES = {
    RelationshipLevel.VERDE: {
      DestinyEffect.DM: [1, 50],       // 50% de probabilidad
      DestinyEffect.GIRO: [51, 80],    // 30% de probabilidad
      DestinyEffect.OXIDO: [81, 100]   // 20% de probabilidad
    },
    RelationshipLevel.AZUL: {
      DestinyEffect.DM: [1, 25],       // 25% de probabilidad
      DestinyEffect.GIRO: [26, 75],    // 50% de probabilidad
      DestinyEffect.OXIDO: [76, 100]   // 25% de probabilidad
    },
    RelationshipLevel.ROJO: {
      DestinyEffect.DM: [1, 15],       // 15% de probabilidad
      DestinyEffect.GIRO: [16, 35],    // 20% de probabilidad
      DestinyEffect.OXIDO: [36, 100]   // 65% de probabilidad
    }
  };

  VinkiarDestinyEngine({this.activationThreshold = 4});

  int rollD10() {
    return _random.nextInt(10) + 1; // 1-10
  }

  int rollD100() {
    return _random.nextInt(100) + 1; // 1-100
  }

  Map<String, dynamic> resolveRound(RelationshipLevel level, int numModifiers) {
    int mods = numModifiers < 1 ? 1 : numModifiers;

    // --- FASE 1: ¿Se activa algo? ---
    List<int> rollsPhase1 = List.generate(mods, (_) => rollD10());

    // Comprobar si ha salido un 10 (Evento Especial) - Toma prioridad absoluta
    bool specialEventTriggered = rollsPhase1.any((roll) => roll == 10);

    // Comprobar si algún dado ha superado el umbral de activación (<= activationThreshold)
    bool negativeEffectTriggered = rollsPhase1.any((roll) => roll <= activationThreshold);

    DestinyEffect resultEffect = DestinyEffect.NADA;
    int? rollPhase2;

    if (specialEventTriggered) {
      resultEffect = DestinyEffect.EVENTO_ESPECIAL;
    } else if (negativeEffectTriggered) {
      // --- FASE 2: ¿Qué efecto negativo se ejecuta? ---
      rollPhase2 = rollD100();
      final table = PROBABILITY_TABLES[level]!;

      for (var entry in table.entries) {
        int low = entry.value[0];
        int high = entry.value[1];
        if (rollPhase2 >= low && rollPhase2 <= high) {
          resultEffect = entry.key;
          break;
        }
      }
    }

    return {
      "level": level.toString().split('.').last,
      "num_modifiers": mods,
      "rolls_phase_1": rollsPhase1,
      "special_event_triggered": specialEventTriggered,
      "negative_effect_triggered": negativeEffectTriggered,
      "roll_phase_2": rollPhase2,
      "result": resultEffect.toString().split('.').last
    };
  }
}
