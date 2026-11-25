import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'theme.dart';
import '../services/vinkiar_secure_database.dart';
import '../services/vinkiar_ai_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/taberna_eventos_service.dart';
import '../services/santuarios_service.dart';
import '../models/relational_tag.dart';
import 'widgets/ssc_traffic_light.dart';
import 'widgets/qr_scanner_dialog.dart';
import 'widgets/decision_engine_sheet.dart';
import 'radar_screen.dart';

typedef JsonMap = Map<String, dynamic>;

enum MissionSource { all, vinki, b2b, p2p, couple, contacts, zone }

class TabernaScreen extends StatefulWidget {
  const TabernaScreen({Key? key}) : super(key: key);

  @override
  State<TabernaScreen> createState() => _TabernaScreenState();
}

class _TabernaScreenState extends State<TabernaScreen> with SingleTickerProviderStateMixin {
  int _userVinks = 150;
  int _userEscrow = 0;
  int _userXp = 450;
  int _userEnergy = 100;
  late TabController _activityTabController;
  final MapController _tabernaMapController = MapController();
  final TextEditingController _zonaFilterCtrl = TextEditingController();

  MissionSource _selectedFilter = MissionSource.all;
  String _selectedEventCategory = 'ALL';
  String _myHandle = '#Pionero';
  LatLng _userLocation = const LatLng(37.389091, -5.984459);

  bool _isLoading = true;
  bool _isFetchingProactive = false;
  List<JsonMap> _quests = [];
  List<EventoTabernaItem> _eventosTaberna = [];
  List<SantuarioNode> _santuariosMapa = [];
  EventoTabernaItem? _selectedMapEvento;
  SantuarioNode? _selectedMapSantuario;
  Map<String, String> _sscLevels = {};
  Map<String, Map<String, dynamic>> _questsMetadata = {};

  static const Color neonGreen = Color(0xFF39FF14);

  @override
  void initState() {
    super.initState();
    _activityTabController = TabController(length: 4, vsync: this);
    _initGpsAndData();

    VinkiarSecureDatabase.questChangeNotifier.addListener(_onQuestDataChanged);
    VinkiarSecureDatabase.contactChangeNotifier.addListener(_onQuestDataChanged);
  }

  @override
  void dispose() {
    VinkiarSecureDatabase.questChangeNotifier.removeListener(_onQuestDataChanged);
    VinkiarSecureDatabase.contactChangeNotifier.removeListener(_onQuestDataChanged);
    _zonaFilterCtrl.dispose();
    _activityTabController.dispose();
    super.dispose();
  }

  Future<void> _initGpsAndData() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (enabled) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm != LocationPermission.denied && perm != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 4),
          );
          _userLocation = LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (_) {}
    await _loadTabernaData();
  }

  void _onQuestDataChanged() {
    if (mounted) {
      _loadTabernaData();
    }
  }

  Future<void> _loadTabernaData() async {
    setState(() => _isLoading = true);

    try {
      final existingQuests = await VinkiarSecureDatabase().getQuests();
      final hasAlpha02 = existingQuests.any((q) => q['id'] == 'VK_ALPHA_02');

      if (existingQuests.isEmpty || !hasAlpha02) {
        await _seedDefaultQuests();
      }

      var loadedQuests = await VinkiarSecureDatabase().getQuests();

      // Autorreconciliación reactiva de prerrequisitos encadenados
      bool needsReload = false;
      for (var q in loadedQuests) {
        if (q['status'] == 'LOCKED') {
          final String? reqId = q['required_quest_id'] ?? q['requiredQuestId'];
          if (reqId != null && reqId.isNotEmpty) {
            final reqQuest = loadedQuests.firstWhere(
              (item) => item['id'] == reqId,
              orElse: () => {},
            );
            if (reqQuest.isNotEmpty && reqQuest['status'] == 'COMPLETED') {
              await VinkiarSecureDatabase().updateQuestStatus(q['id'], 'AVAILABLE');
              needsReload = true;
            }
          }
        }
      }

      if (needsReload) {
        loadedQuests = await VinkiarSecureDatabase().getQuests();
      }

      // Resolver handle del avatar local
      final avatarForHandle = await VinkiarSecureDatabase().getAvatarSheet("LOCAL_USER");
      final avStatsForHandle = avatarForHandle?['stats'] as Map<String, dynamic>? ?? {};
      final rawAlias = (avatarForHandle?['alias']?.toString().isNotEmpty == true)
          ? avatarForHandle!['alias'].toString()
          : (avStatsForHandle['alias']?.toString() ?? 'Pionero');
      _myHandle = rawAlias.startsWith('#') ? rawAlias : '#$rawAlias';

      // Cargar eventos públicos/programados y santuarios geolocalizados desde el backend
      final zFilter = _zonaFilterCtrl.text.trim();
      final isCp = RegExp(r'^\d{4,5}$').hasMatch(zFilter);
      final eventosRemotos = await TabernaEventosService().fetchEventos(
        zona: (!isCp && zFilter.isNotEmpty) ? zFilter : null,
        cp: isCp ? zFilter : null,
        categoria: _selectedEventCategory != 'ALL' ? _selectedEventCategory : null,
        memberHandle: _myHandle,
      );
      final santuariosRemotos = await SantuariosService().fetchRadarNodes(
        lat: _userLocation.latitude,
        lng: _userLocation.longitude,
      );

      _userEnergy = await VinkiarSecureDatabase().getEnergyLevel();

      final Map<String, String> sscMap = {};
      final Map<String, Map<String, dynamic>> metaMap = {};

      for (var q in loadedQuests) {
        final String ssc = await VinkiarSecureDatabase().getConformityLevel(q['id']);
        sscMap[q['id']] = ssc;

        final meta = await VinkiarSecureDatabase().getQuestMetadata(q['id']);
        metaMap[q['id']] = meta;
      }

      try {
        final avatar = await VinkiarSecureDatabase().getAvatarSheet("LOCAL_USER");
        if (avatar != null) {
          if (avatar['experience_points'] != null) {
            _userXp = avatar['experience_points'] as int;
          }
          final stats = avatar['stats'] as Map<String, dynamic>? ?? {};
          if (stats['vinks'] != null) {
            _userVinks = (stats['vinks'] as num).toInt();
          }
          _userEscrow = (stats['escrow'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _quests = loadedQuests;
          _eventosTaberna = eventosRemotos;
          _santuariosMapa = santuariosRemotos;
          if (_selectedMapEvento != null) {
            final refreshed = eventosRemotos.where((e) => e.id == _selectedMapEvento!.id).toList();
            _selectedMapEvento = refreshed.isNotEmpty ? refreshed.first : null;
          }
          _sscLevels = sscMap;
          _questsMetadata = metaMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _seedDefaultQuests() async {
    final db = VinkiarSecureDatabase();
    final existingQuests = await db.getQuests();
    final existingIds = existingQuests.map((q) => q['id']).toSet();

    final defaultQuests = [
      {
        "id": "VK_ALPHA_01",
        "title": "Subasta Inversa de Tareas",
        "description": "Las fricciones cotidianas sobre la carga mental desgastan la erosión afectiva.\n\n⚔️ INSTRUCCIÓN PHYGITAL:\n1. Acuerda la lista de 3 tareas con tu pareja/vínculo.\n2. Pujad Vinks en Escrow.\n3. Quien asuma la tarea estampa su firma; la otra parte certifica para liberar los fondos.",
        "source_type": "COUPLE",
        "reward_vinks": 20,
        "xp_reward": 150,
        "status": "AVAILABLE",
        "required_quest_id": null,
        "created_at": DateTime.now().toIso8601String(),
      },
      {
        "id": "VK_ALPHA_02",
        "title": "Subasta II: Redistribución de Espacios",
        "description": "Fase avanzada de negociación doméstica y co-regulación del búnker.\n\n⚔️ INSTRUCCIÓN PHYGITAL:\n1. Definid las 3 zonas críticas del espacio compartido.\n2. Subastad la reorganización táctica de cada área.\n3. Sancionad con doble firma tras la inspección conjunta.",
        "source_type": "COUPLE",
        "reward_vinks": 40,
        "xp_reward": 200,
        "status": "LOCKED",
        "required_quest_id": "VK_ALPHA_01",
        "created_at": DateTime.now().add(const Duration(seconds: 1)).toIso8601String(),
      },
      {
        "id": "B2B_SANC_101",
        "title": "Santuario Loto - Verificación Presencial",
        "description": "Los Santuarios B2B ofrecen espacios seguros.\n\n⚔️ INSTRUCCIÓN PHYGITAL:\n1. Acude al Santuario Loto.\n2. Escanéalo desde el visor ZKA para validar tu presencia física.",
        "source_type": "B2B",
        "reward_vinks": 35,
        "xp_reward": 120,
        "status": "AVAILABLE",
        "required_quest_id": null,
        "created_at": DateTime.now().toIso8601String(),
      },
    ];

    for (var quest in defaultQuests) {
      if (!existingIds.contains(quest['id'])) {
        await db.saveQuest(quest);
        if (quest['id'] == 'VK_ALPHA_01' || quest['id'] == 'VK_ALPHA_02') {
          await db.saveQuestMetadata(quest['id'] as String, {
            'creator_id': 'VINKI_ORACLE',
            'escrow_amount': quest['reward_vinks'],
            'is_diadic': true,
          });
        }
      }
    }
  }

  Future<void> _aceptarEventoTaberna(EventoTabernaItem ev) async {
    final db = VinkiarSecureDatabase();
    final questId = "EVT_${ev.id}";

    await TabernaEventosService().inscribirseEvento(
      eventoId: ev.id,
      memberHandle: _myHandle,
    );

    await db.saveQuest({
      "id": questId,
      "title": ev.titulo,
      "description": "${ev.descripcion}\n\n📍 Zona: ${ev.zona} · 🗓️ ${ev.fechaEvento} (${ev.horario})",
      "source_type": "B2B",
      "reward_vinks": ev.recompensaVinks,
      "xp_reward": ev.xpReward,
      "status": "IN_PROGRESS",
      "created_at": DateTime.now().toIso8601String(),
    });

    await _loadTabernaData();
    _activityTabController.animateTo(1);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: VinkiarColors.hackingGreen,
          content: Text(
            "⚡ INSCRITO EN EVENTO: '${ev.titulo}' añadido a En Progreso.",
            style: GoogleFonts.jetBrainsMono(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  void _focusEventoEnMapaTaberna(EventoTabernaItem ev) {
    setState(() {
      _selectedMapSantuario = null;
      _selectedMapEvento = ev;
    });
    _activityTabController.animateTo(2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        _tabernaMapController.move(LatLng(ev.latitud, ev.longitud), 16.2);
      } catch (_) {}
    });
  }

  void _abrirMesaDecisionEvento(EventoTabernaItem ev) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DecisionEngineSheet(
        guildId: ev.gremioId.isNotEmpty ? ev.gremioId : "EVT_${ev.id}",
        channelName: ev.titulo,
        myHandle: _myHandle,
      ),
    );
  }

  Future<void> _fetchProactiveQuestsFromVinki() async {
    if (_isFetchingProactive) return;
    setState(() => _isFetchingProactive = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: VinkiarColors.panelDark,
        content: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: VinkiarColors.aegisCyan),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "🤖 Vinki consultando RAG, Eneagrama y Bitácora...",
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );

    final proactiveQuests = await VinkiarAIService().fetchProactiveQuests();

    if (proactiveQuests.isNotEmpty) {
      final existingQuests = await VinkiarSecureDatabase().getQuests();

      final activeQuests = existingQuests.where((q) {
        final st = (q['status'] ?? '').toString().toUpperCase();
        return st == 'AVAILABLE' || st == 'IN_PROGRESS' || st == 'AWAITING_VERIFICATION' || st == 'LOCKED';
      }).toList();

      final activeTitles = activeQuests.map((q) => q['title'].toString().toLowerCase().trim()).toSet();
      final allExistingIds = existingQuests.map((q) => q['id'].toString()).toSet();

      int newlyAdded = 0;

      for (var quest in proactiveQuests) {
        String qId = (quest['id'] ?? quest['quest_id'] ?? "PROACTIVE_${DateTime.now().millisecondsSinceEpoch}").toString();
        final String title = (quest['title'] ?? "Sugerencia de Vinki").toString().trim();

        if (activeTitles.contains(title.toLowerCase())) {
          continue;
        }

        if (allExistingIds.contains(qId)) {
          qId = "${qId}_${DateTime.now().millisecondsSinceEpoch}";
        }

        final rawVinks = quest['reward_vinks'] ?? 25;
        final rawXp = quest['xp_reward'] ?? 100;
        final int vinks = rawVinks is int ? rawVinks : (int.tryParse(rawVinks.toString()) ?? 25);
        final int xp = rawXp is int ? rawXp : (int.tryParse(rawXp.toString()) ?? 100);

        await VinkiarSecureDatabase().saveQuest({
          "id": qId,
          "title": title,
          "description": quest['description'] ?? "Misión recomendada por Vinki AI.",
          "source_type": "VINKI",
          "reward_vinks": vinks,
          "xp_reward": xp,
          "status": "AVAILABLE",
          "created_at": DateTime.now().toIso8601String(),
        });

        await VinkiarSecureDatabase().saveQuestMetadata(qId, {
          'creator_id': 'VINKI_ORACLE',
          'escrow_amount': vinks,
          'is_diadic': false,
        });

        allExistingIds.add(qId);
        activeTitles.add(title.toLowerCase());
        newlyAdded++;
      }

      await _loadTabernaData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: newlyAdded > 0 ? VinkiarColors.hackingGreen : VinkiarColors.vertigoGold,
            content: Text(
              newlyAdded > 0
                  ? "🤖 VINKI HA INYECTADO $newlyAdded NUEVAS MISIONES DESDE EL RAG"
                  : "🤖 VINKI: Las misiones sugeridas ya están activas en tu Tablón",
              style: GoogleFonts.jetBrainsMono(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() => _isFetchingProactive = false);
    }
  }

  void _openPublishContractDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final rewardController = TextEditingController(text: "25");
    final minLevelController = TextEditingController(text: "1");
    String? selectedContactId;
    String? selectedReqQuestId;
    String? errorMessage;

    final contacts = await VinkiarSecureDatabase().getContacts();
    final availableContacts = contacts
        .where((c) => c['ssc_level'] != 'REVOKED')
        .toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: VinkiarColors.abyssBlack,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(
              top: BorderSide(color: VinkiarColors.vertigoGold, width: 1.5),
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "EMITIR CONTRATO P2P // ESCROW",
                      style: GoogleFonts.jetBrainsMono(
                        color: VinkiarColors.vertigoGold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: VinkiarColors.panelDark,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock, color: VinkiarColors.vertigoGold, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "DEPÓSITO EN CUSTODIA (ESCROW): La recompensa se retiene de tus Vinks. Solo se liquidará tras la doble firma de cumplimiento.",
                          style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 8.5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: selectedContactId,
                  dropdownColor: VinkiarColors.panelDark,
                  style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    labelText: "DESTINATARIO / COMPAÑERO DE VÍNCULO",
                    labelStyle: GoogleFonts.jetBrainsMono(
                        color: VinkiarColors.vertigoGold.withOpacity(0.8), fontSize: 10),
                    isDense: true,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: VinkiarColors.vertigoGold.withOpacity(0.4)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: VinkiarColors.vertigoGold),
                    ),
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text("🌐 Misión Abierta (P2P General)"),
                    ),
                    ...availableContacts.map((c) {
                      final String ssc = (c['ssc_level'] ?? 'GREEN').toString().toUpperCase();
                      String badgeIcon = '🟢';
                      if (ssc == 'YELLOW') badgeIcon = '🟡';
                      if (ssc == 'RED') badgeIcon = '🔴';

                      final String arBadge = VinkiarRelationalTags.formatTabernaBadge(
                        c['relationship_type'],
                        c['relational_tag'],
                      );

                      return DropdownMenuItem<String>(
                        value: c['id'].toString(),
                        child: Text(
                          "👤 ${c['alias']} ($arBadge - $badgeIcon)",
                          style: TextStyle(
                            color: ssc == 'RED' ? VinkiarColors.panicRed : Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setModalState(() {
                      selectedContactId = val;
                      errorMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: titleController,
                  style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: "Título del Contrato",
                    labelStyle: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 11),
                    isDense: true,
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.aegisCyan)),
                  ),
                  onChanged: (_) {
                    if (errorMessage != null) setModalState(() => errorMessage = null);
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: descController,
                  maxLines: 2,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    labelText: "Descripción del Reto / Reglas de Subasta",
                    labelStyle: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 11),
                    isDense: true,
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.aegisCyan)),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rewardController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.jetBrainsMono(
                            color: VinkiarColors.vertigoGold, fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: "Depósito Escrow (Ѵ)",
                          labelStyle: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 10),
                          isDense: true,
                          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.vertigoGold)),
                        ),
                        onChanged: (_) {
                          if (errorMessage != null) setModalState(() => errorMessage = null);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: minLevelController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 12),
                        decoration: InputDecoration(
                          labelText: "Nivel Mínimo",
                          labelStyle: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 10),
                          isDense: true,
                          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.aegisCyan)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: selectedReqQuestId,
                  dropdownColor: VinkiarColors.panelDark,
                  style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11),
                  decoration: InputDecoration(
                    labelText: "MISIÓN PRERREQUISITO (OPCIONAL)",
                    labelStyle: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 10),
                    isDense: true,
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.aegisCyan)),
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text("Ninguna (Disponible Inmediatamente)"),
                    ),
                    ..._quests.map((q) => DropdownMenuItem<String>(
                          value: q['id'],
                          child: Text("🔒 Requiere: ${q['title']}"),
                        )),
                  ],
                  onChanged: (val) => setModalState(() => selectedReqQuestId = val),
                ),

                if (errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: VinkiarColors.panicRed.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: VinkiarColors.panicRed),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: VinkiarColors.panicRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: GoogleFonts.jetBrainsMono(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VinkiarColors.vertigoGold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      final title = titleController.text.trim();
                      final rewardAmount = int.tryParse(rewardController.text.trim()) ?? 25;

                      if (title.isEmpty) {
                        setModalState(() {
                          errorMessage = "⚠️ Por favor, escribe un título para el contrato.";
                        });
                        return;
                      }

                      if (rewardAmount < 0) {
                        setModalState(() {
                          errorMessage = "⚠️ La recompensa no puede ser negativa.";
                        });
                        return;
                      }

                      if (_userVinks < rewardAmount) {
                        setModalState(() {
                          errorMessage = "⚠️ SALDO INSUFICIENTE: Tienes $_userVinks Ѵ y requieres $rewardAmount Ѵ para retener en Escrow.";
                        });
                        return;
                      }

                      if (selectedContactId != null) {
                        final targetContact = availableContacts.firstWhere(
                          (c) => c['id'].toString() == selectedContactId,
                          orElse: () => {},
                        );

                        final String sscFromContact = (targetContact['ssc_level'] ?? 'GREEN').toString().toUpperCase();
                        final String sscFromDb = (await VinkiarSecureDatabase().getConformityLevel(selectedContactId!)).toUpperCase();

                        final bool isRed = sscFromContact == 'RED' || sscFromContact == 'REVOKED' || sscFromDb == 'RED' || sscFromDb == 'REVOKED';

                        if (isRed) {
                          setModalState(() {
                            errorMessage = "⛔ BARRERA SSC ACTIVA: El destinatario está en Nivel Rojo. La emisión de contratos está pausada.";
                          });
                          return;
                        }
                      }

                      try {
                        if (rewardAmount > 0) {
                          await VinkiarSecureDatabase().lockEscrow(rewardAmount);
                        }

                        final String questId = "P2P_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
                        final newQuest = {
                          "id": questId,
                          "title": title,
                          "description": descController.text.trim(),
                          "source_type": selectedContactId != null ? "COUPLE" : "P2P",
                          "reward_vinks": rewardAmount,
                          "xp_reward": 100,
                          "status": "AVAILABLE",
                          "min_level": int.tryParse(minLevelController.text.trim()) ?? 1,
                          "required_quest_id": selectedReqQuestId,
                          "created_at": DateTime.now().toIso8601String(),
                        };

                        await VinkiarSecureDatabase().saveQuest(newQuest);
                        await VinkiarSecureDatabase().saveQuestMetadata(questId, {
                          'creator_id': 'LOCAL_AVATAR',
                          'target_id': selectedContactId,
                          'escrow_amount': rewardAmount,
                          'is_diadic': true,
                        });

                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadTabernaData();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: VinkiarColors.vertigoGold,
                              content: Text(
                                "CONTRATO PUBLICADO: $rewardAmount Ѵ retenidos en Escrow bajo custodia.",
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setModalState(() {
                          errorMessage = "Error bloqueando fondos: $e";
                        });
                      }
                    },
                    child: Text(
                      "EMITIR CONTRATO (BLOQUEAR EN ESCROW)",
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFilterSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.aegisCyan, width: 1.5),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "FILTRAR POR ORIGEN DE MISIÓN",
                style: GoogleFonts.jetBrainsMono(
                  color: VinkiarColors.aegisCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              _buildFilterOption("TODAS LAS FUENTES", MissionSource.all, Icons.border_all, Colors.white),
              _buildFilterOption("🤖 ORÁCULO VINKI", MissionSource.vinki, Icons.smart_toy, VinkiarColors.aegisCyan),
              _buildFilterOption("🏛️ SANTUARIOS B2B", MissionSource.b2b, Icons.store, neonGreen),
              _buildFilterOption("👤 CONTRATOS P2P", MissionSource.p2p, Icons.handshake, VinkiarColors.vertigoGold),
              _buildFilterOption("❤️ VÍNCULO / PAREJA", MissionSource.couple, Icons.favorite, Colors.pinkAccent),
              _buildFilterOption("👥 CONTACTOS / GRUPO", MissionSource.contacts, Icons.groups, Colors.purpleAccent),
              _buildFilterOption("📍 RADAR / ZONA LOCAL & EVENTOS", MissionSource.zone, Icons.near_me, Colors.orangeAccent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, MissionSource source, IconData icon, Color color) {
    final bool isSelected = _selectedFilter == source;
    return ListTile(
      leading: Icon(icon, color: color, size: 18),
      title: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          color: isSelected ? color : Colors.white70,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check_circle, color: color, size: 16) : null,
      onTap: () {
        setState(() => _selectedFilter = source);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildQuestListView(List<JsonMap> questList, {bool includeRemoteEvents = false}) {    final filtered = questList.where((q) {
      if (_selectedFilter == MissionSource.all) return true;
      final type = (q['source_type'] ?? q['sourceType'] ?? '').toString().toUpperCase();
      if (_selectedFilter == MissionSource.vinki) return type == 'VINKI';
      if (_selectedFilter == MissionSource.b2b) return type == 'B2B';
      if (_selectedFilter == MissionSource.p2p) return type == 'P2P';
      if (_selectedFilter == MissionSource.couple) return type == 'COUPLE';
      if (_selectedFilter == MissionSource.zone) return q['id'].toString().startsWith('EVT_');
      return true;
    }).toList();

    final existingQuestIds = _quests.map((q) => q['id'].toString()).toSet();
    final bool showEventsCategory = includeRemoteEvents &&
        (_selectedFilter == MissionSource.all ||
            _selectedFilter == MissionSource.zone ||
            _selectedFilter == MissionSource.b2b);

    final visibleEvents = showEventsCategory
        ? _eventosTaberna.where((ev) => !existingQuestIds.contains("EVT_${ev.id}")).toList()
        : <EventoTabernaItem>[];

    if (filtered.isEmpty && visibleEvents.isEmpty) {
      return RefreshIndicator(
        color: VinkiarColors.aegisCyan,
        backgroundColor: VinkiarColors.panelDark,
        onRefresh: _loadTabernaData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.25),
            Center(
              child: Column(
                children: [
                  Text(
                    "No hay misiones en esta categoría.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VinkiarColors.aegisCyan,
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: Text("🤖 SOLICITAR MISIONES A VINKI", style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold)),
                    onPressed: _fetchProactiveQuestsFromVinki,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: VinkiarColors.aegisCyan,
      backgroundColor: VinkiarColors.panelDark,
      onRefresh: _loadTabernaData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
        children: [
          // Tarjetas de Eventos Geolocalizados y de Lore desde Super Admin
          ...visibleEvents.map(
            (ev) => EventoTabernaCard(
              evento: ev,
              onAceptar: () => _aceptarEventoTaberna(ev),
              onVerEnMapa: () => _focusEventoEnMapaTaberna(ev),
              onAbrirDecision: () => _abrirMesaDecisionEvento(ev),
            ),
          ),

          // Tarjetas de Misiones locales, Vinki AI y Contratos P2P
          ...filtered.map((quest) {
            final String sourceType = (quest['source_type'] ?? quest['sourceType'] ?? 'P2P').toString();
            final Color color = _getSourceColor(sourceType);
            final meta = _questsMetadata[quest['id']] ?? {};
            final bool isDiadic = meta['is_diadic'] == true;
            final bool isLocked = quest['status'] == 'LOCKED';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isLocked ? VinkiarColors.panelDark.withOpacity(0.5) : VinkiarColors.panelDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isLocked ? Colors.white24 : color.withOpacity(0.7),
                  width: 1.2,
                ),
              ),
              child: InkWell(
                onTap: () => _showQuestDetailDialog(quest),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getSourceBadge(sourceType),
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: isLocked ? Colors.white54 : color,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isDiadic) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: VinkiarColors.vertigoGold.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: VinkiarColors.vertigoGold, width: 0.8),
                                    ),
                                    child: Text(
                                      "ESCROW 2-DE-2",
                                      style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 7.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildStatusBadge(quest['status'] ?? 'AVAILABLE', isLocked ? Colors.white38 : color),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (isLocked) ...[
                            const Icon(Icons.lock_outline, color: VinkiarColors.panicRed, size: 16),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              quest['title'] ?? 'Misión',
                              style: GoogleFonts.outfit(
                                color: isLocked ? Colors.white54 : Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        quest['description'] ?? '',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(color: VinkiarColors.textDim, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showQuestDetailDialog(Map<String, dynamic> mission) {
    final String status = mission['status'] ?? 'AVAILABLE';
    final String questId = mission['id'];
    final String? reqId = mission['required_quest_id'] ?? mission['requiredQuestId'];

    final rawVinks = mission['reward_vinks'] ?? mission['rewardVinks'] ?? 20;
    final rawXp = mission['xp_reward'] ?? mission['xpReward'] ?? 100;

    final int rewardVinks = rawVinks is int ? rawVinks : (int.tryParse(rawVinks.toString()) ?? 20);
    final int rewardXp = rawXp is int ? rawXp : (int.tryParse(rawXp.toString()) ?? 100);
    const int energyCost = 15;

    final String sourceType = (mission['source_type'] ?? mission['sourceType'] ?? 'P2P').toString();
    final Color color = _getSourceColor(sourceType);
    final meta = _questsMetadata[questId] ?? {};
    final bool isDiadic = meta['is_diadic'] == true || sourceType == 'COUPLE' || sourceType == 'P2P';
    final String creatorId = meta['creator_id'] ?? '';
    final bool amICreator = creatorId == 'LOCAL_AVATAR' || creatorId == 'LOCAL_USER';
    final String? sigCreator = meta['signature_creator'];
    final String? sigExecutor = meta['signature_executor'];

    bool isLockedByReq = false;
    Map<String, dynamic> reqQuest = {};
    if (reqId != null && reqId.isNotEmpty) {
      reqQuest = _quests.firstWhere((q) => q['id'] == reqId, orElse: () => {});
      if (reqQuest.isNotEmpty && reqQuest['status'] != 'COMPLETED') {
        isLockedByReq = true;
      }
    }

    final bool isLocked = status == 'LOCKED' || isLockedByReq;
    final bool isCompleted = status == 'COMPLETED';
    final bool isInProgress = status == 'IN_PROGRESS';
    final bool isAwaitingVerification = status == 'AWAITING_VERIFICATION';
    final bool isB2B = sourceType.toUpperCase() == 'B2B';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final String currentSsc = _sscLevels[questId] ?? 'GREEN';
          final bool isSscBlocked = currentSsc == 'RED' || currentSsc == 'REVOKED';
          final bool isSscCaution = currentSsc == 'YELLOW';

          return Dialog(
            backgroundColor: VinkiarColors.inkBlack,
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isSscBlocked ? VinkiarColors.panicRed : (isLocked ? Colors.white38 : color),
                width: 1.5,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: color.withOpacity(0.6)),
                                ),
                                child: Text(
                                  _getSourceBadge(sourceType),
                                  style: GoogleFonts.jetBrainsMono(
                                    color: color,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              _buildStatusBadge(
                                isSscBlocked ? 'PAUSADA_SSC' : (isLocked ? 'LOCKED' : status),
                                isSscBlocked ? VinkiarColors.panicRed : (isLocked ? Colors.white38 : color),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          Text(
                            mission['title'] ?? 'Misión',
                            style: GoogleFonts.outfit(
                              color: isLocked ? Colors.white70 : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Text(
                            mission['description'] ?? '',
                            style: GoogleFonts.outfit(
                              color: VinkiarColors.textDim,
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),

                          if (isSscBlocked) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: VinkiarColors.panicRed.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: VinkiarColors.panicRed),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.shield_outlined, color: VinkiarColors.panicRed, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "PAUSA ABSOLUTA POR SALVAGUARDA SSC",
                                          style: GoogleFonts.jetBrainsMono(
                                            color: VinkiarColors.panicRed,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          "El consentimiento ha sido suspendido. Las acciones operativas se detienen. Podéis renegociar el semáforo o abortar el contrato liberando el Escrow sin penalización.",
                                          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (isSscCaution) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: VinkiarColors.vertigoGold.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.6)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: VinkiarColors.vertigoGold, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "PRECAUCIÓN (AMARILLO): Consentimiento condicionado. Actuad a ritmo pausado verificando el bienestar mutuo.",
                                      style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 9.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (isDiadic) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: VinkiarColors.panelDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("CONTRATO DIÁDICO // DOBLE FIRMA ZKA", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                      Text("ESCROW: $rewardVinks Ѵ", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(sigExecutor != null ? Icons.verified : Icons.radio_button_unchecked, size: 13, color: sigExecutor != null ? VinkiarColors.hackingGreen : Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(sigExecutor != null ? "Firma Ejecutor: SELLADA" : "Firma Ejecutor: PENDIENTE", style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: sigExecutor != null ? VinkiarColors.hackingGreen : Colors.grey)),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(sigCreator != null ? Icons.verified : Icons.radio_button_unchecked, size: 13, color: sigCreator != null ? VinkiarColors.hackingGreen : Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(sigCreator != null ? "Firma Certificador: SELLADA" : "Firma Certificador: PENDIENTE", style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: sigCreator != null ? VinkiarColors.hackingGreen : Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (isLockedByReq) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: VinkiarColors.panicRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: VinkiarColors.panicRed.withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.lock, color: VinkiarColors.panicRed, size: 14),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      "🔒 Requiere completar primero: ${reqQuest['title'] ?? 'Misión previa'}",
                                      style: GoogleFonts.jetBrainsMono(
                                        color: VinkiarColors.panicRed,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: VinkiarColors.panelDark,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text("RECOMPENSA", style: GoogleFonts.jetBrainsMono(fontSize: 8, color: VinkiarColors.textDim)),
                                    const SizedBox(height: 2),
                                    Text("+$rewardVinks Ѵ", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text("EXPERIENCIA", style: GoogleFonts.jetBrainsMono(fontSize: 8, color: VinkiarColors.textDim)),
                                    const SizedBox(height: 2),
                                    Text("+$rewardXp XP", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text("COSTO", style: GoogleFonts.jetBrainsMono(fontSize: 8, color: VinkiarColors.textDim)),
                                    const SizedBox(height: 2),
                                    Text("$energyCost ⚡", style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          if (isB2B) ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: neonGreen),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              icon: const Icon(Icons.map_outlined, color: neonGreen, size: 16),
                              label: Text(
                                "📍 LOCALIZAR SANTUARIO EN EL RADAR",
                                style: GoogleFonts.jetBrainsMono(color: neonGreen, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                Navigator.pop(dialogCtx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RadarScreen(
                                      focusNodeId: "B2B_SANC_01",
                                      initialViewMode: RadarViewMode.darkMap,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],

                          const SizedBox(height: 12),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "SEMÁFORO DE CONFORMIDAD (SSC):",
                                style: GoogleFonts.jetBrainsMono(
                                  color: VinkiarColors.textDim,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SSCTrafficLight(
                                    currentStatus: currentSsc,
                                    isCompact: false,
                                    onStatusChanged: (newLevel) async {
                                      await VinkiarSecureDatabase().setConformityLevel(questId, newLevel);
                                      setDialogState(() {
                                        _sscLevels[questId] = newLevel;
                                      });
                                      setState(() {
                                        _sscLevels[questId] = newLevel;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text("CERRAR", style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 11)),
                        ),
                      ),

                      if ((status == 'AVAILABLE' && (sourceType == 'VINKI' || sourceType == 'P2P' || sourceType == 'COUPLE')) ||
                          (isSscBlocked && (isInProgress || isAwaitingVerification))) ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: VinkiarColors.panicRed),
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          ),
                          onPressed: () async {
                            Navigator.pop(dialogCtx);
                            if (amICreator && rewardVinks > 0) {
                              await VinkiarSecureDatabase().releaseEscrowTo(rewardVinks, true);
                            }
                            await VinkiarSecureDatabase().updateQuestStatus(questId, 'DISCARDED');
                            await _loadTabernaData();

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: VinkiarColors.panelDark,
                                  content: Text(
                                    isSscBlocked
                                        ? "CONTRATO ABORTADO POR SALVAGUARDA SSC: $rewardVinks Ѵ devueltos de Escrow."
                                        : (amICreator
                                            ? "CONTRATO CANCELADO: $rewardVinks Ѵ devueltos de Escrow."
                                            : "PROPUESTA DESESTIMADA SIN PENALIZACIÓN"),
                                    style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 10),
                                  ),
                                ),
                              );
                            }
                          },
                          child: Text(
                            isSscBlocked ? "🛑 ABORTAR POR SSC" : "🗑️ DESCARTAR",
                            style: GoogleFonts.jetBrainsMono(color: VinkiarColors.panicRed, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],

                      const SizedBox(width: 8),

                      if (isLocked)
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: VinkiarColors.panicRed),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            icon: const Icon(Icons.lock, color: VinkiarColors.panicRed, size: 14),
                            label: Text(
                              "BLOQUEADA",
                              style: GoogleFonts.jetBrainsMono(
                                color: VinkiarColors.panicRed,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: null,
                          ),
                        )
                      else if (isSscBlocked)
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: VinkiarColors.panicRed),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            icon: const Icon(Icons.pause_circle_outline, color: VinkiarColors.panicRed, size: 14),
                            label: Text(
                              "PAUSADA POR SSC",
                              style: GoogleFonts.jetBrainsMono(
                                color: VinkiarColors.panicRed,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: null,
                          ),
                        )
                      else if (!isCompleted)
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isInProgress
                                  ? (isB2B ? neonGreen : VinkiarColors.hackingGreen)
                                  : (isAwaitingVerification ? VinkiarColors.vertigoGold : color),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              Navigator.pop(dialogCtx);

                              if (status == 'AVAILABLE') {
                                if (amICreator && isDiadic) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: VinkiarColors.panelDark,
                                      content: Text("Has publicado este contrato. En espera de que un aliado lo acepte."),
                                    ),
                                  );
                                  return;
                                }
                                await _acceptMission(mission);
                              } else if (isInProgress) {
                                if (isB2B && !questId.startsWith('EVT_')) {
                                  _triggerPhygitalVerification(mission);
                                } else if (isDiadic) {
                                  if (amICreator) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        backgroundColor: VinkiarColors.panelDark,
                                        content: Text("Eres el creador. Esperando a que el ejecutor declare cumplida la tarea."),
                                      ),
                                    );
                                    return;
                                  }
                                  await _executeDiadicStepOne(mission);
                                } else {
                                  await _completeMission(mission);
                                }
                              } else if (isAwaitingVerification) {
                                if (!amICreator) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: VinkiarColors.panelDark,
                                      content: Text("Ya has firmado. Esperando a que el creador certifique el cumplimiento."),
                                    ),
                                  );
                                  return;
                                }
                                await _executeDiadicStepTwo(mission);
                              }
                            },
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _getActionButtonLabel(status, isB2B && !questId.startsWith('EVT_'), isDiadic, amICreator),
                                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getActionButtonLabel(String status, bool isB2B, bool isDiadic, bool amICreator) {
    if (status == 'AVAILABLE') {
      return (amICreator && isDiadic) ? "CONTRATO PUBLICADO (EN ESPERA)" : "ACEPTAR MISIÓN";
    }
    if (status == 'IN_PROGRESS') {
      if (isB2B) return "📸 VALIDAR GLIFO B2B";
      if (isDiadic) {
        return amICreator ? "EN CURSO (ESPERANDO AL EJECUTOR)" : "✍️ DECLARAR CUMPLIDA (FIRMA 1/2)";
      }
      return "COMPLETAR MISIÓN";
    }
    if (status == 'AWAITING_VERIFICATION') {
      return amICreator
          ? "🤝 CERTIFICAR Y LIBERAR ESCROW (2/2)"
          : "ESPERANDO CERTIFICACIÓN DEL CREADOR";
    }
    return "MISIÓN CERRADA";
  }

  Future<void> _executeDiadicStepOne(Map<String, dynamic> mission) async {
    final String questId = mission['id'];
    final String localSig = "SIG_EXEC_${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}";

    try {
      final cleanBase = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;

      await http.post(
        Uri.parse('$cleanBase/api/v1/quests/sign'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'quest_id': questId,
          'signer_id': 'LOCAL_AVATAR',
          'role': 'EXECUTOR',
          'signature': localSig,
        }),
      ).timeout(const Duration(seconds: 8));

      await VinkiarSecureDatabase().saveQuestMetadata(questId, {
        'executor_id': 'LOCAL_AVATAR',
        'signature_executor': localSig,
      });
      await VinkiarSecureDatabase().updateQuestStatus(questId, 'AWAITING_VERIFICATION');
      await _loadTabernaData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: VinkiarColors.vertigoGold,
            content: Text(
              "FIRMA DE EJECUCIÓN REGISTRADA. En espera de la certificación del Creador.",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      await VinkiarSecureDatabase().saveQuestMetadata(questId, {
        'executor_id': 'LOCAL_AVATAR',
        'signature_executor': localSig,
      });
      await VinkiarSecureDatabase().updateQuestStatus(questId, 'AWAITING_VERIFICATION');
      await _loadTabernaData();
    }
  }

  Future<void> _executeDiadicStepTwo(Map<String, dynamic> mission) async {
    final String questId = mission['id'];
    final String localSig = "SIG_CERT_${DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase()}";

    try {
      final cleanBase = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;

      await http.post(
        Uri.parse('$cleanBase/api/v1/quests/sign'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'quest_id': questId,
          'signer_id': 'LOCAL_AVATAR',
          'role': 'CREATOR',
          'signature': localSig,
        }),
      ).timeout(const Duration(seconds: 8));

      await VinkiarSecureDatabase().saveQuestMetadata(questId, {
        'signature_creator': localSig,
      });

      final bool verified = await VinkiarSecureDatabase().verifyDoubleSignature(questId);
      await _loadTabernaData();

      if (mounted && verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: VinkiarColors.hackingGreen,
            content: Text(
              "🎉 CONTRATO CERTIFICADO BILATERALMENTE: Vinks liquidados de Escrow.",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      await VinkiarSecureDatabase().saveQuestMetadata(questId, {
        'signature_creator': localSig,
      });
      await VinkiarSecureDatabase().verifyDoubleSignature(questId);
      await _loadTabernaData();
    }
  }

  void _triggerPhygitalVerification(Map<String, dynamic> mission) {
    showDialog(
      context: context,
      builder: (ctx) => QRScannerDialog(
        onCodeScanned: (scannedCode) async {
          final String targetId = mission['id'];
          final bool isValid = scannedCode.toUpperCase().contains("SANCTUARY") ||
              scannedCode.toUpperCase().contains("B2B") ||
              scannedCode.toUpperCase().contains(targetId.toUpperCase());

          if (isValid) {
            await _completeMission(mission);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: VinkiarColors.panicRed,
                  content: Text(
                    "❌ GLIFO NO COINCIDENTE CON EL SANTUARIO B2B",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _acceptMission(Map<String, dynamic> mission) async {
    const int energyCost = 15;
    final String questId = mission['id'];

    final bool energyDeducted = await VinkiarSecureDatabase().consumeEnergy(energyCost);
    if (!energyDeducted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: VinkiarColors.abyssBlack,
          content: Text(
            "ENERGÍA AGOTADA (⚡). RECARGA EN LA ARMERÍA O SANTUARIOS B2B",
            style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 10.5),
          ),
        ),
      );
      return;
    }

    await VinkiarSecureDatabase().updateQuestStatus(questId, 'IN_PROGRESS');
    setState(() => _userEnergy = (_userEnergy - energyCost).clamp(0, 100));
    await _loadTabernaData();
  }

  Future<void> _completeMission(Map<String, dynamic> mission) async {
    final String questId = mission['id'];
    final rawVinks = mission['reward_vinks'] ?? mission['rewardVinks'] ?? 20;
    final rawXp = mission['xp_reward'] ?? mission['xpReward'] ?? 100;

    final int rewardVinks = rawVinks is int ? rawVinks : (int.tryParse(rawVinks.toString()) ?? 20);
    final int rewardXp = rawXp is int ? rawXp : (int.tryParse(rawXp.toString()) ?? 100);

    await VinkiarSecureDatabase().updateQuestStatus(questId, 'COMPLETED');
    await VinkiarSecureDatabase().addAvatarRewards(rewardVinks, rewardXp);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: VinkiarColors.hackingGreen,
          content: Text(
            "🎉 MISIÓN COMPLETADA: +$rewardVinks Ѵ Vinks y +$rewardXp XP acreditados en tu Bóveda ZKA",
            style: GoogleFonts.jetBrainsMono(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    await _loadTabernaData();
  }

  Color _getSourceColor(String? sourceType) {
    switch (sourceType?.toUpperCase()) {
      case 'VINKI':
        return VinkiarColors.aegisCyan;
      case 'B2B':
        return neonGreen;
      case 'COUPLE':
        return Colors.pinkAccent;
      case 'P2P':
      default:
        return VinkiarColors.vertigoGold;
    }
  }

  String _getSourceBadge(String? sourceType) {
    switch (sourceType?.toUpperCase()) {
      case 'VINKI':
        return "🤖 ORÁCULO VINKI";
      case 'B2B':
        return "🏛️ SANTUARIO B2B";
      case 'COUPLE':
        return "❤️ VÍNCULO";
      case 'P2P':
      default:
        return "👤 CONTRATO P2P";
    }
  }

  Widget _buildStatusBadge(String status, Color missionColor) {
    String label = status;
    if (status == 'AWAITING_VERIFICATION') label = 'VERIFICACIÓN (1/2)';
    if (status == 'LOCKED') label = 'BLOQUEADA';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: missionColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: missionColor.withOpacity(0.7)),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(color: missionColor, fontSize: 8.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existingQuestIds = _quests.map((q) => q['id'].toString()).toSet();
    final availableEventsCount = _eventosTaberna.where((ev) => !existingQuestIds.contains("EVT_${ev.id}")).length;
    final availableQuestsCount = _quests.where((q) => q['status'] == 'AVAILABLE' || q['status'] == 'LOCKED').length;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(minScaleFactor: 0.8, maxScaleFactor: 1.25),
      ),
      child: Scaffold(
        backgroundColor: VinkiarColors.abyssBlack,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openPublishContractDialog,
          backgroundColor: VinkiarColors.vertigoGold,
          foregroundColor: Colors.black,
          icon: const Icon(Icons.add_task, size: 18),
          label: Text("+ CREAR CONTRATO P2P", style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: VinkiarColors.inkBlack,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "TABLÓN // Ѵ $_userVinks${_userEscrow > 0 ? ' [$_userEscrow en Escrow]' : ''} | XP $_userXp",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: _isFetchingProactive
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: VinkiarColors.aegisCyan))
                          : const Icon(Icons.auto_awesome, color: VinkiarColors.aegisCyan, size: 20),
                      tooltip: "Pedir Misiones Proactivas a Vinki AI",
                      onPressed: _fetchProactiveQuestsFromVinki,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.filter_list,
                        color: _selectedFilter == MissionSource.all ? Colors.white54 : VinkiarColors.aegisCyan,
                        size: 20,
                      ),
                      tooltip: "Filtrar por Origen",
                      onPressed: _openFilterSelector,
                    ),
                  ],
                ),
              ),

              // Barra de búsqueda territorial por Zona / CP y categoría de eventos
              Container(
                color: VinkiarColors.panelDark,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _zonaFilterCtrl,
                            onSubmitted: (_) => _loadTabernaData(),
                            style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 10.5),
                            decoration: InputDecoration(
                              hintText: "📍 Filtrar eventos por ciudad o CP (ej. Sevilla, 41004)...",
                              hintStyle: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 9.5),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              filled: true,
                              fillColor: VinkiarColors.abyssBlack,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: VinkiarColors.aegisCyan.withOpacity(0.3)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: VinkiarColors.aegisCyan.withOpacity(0.25)),
                              ),
                              suffixIcon: _zonaFilterCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close, size: 14, color: Colors.white54),
                                      onPressed: () {
                                        _zonaFilterCtrl.clear();
                                        _loadTabernaData();
                                      },
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.search, size: 15, color: VinkiarColors.aegisCyan),
                                      onPressed: _loadTabernaData,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildEventCategoryChip('ALL', 'TODOS'),
                          const SizedBox(width: 6),
                          _buildEventCategoryChip('SOCIAL', '⚡ SOCIAL'),
                          const SizedBox(width: 6),
                          _buildEventCategoryChip('TALLER', '🧠 TALLERES'),
                          const SizedBox(width: 6),
                          _buildEventCategoryChip('RAID', '⚔️ RAIDS'),
                          const SizedBox(width: 6),
                          _buildEventCategoryChip('TRIBU', '🛡️ TRIBUS'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                color: VinkiarColors.panelDark,
                child: TabBar(
                  controller: _activityTabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: VinkiarColors.aegisCyan,
                  labelColor: VinkiarColors.aegisCyan,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: GoogleFonts.jetBrainsMono(fontSize: 9.0, fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: "DISPONIBLES (${availableQuestsCount + availableEventsCount})"),
                    Tab(text: "EN PROGRESO (${_quests.where((q) => q['status'] == 'IN_PROGRESS' || q['status'] == 'AWAITING_VERIFICATION').length})"),
                    Tab(text: "🗺️ MAPA (${_eventosTaberna.length})"),
                    Tab(text: "HISTORIAL (${_quests.where((q) => q['status'] == 'COMPLETED').length})"),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: VinkiarColors.aegisCyan))
                    : TabBarView(
                        controller: _activityTabController,
                        children: [
                          _buildQuestListView(
                            _quests.where((q) => q['status'] == 'AVAILABLE' || q['status'] == 'LOCKED').toList(),
                            includeRemoteEvents: true,
                          ),
                          _buildQuestListView(
                            _quests.where((q) => q['status'] == 'IN_PROGRESS' || q['status'] == 'AWAITING_VERIFICATION').toList(),
                          ),
                          _buildTabernaPhygitalMapView(),
                          _buildQuestListView(
                            _quests.where((q) => q['status'] == 'COMPLETED').toList(),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildEventCategoryChip(String catKey, String label) {
    final bool selected = _selectedEventCategory == catKey;
    return InkWell(
      onTap: () {
        setState(() => _selectedEventCategory = catKey);
        _loadTabernaData();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? VinkiarColors.aegisCyan.withOpacity(0.22) : VinkiarColors.abyssBlack,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? VinkiarColors.aegisCyan : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: selected ? VinkiarColors.aegisCyan : Colors.white60,
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTabernaPhygitalMapView() {
    final LatLng initialCenter = _selectedMapEvento != null
        ? LatLng(_selectedMapEvento!.latitud, _selectedMapEvento!.longitud)
        : (_eventosTaberna.isNotEmpty
            ? LatLng(_eventosTaberna.first.latitud, _eventosTaberna.first.longitud)
            : _userLocation);

    return Stack(
      children: [
        FlutterMap(
          mapController: _tabernaMapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 14.5,
            minZoom: 5.0,
            maxZoom: 19.0,
            onTap: (_, __) {
              if (_selectedMapEvento != null || _selectedMapSantuario != null) {
                setState(() {
                  _selectedMapEvento = null;
                  _selectedMapSantuario = null;
                });
              }
            },
          ),
          children: [
            ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                -0.85, 0.0, 0.0, 0.0, 255.0,
                0.0, -0.85, 0.0, 0.0, 255.0,
                0.0, 0.0, -0.75, 0.0, 255.0,
                0.0, 0.0, 0.0, 1.0, 0.0,
              ]),
              child: TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.vinkiar.sor.vinkiar_flutter',
                maxZoom: 19,
              ),
            ),
            MarkerLayer(
              markers: [
                // Marcador de tu ubicación actual
                Marker(
                  point: _userLocation,
                  width: 34,
                  height: 34,
                  child: Container(
                    decoration: BoxDecoration(
                      color: VinkiarColors.aegisCyan,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: VinkiarColors.aegisCyan.withOpacity(0.8),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.navigation, color: Colors.black, size: 16),
                  ),
                ),

                // Marcadores de Santuarios B2B
                ..._santuariosMapa.map((s) {
                  final bool isFixed = s.tipoSantuario == 'FIJO';
                  final Color sColor = isFixed ? VinkiarColors.vertigoGold : VinkiarColors.lotusPink;
                  return Marker(
                    point: LatLng(s.latitud, s.longitud),
                    width: 36,
                    height: 36,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMapEvento = null;
                          _selectedMapSantuario = s;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF10121A),
                          shape: BoxShape.circle,
                          border: Border.all(color: sColor, width: 1.6),
                        ),
                        child: Icon(
                          isFixed ? Icons.local_cafe : Icons.storefront,
                          color: sColor,
                          size: 17,
                        ),
                      ),
                    ),
                  );
                }),

                // Marcadores de Eventos de La Taberna
                ..._eventosTaberna.map((ev) {
                  final bool isSelected = _selectedMapEvento?.id == ev.id;
                  return Marker(
                    point: LatLng(ev.latitud, ev.longitud),
                    width: isSelected ? 46 : 40,
                    height: isSelected ? 46 : 40,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedMapSantuario = null;
                          _selectedMapEvento = ev;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? neonGreen : const Color(0xFF0A1811),
                          shape: BoxShape.circle,
                          border: Border.all(color: neonGreen, width: 2.0),
                          boxShadow: [
                            BoxShadow(
                              color: neonGreen.withOpacity(isSelected ? 0.8 : 0.45),
                              blurRadius: isSelected ? 14 : 8,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.event_available,
                          color: isSelected ? Colors.black : neonGreen,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),

        // Leyenda superior + botón de centrado GPS
        Positioned(
          top: 10,
          left: 12,
          right: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: VinkiarColors.abyssBlack.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_available, color: neonGreen, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      "Eventos (${_eventosTaberna.length})",
                      style: GoogleFonts.jetBrainsMono(color: neonGreen, fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.local_cafe, color: VinkiarColors.vertigoGold, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      "Santuarios (${_santuariosMapa.length})",
                      style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              FloatingActionButton.small(
                heroTag: "taberna_map_gps",
                backgroundColor: VinkiarColors.panelDark,
                foregroundColor: VinkiarColors.aegisCyan,
                onPressed: () {
                  try {
                    _tabernaMapController.move(_userLocation, 15.0);
                  } catch (_) {}
                },
                child: const Icon(Icons.my_location, size: 18),
              ),
            ],
          ),
        ),

        // Tarjeta flotante inferior al seleccionar un Evento en el mapa
        if (_selectedMapEvento != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 72,
            child: EventoTabernaCard(
              evento: _selectedMapEvento!,
              onAceptar: () => _aceptarEventoTaberna(_selectedMapEvento!),
              onAbrirDecision: () => _abrirMesaDecisionEvento(_selectedMapEvento!),
              onVerEnMapa: () {
                final ev = _selectedMapEvento!;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RadarScreen(
                      focusEventId: ev.id,
                      focusLocation: LatLng(ev.latitud, ev.longitud),
                      initialViewMode: RadarViewMode.darkMap,
                    ),
                  ),
                );
              },
            ),
          ),

        // Tarjeta flotante inferior al seleccionar un Santuario en el mapa
        if (_selectedMapSantuario != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 72,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: VinkiarColors.abyssBlack,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VinkiarColors.vertigoGold, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "🏛️ ${_selectedMapSantuario!.alias}",
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => setState(() => _selectedMapSantuario = null),
                      ),
                    ],
                  ),
                  Text(
                    "${_selectedMapSantuario!.categoria} · ${_selectedMapSantuario!.localCiudad}",
                    style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 9.5),
                  ),
                  if (_selectedMapSantuario!.medallas.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SantuarioMedallasWrap(medallas: _selectedMapSantuario!.medallas),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VinkiarColors.vertigoGold,
                        foregroundColor: Colors.black,
                      ),
                      icon: const Icon(Icons.qr_code_scanner, size: 16),
                      label: Text(
                        "ABRIR EN RADAR Y CANJEAR GLIFO",
                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                      onPressed: () {
                        final sant = _selectedMapSantuario!;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RadarScreen(
                              focusNodeId: sant.id,
                              focusLocation: LatLng(sant.latitud, sant.longitud),
                              initialViewMode: RadarViewMode.darkMap,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
