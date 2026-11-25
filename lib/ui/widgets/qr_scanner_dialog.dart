import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class QRScannerDialog extends StatefulWidget {
  final Function(String) onCodeScanned;

  const QRScannerDialog({
    Key? key,
    required this.onCodeScanned,
  }) : super(key: key);

  @override
  State<QRScannerDialog> createState() => _QRScannerDialogState();
}

class _QRScannerDialogState extends State<QRScannerDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanlineController;
  final TextEditingController _manualInputController =
      TextEditingController(text: "VINKIAR_SANCTUARY_B2B_01");
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _scanlineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanlineController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  void _submitCode(String code) {
    if (code.trim().isEmpty) return;
    widget.onCodeScanned(code.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: VinkiarColors.abyssBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VinkiarColors.aegisCyan, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: VinkiarColors.aegisCyan.withOpacity(0.25),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabecera Cyberpunk del Escáner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: VinkiarColors.panelDark,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
                border: Border(
                  bottom: BorderSide(
                    color: VinkiarColors.aegisCyan.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_scanner,
                          color: VinkiarColors.aegisCyan, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "VISOR DE GLIFOS CRIPTOGRÁFICOS",
                        style: GoogleFonts.jetBrainsMono(
                          color: VinkiarColors.aegisCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Visor de Cámara con Retícula y Scanlines animadas
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 240,
                    decoration: BoxDecoration(
                      color: const Color(0xFF030712),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: VinkiarColors.aegisCyan.withOpacity(0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Fondo con matriz de rejilla Cyberpunk
                        CustomPaint(
                          size: const Size(double.infinity, 240),
                          painter: ViewfinderGridPainter(),
                        ),

                        // Marco de enfoque central (Retícula)
                        Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: VinkiarColors.aegisCyan.withOpacity(0.4),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              // Esquinas reforzadas estilo HUD
                              _buildCorner(Alignment.topLeft, true, true),
                              _buildCorner(Alignment.topRight, true, false),
                              _buildCorner(Alignment.bottomLeft, false, true),
                              _buildCorner(Alignment.bottomRight, false, false),

                              Center(
                                child: Text(
                                  "ENFOQUE ÓPTICO ZKA",
                                  style: GoogleFonts.jetBrainsMono(
                                    color: VinkiarColors.aegisCyan
                                        .withOpacity(0.7),
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Scanline Láser Animada
                        AnimatedBuilder(
                          animation: _scanlineController,
                          builder: (context, child) {
                            return Positioned(
                              top: 50 + (140 * _scanlineController.value),
                              left: 30,
                              right: 30,
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  color: VinkiarColors.aegisCyan,
                                  boxShadow: [
                                    BoxShadow(
                                      color: VinkiarColors.aegisCyan
                                          .withOpacity(0.9),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                    BoxShadow(
                                      color: const Color(0xFF39FF14)
                                          .withOpacity(0.6),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Controles HUD de la Cámara (Linterna / Zoom)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IconButton(
                            icon: Icon(
                              _isTorchOn
                                  ? Icons.flash_on
                                  : Icons.flash_off,
                              color: _isTorchOn
                                  ? VinkiarColors.vertigoGold
                                  : Colors.white54,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _isTorchOn = !_isTorchOn;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Presets rápidos para pruebas de Glifos
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip("Santuario Loto", "VINKIAR_SANCTUARY_B2B_01"),
                        const SizedBox(width: 8),
                        _buildPresetChip("Café Búnker", "VINKIAR_SANCTUARY_B2B_02"),
                        const SizedBox(width: 8),
                        _buildPresetChip("Avatar Centinela", "VINKIAR_AVATAR_USER_94A"),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Input manual o fallback de simulación
                  TextField(
                    controller: _manualInputController,
                    style: GoogleFonts.jetBrainsMono(
                        color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Ingresar payload criptográfico...',
                      hintStyle: GoogleFonts.jetBrainsMono(
                          color: Colors.grey, fontSize: 11),
                      filled: true,
                      fillColor: VinkiarColors.panelDark,
                      isDense: true,
                      prefixIcon: const Icon(Icons.key,
                          color: VinkiarColors.aegisCyan, size: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: VinkiarColors.aegisCyan.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: VinkiarColors.aegisCyan),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Botón de Decodificación
                  ElevatedButton(
                    onPressed: () =>
                        _submitCode(_manualInputController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VinkiarColors.aegisCyan,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      "DECODIFICAR Y ABSORBER GLIFO",
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String code) {
    return InkWell(
      onTap: () {
        _manualInputController.text = code;
        setState(() {});
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: VinkiarColors.panelDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: VinkiarColors.aegisCyan,
            fontSize: 9,
          ),
        ),
      ),
    );
  }

  Widget _buildCorner(Alignment alignment, bool top, bool left) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: VinkiarColors.aegisCyan, width: 2.5)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: VinkiarColors.aegisCyan, width: 2.5)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: VinkiarColors.aegisCyan, width: 2.5)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: VinkiarColors.aegisCyan, width: 2.5)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class ViewfinderGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = VinkiarColors.aegisCyan.withOpacity(0.06)
      ..strokeWidth = 1.0;

    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
