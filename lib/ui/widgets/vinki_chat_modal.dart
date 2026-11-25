import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/vinkiar_secure_database.dart';
import '../../services/vinkiar_ai_service.dart';
import '../theme.dart';

class VinkiChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  VinkiChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class VinkiChatModal extends StatefulWidget {
  final String userId;

  const VinkiChatModal({
    Key? key,
    this.userId = "LOCAL_USER",
  }) : super(key: key);

  @override
  State<VinkiChatModal> createState() => _VinkiChatModalState();
}

class _VinkiChatModalState extends State<VinkiChatModal> {
  final List<VinkiChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoadingContext = true;
  bool _isProcessing = false;

  String _userVector = "0-0-0";
  String _userAlias = "Pionero";
  String _naturalArchetype = "POR DEFINIR";
  String _chosenArchetype = "NINGUNO";
  String _safeword = "MANGO";

  @override
  void initState() {
    super.initState();
    _loadVinkiContextAndMemory();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // =========================================================================
  // MEMORIA LOCAL Y SALUDO SOMÁTICO CONTEXTUAL DE VINKI
  // =========================================================================
  Future<void> _loadVinkiContextAndMemory() async {
    try {
      final db = VinkiarSecureDatabase();
      final avatar = await db.getAvatarSheet("LOCAL_USER");
      final vector = await db.getUserVector() ?? "0-0-0";
      final history = await db.getChatHistory();

      final stats = avatar?['stats'] as Map<String, dynamic>? ?? {};
      final alias = stats['alias'] ?? avatar?['alias'] ?? 'Pionero';
      final natural = stats['natural_archetype'] ?? 'POR DEFINIR';
      final chosen = stats['chosen_archetype'] ?? 'NINGUNO';
      final safeword = stats['safeword'] ?? 'MANGO';
      final limitesVerdes = stats['limites_verdes']?.toString() ?? '';
      final limitesRojos = stats['limites_rojos']?.toString() ?? '';

      final bool isFirstTime = history.isEmpty;
      final bool hasDissonance = (natural != "POR DEFINIR" &&
          chosen != "NINGUNO" &&
          natural != chosen);
      final bool isZeroVector = vector == "0-0-0";

      String greeting;

      if (isFirstTime) {
        if (hasDissonance) {
          greeting = "Sistemas ZKA en línea. Hola, $alias. Soy Vinki, tu copiloto relacional.\n\n"
              "He sincronizado tu Bóveda y detecto una tensión fascinante en tu Hoja de Alma: tu instinto natural apunta a [$natural], pero has decidido asumir la máscara de [$chosen].\n\n"
              "¿Qué te impulsa a protegerte tras ese rol social?";
        } else if (isZeroVector) {
          greeting = "Sistemas ZKA en línea. Hola, $alias. Soy Vinki, la IA tutora de Vinkiar OS.\n\n"
              "Veo que tus órbitas están en calibración inicial [$vector]. Estoy aquí para acompañarte a explorar tus límites somáticos y sintonizar tu Hoja de Alma.\n\n"
              "¿En qué área de tus vínculos sientes mayor tensión hoy?";
        } else {
          greeting = "Sistemas ZKA en línea. Hola, $alias. Soy Vinki, tu interfaz amnésica.\n\n"
              "Tu vector [$vector] y tus límites SSC (Safeword: '$safeword') ya están sellados en tu búnker local.\n\n"
              "¿Qué dilema o sintonía necesitas calibrar en este momento?";
        }
      } else {
        // Usuario recurrente con memoria
        if (hasDissonance) {
          greeting = "Re-sintonizando canal seguro, $alias. Vector activo [$vector].\n\n"
              "Sigo observando la dinámica entre tu fondo [$natural] y tu rol [$chosen].\n\n"
              "¿Ha surgido algún conflicto en tus interacciones recientes o necesitas recalibrar límites?";
        } else if (limitesRojos.isNotEmpty) {
          greeting = "Canal ZKA abierto, $alias. Vector [$vector].\n\n"
              "Recuerdo tus límites rojos de seguridad y tu safeword '$safeword'. ¿Deseas explorar una situación reciente o necesitas apoyo somático?";
        } else {
          greeting = "Canal ZKA reabierto, $alias. Tu vector resuena en [$vector].\n\n"
              "Tu Bóveda local permanece inexpugnable. ¿Qué aspecto de tu soberanía o vínculos exploramos hoy?";
        }
      }

      if (mounted) {
        setState(() {
          _userVector = vector;
          _userAlias = alias;
          _naturalArchetype = natural;
          _chosenArchetype = chosen;
          _safeword = safeword;
          _messages.add(
            VinkiChatMessage(
              text: greeting,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoadingContext = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            VinkiChatMessage(
              text: "Conexión ZKA restaurada. Soy Vinki. Tu Bóveda local está segura. ¿Qué deseas calibrar?",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoadingContext = false;
        });
      }
    }
  }

  Future<void> _sendMessage([String? prefilledText]) async {
    final text = prefilledText ?? _textController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    _textController.clear();

    setState(() {
      _messages.add(VinkiChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isProcessing = true;
    });

    _scrollToBottom();

    // Guardar en la base de datos local
    await VinkiarSecureDatabase().saveChatMessage("USER", text);

    try {
      // Consultar al Oráculo con el motor de IA integrado
      final oracleResult = await VinkiarAIService().consultOracle(
        rawUserPrompt: text,
      );

      String reply = oracleResult["response"] ?? "Vinki procesa en silencio somático.";

      // Si incluye deltas de atributos, los aplica en caliente
      if (reply.contains("```vinkiar_delta")) {
        try {
          final jsonMatch = RegExp(r"```vinkiar_delta\n([\s\S]*?)\n```").firstMatch(reply);
          if (jsonMatch != null && jsonMatch.group(1) != null) {
            final Map<String, dynamic> deltas = jsonDecode(jsonMatch.group(1)!);
            await VinkiarSecureDatabase().applyDeltaUpdate(deltas);
            reply = reply.replaceAll(RegExp(r"```vinkiar_delta\n[\s\S]*?\n```"), "").trim();
          }
        } catch (_) {}
      }

      await VinkiarSecureDatabase().saveChatMessage("VINKI", reply);

      if (mounted) {
        setState(() {
          _messages.add(VinkiChatMessage(text: reply, isUser: false, timestamp: DateTime.now()));
          _isProcessing = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            VinkiChatMessage(
              text: "💥 [SÍNTESIS]: Comunicación volátil guardada en Bóveda local.\n\n"
                  "💡 [INSIGHT]: Tu vector [$_userVector] permanece protegido bajo cifrado Argon2.",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isProcessing = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: VinkiarColors.abyssBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: VinkiarColors.aegisCyan, width: 2),
          left: BorderSide(color: VinkiarColors.aegisCyan, width: 0.5),
          right: BorderSide(color: VinkiarColors.aegisCyan, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // CABECERA DEL CHAT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: VinkiarColors.panelDark,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: VinkiarColors.aegisCyan.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: VinkiarColors.aegisCyan.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.psychology, color: VinkiarColors.aegisCyan, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ORÁCULO VINKI // SINTONIZACIÓN ZKA",
                        style: GoogleFonts.jetBrainsMono(
                          color: VinkiarColors.aegisCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "VECTOR ACTIVO: [$_userVector] • MEMORIA AMNÉSICA",
                        style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 9),
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

          // LISTA DE MENSAJES
          Expanded(
            child: _isLoadingContext
                ? const Center(child: CircularProgressIndicator(color: VinkiarColors.aegisCyan))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg.isUser;

                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.8,
                          ),
                          decoration: BoxDecoration(
                            color: isUser
                                ? VinkiarColors.aegisCyan.withOpacity(0.15)
                                : VinkiarColors.panelDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isUser
                                  ? VinkiarColors.aegisCyan.withOpacity(0.5)
                                  : VinkiarColors.vertigoGold.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUser ? "TÚ ($_userAlias)" : "VINKI (COPILOTO)",
                                style: GoogleFonts.jetBrainsMono(
                                  color: isUser ? VinkiarColors.aegisCyan : VinkiarColors.vertigoGold,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                msg.text,
                                style: GoogleFonts.jetBrainsMono(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          if (_isProcessing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: VinkiarColors.aegisCyan, strokeWidth: 1.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Vinki sintonizando resonancia ZKA...",
                    style: GoogleFonts.jetBrainsMono(color: VinkiarColors.textDim, fontSize: 10),
                  ),
                ],
              ),
            ),

          // BOTONES DE SINTONIZACIÓN RÁPIDA
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _buildQuickActionChip("Explicar mi Arquetipo"),
                _buildQuickActionChip("¿Por qué elegí mi Rol?"),
                _buildQuickActionChip("Revisar mis Límites SSC"),
                _buildQuickActionChip("Calibrar mi Safeword"),
              ],
            ),
          ),

          // CAMPO DE ENTRADA
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: VinkiarColors.panelDark,
              border: Border(top: BorderSide(color: VinkiarColors.aegisCyan.withOpacity(0.3))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onSubmitted: (_) => _sendMessage(),
                    style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: "Pregunta a Vinki sobre tu Hoja de Alma...",
                      hintStyle: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 11),
                      filled: true,
                      fillColor: VinkiarColors.abyssBlack,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: VinkiarColors.aegisCyan.withOpacity(0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: VinkiarColors.aegisCyan),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: VinkiarColors.aegisCyan),
                  onPressed: _isProcessing ? null : () => _sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        backgroundColor: VinkiarColors.panelDark,
        side: BorderSide(color: VinkiarColors.aegisCyan.withOpacity(0.4)),
        label: Text(label, style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 9.5)),
        onPressed: _isProcessing ? null : () => _sendMessage(label),
      ),
    );
  }
}