import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/onboarding_guide_service.dart';
import '../theme.dart';

class ContextualOnboardingModal extends StatefulWidget {
  final OnboardingGuideSpec spec;
  final ValueChanged<bool>? onMuteAllChanged;

  const ContextualOnboardingModal({
    Key? key,
    required this.spec,
    this.onMuteAllChanged,
  }) : super(key: key);

  @override
  State<ContextualOnboardingModal> createState() => _ContextualOnboardingModalState();
}

class _ContextualOnboardingModalState extends State<ContextualOnboardingModal> {
  bool _muteFutureGuides = false;

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final accent = spec.accentColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: VinkiarColors.abyssBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.75), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.18),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera técnica
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withOpacity(0.5)),
                    ),
                    child: Icon(spec.icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spec.codeTag,
                          style: GoogleFonts.jetBrainsMono(
                            color: accent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          spec.title,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                spec.subtitle,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),

              // Claves operativas
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VinkiarColors.panelDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: spec.bullets.map((item) {
                    final colonIdx = item.indexOf(':');
                    final lead = colonIdx > 0 ? item.substring(0, colonIdx + 1) : '';
                    final body = colonIdx > 0 ? item.substring(colonIdx + 1).trim() : item;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Icon(Icons.bolt, color: accent, size: 14),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withOpacity(0.88),
                                  fontSize: 12,
                                  height: 1.38,
                                ),
                                children: [
                                  if (lead.isNotEmpty)
                                    TextSpan(
                                      text: '$lead ',
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  TextSpan(text: body),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // Nota de privacidad ZKA
              Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: accent.withOpacity(0.85), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      spec.footerNote,
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white60,
                        fontSize: 9.5,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Opción para silenciar guías restantes
              InkWell(
                onTap: () {
                  setState(() => _muteFutureGuides = !_muteFutureGuides);
                  widget.onMuteAllChanged?.call(_muteFutureGuides);
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _muteFutureGuides,
                          activeColor: accent,
                          checkColor: Colors.black,
                          side: const BorderSide(color: Colors.white38),
                          onChanged: (val) {
                            final next = val ?? false;
                            setState(() => _muteFutureGuides = next);
                            widget.onMuteAllChanged?.call(next);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "No mostrar más guías automáticas (puedes reactivarlas en La Bóveda)",
                          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Botón de confirmación
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    "ENTENDIDO // CONTINUAR",
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
