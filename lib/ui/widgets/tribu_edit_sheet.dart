import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../services/vinkiar_secure_database.dart';
import '../theme.dart';
import 'tribu_command_card.dart';

// =========================================================================
// SECCIÓN 1: WIDGET DE EDICIÓN COMPLETA DEL GREMIO / TRIBU
// =========================================================================

class TribuEditSheet extends StatefulWidget {
  final Map<String, dynamic> guild;
  final String myHandle;
  final VoidCallback? onSaved;

  const TribuEditSheet({
    super.key,
    required this.guild,
    required this.myHandle,
    this.onSaved,
  });

  @override
  State<TribuEditSheet> createState() => _TribuEditSheetState();
}

// =========================================================================
// SECCIÓN 2: ESTADO, CARGA DE ROLES Y PERSISTENCIA EN POSTGRESQL + BÓVEDA
// =========================================================================

class _TribuEditSheetState extends State<TribuEditSheet> {
  final VinkiarSecureDatabase _db = VinkiarSecureDatabase();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;

  String _sscBaseline = 'GREEN';
  String _decisionMode = 'QUORUM';
  int _quorumPct = 51;
  bool _isSaving = false;
  bool _isLoadingRemote = true;

  String _creatorHandle = '';
  List<String> _miembros = [];
  Set<String> _admins = {};

  String get _cleanBaseUrl => ApiConfig.baseUrl.endsWith('/')
      ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
      : ApiConfig.baseUrl;

  String get _normalizedMyHandle {
    final raw = widget.myHandle.trim();
    if (raw.isEmpty) return '#Pionero';
    return raw.startsWith('#') ? raw : '#$raw';
  }

  bool get _amIFounder {
    if (widget.guild['is_creator'] == true) return true;
    return _creatorHandle.isNotEmpty &&
        _creatorHandle.toLowerCase() == _normalizedMyHandle.toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.guild['name']?.toString() ?? 'Tribu ZKA');
    _descCtrl = TextEditingController(text: widget.guild['description']?.toString() ?? '');
    _sscBaseline = (widget.guild['ssc_baseline'] ?? 'GREEN').toString().toUpperCase();
    _decisionMode = (widget.guild['decision_mode'] ?? 'QUORUM').toString().toUpperCase();
    _quorumPct = (widget.guild['quorum_pct'] as num?)?.toInt() ?? 51;
    _creatorHandle = widget.guild['creator_handle']?.toString() ??
        (widget.guild['is_creator'] == true ? _normalizedMyHandle : '');
    _admins = ((widget.guild['admins'] as List?) ?? []).map((e) => e.toString()).toSet();
    _loadRemoteDetails();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRemoteDetails() async {
    final guildId = widget.guild['guild_id']?.toString() ?? '';
    final localMembers = await _db.getGuildMembers(guildId);
    final localAliases = localMembers
        .where((m) => (m['status'] ?? 'ACTIVE') == 'ACTIVE')
        .map((m) {
          final a = (m['alias'] ?? '').toString().trim();
          return a.startsWith('#') ? a : '#$a';
        })
        .where((a) => a.length > 1)
        .toList();

    try {
      final uri = Uri.parse('$_cleanBaseUrl/api/v1/tribus/${Uri.encodeComponent(guildId)}/bolsa').replace(
        queryParameters: {
          'nombre': _nameCtrl.text.trim(),
          'member_handle': _normalizedMyHandle,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200 && mounted) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final tribu = body['tribu'] as Map<String, dynamic>? ?? {};
        final remoteMembers = (tribu['miembros'] as List? ?? []).map((e) => e.toString()).toList();
        final mergedMembers = <String>{...remoteMembers, ...localAliases, _normalizedMyHandle}.toList();

        setState(() {
          if (tribu['nombre_tribu'] != null && tribu['nombre_tribu'].toString().isNotEmpty) {
            _nameCtrl.text = tribu['nombre_tribu'].toString();
          }
          if (tribu['descripcion'] != null && tribu['descripcion'].toString().isNotEmpty) {
            _descCtrl.text = tribu['descripcion'].toString();
          }
          if (tribu['ssc_baseline'] != null) {
            _sscBaseline = tribu['ssc_baseline'].toString().toUpperCase();
          }
          if (tribu['decision_mode'] != null) {
            _decisionMode = tribu['decision_mode'].toString().toUpperCase();
          }
          if (tribu['quorum_pct'] is num) {
            _quorumPct = (tribu['quorum_pct'] as num).toInt();
          }
          if (tribu['creator_handle'] != null && tribu['creator_handle'].toString().isNotEmpty) {
            _creatorHandle = tribu['creator_handle'].toString();
          }
          _admins = ((tribu['admins'] as List?) ?? []).map((e) => e.toString()).toSet();
          _miembros = mergedMembers;
          _isLoadingRemote = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _miembros = <String>{...localAliases, _normalizedMyHandle}.toList();
        _isLoadingRemote = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty || _isSaving) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final guildId = widget.guild['guild_id']?.toString() ?? '';
    final newDesc = _descCtrl.text.trim();

    try {
      final res = await http.put(
        Uri.parse('$_cleanBaseUrl/api/v1/tribus/${Uri.encodeComponent(guildId)}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'actor_handle': _normalizedMyHandle,
          'name': newName,
          'description': newDesc,
          'ssc_baseline': _sscBaseline,
          'quorum_pct': _quorumPct,
          'decision_mode': _decisionMode,
          if (_amIFounder) 'admins': _admins.toList(),
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 403) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Permiso denegado: solo el fundador o un administrador designado puede editar la Tribu."),
              backgroundColor: VinkiarColors.panicRed,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }
    } catch (_) {}

    final updatedLocal = Map<String, dynamic>.from(widget.guild);
    updatedLocal['name'] = newName;
    updatedLocal['description'] = newDesc;
    updatedLocal['ssc_baseline'] = _sscBaseline;
    updatedLocal['quorum_pct'] = _quorumPct;
    updatedLocal['decision_mode'] = _decisionMode;
    updatedLocal['admins'] = _admins.toList();
    if (_creatorHandle.isNotEmpty) {
      updatedLocal['creator_handle'] = _creatorHandle;
    }

    await _db.saveGuild(updatedLocal);
    await _db.logActivityEvent(
      title: "Tribu Actualizada: $newName",
      description: "Manifiesto y reglas de consenso actualizados por $_normalizedMyHandle.",
      type: "GUILD_JOIN",
    );

    if (mounted) {
      widget.onSaved?.call();
      Navigator.pop(context, updatedLocal);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: VinkiarColors.hackingGreen,
          content: Text(
            "🛡️ TRIBU ACTUALIZADA Y SINCRONIZADA",
            style: GoogleFonts.jetBrainsMono(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ),
      );
    }
  }

  // =========================================================================
  // SECCIÓN 3: INTERFAZ DE EDICIÓN (BUILD)
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final String guildId = widget.guild['guild_id']?.toString() ?? 'ZK-TRIBU';
    final String previewName = _nameCtrl.text.trim().isEmpty ? 'Tribu ZKA' : _nameCtrl.text.trim();
    final Color sscColor = _sscBaseline == 'GREEN'
        ? VinkiarColors.hackingGreen
        : (_sscBaseline == 'YELLOW' ? VinkiarColors.vertigoGold : VinkiarColors.panicRed);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: VinkiarColors.abyssBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: VinkiarColors.aegisCyan, width: 2)),
      ),
      child: _isLoadingRemote
          ? const Center(child: CircularProgressIndicator(color: VinkiarColors.aegisCyan))
          : Column(
              children: [
                // Cabecera
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  color: VinkiarColors.panelDark,
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, color: VinkiarColors.aegisCyan, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "EDITAR GREMIO // $guildId",
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            color: VinkiarColors.aegisCyan,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
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
                      left: 18,
                      right: 18,
                      top: 14,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vista previa heráldica
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: VinkiarColors.panelDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: sscColor.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 46,
                                height: 46,
                                child: CustomPaint(
                                  painter: TribuCrestPainter(
                                    seed: guildId,
                                    primaryColor: VinkiarColors.aegisCyan,
                                    accentColor: sscColor,
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
                                      previewName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "Fundador: ${_creatorHandle.isEmpty ? _normalizedMyHandle : _creatorHandle}",
                                      style: GoogleFonts.jetBrainsMono(
                                        color: VinkiarColors.vertigoGold,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          "NOMBRE DE LA TRIBU:",
                          style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameCtrl,
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: VinkiarColors.panelDark,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          "MANIFIESTO / DESCRIPCIÓN Y NORMAS DE CONVIVENCIA:",
                          style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _descCtrl,
                          maxLines: 4,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 12.5, height: 1.35),
                          decoration: InputDecoration(
                            hintText: "Define los valores, objetivos y acuerdos de esta Tribu...",
                            hintStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 11.5),
                            filled: true,
                            fillColor: VinkiarColors.panelDark,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          "UMBRAL SSC DEL CANAL:",
                          style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildSscPill("VERDE\nAbierto", "GREEN", VinkiarColors.hackingGreen),
                            const SizedBox(width: 6),
                            _buildSscPill("ÁMBAR\nFiltro", "YELLOW", VinkiarColors.vertigoGold),
                            const SizedBox(width: 6),
                            _buildSscPill("ROJO\nPrivado", "RED", VinkiarColors.panicRed),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Text(
                          "MÉTODO DE DECISIÓN DE TESORERÍA POR DEFECTO:",
                          style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildModePill("🛡️ MÍNIMA MISERIA\n(Veto + Consenso)", "LEAST_MISERY", VinkiarColors.hackingGreen),
                            const SizedBox(width: 8),
                            _buildModePill("🗳️ QUÓRUM\n($_quorumPct% Firmas)", "QUORUM", VinkiarColors.vertigoGold),
                          ],
                        ),
                        if (_decisionMode == 'QUORUM') ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildQuorumBtn(51, "51% Mayoría"),
                              const SizedBox(width: 6),
                              _buildQuorumBtn(67, "67% Cualificada"),
                              const SizedBox(width: 6),
                              _buildQuorumBtn(100, "100% Unánime"),
                            ],
                          ),
                        ],

                        if (_amIFounder && _miembros.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            "CO-ADMINISTRADORES DESIGNADOS (PUEDEN EDITAR EL GREMIO):",
                            style: GoogleFonts.jetBrainsMono(
                              color: VinkiarColors.vertigoGold,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ..._miembros.where((m) => m.toLowerCase() != _normalizedMyHandle.toLowerCase()).map((member) {
                            final bool isAdmin = _admins.any((a) => a.toLowerCase() == member.toLowerCase());
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: VinkiarColors.panelDark,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isAdmin ? VinkiarColors.vertigoGold.withOpacity(0.6) : Colors.white12,
                                ),
                              ),
                              child: SwitchListTile(
                                dense: true,
                                activeColor: VinkiarColors.vertigoGold,
                                title: Text(
                                  member,
                                  style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  isAdmin ? "Co-Administrador activo" : "Miembro estándar",
                                  style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10),
                                ),
                                value: isAdmin,
                                onChanged: (val) {
                                  setState(() {
                                    if (val) {
                                      _admins.add(member);
                                    } else {
                                      _admins.removeWhere((a) => a.toLowerCase() == member.toLowerCase());
                                    }
                                  });
                                },
                              ),
                            );
                          }),
                        ],

                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VinkiarColors.aegisCyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                            ),
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: Text(
                              _isSaving ? "GUARDANDO CAMBIOS..." : "SELLAR CAMBIOS EN EL GREMIO",
                              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            onPressed: _isSaving ? null : _saveChanges,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSscPill(String label, String value, Color color) {
    final bool selected = _sscBaseline == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _sscBaseline = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.2) : VinkiarColors.panelDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? color : Colors.white12, width: selected ? 1.5 : 1.0),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              color: selected ? color : Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModePill(String label, String value, Color color) {
    final bool selected = _decisionMode == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _decisionMode = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.2) : VinkiarColors.panelDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? color : Colors.white12, width: selected ? 1.5 : 1.0),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              color: selected ? color : Colors.white54,
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuorumBtn(int pct, String label) {
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
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              color: selected ? VinkiarColors.vertigoGold : Colors.white54,
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
