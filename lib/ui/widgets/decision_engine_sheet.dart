import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../theme.dart';
import 'decision_poll_card.dart';

// =========================================================================
// SECCIÓN 1: MESA UNIVERSAL DE DECISIONES COLECTIVAS (CHAT Y TRIBU)
// =========================================================================

class DecisionEngineSheet extends StatefulWidget {
  final String guildId;
  final String channelName;
  final String myHandle;
  final void Function(String chatPacket)? onPublishToChat;

  const DecisionEngineSheet({
    super.key,
    required this.guildId,
    required this.channelName,
    required this.myHandle,
    this.onPublishToChat,
  });

  @override
  State<DecisionEngineSheet> createState() => _DecisionEngineSheetState();
}

// =========================================================================
// SECCIÓN 2: ESTADO, PLANTILLAS RÁPIDAS Y CREACIÓN EN POSTGRESQL
// =========================================================================

class _DecisionEngineSheetState extends State<DecisionEngineSheet> {
  final TextEditingController _tituloCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [
    TextEditingController(),
    TextEditingController(),
  ];

  String _selectedMode = 'LEAST_MISERY'; // LEAST_MISERY | QUORUM | ZIPPER | BLIND_AUCTION
  int _quorumPct = 51;
  bool _isCreating = false;
  bool _isLoadingHistory = true;
  List<Map<String, dynamic>> _existingDecisions = [];

  String get _cleanBaseUrl => ApiConfig.baseUrl.endsWith('/')
      ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
      : ApiConfig.baseUrl;

  String get _normalizedMyHandle {
    final raw = widget.myHandle.trim();
    if (raw.isEmpty) return '#Pionero';
    return raw.startsWith('#') ? raw : '#$raw';
  }

  @override
  void initState() {
    super.initState();
    _loadChannelDecisions();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadChannelDecisions() async {
    try {
      final res = await http.get(
        Uri.parse('$_cleanBaseUrl/api/v1/decisiones/${Uri.encodeComponent(widget.guildId)}'),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (body['decisiones'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        setState(() {
          _existingDecisions = list;
          _isLoadingHistory = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoadingHistory = false);
  }

  void _applyPreset({
    required String title,
    required String mode,
    required List<String> options,
  }) {
    HapticFeedback.selectionClick();
    setState(() {
      _tituloCtrl.text = title;
      _selectedMode = mode;
      for (final c in _optionCtrls) {
        c.dispose();
      }
      _optionCtrls.clear();
      for (final opt in options) {
        _optionCtrls.add(TextEditingController(text: opt));
      }
    });
  }

  void _addOptionField() {
    if (_optionCtrls.length >= 6) return;
    setState(() => _optionCtrls.add(TextEditingController()));
  }

  void _removeOptionField(int idx) {
    if (_optionCtrls.length <= 2) return;
    setState(() {
      final ctrl = _optionCtrls.removeAt(idx);
      ctrl.dispose();
    });
  }

  Future<void> _launchDecision() async {
    final title = _tituloCtrl.text.trim();
    if (title.isEmpty || _isCreating) return;

    final validOptions = <Map<String, String>>[];
    for (int i = 0; i < _optionCtrls.length; i++) {
      final lbl = _optionCtrls[i].text.trim();
      if (lbl.isNotEmpty) {
        validOptions.add({'id': 'OPT_${i + 1}', 'label': lbl});
      }
    }

    if (_selectedMode != 'ZIPPER' && validOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Añade al menos 2 opciones para someter a decisión."),
          backgroundColor: VinkiarColors.panicRed,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);
    HapticFeedback.mediumImpact();

    try {
      final res = await http.post(
        Uri.parse('$_cleanBaseUrl/api/v1/decisiones/crear'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'guild_id': widget.guildId,
          'titulo': title,
          'descripcion': _descCtrl.text.trim(),
          'modo': _selectedMode,
          'creator_handle': _normalizedMyHandle,
          'quorum_pct': _quorumPct,
          'opciones': validOptions,
          'participantes': [_normalizedMyHandle],
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 201 || res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final dec = body['decision'] as Map<String, dynamic>? ?? {};
        final decId = dec['id']?.toString() ?? '';

        if (decId.isNotEmpty) {
          widget.onPublishToChat?.call("[DECISION_ZKA|$decId|$title|$_selectedMode]");
        }

        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al abrir mesa de decisión: $e"), backgroundColor: VinkiarColors.panicRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // =========================================================================
  // SECCIÓN 3: INTERFAZ PRINCIPAL (BUILD)
  // =========================================================================

  String _modeExplanation() {
    switch (_selectedMode) {
      case 'LEAST_MISERY':
        return "🛡️ Mínima Miseria (AVM): Purga cualquier opción que cruce un Límite Rojo (veto con 0 penalización) y elige la alternativa con mayor confort mínimo garantizado para todos.";
      case 'QUORUM':
        return "🗳️ Consenso por Quórum: Gana la opción que alcance el $_quorumPct% de los votos del grupo.";
      case 'ZIPPER':
        return "🤐 Principio de la Cremallera: Rota automáticamente la prioridad de elección entre los participantes para dar voz equitativa a los perfiles más reservados.";
      case 'BLIND_AUCTION':
        return "💎 Subasta Ciega de Voluntad: Para preferencias encontradas sin riesgo SSC. Cada participante puja Vinks en secreto; quien gana aporta sus Vinks al bote común.";
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: VinkiarColors.abyssBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: VinkiarColors.hackingGreen, width: 2)),
      ),
      child: Column(
        children: [
          // Cabecera
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            color: VinkiarColors.panelDark,
            child: Row(
              children: [
                const Icon(Icons.balance, color: VinkiarColors.hackingGreen, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "MESA DE DECISIONES // ${widget.channelName}".toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          color: VinkiarColors.hackingGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "Resolución de conflictos, juegos y acuerdos sin tiranía de mayoría",
                        style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plantillas rápidas
                  Text(
                    "PLANTILLAS RÁPIDAS:",
                    style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPresetChip(
                          "🎲 Elegir Juego / Dinámica",
                          () => _applyPreset(
                            title: "¿Qué juego o dinámica hacemos ahora?",
                            mode: "LEAST_MISERY",
                            options: ["Juego de rol narrativo", "Reto somático suave", "Charla libre sin pantallas"],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildPresetChip(
                          "🏛️ Elegir Plan / Santuario",
                          () => _applyPreset(
                            title: "¿Qué plan elegimos para quedar?",
                            mode: "LEAST_MISERY",
                            options: ["Café tranquilo en Santuario", "Paseo al aire libre", "Evento en La Taberna"],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildPresetChip(
                          "🤐 Turno Cremallera",
                          () => _applyPreset(
                            title: "¿Quién elige la actividad de esta ronda?",
                            mode: "ZIPPER",
                            options: ["Elegir actividad", "Pasar turno"],
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildPresetChip(
                          "💎 Desempate Subasta",
                          () => _applyPreset(
                            title: "Desempate de preferencia (Playa vs Montaña)",
                            mode: "BLIND_AUCTION",
                            options: ["Opción A (Playa)", "Opción B (Montaña)"],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Selector de 4 modos algorítmicos
                  Text(
                    "1. ALGORITMO DE RESOLUCIÓN:",
                    style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildModeButton("🛡️ MÍNIMA MISERIA", "LEAST_MISERY", VinkiarColors.hackingGreen),
                      const SizedBox(width: 6),
                      _buildModeButton("🗳️ QUÓRUM", "QUORUM", VinkiarColors.vertigoGold),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildModeButton("🤐 CREMALLERA", "ZIPPER", VinkiarColors.aegisCyan),
                      const SizedBox(width: 6),
                      _buildModeButton("💎 SUBASTA CIEGA", "BLIND_AUCTION", VinkiarColors.lotusPink),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: VinkiarColors.panelDark,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      _modeExplanation(),
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, height: 1.35),
                    ),
                  ),

                  if (_selectedMode == 'QUORUM') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildQuorumOption(51, "51%"),
                        const SizedBox(width: 6),
                        _buildQuorumOption(67, "67%"),
                        const SizedBox(width: 6),
                        _buildQuorumOption(100, "100%"),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),
                  Text(
                    "2. CUESTIÓN O CONFLICTO A RESOLVER:",
                    style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _tituloCtrl,
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "Ej. ¿Qué hacemos tras la partida? o Desempate de reglas",
                      hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 11.5),
                      filled: true,
                      fillColor: VinkiarColors.panelDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "3. ALTERNATIVAS (${_optionCtrls.length}):",
                        style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                      if (_optionCtrls.length < 6)
                        TextButton.icon(
                          icon: const Icon(Icons.add_circle_outline, size: 14, color: VinkiarColors.hackingGreen),
                          label: Text(
                            "AÑADIR OPCIÓN",
                            style: GoogleFonts.jetBrainsMono(color: VinkiarColors.hackingGreen, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _addOptionField,
                        ),
                    ],
                  ),
                  ...List.generate(_optionCtrls.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _optionCtrls[i],
                              style: GoogleFonts.outfit(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                hintText: "Opción ${i + 1}",
                                hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                                isDense: true,
                                filled: true,
                                fillColor: VinkiarColors.panelDark,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          if (_optionCtrls.length > 2)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.white38, size: 18),
                              onPressed: () => _removeOptionField(i),
                            ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VinkiarColors.hackingGreen,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 17),
                      label: Text(
                        _isCreating ? "LANZANDO VOTACIÓN..." : "LANZAR DECISIÓN AL CANAL",
                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10.5),
                      ),
                      onPressed: _isCreating ? null : _launchDecision,
                    ),
                  ),

                  // Historial de decisiones del canal
                  if (!_isLoadingHistory && _existingDecisions.isNotEmpty) ...[
                    const Divider(color: Colors.white12, height: 28),
                    Text(
                      "DECISIONES RECIENTES EN ESTE CANAL (${_existingDecisions.length})",
                      style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._existingDecisions.map((d) => DecisionPollCard(
                          decisionId: d['id'].toString(),
                          fallbackTitle: d['titulo']?.toString() ?? 'Decisión ZKA',
                          fallbackMode: d['modo']?.toString() ?? 'LEAST_MISERY',
                          myHandle: _normalizedMyHandle,
                          onResolvedBroadcast: widget.onPublishToChat,
                        )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: VinkiarColors.panelDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 9, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, String mode, Color color) {
    final bool selected = _selectedMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMode = mode),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.2) : VinkiarColors.panelDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? color : Colors.white12, width: selected ? 1.5 : 1.0),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: selected ? color : Colors.white54,
              fontSize: 9.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuorumOption(int pct, String label) {
    final bool selected = _quorumPct == pct;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _quorumPct = pct),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: selected ? VinkiarColors.vertigoGold.withOpacity(0.2) : VinkiarColors.panelDark,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? VinkiarColors.vertigoGold : Colors.white12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: selected ? VinkiarColors.vertigoGold : Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
