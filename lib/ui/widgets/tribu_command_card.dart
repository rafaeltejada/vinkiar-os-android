import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

// =========================================================================
// SECCIÓN 1: MODELO DE RANGO GAMIFICADO DE TRIBU
// =========================================================================

class TribuRankInfo {
  final int level;
  final String rankTitle;
  final double progressToNext;
  final int xpCurrent;
  final int xpNext;
  final Color rankColor;

  const TribuRankInfo({
    required this.level,
    required this.rankTitle,
    required this.progressToNext,
    required this.xpCurrent,
    required this.xpNext,
    required this.rankColor,
  });

  static TribuRankInfo compute({
    required int poolVinks,
    required int memberCount,
    required String sscBaseline,
  }) {
    final int baseXp = (memberCount * 120) + (poolVinks * 4);
    final int level = (baseXp ~/ 250).clamp(1, 20) + 1;
    final int xpFloor = (level - 1) * 250;
    final int xpNext = level * 250;
    final double progress = ((baseXp - xpFloor) / 250.0).clamp(0.08, 1.0);

    String title;
    Color color;
    if (level >= 8) {
      title = "CIUDADELA SOBERANA";
      color = VinkiarColors.vertigoGold;
    } else if (level >= 5) {
      title = "BASTIÓN DE CÉLULA";
      color = VinkiarColors.aegisCyan;
    } else if (level >= 3) {
      title = "CLAN ARTICULADO";
      color = VinkiarColors.hackingGreen;
    } else {
      title = "NÚCLEO EMBRIONARIO";
      color = const Color(0xFF94A3B8);
    }

    if (sscBaseline == 'RED') {
      color = VinkiarColors.panicRed;
    }

    return TribuRankInfo(
      level: level,
      rankTitle: title,
      progressToNext: progress,
      xpCurrent: baseXp,
      xpNext: xpNext,
      rankColor: color,
    );
  }
}

// =========================================================================
// SECCIÓN 2: TARJETA TÁCTICA DE TRIBU (GOBERNANZA + GAMIFICACIÓN VISUAL)
// =========================================================================

class TribuCommandCard extends StatelessWidget {
  final Map<String, dynamic> guild;
  final String myHandle;
  final VoidCallback onOpenBolsa;
  final VoidCallback onOpenDecisions;
  final VoidCallback onOpenGovernance;
  final VoidCallback onOpenChat;
  final VoidCallback onCopyCode;
  final VoidCallback? onEditCode;
  final VoidCallback? onEditTribu;

  const TribuCommandCard({
    super.key,
    required this.guild,
    this.myHandle = '#Pionero',
    required this.onOpenBolsa,
    required this.onOpenDecisions,
    required this.onOpenGovernance,
    required this.onOpenChat,
    required this.onCopyCode,
    this.onEditCode,
    this.onEditTribu,
  });

  Color _sscColor(String ssc) {
    switch (ssc.toUpperCase()) {
      case 'GREEN':
        return VinkiarColors.hackingGreen;
      case 'YELLOW':
        return VinkiarColors.vertigoGold;
      case 'RED':
        return VinkiarColors.panicRed;
      default:
        return VinkiarColors.aegisCyan;
    }
  }

  String _sscLabel(String ssc) {
    switch (ssc.toUpperCase()) {
      case 'GREEN':
        return "VERDE · ABIERTO";
      case 'YELLOW':
        return "ÁMBAR · FILTRO";
      case 'RED':
        return "ROJO · PRIVADO";
      default:
        return ssc.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String guildId = guild['guild_id']?.toString() ?? 'ZK-TRIBU';
    final String name = guild['name']?.toString() ?? 'Tribu ZKA';
    final String description = (guild['description']?.toString().trim().isNotEmpty == true)
        ? guild['description'].toString().trim()
        : 'Pacto comunitario cifrado bajo protocolo Zero-Knowledge.';
    final String ssc = (guild['ssc_baseline'] ?? 'GREEN').toString().toUpperCase();
    final int poolVinks = (guild['common_pool_vinks'] as num?)?.toInt() ?? 0;
    final int memberCount = (guild['member_count'] as num?)?.toInt() ?? 1;
    final bool isCreator = guild['is_creator'] == true;
    final List<String> admins = (guild['admins'] as List? ?? []).map((e) => e.toString().toLowerCase()).toList();
    final String normMe = myHandle.trim().startsWith('#') ? myHandle.trim().toLowerCase() : '#${myHandle.trim().toLowerCase()}';
    final bool isCoAdmin = !isCreator && admins.contains(normMe);

    final Color sscColor = _sscColor(ssc);
    final TribuRankInfo rank = TribuRankInfo.compute(
      poolVinks: poolVinks,
      memberCount: memberCount,
      sscBaseline: ssc,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF141824),
            Color(0xFF0B0D13),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: rank.rankColor.withOpacity(0.55),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: rank.rankColor.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------------------------------------------------------
          // CABECERA HERÁLDICA: ESCUDO PROCEDIMENTAL + RANGO + ESTADO SSC
          // ---------------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.28),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.07)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Escudo Geométrico Único
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CustomPaint(
                    painter: TribuCrestPainter(
                      seed: guildId,
                      primaryColor: rank.rankColor,
                      accentColor: sscColor,
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "T",
                        style: GoogleFonts.jetBrainsMono(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Nombre, Rango y Rol
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: rank.rankColor.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: rank.rankColor.withOpacity(0.6), width: 0.8),
                            ),
                            child: Text(
                              "NV.${rank.level} · ${rank.rankTitle}",
                              style: GoogleFonts.jetBrainsMono(
                                color: rank.rankColor,
                                fontSize: 8.0,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          if (isCreator || isCoAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: VinkiarColors.vertigoGold.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isCreator ? "★ FUNDADOR" : "⚡ ADMIN",
                                style: GoogleFonts.jetBrainsMono(
                                  color: VinkiarColors.vertigoGold,
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (onEditTribu != null) ...[
                  IconButton(
                    tooltip: "Editar nombre, manifiesto y reglas de la Tribu",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    icon: const Icon(Icons.edit_note, color: VinkiarColors.aegisCyan, size: 20),
                    onPressed: onEditTribu,
                  ),
                  const SizedBox(width: 4),
                ],
                // Insignia SSC
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: sscColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: sscColor.withOpacity(0.75)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: sscColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _sscLabel(ssc),
                        style: GoogleFonts.jetBrainsMono(
                          color: sscColor,
                          fontSize: 8.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---------------------------------------------------------------
          // CUERPO: PACTO DE TRIBU + TELEMETRÍA GAMIFICADA
          // ---------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),

                // Barra de Progreso de Cohesión / XP de Tribu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "COHESIÓN DE CÉLULA",
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white54,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${rank.xpCurrent} / ${rank.xpNext} XP",
                      style: GoogleFonts.jetBrainsMono(
                        color: rank.rankColor,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rank.progressToNext,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(rank.rankColor),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 12),

                // HUD de 3 Indicadores Tácticos (Bolsa Común, Miembros y Llave ZK)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onOpenBolsa,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: VinkiarColors.abyssBlack,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.45)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet_outlined,
                                      color: VinkiarColors.vertigoGold, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    "BOLSA COMÚN",
                                    style: GoogleFonts.jetBrainsMono(
                                      color: Colors.white54,
                                      fontSize: 8.0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "$poolVinks Ѵ",
                                style: GoogleFonts.jetBrainsMono(
                                  color: VinkiarColors.vertigoGold,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: onOpenGovernance,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: VinkiarColors.abyssBlack,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.groups_outlined,
                                      color: VinkiarColors.aegisCyan, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    "AVATARES",
                                    style: GoogleFonts.jetBrainsMono(
                                      color: Colors.white54,
                                      fontSize: 8.0,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    "$memberCount activos",
                                    style: GoogleFonts.jetBrainsMono(
                                      color: VinkiarColors.aegisCyan,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Consola de Llave ZK de Invitación
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: VinkiarColors.abyssBlack,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.vpn_key_outlined, color: VinkiarColors.vertigoGold, size: 13),
                      const SizedBox(width: 6),
                      Text(
                        "LLAVE ZK: ",
                        style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 8.5),
                      ),
                      Expanded(
                        child: Text(
                          guildId,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            color: VinkiarColors.vertigoGold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: onCopyCode,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.copy, size: 13, color: VinkiarColors.aegisCyan),
                              const SizedBox(width: 3),
                              Text(
                                "COPIAR",
                                style: GoogleFonts.jetBrainsMono(
                                  color: VinkiarColors.aegisCyan,
                                  fontSize: 8.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (onEditCode != null) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: onEditCode,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(Icons.edit, size: 13, color: VinkiarColors.vertigoGold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Botonera Táctica de Operaciones (2x2 equilibrada)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: VinkiarColors.vertigoGold),
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                        ),
                        icon: const Icon(Icons.account_balance_wallet,
                            size: 14, color: VinkiarColors.vertigoGold),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "BOLSA COMÚN",
                            style: GoogleFonts.jetBrainsMono(
                              color: VinkiarColors.vertigoGold,
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onPressed: onOpenBolsa,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: VinkiarColors.hackingGreen),
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                        ),
                        icon: const Icon(Icons.balance, size: 14, color: VinkiarColors.hackingGreen),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "DECIDIR (AVM)",
                            style: GoogleFonts.jetBrainsMono(
                              color: VinkiarColors.hackingGreen,
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onPressed: onOpenDecisions,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: rank.rankColor.withOpacity(0.8)),
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                        ),
                        icon: Icon(Icons.groups_outlined, size: 14, color: rank.rankColor),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "MIEMBROS",
                            style: GoogleFonts.jetBrainsMono(
                              color: rank.rankColor,
                              fontSize: 9.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onPressed: onOpenGovernance,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VinkiarColors.aegisCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        ),
                        icon: const Icon(Icons.forum_outlined, size: 14),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "CANAL ZKA",
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                        onPressed: onOpenChat,
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

// =========================================================================
// SECCIÓN 3: PINTOR HERÁLDICO PROCEDIMENTAL PARA EL ESCUDO DE TRIBU
// =========================================================================

class TribuCrestPainter extends CustomPainter {
  final String seed;
  final Color primaryColor;
  final Color accentColor;

  TribuCrestPainter({
    required this.seed,
    required this.primaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Hexágono exterior
    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - (math.pi / 2);
      final pt = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        hexPath.moveTo(pt.dx, pt.dy);
      } else {
        hexPath.lineTo(pt.dx, pt.dy);
      }
    }
    hexPath.close();

    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withOpacity(0.28),
          const Color(0xFF08090C),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final borderPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawPath(hexPath, fillPaint);
    canvas.drawPath(hexPath, borderPaint);

    // Anillo interior rotado según el hash del guildId
    final int hashVal = seed.codeUnits.fold(0, (prev, elem) => prev + elem);
    final double rotOffset = (hashVal % 60) * (math.pi / 180.0);
    final innerRadius = radius * 0.72;
    final innerPaint = Paint()
      ..color = accentColor.withOpacity(0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final innerPath = Path();
    for (int i = 0; i < 3; i++) {
      final angle = ((2 * math.pi / 3) * i) + rotOffset;
      final pt = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );
      if (i == 0) {
        innerPath.moveTo(pt.dx, pt.dy);
      } else {
        innerPath.lineTo(pt.dx, pt.dy);
      }
    }
    innerPath.close();
    canvas.drawPath(innerPath, innerPaint);
  }

  @override
  bool shouldRepaint(covariant TribuCrestPainter oldDelegate) {
    return oldDelegate.seed != seed ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}
