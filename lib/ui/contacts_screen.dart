import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'theme.dart';
import '../services/vinkiar_secure_database.dart';
import '../services/vinkiar_sync_service.dart';
import 'ritual_cristalizacion_screen.dart';
import 'chat_qa_screen.dart';
import 'contact_detail_sheet.dart';
import 'widgets/tribu_bolsa_comun_sheet.dart';
import 'widgets/tribu_command_card.dart';
import 'widgets/tribu_edit_sheet.dart';
import 'widgets/decision_engine_sheet.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _guilds = [];
  List<Map<String, dynamic>> _activityFeed = [];
  bool _isLoading = true;
  String _myHandle = '#Pionero';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    VinkiarSecureDatabase.contactChangeNotifier.addListener(_loadData);
    _loadData();
  }

  @override
  void dispose() {
    VinkiarSecureDatabase.contactChangeNotifier.removeListener(_loadData);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final db = VinkiarSecureDatabase();

    var contactsList = await db.getContacts();
    if (contactsList.isEmpty) {
      await _seedDefaultContacts();
      contactsList = await db.getContacts();
    }

    final avatar = await db.getAvatarSheet("LOCAL_USER");
    final avStats = avatar?['stats'] as Map<String, dynamic>? ?? {};
    final rawAlias = (avatar?['alias']?.toString().isNotEmpty == true)
        ? avatar!['alias'].toString()
        : (avStats['alias']?.toString() ?? 'Pionero');
    final formattedHandle = rawAlias.startsWith('#') ? rawAlias : '#$rawAlias';

    final guildsList = await db.getGuilds();
    var feedList = await db.getActivityFeed();

    if (feedList.isEmpty) {
      await db.logActivityEvent(
        title: "Bóveda ZKA Sincronizada",
        description: "El avatar inició sesión bajo criptografía de conocimiento cero.",
        type: "SECURITY",
      );
      feedList = await db.getActivityFeed();
    }

    if (mounted) {
      setState(() {
        _myHandle = formattedHandle;
        _contacts = contactsList;
        _guilds = guildsList;
        _activityFeed = feedList;
        _isLoading = false;
      });
    }
  }

  Future<void> _seedDefaultContacts() async {
    final db = VinkiarSecureDatabase();
    final now = DateTime.now().toIso8601String();

    final sampleContacts = [
      {
        "id": "USR_PAR_01",
        "alias": "AuraSombra_99",
        "character_class": "EL BARDO DE DATOS",
        "relationship_type": "PARTNER",
        "ssc_level": "GREEN",
        "is_active": 1,
        "reputation_score": 0.98,
        "last_interaction": now,
        "created_at": now,
      },
      {
        "id": "USR_FRN_02",
        "alias": "Vektor_Faraday",
        "character_class": "EL CENTINELA DE FARADAY",
        "relationship_type": "FRIEND",
        "ssc_level": "YELLOW",
        "is_active": 1,
        "reputation_score": 0.85,
        "last_interaction": now,
        "created_at": now,
      },
    ];

    for (var c in sampleContacts) {
      await db.saveContact(c);
    }
  }


  void _showCrystallizeNewContactModal() {
    final handleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VinkiarColors.abyssBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: VinkiarColors.hackingGreen, width: 1.5),
        ),
        title: Text(
          "CRISTALIZAR NUEVO VÍNCULO EN CÉLULA",
          style: GoogleFonts.jetBrainsMono(
            color: VinkiarColors.hackingGreen,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Introduce el #Handle del avatar con el que has pactado un encuentro o vínculo para iniciar el Ritual de Cristalización y sellar vuestro Doble Semáforo SSC.",
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11.5, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: handleCtrl,
              autofocus: true,
              style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: "Ej. #Alicia o Alicia",
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                filled: true,
                fillColor: VinkiarColors.panelDark,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCELAR", style: GoogleFonts.jetBrainsMono(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: VinkiarColors.hackingGreen,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.fingerprint, size: 16),
            label: Text("INICIAR RITUAL", style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10.5)),
            onPressed: () async {
              final raw = handleCtrl.text.replaceAll('#', '').trim();
              if (raw.isEmpty) return;
              Navigator.pop(ctx);
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => RitualCristalizacionScreen(
                    targetHandle: "#$raw",
                    targetAlias: raw,
                    provisionalGuildId: VinkiarSyncService.buildCanonicalCellGuildId(_myHandle, raw),
                  ),
                ),
              );
              if (ok == true && mounted) {
                await _loadData();
              }
            },
          ),
        ],
      ),
    );
  }

  String _sanitizeGuildCode(String input) {
    String clean = input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '-');
    clean = clean.replaceAll(RegExp(r'[^A-Z0-9_\-]'), '');
    return clean;
  }

  // =========================================================================
  // MODAL REDISEÑADO: FUNDAR TRIBU CON ESCUDO EN VIVO Y SELECTOR SSC VISUAL
  // =========================================================================
  void _showCreateGuildModal() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final codeController = TextEditingController();
    String sscBaseline = "GREEN";
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.aegisCyan, width: 1.5),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final previewName = nameController.text.trim().isEmpty
              ? "Nueva Tribu ZKA"
              : nameController.text.trim();
          final previewSeed = _sanitizeGuildCode(codeController.text).isNotEmpty
              ? _sanitizeGuildCode(codeController.text)
              : previewName;
          final Color sscAccent = sscBaseline == 'GREEN'
              ? VinkiarColors.hackingGreen
              : (sscBaseline == 'YELLOW' ? VinkiarColors.vertigoGold : VinkiarColors.panicRed);

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                          const Icon(Icons.shield_outlined, color: VinkiarColors.aegisCyan, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            "FUNDAR TRIBU // GREMIO ZKA",
                            style: GoogleFonts.jetBrainsMono(
                              color: VinkiarColors.aegisCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 14),

                  // Vista Previa del Estandarte Heráldico en vivo
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VinkiarColors.panelDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sscAccent.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 46,
                          height: 46,
                          child: CustomPaint(
                            painter: TribuCrestPainter(
                              seed: previewSeed,
                              primaryColor: VinkiarColors.aegisCyan,
                              accentColor: sscAccent,
                            ),
                            child: Center(
                              child: Text(
                                previewName.substring(0, 1).toUpperCase(),
                                style: GoogleFonts.jetBrainsMono(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "ESTANDARTE EN VIVO",
                                style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 8),
                              ),
                              Text(
                                previewName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Fundador: $_myHandle · Bolsa Inicial: 0 Ѵ",
                                style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 8.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: nameController,
                    onChanged: (_) => setModalState(() {}),
                    style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "Nombre de la Tribu (Ej. Resistencia del Loto)",
                      hintStyle: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 11),
                      filled: true,
                      fillColor: VinkiarColors.panelDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeController,
                    onChanged: (_) => setModalState(() {}),
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "CÓDIGO DE ACCESO ZK (OPCIONAL)",
                      labelStyle: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 9.5),
                      hintText: "Ej. LOTO-NEGRO (o automático)",
                      hintStyle: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 10),
                      filled: true,
                      fillColor: VinkiarColors.panelDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: "Manifiesto o pacto de convivencia de la Tribu...",
                      hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
                      filled: true,
                      fillColor: VinkiarColors.panelDark,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    "UMBRAL SSC DE ENTRADA:",
                    style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildSscPillSelector(
                        label: "VERDE\nAbierto",
                        value: "GREEN",
                        current: sscBaseline,
                        color: VinkiarColors.hackingGreen,
                        onSelect: (v) => setModalState(() => sscBaseline = v),
                      ),
                      const SizedBox(width: 6),
                      _buildSscPillSelector(
                        label: "ÁMBAR\nFiltro",
                        value: "YELLOW",
                        current: sscBaseline,
                        color: VinkiarColors.vertigoGold,
                        onSelect: (v) => setModalState(() => sscBaseline = v),
                      ),
                      const SizedBox(width: 6),
                      _buildSscPillSelector(
                        label: "ROJO\nPrivado",
                        value: "RED",
                        current: sscBaseline,
                        color: VinkiarColors.panicRed,
                        onSelect: (v) => setModalState(() => sscBaseline = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VinkiarColors.aegisCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.add_moderator, size: 18),
                      label: Text(
                        isSaving ? "FEDERANDO CANAL EN RED..." : "FUNDAR GREMIO Y ABRIR TÚNEL",
                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              final name = nameController.text.trim();
                              if (name.isEmpty) return;

                              setModalState(() => isSaving = true);

                              String customCode = _sanitizeGuildCode(codeController.text);
                              final String guildId = customCode.isNotEmpty
                                  ? customCode
                                  : "ZK-TRIBU-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";

                              try {
                                await http.post(
                                  Uri.parse('${ApiConfig.baseUrl}/api/v1/guild/create'),
                                  headers: {'Content-Type': 'application/json'},
                                  body: jsonEncode({
                                    'guild_id': guildId,
                                    'name': name,
                                    'description': descController.text.trim(),
                                    'ssc_baseline': sscBaseline,
                                    'creator_id': _myHandle,
                                  }),
                                ).timeout(const Duration(seconds: 8));
                              } catch (_) {}

                              final db = VinkiarSecureDatabase();
                              await db.saveGuild({
                                "guild_id": guildId,
                                "name": name,
                                "description": descController.text.trim(),
                                "ssc_baseline": sscBaseline,
                                "common_pool_vinks": 0,
                                "member_count": 1,
                                "is_creator": true,
                              });

                              await db.logActivityEvent(
                                title: "Gremio Fundado: $name",
                                description: "Código de acceso ZK: $guildId",
                                type: "GUILD_JOIN",
                              );

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                _loadData();
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSscPillSelector({
    required String label,
    required String value,
    required String current,
    required Color color,
    required ValueChanged<String> onSelect,
  }) {
    final bool selected = value == current;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.2) : VinkiarColors.panelDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? color : Colors.white12,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
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

  // =========================================================================
  // MODAL REDISEÑADO: GOBERNANZA SSC DE MIEMBROS DE TRIBU
  // =========================================================================
  void _showManageGuildMembersModal(Map<String, dynamic> guild) async {
    final db = VinkiarSecureDatabase();
    final String guildId = guild['guild_id'];
    List<Map<String, dynamic>> members = await db.getGuildMembers(guildId);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.vertigoGold, width: 1.8),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final int activeCount = members.where((m) => (m['status'] ?? 'ACTIVE') == 'ACTIVE').length;
          final int barbechoCount = members.where((m) => m['status'] == 'BARBECHO').length;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.84,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.gavel_outlined, color: VinkiarColors.vertigoGold, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "CONSEJO DE GOBERNANZA // ${guild['name']}".toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.jetBrainsMono(
                                color: VinkiarColors.vertigoGold,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Regulación interna restaurativa: aplica Barbecho temporal para enfriar fricciones o revoca el acceso ante vulneración de límites SSC.",
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, height: 1.35),
                ),
                const SizedBox(height: 12),

                // Barra de resumen de estado de miembros
                Row(
                  children: [
                    _buildGovCounterBadge("ACTIVOS", "$activeCount", VinkiarColors.hackingGreen),
                    const SizedBox(width: 8),
                    _buildGovCounterBadge("BARBECHO", "$barbechoCount", VinkiarColors.vertigoGold),
                    const SizedBox(width: 8),
                    _buildGovCounterBadge("TOTAL", "${members.length}", VinkiarColors.aegisCyan),
                  ],
                ),
                const Divider(color: Colors.white12, height: 20),

                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final m = members[index];
                      final String status = m['status'] ?? 'ACTIVE';
                      final String alias = m['alias'] ?? 'Miembro';

                      Color statusColor = VinkiarColors.hackingGreen;
                      String statusLabel = "ACTIVO · CON VOTO";
                      if (status == 'BARBECHO') {
                        statusColor = VinkiarColors.vertigoGold;
                        statusLabel = "EN BARBECHO · PAUSA";
                      } else if (status == 'EXPELLED') {
                        statusColor = VinkiarColors.panicRed;
                        statusLabel = "EXPULSADO · REVOCADO";
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VinkiarColors.panelDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: statusColor.withOpacity(0.5), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: VinkiarColors.abyssBlack,
                                    border: Border.all(color: statusColor, width: 1.5),
                                  ),
                                  child: Center(
                                    child: Text(
                                      alias.replaceAll('#', '').substring(0, 1).toUpperCase(),
                                      style: GoogleFonts.jetBrainsMono(
                                        color: statusColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        alias,
                                        style: GoogleFonts.jetBrainsMono(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        m['archetype'] ?? 'INICIADO ZKA',
                                        style: GoogleFonts.outfit(color: VinkiarColors.textDim, fontSize: 10.5),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: statusColor, width: 0.9),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: GoogleFonts.jetBrainsMono(
                                      color: statusColor,
                                      fontSize: 8.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (status == 'BARBECHO')
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: VinkiarColors.hackingGreen),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                    ),
                                    icon: const Icon(Icons.restore, size: 13, color: VinkiarColors.hackingGreen),
                                    label: Text(
                                      "REINCORPORAR",
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.0,
                                        color: VinkiarColors.hackingGreen,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: () async {
                                      await db.updateGuildMemberStatus(guildId: guildId, memberId: m['id'], newStatus: 'ACTIVE');
                                      await db.logActivityEvent(
                                        title: "Miembro Reincorporado",
                                        description: "$alias salió de barbecho en ${guild['name']}.",
                                        type: "GUILD_JOIN",
                                      );
                                      members = await db.getGuildMembers(guildId);
                                      setModalState(() {});
                                      _loadData();
                                    },
                                  )
                                else if (status == 'ACTIVE')
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: VinkiarColors.vertigoGold),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                    ),
                                    icon: const Icon(Icons.pause_circle_outline, size: 13, color: VinkiarColors.vertigoGold),
                                    label: Text(
                                      "BARBECHO (PAUSA)",
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.0,
                                        color: VinkiarColors.vertigoGold,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: () async {
                                      await db.updateGuildMemberStatus(guildId: guildId, memberId: m['id'], newStatus: 'BARBECHO');
                                      await db.logActivityEvent(
                                        title: "Pausa en Barbecho SSC",
                                        description: "$alias en cuarentena temporal en ${guild['name']}.",
                                        type: "SSC_CHANGE",
                                      );
                                      members = await db.getGuildMembers(guildId);
                                      setModalState(() {});
                                      _loadData();
                                    },
                                  ),
                                const SizedBox(width: 8),
                                if (status != 'EXPELLED')
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: VinkiarColors.panicRed),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      minimumSize: Size.zero,
                                    ),
                                    icon: const Icon(Icons.person_remove, size: 13, color: VinkiarColors.panicRed),
                                    label: Text(
                                      "EXPULSAR",
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.0,
                                        color: VinkiarColors.panicRed,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: () async {
                                      await db.updateGuildMemberStatus(guildId: guildId, memberId: m['id'], newStatus: 'EXPELLED');
                                      await db.logActivityEvent(
                                        title: "Miembro Expulsado",
                                        description: "$alias fue revocado de ${guild['name']}.",
                                        type: "SSC_CHANGE",
                                      );
                                      members = await db.getGuildMembers(guildId);
                                      setModalState(() {});
                                      _loadData();
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGovCounterBadge(String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: VinkiarColors.panelDark,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Text(
              val,
              style: GoogleFonts.jetBrainsMono(color: color, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 7.5),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditGuildCodeModal(Map<String, dynamic> guild) {
    final codeController = TextEditingController(text: guild['guild_id']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VinkiarColors.abyssBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: VinkiarColors.vertigoGold, width: 1.5),
        ),
        title: Text(
          "PERSONALIZAR CÓDIGO DE ACCESO",
          style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Tribu: ${guild['name']}",
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "NUEVO CÓDIGO / ALIAS",
                labelStyle: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 10),
                hintText: "Ej. LOTO-NEGRO",
                filled: true,
                fillColor: VinkiarColors.panelDark,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCELAR", style: GoogleFonts.jetBrainsMono(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: VinkiarColors.vertigoGold, foregroundColor: Colors.black),
            onPressed: () async {
              final newCode = _sanitizeGuildCode(codeController.text);
              if (newCode.isEmpty || newCode == guild['guild_id']) {
                Navigator.pop(ctx);
                return;
              }

              final oldId = guild['guild_id'];
              final db = VinkiarSecureDatabase();

              try {
                await http.post(
                  Uri.parse('${ApiConfig.baseUrl}/api/v1/guild/create'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'guild_id': newCode,
                    'name': guild['name'],
                    'description': guild['description'] ?? '',
                    'ssc_baseline': guild['ssc_baseline'] ?? 'GREEN',
                    'creator_id': _myHandle,
                  }),
                ).timeout(const Duration(seconds: 8));
              } catch (_) {}

              final updatedGuild = Map<String, dynamic>.from(guild);
              updatedGuild['guild_id'] = newCode;

              final allGuilds = await db.getGuilds();
              allGuilds.removeWhere((g) => g['guild_id'] == oldId);
              allGuilds.insert(0, updatedGuild);

              await db.saveGuild(updatedGuild);

              if (mounted) {
                Navigator.pop(ctx);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: VinkiarColors.aegisCyan,
                    content: Text("CÓDIGO ACTUALIZADO A: $newCode", style: GoogleFonts.jetBrainsMono(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                );
              }
            },
            child: Text("GUARDAR", style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _showJoinGuildModal() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VinkiarColors.abyssBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: VinkiarColors.vertigoGold, width: 1.5),
        ),
        title: Text(
          "UNIRSE A TRIBU POR CÓDIGO",
          style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: codeController,
          textCapitalization: TextCapitalization.characters,
          style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            hintText: "Ej. LOTO-NEGRO o ZK-TRIBU-...",
            hintStyle: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 11),
            filled: true,
            fillColor: VinkiarColors.panelDark,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCELAR", style: GoogleFonts.jetBrainsMono(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: VinkiarColors.vertigoGold, foregroundColor: Colors.black),
            onPressed: () async {
              final code = _sanitizeGuildCode(codeController.text);
              if (code.isEmpty) return;

              String remoteName = "Tribu $code";
              String remoteDesc = "Canal comunitario sincronizado.";
              String remoteSsc = "GREEN";
              int remoteSaldo = 0;
              int remoteMembers = 2;

              try {
                final res = await http.post(
                  Uri.parse('${ApiConfig.baseUrl}/api/v1/tribus/${Uri.encodeComponent(code)}/join'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'member_handle': _myHandle}),
                ).timeout(const Duration(seconds: 8));

                if (res.statusCode == 200) {
                  final body = jsonDecode(res.body) as Map<String, dynamic>;
                  final tribu = body['tribu'] as Map<String, dynamic>? ?? {};
                  if (tribu['nombre_tribu'] != null) remoteName = tribu['nombre_tribu'].toString();
                  if (tribu['descripcion'] != null && tribu['descripcion'].toString().isNotEmpty) {
                    remoteDesc = tribu['descripcion'].toString();
                  }
                  if (tribu['ssc_baseline'] != null) remoteSsc = tribu['ssc_baseline'].toString();
                  remoteSaldo = (tribu['saldo_vinks'] as num?)?.toInt() ?? 0;
                  remoteMembers = (tribu['total_members'] as num?)?.toInt() ?? 2;
                }
              } catch (_) {}

              final db = VinkiarSecureDatabase();
              await db.saveGuild({
                "guild_id": code,
                "name": remoteName,
                "description": remoteDesc,
                "ssc_baseline": remoteSsc,
                "common_pool_vinks": remoteSaldo,
                "member_count": remoteMembers,
                "is_creator": false,
              });

              await db.logActivityEvent(
                title: "Unido a Tribu: $code",
                description: "Canal P2P sincronizado en la Bóveda.",
                type: "GUILD_JOIN",
              );

              if (mounted) {
                Navigator.pop(ctx);
                _loadData();
              }
            },
            child: Text("UNIRSE", style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: VinkiarColors.aegisCyan,
        duration: const Duration(seconds: 2),
        content: Text(
          "CÓDIGO COPIADO AL PORTAPAPELES: $text",
          style: GoogleFonts.jetBrainsMono(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
        ),
      ),
    );
  }

  void _changeSSCLevel(String contactId, String currentLevel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.aegisCyan, width: 1.5),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "CALIBRAR ACCESO DE CONSENTIMIENTO (SSC)",
              style: GoogleFonts.jetBrainsMono(
                color: VinkiarColors.aegisCyan,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            _buildSSCOption(contactId, "NIVEL VERDE (ACCESO TOTAL / LIBRE)", "GREEN", VinkiarColors.hackingGreen),
            _buildSSCOption(contactId, "NIVEL AMARILLO (ACCESO RESTRINGIDO / CAUTELA)", "YELLOW", VinkiarColors.vertigoGold),
            _buildSSCOption(contactId, "NIVEL ROJO (PAUSA DE COMUNICACIÓN)", "RED", VinkiarColors.panicRed),
            const Divider(color: Colors.white24, height: 20),
            _buildSSCOption(contactId, "REVOCAR CONSENTIMIENTO Y EXILIAR", "REVOKED", Colors.purpleAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildSSCOption(String contactId, String label, String sscKey, Color color) {
    return ListTile(
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(
        label,
        style: GoogleFonts.jetBrainsMono(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      onTap: () async {
        await VinkiarSecureDatabase().updateContactSSC(contactId, sscKey);
        await VinkiarSecureDatabase().logActivityEvent(
          title: "Límite SSC Modificado",
          description: "Contacto $contactId pasó a nivel $sscKey.",
          type: "SSC_CHANGE",
        );
        if (mounted) {
          Navigator.pop(context);
          await _loadData();
        }
      },
    );
  }

  Color _getSSCColor(String? level) {
    switch (level) {
      case 'GREEN':
        return VinkiarColors.hackingGreen;
      case 'YELLOW':
        return VinkiarColors.vertigoGold;
      case 'RED':
        return VinkiarColors.panicRed;
      case 'REVOKED':
      default:
        return Colors.purpleAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalTribeVinks = _guilds.fold<int>(
      0,
      (sum, g) => sum + ((g['common_pool_vinks'] as num?)?.toInt() ?? 0),
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(minScaleFactor: 0.8, maxScaleFactor: 1.25),
      ),
      child: Scaffold(
        backgroundColor: VinkiarColors.abyssBlack,
        appBar: AppBar(
          backgroundColor: VinkiarColors.panelDark,
          title: Text(
            "CÉLULA RELACIONAL // COMUNIDAD",
            style: GoogleFonts.jetBrainsMono(
              color: VinkiarColors.aegisCyan,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: VinkiarColors.aegisCyan,
            labelColor: VinkiarColors.aegisCyan,
            unselectedLabelColor: Colors.white54,
            labelStyle: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "VÍNCULOS (1 a 1)"),
              Tab(text: "TRIBUS / GREMIOS"),
              Tab(text: "FEED DE ACTIVIDAD"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: VinkiarColors.aegisCyan))
            : TabBarView(
                controller: _tabController,
                children: [
                  // ---------------------------------------------------------
                  // PESTAÑA 1: CONTACTOS 1 A 1
                  // ---------------------------------------------------------
                  ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 84),
                    itemCount: _contacts.length + 1,
                    itemBuilder: (context, idx) {
                      if (idx == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: VinkiarColors.hackingGreen,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.person_add_alt_1, size: 18),
                              label: Text(
                                "CRISTALIZAR VÍNCULO / AÑADIR CONTACTO",
                                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10.5),
                              ),
                              onPressed: _showCrystallizeNewContactModal,
                            ),
                          ),
                        );
                      }
                      final contact = _contacts[idx - 1];
                      final String ssc = contact['ssc_level'] ?? 'GREEN';
                      final Color sscColor = _getSSCColor(ssc);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: VinkiarColors.panelDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sscColor.withOpacity(0.6), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      contact['relationship_type'] == 'PARTNER'
                                          ? Icons.favorite
                                          : Icons.person_pin,
                                      color: contact['relationship_type'] == 'PARTNER'
                                          ? Colors.pinkAccent
                                          : VinkiarColors.aegisCyan,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      contact['relationship_type'] == 'PARTNER'
                                          ? "❤️ PAREJA / VÍNCULO"
                                          : "👤 CONTACTO ZKA",
                                      style: GoogleFonts.jetBrainsMono(
                                        color: Colors.white70,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                InkWell(
                                  onTap: () => _changeSSCLevel(contact['id'], ssc),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: sscColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: sscColor),
                                    ),
                                    child: Text(
                                      "SSC: $ssc",
                                      style: GoogleFonts.jetBrainsMono(
                                        color: sscColor,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              contact['alias'] ?? 'Avatar Desconocido',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              contact['character_class'] ?? 'INICIADO ZKA',
                              style: GoogleFonts.jetBrainsMono(
                                color: VinkiarColors.textDim,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.tune, size: 14, color: VinkiarColors.vertigoGold),
                                  label: Text("FICHA DE VÍNCULO", style: GoogleFonts.jetBrainsMono(fontSize: 10, color: VinkiarColors.vertigoGold)),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => ContactDetailSheet(
                                        contact: contact,
                                        onUpdated: () => _loadData(),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.chat_bubble_outline, size: 14, color: VinkiarColors.aegisCyan),
                                  label: Text("CHAT ZKA", style: GoogleFonts.jetBrainsMono(fontSize: 10, color: VinkiarColors.aegisCyan)),
                                  onPressed: ssc == 'RED' || ssc == 'REVOKED'
                                      ? null
                                      : () {
                                          final aliasStr = (contact['alias'] ?? 'Contacto ZKA').toString();
                                          final canonicalCellId = VinkiarSyncService.buildCanonicalCellGuildId(_myHandle, aliasStr);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ChatQAScreen(
                                                initialGuildId: canonicalCellId,
                                                initialTargetName: aliasStr,
                                              ),
                                            ),
                                          );
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // ---------------------------------------------------------
                  // PESTAÑA 2: TRIBUS Y GREMIOS (PANEL DE COMANDO GAMIFICADO)
                  // ---------------------------------------------------------
                  ListView(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 84),
                    children: [
                      // HUD Global de Tribus & Tesorería Agregada
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF151926), Color(0xFF0C0E14)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.55)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "RED DE TRIBUS FEDERADAS",
                                      style: GoogleFonts.jetBrainsMono(
                                        color: VinkiarColors.aegisCyan,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${_guilds.length} clanes activos · $totalTribeVinks Ѵ en bolsas",
                                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11.5),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: VinkiarColors.vertigoGold.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    "$totalTribeVinks Ѵ",
                                    style: GoogleFonts.jetBrainsMono(
                                      color: VinkiarColors.vertigoGold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: VinkiarColors.aegisCyan,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                    ),
                                    icon: const Icon(Icons.add_moderator, size: 16),
                                    label: Text(
                                      "FUNDAR TRIBU",
                                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: _showCreateGuildModal,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: VinkiarColors.vertigoGold),
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                    ),
                                    icon: const Icon(Icons.vpn_key_outlined, size: 15, color: VinkiarColors.vertigoGold),
                                    label: Text(
                                      "UNIRSE (CÓDIGO)",
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: VinkiarColors.vertigoGold,
                                      ),
                                    ),
                                    onPressed: _showJoinGuildModal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      if (_guilds.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: VinkiarColors.panelDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.shield_moon_outlined, color: VinkiarColors.vertigoGold, size: 36),
                              const SizedBox(height: 10),
                              Text(
                                "SIN TRIBUS EN TU BÓVEDA",
                                style: GoogleFonts.jetBrainsMono(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Funda tu propio clan con bolsa común y gobernanza por quórum, o introduce la llave ZK de una tribu existente.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11.5, height: 1.4),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._guilds.map((guild) {
                          final String guildId = guild['guild_id'] ?? '';
                          final bool isCreator = guild['is_creator'] == true;
                          final List<String> admins = (guild['admins'] as List? ?? []).map((e) => e.toString().toLowerCase()).toList();
                          final bool canEditTribu = isCreator || admins.contains(_myHandle.toLowerCase());

                          return TribuCommandCard(
                            guild: guild,
                            myHandle: _myHandle,
                            onCopyCode: () => _copyToClipboard(guildId),
                            onEditCode: isCreator ? () => _showEditGuildCodeModal(guild) : null,
                            onEditTribu: canEditTribu
                                ? () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => TribuEditSheet(
                                        guild: guild,
                                        myHandle: _myHandle,
                                        onSaved: () => _loadData(),
                                      ),
                                    ).then((_) => _loadData());
                                  }
                                : null,
                            onOpenBolsa: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => TribuBolsaComunSheet(
                                  guildId: guildId,
                                  guildName: guild['name'] ?? 'Tribu ZKA',
                                  myHandle: _myHandle,
                                  isCreator: canEditTribu,
                                ),
                              ).then((_) => _loadData());
                            },
                            onOpenDecisions: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => DecisionEngineSheet(
                                  guildId: guildId,
                                  channelName: guild['name'] ?? 'Tribu ZKA',
                                  myHandle: _myHandle,
                                  onPublishToChat: (packet) async {
                                    await VinkiarSecureDatabase().saveLocalMessage(
                                      guildId: guildId,
                                      senderId: 'LOCAL_AVATAR',
                                      decryptedContent: packet,
                                      timestamp: DateTime.now().toIso8601String(),
                                    );
                                    if (mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatQAScreen(
                                            initialGuildId: guildId,
                                            initialTargetName: guild['name'] ?? 'Tribu ZKA',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ).then((_) => _loadData());
                            },
                            onOpenGovernance: () => _showManageGuildMembersModal(guild),
                            onOpenChat: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatQAScreen(
                                    initialGuildId: guildId,
                                    initialTargetName: guild['name'] ?? 'Tribu ZKA',
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                    ],
                  ),

                  // ---------------------------------------------------------
                  // PESTAÑA 3: FEED DE ACTIVIDAD P2P
                  // ---------------------------------------------------------
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _activityFeed.length,
                    itemBuilder: (context, index) {
                      final event = _activityFeed[index];
                      final String type = event['type'] ?? 'INFO';
                      final String time = event['timestamp']?.length > 16
                          ? event['timestamp'].substring(11, 16)
                          : '';

                      IconData iconData = Icons.notifications_none;
                      Color iconColor = VinkiarColors.aegisCyan;

                      if (type == 'GUILD_JOIN') {
                        iconData = Icons.groups;
                        iconColor = VinkiarColors.vertigoGold;
                      } else if (type == 'SSC_CHANGE') {
                        iconData = Icons.traffic;
                        iconColor = VinkiarColors.panicRed;
                      } else if (type == 'LEVEL_UP') {
                        iconData = Icons.military_tech;
                        iconColor = VinkiarColors.hackingGreen;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VinkiarColors.panelDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(iconData, color: iconColor, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        event['title'] ?? 'Evento',
                                        style: GoogleFonts.jetBrainsMono(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(time, style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 8.5)),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    event['description'] ?? '',
                                    style: GoogleFonts.outfit(color: VinkiarColors.textDim, fontSize: 10.5),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
        floatingActionButton: _tabController.index == 0
            ? FloatingActionButton.extended(
                heroTag: "crystallize_contact_fab",
                backgroundColor: VinkiarColors.hackingGreen,
                foregroundColor: Colors.black,
                icon: const Icon(Icons.fingerprint, size: 18),
                label: Text("CRISTALIZAR VÍNCULO", style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10)),
                onPressed: _showCrystallizeNewContactModal,
              )
            : (_tabController.index == 1
                ? FloatingActionButton.extended(
                    heroTag: "create_guild_fab",
                    backgroundColor: VinkiarColors.aegisCyan,
                    foregroundColor: Colors.black,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text("FUNDAR TRIBU", style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10)),
                    onPressed: _showCreateGuildModal,
                  )
                : null),
      ),
    );
  }
}