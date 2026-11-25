import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AnalogClockDecoy extends StatefulWidget {
  final Function(String digit) onDigitDialed;
  final VoidCallback onClear;
  final int dialedCount;

  const AnalogClockDecoy({
    Key? key,
    required this.onDigitDialed,
    required this.onClear,
    this.dialedCount = 0,
  }) : super(key: key);

  @override
  State<AnalogClockDecoy> createState() => _AnalogClockDecoyState();
}

class _AnalogClockDecoyState extends State<AnalogClockDecoy> {
  late Timer _ticker;
  DateTime _now = DateTime.now();
  int? _highlightedNumber;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  void _handleNumberTap(int number) {
    HapticFeedback.mediumImpact();
    setState(() => _highlightedNumber = number);

    // En el reloj analógico: la posición 12 representa el dígito '0'
    final digit = (number == 12) ? "0" : number.toString();
    widget.onDigitDialed(digit);

    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _highlightedNumber = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior de simulación de app de reloj
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        "CLOCK // STANDBY",
                        style: GoogleFonts.jetBrainsMono(
                          color: Colors.white24,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Indicadores sutiles de dígitos marcados (máximo 4 puntos discretos)
                      Row(
                        children: List.generate(4, (i) {
                          final isFilled = i < (widget.dialedCount % 5);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isFilled ? Colors.white54 : Colors.white10,
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  Text(
                    "${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}",
                    style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            ),
            // Esfera interactiva del reloj
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Stack(
                      children: [
                        // Fondo con marcas y manecillas activas
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ClockPainter(now: _now),
                          ),
                        ),
                        // Botones de las 12 horas alineados en el perímetro exacto
                        ...List.generate(12, (index) {
                          final number = index + 1;
                          // Cálculo angular en radianes (0 rad en la derecha / 3 en punto)
                          final angleRad = (number * 30 - 90) * (pi / 180);
                          // Alineación relativa de -1.0 a 1.0 (0.76 ubica el número dentro del aro)
                          final alignX = cos(angleRad) * 0.76;
                          final alignY = sin(angleRad) * 0.76;
                          final isHighlighted = _highlightedNumber == number;

                          return Align(
                            alignment: Alignment(alignX, alignY),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (_) => _handleNumberTap(number),
                              child: Container(
                                width: 52,
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isHighlighted
                                      ? Colors.white.withOpacity(0.25)
                                      : Colors.transparent,
                                  border: isHighlighted
                                      ? Border.all(color: Colors.white60, width: 1.5)
                                      : null,
                                ),
                                child: Text(
                                  "$number",
                                  style: GoogleFonts.outfit(
                                    color: isHighlighted ? Colors.white : Colors.white70,
                                    fontSize: 18,
                                    fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w300,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        // Pivote central interactivo (Tocar limpia el buffer)
                        Align(
                          alignment: Alignment.center,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onClear();
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                              ),
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black,
                                  border: Border.all(color: Colors.white54, width: 2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  final DateTime now;
  _ClockPainter({required this.now});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Aro exterior de la esfera
    final dialPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 0.94, dialPaint);

    // Ticks perimetrales de minutos
    final tickPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1.0;
    for (int i = 0; i < 60; i++) {
      if (i % 5 != 0) {
        final tickAngle = (i * 6 - 90) * (pi / 180);
        final start = center + Offset(cos(tickAngle) * (radius * 0.90), sin(tickAngle) * (radius * 0.90));
        final end = center + Offset(cos(tickAngle) * (radius * 0.93), sin(tickAngle) * (radius * 0.93));
        canvas.drawLine(start, end, tickPaint);
      }
    }

    // Manecilla Horaria
    final hourAngle = ((now.hour % 12) + now.minute / 60) * 30 * (pi / 180) - (pi / 2);
    final hourHandPaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      center + Offset(cos(hourAngle) * (radius * 0.44), sin(hourAngle) * (radius * 0.44)),
      hourHandPaint,
    );

    // Manecilla Minutero
    final minuteAngle = (now.minute + now.second / 60) * 6 * (pi / 180) - (pi / 2);
    final minHandPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      center + Offset(cos(minuteAngle) * (radius * 0.66), sin(minuteAngle) * (radius * 0.66)),
      minHandPaint,
    );

    // Segundero
    final secAngle = now.second * 6 * (pi / 180) - (pi / 2);
    final secPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1.2;
    canvas.drawLine(
      center,
      center + Offset(cos(secAngle) * (radius * 0.74), sin(secAngle) * (radius * 0.74)),
      secPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ClockPainter oldDelegate) => true;
}