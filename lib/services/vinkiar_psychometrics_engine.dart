import 'dart:math' as math;

/// Motor Psicométrico y Somático del Triple Eneagrama Vivo (Vinkiar OS)
/// Implementa las ecuaciones del Informe Técnico III, Hoja de Alma y Guía Maestra:
/// - Rueda I (Ego): 9 Eneatipos de Daniels + Arquetipos de Seducción (Greene / Vallejo-Nágera) + Horney
/// - Rueda II (Eros): 5 Blueprints Somáticos + Escala SOS (Erotofilia/Erotofobia) + Control Dual
/// - Rueda III (Philia): 4 Estilos de Apego (Bowlby / Bartholomew) + Diferenciación del Self (Bowen -> I_AR)
/// - Cables de Atracción (Luis Tejedor): Sexual, Emocional, Racional
/// - Delta-Engine con filtro de inercia exponencial (lambda = 0.15 Ego, 0.25 Eros/Philia)
class VinkiarPsychometricsEngine {
  static const double lambdaEgo = 0.15;
  static const double lambdaErosPhilia = 0.25;
  static const double minRadialFloor = 0.05;
  static const double maxRadialCeiling = 1.00;

  /// Catálogo canónico de los 9 Eneatipos + Arquetipos de Seducción + Vector de Horney
  static const Map<int, Map<String, String>> egoArchetypeCatalog = {
    1: {
      'key': 'divo',
      'enneagram': 'Eneatipo 1 (Perfeccionista)',
      'seduction': 'EL DIVO / LA DIVA',
      'horney': 'Contra las personas',
      'defense': 'Formación reactiva',
      'natural_role': 'ARQUITECTO DE LA ÉGIDA (E1 · Divo)',
    },
    2: {
      'key': 'rescatador',
      'enneagram': 'Eneatipo 2 (Ayudador)',
      'seduction': 'EL RESCATADOR',
      'horney': 'Hacia las personas',
      'defense': 'Proyección de necesidades',
      'natural_role': 'SANADOR SOMÁTICO (E2 · Rescatador)',
    },
    3: {
      'key': 'vividor',
      'enneagram': 'Eneatipo 3 (Realizador)',
      'seduction': 'EL VIVIDOR / LIBERTINO',
      'horney': 'Contra las personas',
      'defense': 'Identificación con el rol',
      'natural_role': 'ESTRATEGA DEL ÁGORA (E3 · Vividor)',
    },
    4: {
      'key': 'artista',
      'enneagram': 'Eneatipo 4 (Individualista)',
      'seduction': 'EL ARTISTA',
      'horney': 'Lejos de las personas',
      'defense': 'Introyección y sublimación',
      'natural_role': 'ALQUIMISTA SIMBÓLICO (E4 · Artista)',
    },
    5: {
      'key': 'intelectual',
      'enneagram': 'Eneatipo 5 (Observador)',
      'seduction': 'EL INTELECTUAL',
      'horney': 'Lejos de las personas',
      'defense': 'Aislamiento cognitivo',
      'natural_role': 'TECNOMANTE INFILTRADOR (E5 · Intelectual)',
    },
    6: {
      'key': 'afrodita',
      'enneagram': 'Eneatipo 6 (Leal Escéptico)',
      'seduction': 'AFRODITA',
      'horney': 'Hacia / Contra las personas',
      'defense': 'Proyección e hipervigilancia',
      'natural_role': 'CENTINELA DE LA TRIBU (E6 · Afrodita)',
    },
    7: {
      'key': 'cautivador',
      'enneagram': 'Eneatipo 7 (Epicúreo)',
      'seduction': 'EL CAUTIVADOR',
      'horney': 'Lejos de las personas',
      'defense': 'Racionalización optimista',
      'natural_role': 'BARDO REVOLUCIONARIO (E7 · Cautivador)',
    },
    8: {
      'key': 'lider',
      'enneagram': 'Eneatipo 8 (Desafiador)',
      'seduction': 'EL LÍDER',
      'horney': 'Contra las personas',
      'defense': 'Negación de vulnerabilidad',
      'natural_role': 'TANQUE DE LA ÉGIDA (E8 · Líder)',
    },
    9: {
      'key': 'encantador',
      'enneagram': 'Eneatipo 9 (Mediador)',
      'seduction': 'EL ENCANTADOR',
      'horney': 'Hacia las personas',
      'defense': 'Narcotización psíquica',
      'natural_role': 'DIPLOMÁTICO DEL LOTO (E9 · Encantador)',
    },
  };

  /// Determina el Arquetipo Natural completo a partir de las 3 Ruedas (Ego, Eros, Philia)
  static Map<String, dynamic> synthesizeNaturalArchetype({
    required Map<String, double> egoVector,
    required Map<String, double> erosVector,
    required Map<String, double> philiaVector,
  }) {
    // 1. Eneatipo dominante en Rueda I (Ego)
    int dominantEgoId = 5;
    double bestEgoVal = -1.0;
    egoArchetypeCatalog.forEach((id, meta) {
      final k = meta['key']!;
      final v = (egoVector[k] ?? (k == 'afrodita' ? (egoVector['cautivador'] ?? 0.0) : 0.0));
      if (v > bestEgoVal) {
        bestEgoVal = v;
        dominantEgoId = id;
      }
    });

    final egoMeta = egoArchetypeCatalog[dominantEgoId]!;

    // 2. Blueprint dominante en Rueda II (Eros)
    final erosMap = {
      'Energético': erosVector['energetico'] ?? 0.0,
      'Sensual': erosVector['sensual'] ?? 0.0,
      'Sexual': erosVector['sexual'] ?? 0.0,
      'Kinky': erosVector['kinky'] ?? 0.0,
      'Cambiaformas': erosVector['cambiaformas'] ?? 0.0,
    };
    String dominantBlueprint = 'Sensual';
    double bestErosVal = -1.0;
    erosMap.forEach((k, v) {
      if (v > bestErosVal) {
        bestErosVal = v;
        dominantBlueprint = k;
      }
    });

    // 3. Estilo de Apego dominante en Rueda III (Philia)
    final philiaMap = {
      'Seguro': philiaVector['seguro'] ?? 0.0,
      'Ocnófilo': philiaVector['ocnofilo'] ?? 0.0,
      'Filóbata': philiaVector['filobata'] ?? 0.0,
      'Desorganizado': philiaVector['desorganizado'] ?? 0.0,
    };
    String dominantPhilia = 'Seguro';
    double bestPhiliaVal = -1.0;
    philiaMap.forEach((k, v) {
      if (v > bestPhiliaVal) {
        bestPhiliaVal = v;
        dominantPhilia = k;
      }
    });

    final String fullNaturalArchetype = "${egoMeta['natural_role']} · $dominantBlueprint";

    return {
      'dominant_enneatype': dominantEgoId,
      'seduction_archetype': egoMeta['seduction'],
      'horney_vector': egoMeta['horney'],
      'defense_mechanism': egoMeta['defense'],
      'dominant_blueprint': dominantBlueprint,
      'dominant_attachment': dominantPhilia,
      'natural_archetype': fullNaturalArchetype,
      'character_class': fullNaturalArchetype,
    };
  }

  /// Filtro de inercia somática exponencial (Informe Técnico III, Sec. 1.2):
  /// r_i(t+1) = clamp( r_i(t)*(1 - lambda) + (r_i(t) + delta_i)*lambda, 0.05, 1.0 )
  /// Operando en escala porcentual [5.0, 100.0]
  static double applyInertialDelta({
    required double currentPct,
    required double deltaPct,
    required double lambda,
  }) {
    final double rNorm = (currentPct / 100.0).clamp(0.0, 1.0);
    final double dNorm = deltaPct / 100.0;
    final double nextNorm = (rNorm * (1.0 - lambda) + (rNorm + dNorm) * lambda)
        .clamp(minRadialFloor, maxRadialCeiling);
    return double.parse((nextNorm * 100.0).toStringAsFixed(2));
  }

  /// Área poligonal efectiva proyectada por una rueda regular de M ejes (radios en [0, 1])
  static double computePolygonAreaRatio(List<double> radiiPct) {
    final int m = radiiPct.length;
    if (m < 3) return 0.0;
    final double sinStep = math.sin((2.0 * math.pi) / m);
    double area = 0.0;
    for (int i = 0; i < m; i++) {
      final r1 = (radiiPct[i] / 100.0).clamp(0.0, 1.0);
      final r2 = (radiiPct[(i + 1) % m] / 100.0).clamp(0.0, 1.0);
      area += 0.5 * r1 * r2 * sinStep;
    }
    final double maxArea = 0.5 * m * sinStep;
    return maxArea > 0 ? (area / maxArea).clamp(0.0, 1.0) : 0.0;
  }

  /// Índice de Fuerza Somática (IFS en [0.0, 100.0]):
  /// IFS = 100 * (0.40 * A_ego/A_max + 0.35 * A_eros/A_max + 0.25 * A_philia/A_max)
  static double computeSomaticStrengthIndex({
    required List<double> egoRadiiPct,
    required List<double> erosRadiiPct,
    required List<double> philiaRadiiPct,
  }) {
    final aEgo = computePolygonAreaRatio(egoRadiiPct);
    final aEros = computePolygonAreaRatio(erosRadiiPct);
    final aPhilia = computePolygonAreaRatio(philiaRadiiPct);
    final ifs = 100.0 * (0.40 * aEgo + 0.35 * aEros + 0.25 * aPhilia);
    return double.parse(ifs.clamp(0.0, 100.0).toStringAsFixed(1));
  }

  /// Índice de Autonomía Relacional / Diferenciación del Self (I_AR en [0.0, 1.0]):
  /// I_AR = (D_c * D_e) / (1 + F_e)
  static double computeRelationalAutonomyIndex({
    required double cognitiveDifferentiation, // D_c in [0, 1]
    required double emotionalDeidentification, // D_e in [0, 1]
    required double activeFusionRate, // F_e >= 0
  }) {
    final iar = (cognitiveDifferentiation.clamp(0.0, 1.0) *
            emotionalDeidentification.clamp(0.0, 1.0)) /
        (1.0 + math.max(0.0, activeFusionRate));
    return double.parse(iar.clamp(0.0, 1.0).toStringAsFixed(2));
  }

  /// Índice de Coherencia Anímica (ICA en [0.0, 100.0]):
  /// ICA > 75 indica integración psicológica; ICA < 40 señala fricción somática aguda.
  static double computeSoulCoherenceIndex({
    required List<double> egoRadiiPct,
    required List<double> erosRadiiPct,
    required List<double> philiaRadiiPct,
  }) {
    double _stdDev(List<double> vals) {
      if (vals.isEmpty) return 0.0;
      final norm = vals.map((v) => (v / 100.0).clamp(0.0, 1.0)).toList();
      final mean = norm.reduce((a, b) => a + b) / norm.length;
      final variance = norm.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / norm.length;
      return math.sqrt(variance);
    }

    (double, double) _centroid(List<double> vals) {
      final int m = vals.length;
      if (m == 0) return (0.0, 0.0);
      double sx = 0.0;
      double sy = 0.0;
      for (int i = 0; i < m; i++) {
        final theta = (2.0 * math.pi * i) / m - math.pi / 2.0;
        final r = (vals[i] / 100.0).clamp(0.0, 1.0);
        sx += r * math.cos(theta);
        sy += r * math.sin(theta);
      }
      return (sx / m, sy / m);
    }

    final meanSigma = (_stdDev(egoRadiiPct) + _stdDev(erosRadiiPct) + _stdDev(philiaRadiiPct)) / 3.0;
    final cEgo = _centroid(egoRadiiPct);
    final cEros = _centroid(erosRadiiPct);
    final dCentroids = math.sqrt(math.pow(cEgo.$1 - cEros.$1, 2) + math.pow(cEgo.$2 - cEros.$2, 2));

    const double alpha = 0.85;
    const double beta = 0.45;
    final ica = 100.0 * (1.0 - (alpha * meanSigma + beta * dCentroids)).clamp(0.0, 1.0);
    return double.parse(ica.toStringAsFixed(1));
  }

  /// Índice de Colisión Afectiva Diádica (ICA_diadico en [0.0, 1.0]):
  /// Detecta la danza de persecución-distanciamiento (Ocnófilo x Filóbata) ponderada por I_AR
  static double computeDyadicAffectiveCollision({
    required double anxietyA, // [0, 1]
    required double avoidanceB, // [0, 1]
    required double anxietyB, // [0, 1]
    required double avoidanceA, // [0, 1]
    required double iarA, // [0, 1]
    required double iarB, // [0, 1]
  }) {
    final crossLoop = math.max(anxietyA * avoidanceB, anxietyB * avoidanceA);
    final vulnerabilityFactor = (2.0 - (iarA.clamp(0.0, 1.0) + iarB.clamp(0.0, 1.0))).clamp(0.1, 2.0);
    return double.parse((crossLoop * vulnerabilityFactor).clamp(0.0, 1.0).toStringAsFixed(2));
  }

  /// Ecuación de Disonancia Ego-Eros (Culpa Postcoital en [0.0, 1.0]):
  /// Culpa = Intensidad_Kinky * (1 - Erotofilia_Norm) * Rigidez_Ego1
  static double computePostCoitalGuiltRisk({
    required double kinkyPct, // [0, 100]
    required double sosIndex, // [-10, 10]
    required double ego1DivoPct, // [0, 100]
  }) {
    final kNorm = (kinkyPct / 100.0).clamp(0.0, 1.0);
    final erotophiliaNorm = ((sosIndex + 10.0) / 20.0).clamp(0.0, 1.0);
    final rigidityNorm = (ego1DivoPct / 100.0).clamp(0.0, 1.0);
    final guilt = kNorm * (1.0 - erotophiliaNorm) * rigidityNorm;
    return double.parse(guilt.clamp(0.0, 1.0).toStringAsFixed(2));
  }
}
