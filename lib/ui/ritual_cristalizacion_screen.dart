import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../services/vinkiar_psychometrics_engine.dart';
import '../services/vinkiar_secure_database.dart';
import '../services/vinkiar_sync_service.dart';
import '../models/relational_tag.dart';
import 'theme.dart';

enum QuestRitualState { selecting, committed, completedReadyToSeal, crystallized }

class RitualCristalizacionScreen extends StatefulWidget {
  final String targetHandle;
  final String targetAlias;
  final String provisionalGuildId;

  const RitualCristalizacionScreen({
    Key? key,
    required this.targetHandle,
    required this.targetAlias,
    required this.provisionalGuildId,
  }) : super(key: key);

  @override
  State<RitualCristalizacionScreen> createState() => _RitualCristalizacionScreenState();
}

class _RitualCristalizacionScreenState extends State<RitualCristalizacionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _sealController;
  Timer? _holdTimer;
  double _holdProgress = 0.0;
  bool _isSealing = false;

  QuestRitualState _ritualState = QuestRitualState.selecting;

  List<Map<String, dynamic>> _availableQuests = [];
  Map<String, dynamic>? _selectedQuest;

  String _selectedRelationalKey = "EXPLORATION";

  List<String> _greenLimits = [];
  List<String> _yellowLimits = [];
  List<String> _redLimits = [];

  @override
  void initState() {
    super.initState();
    _sealController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _initDefaultLimitsForFirstEncounter();
    _loadQuests();
  }

  @override
  void dispose() {
    _sealController.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  void _initDefaultLimitsForFirstEncounter() {
    _greenLimits = [
      "Espacio público y neutral (Santuario o Café)",
      "Diálogo reflexivo y escucha atenta",
      "Café / Infusión analógica sin prisa",
      "Libertad de retirarse en cualquier momento",
    ];
    _yellowLimits = [
      "Contacto físico casual o abrazos",
      "Preguntas sobre intimidad pasada",
      "Prolongar la cita más de 1 hora",
    ];
    _redLimits = [
      "Ir a espacios privados o domicilios",
      "Contacto sexual en primer encuentro",
      "Consumo obligado de alcohol o sustancias",
      "Presión para revelar identidad civil o redes",
    ];
  }

  Future<void> _loadQuests() async {
    final db = VinkiarSecureDatabase();
    final quests = await db.getQuests();

    final List<Map<String, dynamic>> defaultOptions = [
      {
        "id": "QUEST_PHY_CAFE_01",
        "title": "Encuentro en Santuario: Café & Calibración Somática",
        "lore": "El primer enlace analógico requiere un territorio neutral donde la presencia preceda al algoritmo.",
        "instruction": "1. Acudid a un Santuario B2B o Café público neutral.\n2. Silenciad las notificaciones de los dispositivos durante 40 minutos.\n3. Compartid una conversación honesta sobre vuestras expectativas y límites de interacción.",
        "reflection": "¿Cómo influye el espacio físico en la sensación de seguridad compartida?",
        "reward_vinks": 30,
        "xp_reward": 120,
        "source_type": "B2B",
      },
      {
        "id": "QUEST_EROS_03",
        "title": "Protocolo de Negociación RACK & Umbral Somático",
        "lore": "En el universo ZKA, la intensidad y la confianza se construyen definiendo primero los límites y la Safeword.",
        "instruction": "1. Mapead límites SSC antes de cualquier acercamiento.\n2. Estableced una palabra de seguridad (Safeword) y una señal gestual no verbal.\n3. Mantened un ritmo pausado de presencia corporal.",
        "reflection": "¿Cómo cambia el clima de confianza cuando el consentimiento precede al deseo?",
        "reward_vinks": 45,
        "xp_reward": 150,
        "source_type": "VINKI",
      },
      {
        "id": "QUEST_TER_11",
        "title": "El Mapa del Apego y la Comunicación Asertiva",
        "lore": "Las fricciones cotidianas y el miedo al rechazo activan defensas automáticas.",
        "instruction": "1. Expresad una necesidad afectiva o límite sin rodeos ni agresividad.\n2. Escuchad la respuesta del otro sin interrumpir durante 3 minutos.\n3. Co-regulad con una respiración consciente compartida.",
        "reflection": "Observa si la asertividad tranquila desactiva la reactividad del ego.",
        "reward_vinks": 35,
        "xp_reward": 100,
        "source_type": "P2P",
      },
    ];

    final Map<String, Map<String, dynamic>> map = {};
    for (var q in defaultOptions) {
      map[q['id']] = q;
    }
    for (var q in quests) {
      if (!map.containsKey(q['id'])) {
        map[q['id']] = {
          "id": q['id'],
          "title": q['title'] ?? 'Misión Táctica',
          "lore": "Misión operativa disponible en la red ZKA.",
          "instruction": q['description'] ?? 'Realizad la misión según los acuerdos.',
          "reflection": "Validación de confianza mutua.",
          "reward_vinks": q['reward_vinks'] ?? 25,
          "xp_reward": q['xp_reward'] ?? 100,
          "source_type": q['source_type'] ?? 'P2P',
        };
      }
    }

    if (mounted) {
      setState(() {
        _availableQuests = map.values.toList();
        _selectedQuest = _availableQuests.first;
      });
    }
  }

  void _openCreateCustomQuestDialog() {
    final titleCtrl = TextEditingController(text: "Café en Santuario & Diálogo Soberano");
    final locationCtrl = TextEditingController(text: "Café Búnker Central (o cafetería neutral)");
    final instructionCtrl = TextEditingController(
      text: "Quedar en un espacio público neutral para tomar un café, contrastar límites SSC sin móviles y verificar afinidad somática durante 45 minutos.",
    );
    final rewardCtrl = TextEditingController(text: "35");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: VinkiarColors.abyssBlack,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: VinkiarColors.hackingGreen, width: 2)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_location_alt, color: VinkiarColors.hackingGreen, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "PROPONER MISIÓN PHYGITAL A MEDIDA",
                        style: GoogleFonts.jetBrainsMono(
                          color: VinkiarColors.hackingGreen,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  labelText: "Título del Encuentro / Reto",
                  labelStyle: TextStyle(color: Colors.white70, fontSize: 11),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.hackingGreen)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  labelText: "Santuario B2B o Territorio Neutral",
                  labelStyle: TextStyle(color: Colors.white70, fontSize: 11),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.hackingGreen)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instructionCtrl,
                maxLines: 3,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  labelText: "Pautas de la Misión (Qué haréis juntos/as)",
                  labelStyle: TextStyle(color: Colors.white70, fontSize: 11),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.hackingGreen)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rewardCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 12),
                decoration: const InputDecoration(
                  labelText: "Recompensa sugerida (Vinks Ѵ)",
                  labelStyle: TextStyle(color: Colors.white70, fontSize: 11),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.vertigoGold)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VinkiarColors.hackingGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.handshake, size: 18),
                  label: Text(
                    "CONVERTIR EN MISIÓN DEL RITUAL",
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  onPressed: () async {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;

                    final newQuest = {
                      "id": "CUSTOM_PHYGITAL_${DateTime.now().millisecondsSinceEpoch}",
                      "title": title,
                      "lore": "Encuentro phygital pactado libremente entre avatares en ${locationCtrl.text.trim()}.",
                      "instruction": instructionCtrl.text.trim(),
                      "reflection": "Comprobad vuestro bienestar y el cumplimiento de los límites fijados tras la despedida.",
                      "reward_vinks": int.tryParse(rewardCtrl.text.trim()) ?? 35,
                      "xp_reward": 140,
                      "source_type": "COUPLE",
                    };

                    await VinkiarSecureDatabase().saveQuest({
                      "id": newQuest['id'],
                      "title": newQuest['title'],
                      "description": "${newQuest['lore']}\n\n⚔️ INSTRUCCIÓN:\n${newQuest['instruction']}",
                      "source_type": "COUPLE",
                      "reward_vinks": newQuest['reward_vinks'],
                      "xp_reward": newQuest['xp_reward'],
                      "status": "AVAILABLE",
                      "created_at": DateTime.now().toIso8601String(),
                    });

                    Navigator.pop(ctx);
                    setState(() {
                      _availableQuests.insert(0, newQuest);
                      _selectedQuest = newQuest;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddLimitDialog(String colorCategory) {
    final textCtrl = TextEditingController();
    Color themeColor = VinkiarColors.hackingGreen;
    String categoryTitle = "VERDE";
    if (colorCategory == "YELLOW") {
      themeColor = VinkiarColors.vertigoGold;
      categoryTitle = "AMARILLO (CAUTELA)";
    } else if (colorCategory == "RED") {
      themeColor = VinkiarColors.panicRed;
      categoryTitle = "ROJO (INVIOLABLE)";
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VinkiarColors.abyssBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: themeColor, width: 1.5),
        ),
        title: Text(
          "AÑADIR LÍMITE $categoryTitle",
          style: GoogleFonts.jetBrainsMono(color: themeColor, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            hintText: "Ej. Sin temas íntimos, sin besos, despedida en el metro...",
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: themeColor.withOpacity(0.5))),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: themeColor)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCELAR", style: GoogleFonts.jetBrainsMono(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.black),
            onPressed: () {
              final text = textCtrl.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  if (colorCategory == "GREEN") _greenLimits.add(text);
                  if (colorCategory == "YELLOW") _yellowLimits.add(text);
                  if (colorCategory == "RED") _redLimits.add(text);
                });
              }
              Navigator.pop(ctx);
            },
            child: Text("AÑADIR", style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _onHoldStart() {
    if (_isSealing || _ritualState != QuestRitualState.completedReadyToSeal) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _holdProgress = 0.0;
    });

    const stepMs = 30;
    const totalMs = 2500;
    _holdTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
      if (!mounted) return;
      setState(() {
        _holdProgress += stepMs / totalMs;
      });

      if (_holdProgress >= 1.0) {
        timer.cancel();
        _executeCrystallization();
      }
    });
  }

  void _onHoldEnd() {
    if (_isSealing || _ritualState != QuestRitualState.completedReadyToSeal) return;
    _holdTimer?.cancel();
    setState(() {
      _holdProgress = 0.0;
    });
  }

  Future<void> _executeCrystallization() async {
    setState(() {
      _isSealing = true;
      _holdProgress = 1.0;
    });

    HapticFeedback.heavyImpact();
    final db = VinkiarSecureDatabase();
    
    final mySheetPre = await db.getAvatarSheet("LOCAL_USER");
    final myStatsPre = mySheetPre?['stats'] as Map<String, dynamic>? ?? {};
    final myRawAlias = (mySheetPre?['alias']?.toString().isNotEmpty == true)
        ? mySheetPre!['alias'].toString()
        : (myStatsPre['alias']?.toString() ?? 'Pionero');
    final cleanMyHandle = myRawAlias.replaceAll("#", "").trim();

    final cleanTarget = widget.targetHandle
        .replaceAll("TÚNEL //", "")
        .replaceAll("#", "")
        .trim();
    final cleanAlias = widget.targetAlias
        .replaceAll("TÚNEL //", "")
        .replaceAll("#", "")
        .trim();
        
    final questId = _selectedQuest?['id'] ?? "QUEST_PHY_01";
    final questTitle = _selectedQuest?['title'] ?? "Misión Phygital";
    final tagDef = VinkiarRelationalTags.find(_selectedRelationalKey);
    final canonicalCellGuild = VinkiarSyncService.buildCanonicalCellGuildId(cleanMyHandle, cleanTarget);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/bonds/crystallize'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_a_id': cleanMyHandle,
          'user_b_id': cleanTarget,
          'quest_id': questId,
          'signature_a': 'ZK_SIG_${cleanMyHandle}_${DateTime.now().millisecondsSinceEpoch}',
          'signature_b': 'ZK_SIG_TARGET_${cleanTarget}_OK',
        }),
      ).timeout(const Duration(seconds: 8));

      String bondId = "VINCULO_${DateTime.now().millisecondsSinceEpoch}";
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        bondId = data['bond_id'] ?? bondId;
      }

      await db.saveContact({
        "id": "CONTACT_$cleanTarget",
        "alias": "#$cleanAlias",
        "character_class": "COMPAÑERO DE CÉLULA",
        "relationship_type": tagDef.key,
        "ssc_level": "GREEN",
        "is_active": 1,
        "reputation_score": 1.0,
        "last_interaction": DateTime.now().toIso8601String(),
        "created_at": DateTime.now().toIso8601String(),
      });

      await VinkiarSyncService().sendZkaControlPacket(jsonEncode({
        "type": "BOND_CRYSTALLIZED_SYNC",
        "sender_handle": "#$cleanMyHandle",
        "target_handle": "#$cleanTarget",
        "canonical_guild_id": canonicalCellGuild,
        "quest_title": questTitle,
      }));

      final mySheet = await db.getAvatarSheet("LOCAL_USER");
      final myStats = mySheet?['stats'] as Map<String, dynamic>? ?? {};
      final myPhilia = myStats['philia_vector'] as Map<String, dynamic>? ?? {};
      final double myAnxiety = ((myPhilia['ocnofilo'] as num?)?.toDouble() ?? 20.0) / 100.0;
      final double myAvoidance = ((myPhilia['filobata'] as num?)?.toDouble() ?? 20.0) / 100.0;
      final double myIar = (myPhilia['iAR'] as num?)?.toDouble() ?? 0.75;
      final double myIfs = ((myStats['ifs_index'] as num?)?.toDouble() ?? 25.0) / 100.0;

      final double computedDyadicIca = VinkiarPsychometricsEngine.computeDyadicAffectiveCollision(
        anxietyA: myAnxiety,
        avoidanceB: 0.20,
        anxietyB: 0.20,
        avoidanceA: myAvoidance,
        iarA: myIar,
        iarB: 0.75,
      );

      await db.saveContactBondSettings(
        contactId: "CONTACT_$cleanTarget",
        sscGlobalLevel: "GREEN",
        relationalTag: tagDef.fullLabel,
        bioDescription: "Vínculo sellado bajo pacto ${tagDef.shortLabel}. Misión: '$questTitle'.",
        avatarGlifo: "shield",
        myGreenLimits: _greenLimits,
        myYellowLimits: _yellowLimits,
        myRedLimits: _redLimits,
        incomingGreenLimits: _greenLimits,
        incomingYellowLimits: _yellowLimits,
        incomingRedLimits: _redLimits,
        privateNotes: "Cristalizado con la misión $questId bajo el sello $bondId",
        completedQuests: 1,
        failedQuests: 0,
        sharedXP: 300,
        jointVinks: 50,
        ifsScore: double.parse(myIfs.clamp(0.05, 1.0).toStringAsFixed(2)),
        icaScore: computedDyadicIca,
      );

      await db.addAvatarRewards(
        (_selectedQuest?['reward_vinks'] as num?)?.toInt() ?? 50,
        (_selectedQuest?['xp_reward'] as num?)?.toInt() ?? 150,
      );

      await db.logActivityEvent(
        title: "Vínculo Cristalizado con #$cleanAlias",
        description: "Misión '$questTitle' superada. Modelo AR: ${tagDef.shortLabel} sellado en Bóveda.",
        type: "BOND_CRYSTALLIZATION",
      );

      await db.updateQuestStatus(questId, "COMPLETED");

      if (mounted) {
        setState(() {
          _isSealing = false;
          _ritualState = QuestRitualState.crystallized;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSealing = false;
          _ritualState = QuestRitualState.crystallized;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VinkiarColors.abyssBlack,
      appBar: AppBar(
        backgroundColor: VinkiarColors.panelDark,
        title: Text(
          "RITUAL DE CRISTALIZACIÓN PHYGITAL",
          style: GoogleFonts.jetBrainsMono(
            color: VinkiarColors.hackingGreen,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VinkiarColors.panelDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: VinkiarColors.hackingGreen.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAvatarPill("TÚ (LOCAL)", "0-0-0", VinkiarColors.aegisCyan),
                    const Icon(Icons.all_inclusive, color: VinkiarColors.hackingGreen, size: 26),
                    _buildAvatarPill(widget.targetAlias, widget.targetHandle, VinkiarColors.vertigoGold),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_ritualState == QuestRitualState.selecting) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "1. ELIGE O CREA TU MISIÓN PHYGITAL",
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.add_circle_outline, color: VinkiarColors.hackingGreen, size: 14),
                      label: Text(
                        "MISIÓN A MEDIDA",
                        style: GoogleFonts.jetBrainsMono(color: VinkiarColors.hackingGreen, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _openCreateCustomQuestDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: VinkiarColors.panelDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.4)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      dropdownColor: VinkiarColors.abyssBlack,
                      isExpanded: true,
                      value: _selectedQuest?['id'],
                      icon: const Icon(Icons.arrow_drop_down, color: VinkiarColors.aegisCyan),
                      items: _availableQuests.map((q) {
                        return DropdownMenuItem<String>(
                          value: q['id'] as String,
                          child: Text(
                            q['title'] ?? 'Misión',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedQuest = _availableQuests.firstWhere((q) => q['id'] == val);
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                if (_selectedQuest != null) _buildQuestDetailsCard(_selectedQuest!),
                const SizedBox(height: 18),

                _buildEditableLimitsSection(),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VinkiarColors.aegisCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.handshake, size: 18),
                    label: Text(
                      "🤝 CONFIRMAR COMPROMISO: VAMOS A REALIZARLA",
                      style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      setState(() {
                        _ritualState = QuestRitualState.committed;
                      });
                    },
                  ),
                ),
              ],

              if (_ritualState == QuestRitualState.committed) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: VinkiarColors.panelDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: VinkiarColors.vertigoGold, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.access_time_filled, color: VinkiarColors.vertigoGold, size: 36),
                      const SizedBox(height: 10),
                      Text(
                        "MISIÓN PHYGITAL EN CURSO",
                        style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selectedQuest?['title'] ?? 'Encuentro Analógico',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Acudid al lugar acordado y disfrutad del encuentro analógico respetando los límites acordados en el Doble Semáforo.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: VinkiarColors.textDim, fontSize: 11.5, height: 1.35),
                      ),
                      const Divider(color: Colors.white12, height: 24),
                      Text(
                        "Límites Rojos blindados para este primer encuentro: ${_redLimits.length} condiciones.",
                        style: GoogleFonts.jetBrainsMono(color: VinkiarColors.panicRed, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VinkiarColors.hackingGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.task_alt, size: 18),
                    label: Text(
                      "⚔️ HEMOS COMPLETADO LA MISIÓN FÍSICA",
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      setState(() {
                        _ritualState = QuestRitualState.completedReadyToSeal;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _ritualState = QuestRitualState.selecting;
                    });
                  },
                  child: Text("REAJUSTAR MISIÓN O LÍMITES", style: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 10)),
                ),
              ],

              if (_ritualState == QuestRitualState.completedReadyToSeal) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: VinkiarColors.panelDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: VinkiarColors.hackingGreen.withOpacity(0.5)),
                  ),
                  child: Text(
                    "✨ MISIÓN COMPLETADA: ${_selectedQuest?['title']}",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.jetBrainsMono(color: VinkiarColors.hackingGreen, fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),

                GestureDetector(
                  onTapDown: (_) => _onHoldStart(),
                  onTapUp: (_) => _onHoldEnd(),
                  onTapCancel: () => _onHoldEnd(),
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _sealController,
                          builder: (context, _) {
                            return CustomPaint(
                              size: const Size(220, 220),
                              painter: _CrystallizationRunePainter(
                                rotationAngle: _sealController.value * 2 * math.pi,
                                progress: _holdProgress,
                              ),
                            );
                          },
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _holdProgress > 0.0
                                ? VinkiarColors.hackingGreen.withOpacity(0.3)
                                : VinkiarColors.panelDark,
                            border: Border.all(
                              color: _holdProgress > 0.0
                                  ? VinkiarColors.hackingGreen
                                  : VinkiarColors.aegisCyan,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_holdProgress > 0.0
                                        ? VinkiarColors.hackingGreen
                                        : VinkiarColors.aegisCyan)
                                    .withOpacity(0.4),
                                blurRadius: 16,
                                spreadRadius: 4,
                              )
                            ],
                          ),
                          child: Icon(
                            _isSealing ? Icons.sync : Icons.fingerprint,
                            color: _holdProgress > 0.0
                                ? VinkiarColors.hackingGreen
                                : VinkiarColors.aegisCyan,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  _isSealing
                      ? "FORJANDO FIRMAS ZK MUTUAS..."
                      : (_holdProgress > 0.0
                          ? "SELLANDO (${(_holdProgress * 100).toInt()}%)..."
                          : "MANTÉN PULSADO EL GLIFO PARA FIRMAR EL PACTO"),
                  style: GoogleFonts.jetBrainsMono(
                    color: _holdProgress > 0.0
                        ? VinkiarColors.hackingGreen
                        : VinkiarColors.aegisCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Sella el Doble Semáforo y cristaliza a ${widget.targetAlias} en tu Bóveda local.",
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 10),
                ),
              ],

              if (_ritualState == QuestRitualState.crystallized) ...[
                const SizedBox(height: 20),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: VinkiarColors.hackingGreen.withOpacity(0.2),
                    border: Border.all(color: VinkiarColors.hackingGreen, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: VinkiarColors.hackingGreen.withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: 4,
                      )
                    ],
                  ),
                  child: const Icon(Icons.check, color: VinkiarColors.hackingGreen, size: 50),
                ),
                const SizedBox(height: 20),
                Text(
                  "¡VÍNCULO DE CÉLULA CRISTALIZADO!",
                  style: GoogleFonts.jetBrainsMono(
                    color: VinkiarColors.hackingGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "El Túnel Provisional ha sido desmantelado. ${widget.targetAlias} es ahora un Contacto Permanente de Célula en tu Bóveda SQLCipher con tus límites del Doble Semáforo sellados.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: VinkiarColors.panelDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.5)),
                  ),
                  child: Text(
                    "RECOMPENSA ACREDITADA: +${_selectedQuest?['reward_vinks'] ?? 50} Ѵ | +${_selectedQuest?['xp_reward'] ?? 150} XP",
                    style: GoogleFonts.jetBrainsMono(
                      color: VinkiarColors.vertigoGold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VinkiarColors.hackingGreen,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.chat, size: 18),
                    label: Text(
                      "VOLVER AL CANAL DE CÉLULA",
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPill(String name, String sub, Color color) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: VinkiarColors.abyssBlack,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(Icons.person, color: color, size: 22),
        ),
        const SizedBox(height: 6),
        Text(name,
            style: GoogleFonts.jetBrainsMono(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        Text(sub, style: GoogleFonts.jetBrainsMono(color: color, fontSize: 9)),
      ],
    );
  }

  Widget _buildQuestDetailsCard(Map<String, dynamic> quest) {
    final rawVinks = quest['reward_vinks'] ?? 30;
    final rawXp = quest['xp_reward'] ?? 120;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VinkiarColors.panelDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "DETALLES DE LA MISIÓN",
                style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 9.5, fontWeight: FontWeight.bold),
              ),
              Text(
                "+$rawVinks Ѵ | +$rawXp XP",
                style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 9.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            quest['title'] ?? 'Misión',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          if (quest['lore'] != null && quest['lore'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              "📖 LORE: ${quest['lore']}",
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, height: 1.3),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: VinkiarColors.abyssBlack,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "⚔️ INSTRUCCIÓN PHYGITAL:",
                  style: GoogleFonts.jetBrainsMono(color: VinkiarColors.hackingGreen, fontSize: 9, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  quest['instruction'] ?? (quest['description'] ?? 'Encuentro analógico en territorio neutral.'),
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableLimitsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VinkiarColors.panelDark.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "2. PACTO DE LÍMITES BILATERALES",
                style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _initDefaultLimitsForFirstEncounter();
                  });
                },
                child: Text(
                  "RESTAURAR PLANTILLA",
                  style: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 8.5, decoration: TextDecoration.underline),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "En un primer encuentro con alguien que aún no conoces, es vital reforzar las zonas amarilla y roja.",
            style: GoogleFonts.outfit(color: VinkiarColors.textDim, fontSize: 10.5),
          ),
          const Divider(color: Colors.white12, height: 18),

          Text(
            "ETIQUETA DE CÉLULA (AR):",
            style: GoogleFonts.jetBrainsMono(
              color: VinkiarColors.vertigoGold,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: VinkiarColors.abyssBlack,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                dropdownColor: VinkiarColors.abyssBlack,
                isExpanded: true,
                value: _selectedRelationalKey,
                items: VinkiarRelationalTags.all.map((tag) {
                  return DropdownMenuItem<String>(
                    value: tag.key,
                    child: Text(
                      tag.fullLabel,
                      style: GoogleFonts.jetBrainsMono(color: tag.color, fontSize: 11),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedRelationalKey = val);
                  }
                },
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 18),

          _buildCategoryHeader("🟢 ZONA VERDE (CONSENTIMIENTO ACTIVO)", "GREEN", VinkiarColors.hackingGreen),
          _buildLimitsChipList(_greenLimits, VinkiarColors.hackingGreen, (index) {
            setState(() => _greenLimits.removeAt(index));
          }),
          const SizedBox(height: 12),

          _buildCategoryHeader("🟡 ZONA AMARILLA (PRECAUCIÓN / CONDICIONAL)", "YELLOW", VinkiarColors.vertigoGold),
          _buildLimitsChipList(_yellowLimits, VinkiarColors.vertigoGold, (index) {
            setState(() => _yellowLimits.removeAt(index));
          }),
          const SizedBox(height: 12),

          _buildCategoryHeader("🔴 ZONA ROJA (INVIOLABLE / SIN NEGOCIACIÓN)", "RED", VinkiarColors.panicRed),
          _buildLimitsChipList(_redLimits, VinkiarColors.panicRed, (index) {
            setState(() => _redLimits.removeAt(index));
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title, String category, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.jetBrainsMono(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
        ),
        InkWell(
          onTap: () => _openAddLimitDialog(category),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(Icons.add, color: color, size: 10),
                const SizedBox(width: 2),
                Text("AÑADIR", style: GoogleFonts.jetBrainsMono(color: color, fontSize: 8.5, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLimitsChipList(List<String> limits, Color color, Function(int) onDelete) {
    if (limits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text("Sin límites asignados.", style: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 9.5)),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: List.generate(limits.length, (index) {
          final text = limits[index];
          return Chip(
            backgroundColor: color.withOpacity(0.12),
            side: BorderSide(color: color.withOpacity(0.6), width: 0.8),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
            label: Text(
              text,
              style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 9),
            ),
            deleteIcon: Icon(Icons.close, size: 12, color: color),
            onDeleted: () => onDelete(index),
          );
        }),
      ),
    );
  }
}

class _CrystallizationRunePainter extends CustomPainter {
  final double rotationAngle;
  final double progress;

  _CrystallizationRunePainter({
    required this.rotationAngle,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.88;

    final basePaint = Paint()
      ..color = VinkiarColors.aegisCyan.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, basePaint);

    if (progress > 0.0) {
      final progressPaint = Paint()
        ..color = VinkiarColors.hackingGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        progress * 2 * math.pi,
        false,
        progressPaint,
      );
    }

    final path = Path();
    const int points = 6;
    for (int i = 0; i < points; i++) {
      final a = rotationAngle + (i * 2 * math.pi / points);
      final r = (i % 2 == 0) ? radius : radius * 0.65;
      final x = center.dx + r * math.cos(a);
      final y = center.dy + r * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final runePaint = Paint()
      ..color = (progress > 0.0 ? VinkiarColors.hackingGreen : VinkiarColors.aegisCyan)
          .withOpacity(0.35 + (progress * 0.45))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(path, runePaint);
  }

  @override
  bool shouldRepaint(covariant _CrystallizationRunePainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle || oldDelegate.progress != progress;
  }
}