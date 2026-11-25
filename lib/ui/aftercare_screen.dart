import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/acoustic_sentinel_service.dart';
import '../services/vinkiar_secure_database.dart';
import 'theme.dart';

class AftercareScreen extends StatefulWidget {
  final SentinelTriggerReason? triggerReason;

  const AftercareScreen({
    Key? key,
    this.triggerReason,
  }) : super(key: key);

  @override
  State<AftercareScreen> createState() => _AftercareScreenState();
}

class _AftercareScreenState extends State<AftercareScreen> {
  double _wellbeingScore = 7.0; // Escala 1 a 10

  // Checklist fisiológico
  bool _drankWater = false;
  bool _thermalRegulation = false;
  bool _breathingPause = false;
  bool _physicalSpaceSafe = true;

  // Recalibración de límites
  final TextEditingController _newRedLimitController = TextEditingController();
  final TextEditingController _diaryNoteController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _newRedLimitController.dispose();
    _diaryNoteController.dispose();
    super.dispose();
  }

  Color _getScoreColor() {
    if (_wellbeingScore >= 8.0) return VinkiarColors.hackingGreen;
    if (_wellbeingScore >= 5.0) return VinkiarColors.vertigoGold;
    return VinkiarColors.panicRed;
  }

  String _getScoreLabel() {
    if (_wellbeingScore >= 8.0) return "SISTEMA REGULADO // CALMA";
    if (_wellbeingScore >= 5.0) return "ACTIVACIÓN RESIDUAL // EN OBSERVACIÓN";
    return "DISONANCIA SEVERA // REPOSO OBLIGATORIO";
  }

  Future<void> _consolidateAftercare() async {
    setState(() => _isSaving = true);
    final db = VinkiarSecureDatabase();

    try {
      // 1. Guardar nuevo límite rojo si se ha especificado uno tras la disonancia
      final newRedLimit = _newRedLimitController.text.trim();
      if (newRedLimit.isNotEmpty) {
        final avatar = await db.getAvatarSheet("LOCAL_USER");
        final stats = avatar?['stats'] as Map<String, dynamic>? ?? {};
        final currentReds = stats['limites_rojos']?.toString() ?? "";
        final updatedReds = currentReds.isEmpty
            ? newRedLimit
            : "$currentReds, $newRedLimit";

        await db.updateAvatarData({"limites_rojos": updatedReds});
      }

      // 2. Registrar reflexión privada en la Bitácora Clandestina usando los parámetros con nombre
      final diarySnippet = _diaryNoteController.text.trim();
      if (diarySnippet.isNotEmpty) {
        await db.saveDiaryEntry(
          title: "Registro Aftercare - Pausa SSC",
          content: diarySnippet,
        );
      }

      // 3. Reactivar la vigilancia pasiva del Centinela Acústico
      AcousticSentinelService().startVigilance();
    } catch (_) {}

    if (mounted) {
      setState(() => _isSaving = false);
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
    }
  }

  Widget _buildCheckItem({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: VinkiarColors.abyssBlack,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: value ? VinkiarColors.hackingGreen.withOpacity(0.4) : Colors.white12,
        ),
      ),
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        activeColor: VinkiarColors.hackingGreen,
        checkColor: Colors.black,
        title: Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = _getScoreColor();

    return Scaffold(
      backgroundColor: VinkiarColors.abyssBlack,
      appBar: AppBar(
        backgroundColor: VinkiarColors.panelDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.favorite_outline, color: VinkiarColors.lotusPink, size: 20),
            const SizedBox(width: 8),
            Text(
              "PROTOCOLO DE AFTERCARE // DESCOMPRESIÓN",
              style: GoogleFonts.jetBrainsMono(
                color: VinkiarColors.lotusPink,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // INTRODUCCIÓN Y REGLA DE CERO PENALIZACIONES
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VinkiarColors.panelDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield, color: VinkiarColors.aegisCyan, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "CERO PENALIZACIONES: Preservar la integridad es la máxima victoria. Tu experiencia y tus Vinks permanecen intactos.",
                        style: GoogleFonts.jetBrainsMono(
                          color: VinkiarColors.aegisCyan,
                          fontSize: 9.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 1. EVALUACIÓN SOMÁTICA (1 AL 10)
              Text("1. ESTADO DEL SISTEMA NERVIOSO (1 - 10)", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 10.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VinkiarColors.panelDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scoreColor.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _getScoreLabel(),
                          style: GoogleFonts.jetBrainsMono(
                            color: scoreColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${_wellbeingScore.toInt()}/10",
                          style: GoogleFonts.jetBrainsMono(
                            color: scoreColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _wellbeingScore,
                      min: 1.0,
                      max: 10.0,
                      divisions: 9,
                      activeColor: scoreColor,
                      inactiveColor: Colors.white12,
                      onChanged: (val) => setState(() => _wellbeingScore = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 2. CHECKLIST FISIOLÓGICO Y ANCLAJES
              Text("2. ANCLAJES FISIOLÓGICOS RECOMENDADOS", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 10.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildCheckItem(
                title: "HIDRATACIÓN & GLUCOSA",
                subtitle: "Bebe un vaso de agua o infusión tibia. Si hay temblor, consume algo dulce.",
                value: _drankWater,
                onChanged: (val) => setState(() => _drankWater = val ?? false),
              ),
              _buildCheckItem(
                title: "REGULACIÓN TÉRMICA",
                subtitle: "El bajón de adrenalina enfría el cuerpo. Usa una manta o ropa cómoda.",
                value: _thermalRegulation,
                onChanged: (val) => setState(() => _thermalRegulation = val ?? false),
              ),
              _buildCheckItem(
                title: "RESPIRACIÓN DIAFRAGMÁTICA (4-7-8)",
                subtitle: "Inhala en 4s, sostén en 7s y exhala despacio en 8s para regular el nervio vago.",
                value: _breathingPause,
                onChanged: (val) => setState(() => _breathingPause = val ?? false),
              ),
              _buildCheckItem(
                title: "ESPACIO SEGURO Y DISTANCIA",
                subtitle: "Verifica que el entorno físico esté despejado y consensuado.",
                value: _physicalSpaceSafe,
                onChanged: (val) => setState(() => _physicalSpaceSafe = val ?? false),
              ),
              const SizedBox(height: 18),

              // 3. RECALIBRACIÓN DE LÍMITES ROJOS (OPCIONAL)
              Text("3. BLINDAR NUEVO LÍMITE ROJO (OPCIONAL)", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.panicRed, fontSize: 10.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                "Si la disonancia se debió a un detonante no pactado, inclúyelo para sellarlo en tu Bóveda:",
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newRedLimitController,
                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11),
                decoration: InputDecoration(
                  hintText: "Ej. Privación visual no anunciada, ritmo acelerado...",
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 10.5),
                  filled: true,
                  fillColor: VinkiarColors.panelDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: VinkiarColors.panicRed.withOpacity(0.4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: VinkiarColors.panicRed.withOpacity(0.4)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: VinkiarColors.panicRed, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 4. REFLEXIÓN PARA LA BITÁCORA CLANDESTINA (OPCIONAL)
              Text("4. REFLEXIÓN EN BITÁCORA PRIVADA (OPCIONAL)", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 10.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                "Vinki utilizará esta nota cifrada para no sugerir misiones de fricción similar:",
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _diaryNoteController,
                maxLines: 3,
                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11),
                decoration: InputDecoration(
                  hintText: "¿Qué necesitó tu cuerpo en ese momento? ¿Qué aprendizaje queda?",
                  hintStyle: const TextStyle(color: Colors.white30, fontSize: 10.5),
                  filled: true,
                  fillColor: VinkiarColors.panelDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: VinkiarColors.vertigoGold.withOpacity(0.4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: VinkiarColors.vertigoGold.withOpacity(0.4)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: VinkiarColors.vertigoGold, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // BOTÓN FINAL DE CONSOLIDACIÓN
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VinkiarColors.lotusPink,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    _isSaving ? "SELLANDO APRENDIZAJES..." : "CONSOLIDAR BIENESTAR Y CONTINUAR",
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  onPressed: _isSaving ? null : _consolidateAftercare,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}