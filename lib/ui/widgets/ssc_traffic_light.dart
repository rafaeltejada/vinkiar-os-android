import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class SSCTrafficLight extends StatelessWidget {
  final String currentStatus; // 'GREEN', 'YELLOW', 'RED', 'REVOKED'
  final Function(String newColor) onStatusChanged;
  final bool isCompact;

  const SSCTrafficLight({
    Key? key,
    required this.currentStatus,
    required this.onStatusChanged,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 16,
        vertical: isCompact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: VinkiarColors.panelDark,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: statusColor.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Luz Verde (Flujo Libre)
          _buildLightDot('GREEN', Colors.greenAccent, "Verde - Flujo Libre"),
          SizedBox(width: isCompact ? 6 : 10),
          // Luz Amarilla (Precaución)
          _buildLightDot('YELLOW', VinkiarColors.vertigoGold, "Amarillo - Precaución"),
          SizedBox(width: isCompact ? 6 : 10),
          // Luz Roja (Pausa Absoluta)
          _buildLightDot('RED', VinkiarColors.panicRed, "Rojo - Pausa Absoluta"),
          
          if (!isCompact) ...[
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.5)),
              ),
              child: Text(
                _getStatusLabel(),
                style: GoogleFonts.jetBrainsMono(
                  color: statusColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLightDot(String level, Color color, String tooltip) {
    final bool isActive = currentStatus.toUpperCase() == level;
    // Diámetro ampliado: 28px si está activo, 22px inactivo para máxima ergonomía
    final double dotSize = isCompact 
        ? (isActive ? 18.0 : 13.0)
        : (isActive ? 28.0 : 22.0);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onStatusChanged(level);
        },
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          // Área táctil de 44x44px mínima para interacción con dedos
          padding: EdgeInsets.all(isCompact ? 4.0 : 8.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? color : color.withOpacity(0.25),
              boxShadow: [
                if (isActive)
                  BoxShadow(
                    color: color.withOpacity(0.9),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
              ],
              border: Border.all(
                color: isActive ? Colors.white : color.withOpacity(0.4),
                width: isActive ? 2.0 : 1.0,
              ),
            ),
            child: isActive && !isCompact
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (currentStatus.toUpperCase()) {
      case 'YELLOW':
        return VinkiarColors.vertigoGold;
      case 'RED':
      case 'REVOKED':
        return VinkiarColors.panicRed;
      case 'GREEN':
      default:
        return Colors.greenAccent;
    }
  }

  String _getStatusLabel() {
    switch (currentStatus.toUpperCase()) {
      case 'YELLOW':
        return "PRECAUCIÓN (🟡)";
      case 'RED':
      case 'REVOKED':
        return "PAUSA ABSOLUTA (🔴)";
      case 'GREEN':
      default:
        return "FLUJO LIBRE (🟢)";
    }
  }
}