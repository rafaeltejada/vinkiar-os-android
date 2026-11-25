import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme.dart';

// =========================================================================
// MODELOS DE DATOS DE LAS 3 RUEDAS (ORIGEN 0 REAL Y LERP PARA ANIMACIÓN)
// =========================================================================

class EgoVector {
  final double divo;
  final double rescatador;
  final double vividor;
  final double artista;
  final double intelectual;
  final double cautivador;
  final double entusiasta;
  final double lider;
  final double encantador;

  const EgoVector({
    this.divo = 0.0,
    this.rescatador = 0.0,
    this.vividor = 0.0,
    this.artista = 0.0,
    this.intelectual = 0.0,
    this.cautivador = 0.0,
    this.entusiasta = 0.0,
    this.lider = 0.0,
    this.encantador = 0.0,
  });

  factory EgoVector.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const EgoVector();
    return EgoVector(
      divo: (map['divo'] ?? 0.0).toDouble(),
      rescatador: (map['rescatador'] ?? 0.0).toDouble(),
      vividor: (map['vividor'] ?? 0.0).toDouble(),
      artista: (map['artista'] ?? 0.0).toDouble(),
      intelectual: (map['intelectual'] ?? 0.0).toDouble(),
      cautivador: (map['afrodita'] ?? (map['cautivador'] ?? 0.0)).toDouble(),
      entusiasta: (map['cautivador'] ?? (map['entusiasta'] ?? 0.0)).toDouble(),
      lider: (map['lider'] ?? 0.0).toDouble(),
      encantador: (map['encantador'] ?? 0.0).toDouble(),
    );
  }

  bool get isZero =>
      divo == 0.0 &&
      rescatador == 0.0 &&
      vividor == 0.0 &&
      artista == 0.0 &&
      intelectual == 0.0 &&
      cautivador == 0.0 &&
      entusiasta == 0.0 &&
      lider == 0.0 &&
      encantador == 0.0;

  String get dominantArchetype {
    if (isZero) return "En reposo (0%)";
    final map = {
      'E1 Divo': divo,
      'E2 Rescatador': rescatador,
      'E3 Vividor': vividor,
      'E4 Artista': artista,
      'E5 Intelectual': intelectual,
      'E6 Afrodita': cautivador,
      'E7 Cautivador': entusiasta,
      'E8 Líder': lider,
      'E9 Encantador': encantador,
    };
    var highest = map.entries.first;
    for (var entry in map.entries) {
      if (entry.value > highest.value) highest = entry;
    }
    return "${highest.key} (${highest.value.toInt()}%)";
  }

  static EgoVector lerp(EgoVector a, EgoVector b, double t) {
    return EgoVector(
      divo: lerpDouble(a.divo, b.divo, t) ?? 0.0,
      rescatador: lerpDouble(a.rescatador, b.rescatador, t) ?? 0.0,
      vividor: lerpDouble(a.vividor, b.vividor, t) ?? 0.0,
      artista: lerpDouble(a.artista, b.artista, t) ?? 0.0,
      intelectual: lerpDouble(a.intelectual, b.intelectual, t) ?? 0.0,
      cautivador: lerpDouble(a.cautivador, b.cautivador, t) ?? 0.0,
      entusiasta: lerpDouble(a.entusiasta, b.entusiasta, t) ?? 0.0,
      lider: lerpDouble(a.lider, b.lider, t) ?? 0.0,
      encantador: lerpDouble(a.encantador, b.encantador, t) ?? 0.0,
    );
  }
}

class ErosVector {
  final double energetico;
  final double sensual;
  final double sexual;
  final double kinky;
  final double cambiaformas;
  final double sosIndex;

  const ErosVector({
    this.energetico = 0.0,
    this.sensual = 0.0,
    this.sexual = 0.0,
    this.kinky = 0.0,
    this.cambiaformas = 0.0,
    this.sosIndex = 0.0,
  });

  factory ErosVector.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ErosVector();
    return ErosVector(
      energetico: (map['energetico'] ?? 0.0).toDouble(),
      sensual: (map['sensual'] ?? 0.0).toDouble(),
      sexual: (map['sexual'] ?? 0.0).toDouble(),
      kinky: (map['kinky'] ?? 0.0).toDouble(),
      cambiaformas: (map['cambiaformas'] ?? 0.0).toDouble(),
      sosIndex: (map['sosIndex'] ?? (map['erotofiliaIndex'] ?? 0.0)).toDouble(),
    );
  }

  bool get isZero =>
      energetico == 0.0 &&
      sensual == 0.0 &&
      sexual == 0.0 &&
      kinky == 0.0 &&
      cambiaformas == 0.0;

  String get dominantBlueprint {
    if (isZero) return "En reposo (0%)";
    final map = {
      'Energético': energetico,
      'Sensual': sensual,
      'Sexual': sexual,
      'Kinky': kinky,
      'Cambiaformas': cambiaformas,
    };
    var highest = map.entries.first;
    for (var entry in map.entries) {
      if (entry.value > highest.value) highest = entry;
    }
    return "${highest.key} (${highest.value.toInt()}%)";
  }

  static ErosVector lerp(ErosVector a, ErosVector b, double t) {
    return ErosVector(
      energetico: lerpDouble(a.energetico, b.energetico, t) ?? 0.0,
      sensual: lerpDouble(a.sensual, b.sensual, t) ?? 0.0,
      sexual: lerpDouble(a.sexual, b.sexual, t) ?? 0.0,
      kinky: lerpDouble(a.kinky, b.kinky, t) ?? 0.0,
      cambiaformas: lerpDouble(a.cambiaformas, b.cambiaformas, t) ?? 0.0,
      sosIndex: lerpDouble(a.sosIndex, b.sosIndex, t) ?? 0.0,
    );
  }
}

class PhiliaVector {
  final double seguro;
  final double ocnofilo;
  final double filobata;
  final double desorganizado;
  final double iAR;

  const PhiliaVector({
    this.seguro = 0.0,
    this.ocnofilo = 0.0,
    this.filobata = 0.0,
    this.desorganizado = 0.0,
    this.iAR = 0.0,
  });

  factory PhiliaVector.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PhiliaVector();
    return PhiliaVector(
      seguro: (map['seguro'] ?? 0.0).toDouble(),
      ocnofilo: (map['ocnofilo'] ?? (map['ansioso'] ?? 0.0)).toDouble(),
      filobata: (map['filobata'] ?? (map['evitativo'] ?? 0.0)).toDouble(),
      desorganizado: (map['desorganizado'] ?? 0.0).toDouble(),
      iAR: (map['iAR'] ?? (map['diferenciacionSelf'] ?? 0.0)).toDouble(),
    );
  }

  bool get isZero =>
      seguro == 0.0 &&
      ocnofilo == 0.0 &&
      filobata == 0.0 &&
      desorganizado == 0.0;

  String get levelLabel {
    if (isZero && iAR == 0.0) return "0.00 (En reposo)";
    final str = iAR.toStringAsFixed(2);
    if (iAR >= 0.7) return "$str (Alta)";
    if (iAR >= 0.4) return "$str (Media)";
    return "$str (Baja)";
  }

  static PhiliaVector lerp(PhiliaVector a, PhiliaVector b, double t) {
    return PhiliaVector(
      seguro: lerpDouble(a.seguro, b.seguro, t) ?? 0.0,
      ocnofilo: lerpDouble(a.ocnofilo, b.ocnofilo, t) ?? 0.0,
      filobata: lerpDouble(a.filobata, b.filobata, t) ?? 0.0,
      desorganizado: lerpDouble(a.desorganizado, b.desorganizado, t) ?? 0.0,
      iAR: lerpDouble(a.iAR, b.iAR, t) ?? 0.0,
    );
  }
}

// =========================================================================
// WIDGET PRINCIPAL: EneagramChart
// =========================================================================

class EneagramChart extends StatefulWidget {
  final String? vector;
  final EgoVector? egoVector;
  final ErosVector? erosVector;
  final PhiliaVector? philiaVector;
  final double size;
  final Duration animationDuration;

  const EneagramChart({
    super.key,
    this.vector,
    this.egoVector,
    this.erosVector,
    this.philiaVector,
    this.size = 280,
    this.animationDuration = const Duration(milliseconds: 1400),
  });

  @override
  State<EneagramChart> createState() => _EneagramChartState();
}

class _EneagramChartState extends State<EneagramChart> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _curveAnimation;

  EgoVector _oldEgo = const EgoVector();
  EgoVector _targetEgo = const EgoVector();

  ErosVector _oldEros = const ErosVector();
  ErosVector _targetEros = const ErosVector();

  PhiliaVector _oldPhilia = const PhiliaVector();
  PhiliaVector _targetPhilia = const PhiliaVector();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _curveAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _targetEgo = widget.egoVector ?? const EgoVector();
    _targetEros = widget.erosVector ?? const ErosVector();
    _targetPhilia = widget.philiaVector ?? const PhiliaVector();

    _animController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant EneagramChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newEgo = widget.egoVector ?? const EgoVector();
    final newEros = widget.erosVector ?? const ErosVector();
    final newPhilia = widget.philiaVector ?? const PhiliaVector();

    if (newEgo != _targetEgo || newEros != _targetEros || newPhilia != _targetPhilia) {
      _oldEgo = EgoVector.lerp(_oldEgo, _targetEgo, _curveAnimation.value);
      _oldEros = ErosVector.lerp(_oldEros, _targetEros, _curveAnimation.value);
      _oldPhilia = PhiliaVector.lerp(_oldPhilia, _targetPhilia, _curveAnimation.value);

      _targetEgo = newEgo;
      _targetEros = newEros;
      _targetPhilia = newPhilia;

      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curveAnimation,
      builder: (context, _) {
        final currentEgo = EgoVector.lerp(_oldEgo, _targetEgo, _curveAnimation.value);
        final currentEros = ErosVector.lerp(_oldEros, _targetEros, _curveAnimation.value);
        final currentPhilia = PhiliaVector.lerp(_oldPhilia, _targetPhilia, _curveAnimation.value);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _TripleEneagramaVivoV2Painter(
                  ego: currentEgo,
                  eros: currentEros,
                  philia: currentPhilia,
                  amberGold: const Color(0xFFFFB800),
                  magentaNeon: const Color(0xFFFF007A),
                  electricCyan: const Color(0xFF00F0FF),
                  darkSlate: const Color(0xFF1E293B),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: VinkiarColors.panelDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  _buildLegendItem("Ego", currentEgo.dominantArchetype, const Color(0xFFFFB800)),
                  _buildLegendItem("Eros", currentEros.dominantBlueprint, const Color(0xFFFF007A)),
                  _buildLegendItem("Philia I_AR", currentPhilia.levelLabel, const Color(0xFF00F0FF)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.8), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 5),
        Text("$label: ", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.textDim, fontSize: 9.5)),
        Text(value, style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// =========================================================================
// CUSTOM PAINTER: DIBUJO CON TEXTOS COMPLETOS Y EXPANSIÓN VISIBLE
// =========================================================================

class _TripleEneagramaVivoV2Painter extends CustomPainter {
  final EgoVector ego;
  final ErosVector eros;
  final PhiliaVector philia;
  final Color amberGold;
  final Color magentaNeon;
  final Color electricCyan;
  final Color darkSlate;

  _TripleEneagramaVivoV2Painter({
    required this.ego,
    required this.eros,
    required this.philia,
    required this.amberGold,
    required this.magentaNeon,
    required this.electricCyan,
    required this.darkSlate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 38;

    // 1. Radar polar de fondo (5 niveles de 20% a 100%)
    for (int i = 1; i <= 5; i++) {
      final r = maxRadius * (i / 5.0);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = darkSlate.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // Ejes radiales
    for (int i = 0; i < 9; i++) {
      final angle = (i * 2 * math.pi) / 9 - math.pi / 2;
      canvas.drawLine(
        center,
        Offset(center.dx + maxRadius * math.cos(angle), center.dy + maxRadius * math.sin(angle)),
        Paint()..color = darkSlate.withOpacity(0.4)..strokeWidth = 0.6,
      );
    }

    // Núcleo en reposo (cuando todo es 0)
    final bool allZero = ego.isZero && eros.isZero && philia.isZero;
    if (allZero) {
      canvas.drawCircle(
        center,
        6.0,
        Paint()
          ..color = electricCyan.withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0),
      );
      canvas.drawCircle(center, 2.5, Paint()..color = Colors.white.withOpacity(0.8));
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // =======================================================================
    // 2. RUEDA I: EGO (9 Ejes - Anillo Exterior - Oro Ámbar)
    // =======================================================================
    final egoList = [
      {'name': 'E1: Divo', 'val': ego.divo},
      {'name': 'E2: Rescatador', 'val': ego.rescatador},
      {'name': 'E3: Vividor', 'val': ego.vividor},
      {'name': 'E4: Artista', 'val': ego.artista},
      {'name': 'E5: Intelectual', 'val': ego.intelectual},
      {'name': 'E6: Afrodita', 'val': ego.cautivador},
      {'name': 'E7: Cautivador', 'val': ego.entusiasta},
      {'name': 'E8: Líder', 'val': ego.lider},
      {'name': 'E9: Encantador', 'val': ego.encantador},
    ];

    final egoPoints = <Offset>[];
    for (int i = 0; i < 9; i++) {
      final angle = (i * 2 * math.pi) / 9 - math.pi / 2;
      final val = (egoList[i]['val'] as double).clamp(0.0, 100.0);
      final r = ego.isZero ? 0.0 : maxRadius * (0.20 + (val / 100.0) * 0.80);
      egoPoints.add(Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle)));

      final isLoaded = val > 0.0;
      final lx = center.dx + (maxRadius + 20) * math.cos(angle);
      final ly = center.dy + (maxRadius + 20) * math.sin(angle);
      textPainter.text = TextSpan(
        text: "${egoList[i]['name']}\n(${val.toInt()}%)",
        style: GoogleFonts.jetBrainsMono(
          color: isLoaded ? amberGold : VinkiarColors.textDim.withOpacity(0.35),
          fontSize: 7.0,
          fontWeight: isLoaded ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(lx - textPainter.width / 2, ly - textPainter.height / 2));
    }
    if (!ego.isZero) {
      _drawPolygon(canvas, egoPoints, amberGold, 0.16, 2.2, null);
    }

    // =======================================================================
    // 3. RUEDA II: EROS (5 Ejes - Anillo Intermedio - Magenta Neón)
    // =======================================================================
    final erosList = [
      {'name': 'Energético', 'val': eros.energetico},
      {'name': 'Sensual', 'val': eros.sensual},
      {'name': 'Sexual', 'val': eros.sexual},
      {'name': 'Kinky', 'val': eros.kinky},
      {'name': 'Cambiaformas', 'val': eros.cambiaformas},
    ];

    final erosPoints = <Offset>[];
    final erosMaxRadius = maxRadius * 0.72;

    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi) / 5 - math.pi / 2;
      final val = (erosList[i]['val'] as double).clamp(0.0, 100.0);
      final r = eros.isZero ? 0.0 : erosMaxRadius * (0.22 + (val / 100.0) * 0.78);
      erosPoints.add(Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle)));

      // ETIQUETAS Y PORCENTAJES DE EROS
      final isLoaded = val > 0.0;
      final lx = center.dx + (erosMaxRadius * 0.65) * math.cos(angle);
      final ly = center.dy + (erosMaxRadius * 0.65) * math.sin(angle);
      textPainter.text = TextSpan(
        text: "${erosList[i]['name']}\n[${val.toInt()}%]",
        style: GoogleFonts.jetBrainsMono(
          color: isLoaded ? magentaNeon : magentaNeon.withOpacity(0.35),
          fontSize: 6.5,
          fontWeight: isLoaded ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(lx - textPainter.width / 2, ly - textPainter.height / 2));
    }
    if (!eros.isZero) {
      _drawPolygon(canvas, erosPoints, magentaNeon, 0.18, 1.8, [6, 3]);
    }

    // =======================================================================
    // 4. RUEDA III: PHILIA (4 Ejes - Anillo Interior - Cian Eléctrico)
    // =======================================================================
    final philiaList = [
      {'name': 'Seguro', 'val': philia.seguro},
      {'name': 'Ocnófilo', 'val': philia.ocnofilo},
      {'name': 'Filóbata', 'val': philia.filobata},
      {'name': 'Desorganizado', 'val': philia.desorganizado},
    ];

    final philiaPoints = <Offset>[];
    final philiaMaxRadius = maxRadius * 0.48;

    for (int i = 0; i < 4; i++) {
      final angle = (i * 2 * math.pi) / 4 - math.pi / 4;
      final val = (philiaList[i]['val'] as double).clamp(0.0, 100.0);
      final r = philia.isZero ? 0.0 : philiaMaxRadius * (0.25 + (val / 100.0) * 0.75);
      philiaPoints.add(Offset(center.dx + r * math.cos(angle), center.dy + r * math.sin(angle)));

      // ETIQUETAS Y PORCENTAJES DE PHILIA
      final isLoaded = val > 0.0;
      final lx = center.dx + (philiaMaxRadius * 0.50) * math.cos(angle);
      final ly = center.dy + (philiaMaxRadius * 0.50) * math.sin(angle);
      textPainter.text = TextSpan(
        text: "${philiaList[i]['name']}\n{${val.toInt()}%}",
        style: GoogleFonts.jetBrainsMono(
          color: isLoaded ? electricCyan : electricCyan.withOpacity(0.35),
          fontSize: 6.0,
          fontWeight: isLoaded ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(lx - textPainter.width / 2, ly - textPainter.height / 2));
    }
    if (!philia.isZero) {
      _drawPolygon(canvas, philiaPoints, electricCyan, 0.22, 1.6, [2, 2]);
    }
  }

  void _drawPolygon(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double fillAlpha,
    double strokeWidth,
    List<double>? dashArray,
  ) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color.withOpacity(fillAlpha)..style = PaintingStyle.fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    );

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (dashArray != null && dashArray.length >= 2) {
      for (final metric in path.computeMetrics()) {
        double distance = 0.0;
        int dashIndex = 0;
        while (distance < metric.length) {
          final len = dashArray[dashIndex % dashArray.length];
          if (dashIndex % 2 == 0) {
            canvas.drawPath(metric.extractPath(distance, (distance + len).clamp(0.0, metric.length)), strokePaint);
          }
          distance += len;
          dashIndex++;
        }
      }
    } else {
      canvas.drawPath(path, strokePaint);
    }

    final dotPaint = Paint()..color = color;
    for (var pt in points) {
      canvas.drawCircle(pt, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TripleEneagramaVivoV2Painter oldDelegate) {
    return oldDelegate.ego != ego || oldDelegate.eros != eros || oldDelegate.philia != philia;
  }
}