import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/vinkiar_secure_database.dart';
import '../services/vinkiar_sync_service.dart';
import 'theme.dart';
import 'widgets/double_ssc_matrix_tab.dart';

// =========================================================================
// SECCIÓN 1: WIDGET DE FICHA DIÁDICA DEL CONTACTO
// =========================================================================

class ContactDetailSheet extends StatefulWidget {
  final Map<String, dynamic> contact;
  final VoidCallback onUpdated;

  const ContactDetailSheet({
    Key? key,
    required this.contact,
    required this.onUpdated,
  }) : super(key: key);

  @override
  State<ContactDetailSheet> createState() => _ContactDetailSheetState();
}

// =========================================================================
// SECCIÓN 2: ESTADO, CARGA Y GUARDADO EN BÓVEDA CIFRADA
// =========================================================================

class _ContactDetailSheetState extends State<ContactDetailSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _notesController = TextEditingController();

  Map<String, dynamic> _bondSettings = {};
  bool _isLoading = true;

  final List<String> _relationalTags = [
    "Vínculo Libre (Afinidad A³)",
    "Compañera de Manada / Amistad Profunda",
    "Pareja / Vínculo Primario",
    "Cómplice Somático / Kink",
    "Contacto Célula ZKA",
    "Sin Etiquetas (Indeterminado)",
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await VinkiarSecureDatabase().getContactBondSettings(widget.contact['id']);
    if (mounted) {
      setState(() {
        _bondSettings = settings;
        _notesController.text = settings['private_notes'] ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveCurrentSettings() async {
    await VinkiarSecureDatabase().saveContactBondSettings(
      contactId: widget.contact['id'],
      sscGlobalLevel: _bondSettings['ssc_level'] ?? 'GREEN',
      relationalTag: _bondSettings['relational_tag'] ?? _relationalTags.first,
      bioDescription: _bondSettings['bio_description'] ?? '',
      avatarGlifo: _bondSettings['avatar_glifo'] ?? 'shield',
      myGreenLimits: List<String>.from(_bondSettings['my_green'] ?? []),
      myYellowLimits: List<String>.from(_bondSettings['my_yellow'] ?? []),
      myRedLimits: List<String>.from(_bondSettings['my_red'] ?? []),
      incomingGreenLimits: List<String>.from(_bondSettings['incoming_green'] ?? []),
      incomingYellowLimits: List<String>.from(_bondSettings['incoming_yellow'] ?? []),
      incomingRedLimits: List<String>.from(_bondSettings['incoming_red'] ?? []),
      privateNotes: _notesController.text.trim(),
      completedQuests: _bondSettings['completed_quests'] ?? 0,
      failedQuests: _bondSettings['failed_quests'] ?? 0,
      sharedXP: _bondSettings['shared_xp'] ?? 0,
      jointVinks: _bondSettings['joint_vinks'] ?? 0,
      ifsScore: (_bondSettings['ifs_score'] ?? 0.28).toDouble(),
      icaScore: (_bondSettings['ica_score'] ?? 0.22).toDouble(),
    );
    widget.onUpdated();
  }

  // =========================================================================
  // SECCIÓN 3: ESTRUCTURA PRINCIPAL Y NAVEGACIÓN DE 4 PESTAÑAS
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final String alias = widget.contact['alias'] ?? 'Avatar Desconocido';
    final String ssc = _bondSettings['ssc_level'] ?? 'GREEN';
    final String currentTag = _bondSettings['relational_tag'] ?? _relationalTags.first;

    Color sscColor = VinkiarColors.hackingGreen;
    if (ssc == 'YELLOW') sscColor = VinkiarColors.vertigoGold;
    if (ssc == 'RED') sscColor = VinkiarColors.panicRed;
    if (ssc == 'BARBECHO') sscColor = Colors.orangeAccent;
    if (ssc == 'REVOKED') sscColor = Colors.purpleAccent;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: VinkiarColors.abyssBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: VinkiarColors.aegisCyan, width: 2)),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: VinkiarColors.aegisCyan))
          : Column(
              children: [
                // CABECERA DEL AVATAR CON METADATOS Y SEMÁFORO OPERATIVO
                Container(
                  padding: const EdgeInsets.all(16),
                  color: VinkiarColors.panelDark,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: VinkiarColors.abyssBlack,
                              border: Border.all(color: VinkiarColors.aegisCyan, width: 1.5),
                            ),
                            child: const Icon(Icons.shield, color: VinkiarColors.aegisCyan, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alias.toUpperCase(),
                                  style: GoogleFonts.jetBrainsMono(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "#${alias.replaceAll(' ', '_').toLowerCase()} · ${widget.contact['character_class'] ?? 'INICIADO'}",
                                  style: GoogleFonts.outfit(color: VinkiarColors.textDim, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: sscColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: sscColor),
                            ),
                            child: Text(
                              "SSC: $ssc",
                              style: GoogleFonts.jetBrainsMono(
                                color: sscColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TabBar(
                        controller: _tabController,
                        indicatorColor: VinkiarColors.aegisCyan,
                        labelColor: VinkiarColors.aegisCyan,
                        unselectedLabelColor: Colors.white54,
                        labelStyle: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold),
                        tabs: const [
                          Tab(text: "PERFIL 3D"),
                          Tab(text: "DOBLE SEMÁFORO"),
                          Tab(text: "MISIONES & XP"),
                          Tab(text: "BITÁCORA"),
                        ],
                      ),
                    ],
                  ),
                ),

                // CUERPO DE LAS 4 PESTAÑAS
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // PESTAÑA 1: PERFIL, ARQUETIPOS Y COMPATIBILIDAD 3D
                      _buildProfile3dTab(currentTag),

                      // PESTAÑA 2: DOBLE SEMÁFORO SSC DE REVELACIÓN GRADUAL (VISIBLE / OCULTO)
                      DoubleSscMatrixTab(
                        contactId: widget.contact['id'].toString(),
                        contactHandle: "#${alias.replaceAll(' ', '_').toLowerCase()}",
                        myHandle: VinkiarSyncService().activeUserId.isNotEmpty
                            ? VinkiarSyncService().activeUserId
                            : "LOCAL_AVATAR",
                        syncService: VinkiarSyncService(),
                        onProfileChanged: () async {
                          await _loadSettings();
                          widget.onUpdated();
                        },
                      ),

                      // PESTAÑA 3: MISIONES, ECONOMÍA Y PURGADO
                      _buildMissionsAndEconomyTab(),

                      // PESTAÑA 4: BITÁCORA SECRETA Y NOTAS PRIVADAS
                      _buildPrivateDiaryTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // =========================================================================
  // SECCIÓN 4: CONTENIDO DE PESTAÑAS (PERFIL 3D, MISIONES Y BITÁCORA)
  // =========================================================================

  Widget _buildProfile3dTab(String currentTag) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRelationalTagSelector(currentTag),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VinkiarColors.panelDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "MANIFIESTO / DESCRIPCIÓN DEL PERSONAJE:",
                style: GoogleFonts.jetBrainsMono(color: VinkiarColors.textDim, fontSize: 9),
              ),
              const SizedBox(height: 6),
              Text(
                _bondSettings['bio_description'] ?? 'Sin descripción pública.',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "TERMÓMETRO DE COMPATIBILIDAD VINKIAR (3D):",
          style: GoogleFonts.jetBrainsMono(
            color: VinkiarColors.vertigoGold,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildCompatIndicator(
                "IFS (FRICCIÓN SOMÁTICA)",
                "${((1.0 - (_bondSettings['ifs_score'] ?? 0.28)) * 100).toInt()}%",
                "Compatibilidad Piel / Blueprints",
                VinkiarColors.lotusPink,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCompatIndicator(
                "ICA (COLISIÓN AFECTIVA)",
                "${((1.0 - (_bondSettings['ica_score'] ?? 0.22)) * 100).toInt()}%",
                "Sincronía de Apego y Vínculo",
                VinkiarColors.aegisCyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildStateSelector(),
      ],
    );
  }

  Widget _buildMissionsAndEconomyTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  "MISIONES SUPERADAS",
                  "${_bondSettings['completed_quests'] ?? 3}",
                  Icons.check_circle_outline,
                  VinkiarColors.hackingGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  "MISIONES FALLADAS",
                  "${_bondSettings['failed_quests'] ?? 0}",
                  Icons.cancel_outlined,
                  VinkiarColors.panicRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  "XP DE CÉLULA",
                  "${_bondSettings['shared_xp'] ?? 320} XP",
                  Icons.military_tech,
                  VinkiarColors.vertigoGold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  "FONDO DE VINKS",
                  "Ѵ ${_bondSettings['joint_vinks'] ?? 65}",
                  Icons.toll,
                  VinkiarColors.aegisCyan,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: VinkiarColors.panicRed),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.cleaning_services, color: VinkiarColors.panicRed, size: 16),
              label: Text(
                "PURGAR MEMORIA DEL CHAT CON ESTE AVATAR",
                style: GoogleFonts.jetBrainsMono(
                  color: VinkiarColors.panicRed,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                final db = VinkiarSecureDatabase();
                await db.purgeMessagesOlderThan("GUILD_${widget.contact['id']}", const Duration(seconds: 0));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("HISTORIAL DIÁDICO PURGADO DE MEMORIA"),
                      backgroundColor: VinkiarColors.panicRed,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateDiaryTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "NOTAS LOCALES DE VÍNCULO (CIFRADAS CON ARGON2ID):",
            style: GoogleFonts.jetBrainsMono(
              color: VinkiarColors.vertigoGold,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _notesController,
              maxLines: 12,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 12.5),
              decoration: InputDecoration(
                filled: true,
                fillColor: VinkiarColors.panelDark,
                hintText: "Escribe reflexiones sobre este vínculo, acuerdos o sensaciones...",
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: VinkiarColors.aegisCyan, foregroundColor: Colors.black),
              icon: const Icon(Icons.save, size: 16),
              label: Text(
                "SELLAR NOTAS EN BÓVEDA",
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              onPressed: () async {
                await _saveCurrentSettings();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("NOTAS SELLADAS EN TU BÓVEDA"),
                      backgroundColor: VinkiarColors.hackingGreen,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECCIÓN 5: WIDGETS AUXILIARES DE ETIQUETAS, ESTADO Y MÉTRICAS
  // =========================================================================

  Widget _buildRelationalTagSelector(String currentTag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: VinkiarColors.panelDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "ETIQUETA (AR):",
            style: GoogleFonts.jetBrainsMono(
              color: VinkiarColors.vertigoGold,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _relationalTags.contains(currentTag) ? currentTag : _relationalTags.first,
              dropdownColor: VinkiarColors.panelDark,
              style: GoogleFonts.jetBrainsMono(
                color: VinkiarColors.aegisCyan,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              items: _relationalTags.map((tag) => DropdownMenuItem(value: tag, child: Text(tag))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _bondSettings['relational_tag'] = val);
                  _saveCurrentSettings();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VinkiarColors.panelDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "ESTADO GENERAL:",
            style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          DropdownButton<String>(
            value: _bondSettings['ssc_level'] ?? 'GREEN',
            dropdownColor: VinkiarColors.panelDark,
            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
            items: const [
              DropdownMenuItem(
                value: "GREEN",
                child: Text("🟢 ACCESO TOTAL", style: TextStyle(color: VinkiarColors.hackingGreen)),
              ),
              DropdownMenuItem(
                value: "YELLOW",
                child: Text("🟡 CAUTELA", style: TextStyle(color: VinkiarColors.vertigoGold)),
              ),
              DropdownMenuItem(
                value: "RED",
                child: Text("🔴 PAUSA DE CHAT", style: TextStyle(color: VinkiarColors.panicRed)),
              ),
              DropdownMenuItem(
                value: "BARBECHO",
                child: Text("🟠 EN BARBECHO", style: TextStyle(color: Colors.orangeAccent)),
              ),
              DropdownMenuItem(
                value: "REVOKED",
                child: Text("🟣 EXILIAR", style: TextStyle(color: Colors.purpleAccent)),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _bondSettings['ssc_level'] = val);
                _saveCurrentSettings();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompatIndicator(String title, String percent, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VinkiarColors.panelDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(percent, style: GoogleFonts.jetBrainsMono(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.outfit(color: VinkiarColors.textDim, fontSize: 9.5)),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: VinkiarColors.panelDark, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 9))),
            ],
          ),
          const SizedBox(height: 6),
          Text(val, style: GoogleFonts.jetBrainsMono(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
