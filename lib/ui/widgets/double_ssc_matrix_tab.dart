import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/vinkiar_secure_database.dart';
import '../../services/vinkiar_ssc_manager.dart';
import '../../services/vinkiar_sync_service.dart';

// =========================================================================
// SECCIÓN 1: WIDGET PRINCIPAL Y PARÁMETROS DE ENTRADA
// =========================================================================

class DoubleSscMatrixTab extends StatefulWidget {
  final String contactId;
  final String contactHandle;
  final String myHandle;
  final VinkiarSyncService? syncService;
  final VoidCallback? onProfileChanged;

  const DoubleSscMatrixTab({
    super.key,
    required this.contactId,
    required this.contactHandle,
    required this.myHandle,
    this.syncService,
    this.onProfileChanged,
  });

  @override
  State<DoubleSscMatrixTab> createState() => _DoubleSscMatrixTabState();
}

// =========================================================================
// SECCIÓN 2: ESTADO LOCAL, CARGA Y PERSISTENCIA CIFRADA
// =========================================================================

class _DoubleSscMatrixTabState extends State<DoubleSscMatrixTab> {
  final VinkiarSecureDatabase _db = VinkiarSecureDatabase();
  final TextEditingController _newLimitController = TextEditingController();

  DyadicSscProfile? _profile;
  SscLimitTier _selectedNewTier = SscLimitTier.green;
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    VinkiarSecureDatabase.contactChangeNotifier.addListener(_onExternalVaultUpdate);
  }

  @override
  void dispose() {
    VinkiarSecureDatabase.contactChangeNotifier.removeListener(_onExternalVaultUpdate);
    _newLimitController.dispose();
    super.dispose();
  }

  void _onExternalVaultUpdate() {
    if (mounted) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    final loaded = await _db.getDyadicSscProfile(widget.contactId);
    if (!mounted) return;
    setState(() {
      _profile = loaded;
      _isLoading = false;
    });
  }

  Future<void> _persistProfile(DyadicSscProfile updated) async {
    await _db.saveDyadicSscProfile(updated);
    if (!mounted) return;
    setState(() => _profile = updated);
    widget.onProfileChanged?.call();
  }

  // =========================================================================
  // SECCIÓN 3: ACCIONES DE SINTONÍA, VISIBILIDAD Y SINCRONIZACIÓN ZKA
  // =========================================================================

  Future<void> _changeOperationalState(SscOperationalState newState) async {
    if (_profile == null) return;
    await _persistProfile(_profile!.copyWith(
      operationalState: newState,
      updatedAt: DateTime.now(),
    ));
  }

  /// Selecciona explícitamente el nivel de revelación (0, 1 o 2) y marca las casillas de esa capa
  Future<void> _selectSynergyLevel(int targetLevel) async {
    if (_profile == null) return;
    final updated = VinkiarSSCManager.applySynergyLevelPreset(_profile!, targetLevel);
    await _persistProfile(updated);
  }

  /// Conmuta individualmente la casilla Visible / Oculto de un elemento
  Future<void> _toggleCheckbox(String itemId, bool? checked) async {
    if (_profile == null || checked == null) return;
    final updated = VinkiarSSCManager.toggleItemVisibility(_profile!, itemId, checked);
    await _persistProfile(updated);
  }

  Future<void> _addCustomLimit() async {
    final text = _newLimitController.text.trim();
    if (text.isEmpty || _profile == null) return;

    final autoVisible = VinkiarSSCManager.isTierUnlockedForLevel(
      _selectedNewTier,
      _profile!.synergyLevel,
    );

    final newItem = SscLimitItem(
      id: 'ssc_${DateTime.now().millisecondsSinceEpoch}',
      label: text,
      tier: _selectedNewTier,
      isVisible: autoVisible,
      manualOverride: false,
    );

    _newLimitController.clear();
    await _persistProfile(_profile!.copyWith(
      myLimits: [..._profile!.myLimits, newItem],
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _deleteLimit(String itemId) async {
    if (_profile == null) return;
    final filtered = _profile!.myLimits.where((e) => e.id != itemId).toList();
    await _persistProfile(_profile!.copyWith(
      myLimits: filtered,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _syncVisibleLayerToPeer() async {
    if (_profile == null || _isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final payload = VinkiarSSCManager.buildZkaShareablePayload(
        senderHandle: widget.myHandle,
        profile: _profile!,
      );

      final sentLive = await (widget.syncService ?? VinkiarSyncService()).sendZkaControlPacket(payload);

      final visibleCount = _profile!.myLimits.where((e) => e.isVisible).length;
      final hiddenCount = _profile!.myLimits.length - visibleCount;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10121A),
            content: Text(
              sentLive
                  ? "ZKA SYNC EN VIVO: $visibleCount límites visibles transmitidos · $hiddenCount ocultos en bóveda."
                  : "BÓVEDA SELLADA: $visibleCount visibles listos para transmitir al conectar · $hiddenCount ocultos.",
              style: GoogleFonts.jetBrainsMono(color: const Color(0xFF39FF14), fontSize: 10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// Simula la llegada de un paquete ZKA desde el contacto para previsualizar el panel y las colisiones
  Future<void> _simulateIncomingDisclosure() async {
    if (_profile == null) return;
    final sampleIncoming = <SscLimitItem>[
      const SscLimitItem(
        id: 'sim_peer_g1',
        label: 'Conversación profunda sin móviles sobre la mesa',
        tier: SscLimitTier.green,
        isVisible: true,
      ),
      const SscLimitItem(
        id: 'sim_peer_y1',
        label: 'Compartir ubicación solo durante el trayecto al Santuario',
        tier: SscLimitTier.yellow,
        isVisible: true,
      ),
      const SscLimitItem(
        id: 'sim_peer_r1',
        label: 'Encuentros presenciales en Santuarios acreditados',
        tier: SscLimitTier.red,
        isVisible: true,
      ),
    ];

    await _persistProfile(_profile!.copyWith(
      incomingLimits: sampleIncoming,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _clearIncomingDisclosure() async {
    if (_profile == null) return;
    await _persistProfile(_profile!.copyWith(
      incomingLimits: const [],
      updatedAt: DateTime.now(),
    ));
  }

  // =========================================================================
  // SECCIÓN 4: CONSTRUCCIÓN DE INTERFAZ (BUILD PRINCIPAL)
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _profile == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
      );
    }

    final profile = _profile!;
    final collisions = VinkiarSSCManager.detectCollisions(profile);
    final visibleCount = profile.myLimits.where((e) => e.isVisible).length;
    final hiddenCount = profile.myLimits.length - visibleCount;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. SEMÁFORO OPERATIVO (ESTADO EN TIEMPO REAL)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF08090C),
              border: Border.all(color: const Color(0xFF1C1F26)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "1. SEMÁFORO OPERATIVO // DISPONIBILIDAD ACTUAL",
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF00E5FF),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildOpButton(SscOperationalState.green, "VERDE", const Color(0xFF39FF14)),
                    const SizedBox(width: 6),
                    _buildOpButton(SscOperationalState.yellow, "ÁMBAR", const Color(0xFFE5B869)),
                    const SizedBox(width: 6),
                    _buildOpButton(SscOperationalState.red, "ROJO (PAUSA)", const Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 2. SELECTOR EXPLÍCITO DE REVELACIÓN GRADUAL (NIVEL 0, 1 O 2)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10121A),
              border: Border.all(color: const Color(0xFFE5B869).withOpacity(0.4)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "2. REVELACIÓN GRADUAL // CAPA ACTIVA",
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFFE5B869),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "$visibleCount VISIBLES · $hiddenCount OCULTOS",
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF39FF14),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Elige una capa rápida o marca individualmente cada casilla del catálogo:",
                  style: GoogleFonts.jetBrainsMono(color: Colors.grey[400], fontSize: 9),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildLevelPill(0, "N0 · VERDES", const Color(0xFF39FF14)),
                    const SizedBox(width: 6),
                    _buildLevelPill(1, "N1 · +ÁMBAR", const Color(0xFFE5B869)),
                    const SizedBox(width: 6),
                    _buildLevelPill(2, "N2 · TODO", const Color(0xFF00E5FF)),
                  ],
                ),
              ],
            ),
          ),

          // ALERTAS DE COLISIÓN CON LÍMITES RECIBIDOS DE LA CONTRAPARTE
          if (collisions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.12),
                border: Border.all(color: const Color(0xFFEF4444)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "⚠️ COLISIÓN DE LÍMITES DETECTADA (${collisions.length})",
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...collisions.map((c) => Text(
                        "• Tú [${c.myTier.name.toUpperCase()}]: '${c.myLabel}' vs ${widget.contactHandle} [${c.peerTier.name.toUpperCase()}]",
                        style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 9.5),
                      )),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 3. MATRIZ CON CASILLAS DE VERIFICACIÓN (VISIBLE / OCULTO) POR CATEGORÍA
          ...SscLimitTier.values.map((tier) => _buildTierSection(tier, profile)),

          const SizedBox(height: 10),

          // AÑADIR NUEVO LÍMITE O DESEO
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF08090C),
              border: Border.all(color: const Color(0xFF1C1F26)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AÑADIR NUEVO ELEMENTO AL CATÁLOGO SSC",
                  style: GoogleFonts.jetBrainsMono(color: Colors.grey[400], fontSize: 9.5),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    DropdownButton<SscLimitTier>(
                      value: _selectedNewTier,
                      dropdownColor: const Color(0xFF10121A),
                      style: GoogleFonts.jetBrainsMono(
                        color: _tierColor(_selectedNewTier),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      items: const [
                        DropdownMenuItem(value: SscLimitTier.green, child: Text("VERDE")),
                        DropdownMenuItem(value: SscLimitTier.yellow, child: Text("ÁMBAR")),
                        DropdownMenuItem(value: SscLimitTier.red, child: Text("ROJO")),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedNewTier = val);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _newLimitController,
                        style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11),
                        decoration: InputDecoration(
                          hintText: "Ej. Sin alcohol en primera cita...",
                          hintStyle: GoogleFonts.jetBrainsMono(color: Colors.grey[600], fontSize: 10),
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addCustomLimit,
                      icon: const Icon(Icons.add_circle, color: Color(0xFF00E5FF)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 4. LÍMITES REVELADOS POR EL CONTACTO (SIEMPRE VISIBLE + SIMULADOR)
          _buildIncomingPeerSection(profile),

          const SizedBox(height: 14),

          // BOTÓN DE SINCRONIZACIÓN P2P ZKA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSyncing ? null : _syncVisibleLayerToPeer,
              icon: const Icon(Icons.lock_open, size: 15, color: Colors.black),
              label: Text(
                "TRANSMITIR SOLO CASILLAS VISIBLES ($visibleCount) A ${widget.contactHandle.toUpperCase()}",
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF39FF14),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // SECCIÓN 5: COMPONENTES AUXILIARES DE MATRIZ, NIVELES Y PANEL RECIBIDO
  // =========================================================================

  Widget _buildIncomingPeerSection(DyadicSscProfile profile) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF08090C),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.45)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "4. CAPA REVELADA POR ${widget.contactHandle.toUpperCase()} (${profile.incomingLimits.length})",
                  style: GoogleFonts.jetBrainsMono(
                    color: const Color(0xFF00E5FF),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              InkWell(
                onTap: _simulateIncomingDisclosure,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.15),
                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.6)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    "Simular recepción",
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF00E5FF),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (profile.incomingLimits.isNotEmpty) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: _clearIncomingDisclosure,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade700),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      "Limpiar",
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.grey[400],
                        fontSize: 8.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (profile.incomingLimits.isEmpty)
            Text(
              "Aún no has recibido límites revelados de ${widget.contactHandle}. Cuando pulse 'Transmitir solo casillas visibles' en su dispositivo, aparecerán aquí cifrados de extremo a extremo.",
              style: GoogleFonts.jetBrainsMono(
                color: Colors.grey[500],
                fontSize: 9,
                height: 1.35,
              ),
            )
          else
            ...profile.incomingLimits.map((peerItem) {
              final c = _tierColor(peerItem.tier);
              final tierLabel = peerItem.tier == SscLimitTier.green
                  ? "VERDE · DESEO"
                  : peerItem.tier == SscLimitTier.yellow
                      ? "ÁMBAR · NEGOCIABLE"
                      : "ROJO · LÍMITE DURO";
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.08),
                  border: Border(left: BorderSide(color: c, width: 3.5)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tierLabel,
                      style: GoogleFonts.jetBrainsMono(
                        color: c,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      peerItem.label,
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Color _tierColor(SscLimitTier tier) {
    switch (tier) {
      case SscLimitTier.green:
        return const Color(0xFF39FF14);
      case SscLimitTier.yellow:
        return const Color(0xFFE5B869);
      case SscLimitTier.red:
        return const Color(0xFFEF4444);
    }
  }

  String _tierTitle(SscLimitTier tier) {
    switch (tier) {
      case SscLimitTier.green:
        return "VERDES // DESEOS Y AFINIDAD";
      case SscLimitTier.yellow:
        return "AMARILLOS // NEGOCIABLES Y MATICES";
      case SscLimitTier.red:
        return "ROJOS // LÍMITES DUROS Y CUIDADOS";
    }
  }

  Widget _buildLevelPill(int level, String label, Color color) {
    final isSelected = _profile?.synergyLevel == level;
    return Expanded(
      child: InkWell(
        onTap: () => _selectSynergyLevel(level),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.22) : const Color(0xFF08090C),
            border: Border.all(
              color: isSelected ? color : const Color(0xFF1C1F26),
              width: isSelected ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: isSelected ? color : Colors.grey[500],
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOpButton(SscOperationalState state, String label, Color color) {
    final isSelected = _profile?.operationalState == state;
    return Expanded(
      child: InkWell(
        onTap: () => _changeOperationalState(state),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.22) : const Color(0xFF10121A),
            border: Border.all(color: isSelected ? color : const Color(0xFF1C1F26)),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: isSelected ? color : Colors.grey[500],
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTierSection(SscLimitTier tier, DyadicSscProfile profile) {
    final color = _tierColor(tier);
    final items = profile.myLimits.where((e) => e.tier == tier).toList();
    final visibleInTier = items.where((e) => e.isVisible).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF08090C),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _tierTitle(tier),
                style: GoogleFonts.jetBrainsMono(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "$visibleInTier/${items.length} VISIBLES",
                style: GoogleFonts.jetBrainsMono(
                  color: visibleInTier > 0 ? color : Colors.grey[600],
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            Text(
              "Sin elementos en esta categoría.",
              style: GoogleFonts.jetBrainsMono(color: Colors.grey[600], fontSize: 9.5),
            )
          else
            ...items.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: item.isVisible ? color.withOpacity(0.08) : const Color(0xFF10121A),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: item.isVisible,
                      activeColor: color,
                      checkColor: Colors.black,
                      side: BorderSide(color: color.withOpacity(0.7)),
                      onChanged: (val) => _toggleCheckbox(item.id, val),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => _toggleCheckbox(item.id, !item.isVisible),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: GoogleFonts.jetBrainsMono(
                                color: item.isVisible ? Colors.white : Colors.grey[500],
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              item.isVisible
                                  ? "👁️ VISIBLE para ${widget.contactHandle}"
                                  : "🔒 OCULTO (Solo en tu Bóveda local)",
                              style: GoogleFonts.jetBrainsMono(
                                color: item.isVisible ? color : Colors.grey[600],
                                fontSize: 8.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                      onPressed: () => _deleteLimit(item.id),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}