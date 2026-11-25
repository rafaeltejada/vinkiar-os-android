import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/api_config.dart';
import '../main.dart';
import '../services/onboarding_guide_service.dart';
import '../services/vinkiar_secure_database.dart';
import '../services/acoustic_sentinel_service.dart';
import '../services/safety_config_service.dart';
import 'contacts_screen.dart';
import 'profile/widgets/eneagram_chart.dart';
import 'theme.dart';
import 'widgets/vinki_chat_modal.dart';
import 'widgets/zkp_sovereign_security_sheet.dart';
import 'vault_diary_screen.dart';
import 'armeria_screen.dart';
import 'chat_qa_screen.dart';
import 'smoke_screen_overlay.dart';
import 'mascara_publica_screen.dart';

// =========================================================================
// SECCIÓN 1: WIDGET PRINCIPAL DE LA BÓVEDA CRIPTOGRÁFICA
// =========================================================================

class BovedaScreen extends StatefulWidget {
  const BovedaScreen({Key? key}) : super(key: key);

  @override
  State<BovedaScreen> createState() => BovedaScreenState();
}

// =========================================================================
// SECCIÓN 2: ESTADO LOCAL, ARQUETIPOS, CENTINELA Y LINAJE ZK
// =========================================================================

class BovedaScreenState extends State<BovedaScreen> {
  Map<String, dynamic>? _avatarData;
  Map<String, dynamic>? _soulSheetData;
  String? _userVector;

  EgoVector? _egoVector;
  ErosVector? _erosVector;
  PhiliaVector? _philiaVector;

  String _naturalArchetype = "POR DEFINIR";
  String _chosenArchetype = "NINGUNO";
  double _alignmentPercentage = 0.0;
  String _alignmentAdvice = "Selecciona un Rol Social para evaluar la tensión con tu Arquetipo Natural.";
  double _reputationScore = 0.95;

  int _empathy = 0;
  int _willpower = 0;
  int _erotism = 0;
  int _sovereignty = 0;

  bool _loading = true;
  String _inviteCode = "SINCRONIZANDO_ZK...";
  bool _isInviteReused = false;

  bool _isProfileExpanded = true;
  bool _isEneagramExpanded = false;
  bool _isTribeExpanded = false;
  bool _isSscExpanded = false;
  bool _isToolsExpanded = false;

  // Estado del Árbol de Linaje Real (Avalista -> Tú -> Avalados)
  List<dynamic> _lineageNodes = [];
  Map<String, dynamic>? _sponsorInfo;
  double _totalLineagePenalty = 0.0;
  bool _isLoadingLineage = false;
  String? _lineageSyncError;

  bool _isSentinelListening = false;
  DecoyType _currentDecoyType = DecoyType.calculator;
  String _anchorHandle = "#ANCLA_SIN_DESIGNAR";
  String _anchorPhone = "";
  String _anchorEmail = "";

  final List<String> _availableChosenRoles = const [
    "NINGUNO",
    "BARDO REVOLUCIONARIO",
    "TANQUE DE LA ÉGIDA",
    "TECNOMANTE INFILTRADOR",
    "SANADOR SOMÁTICO",
    "ILUSIONISTA HÁPTICO",
    "BIO-HACKER SOMÁTICO",
  ];

  @override
  void initState() {
    super.initState();
    _loadSecureData();
    _fetchOrGenerateInviteCode();
    _initSentinelService();
    VinkiarSecureDatabase.avatarChangeNotifier.addListener(_onAvatarChanged);
  }

  @override
  void dispose() {
    VinkiarSecureDatabase.avatarChangeNotifier.removeListener(_onAvatarChanged);
    super.dispose();
  }

  void _initSentinelService() {
    final sentinel = AcousticSentinelService();
    sentinel.initialize();
    sentinel.onSecurityBlackout = (reason) {
      if (mounted && !sentinel.isOverlayActive) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SmokeScreenOverlay(
              reason: reason,
              isEmergencySOS: false,
            ),
          ),
        );
      }
    };
    sentinel.onEmergencyLockdown = () {
      if (mounted && !sentinel.isOverlayActive) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SmokeScreenOverlay(
              reason: SentinelTriggerReason.hardwarePanic,
              isEmergencySOS: true,
            ),
          ),
        );
      }
    };
  }

  Future<String?> _loadLocalUserId() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final authFile = File('${dir.path}/vinkiar_authenticated_id.json');
      if (await authFile.exists()) {
        final content = await authFile.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        final id = data['user_id'] as String?;
        if (id != null && id.isNotEmpty) return id;
      }

      final localFile = File('${dir.path}/vinkiar_local_user_id.json');
      if (await localFile.exists()) {
        final content = await localFile.readAsString();
        final Map<String, dynamic> data = jsonDecode(content);
        final id = data['user_id'] as String?;
        if (id != null && id.isNotEmpty) return id;
      }
    } catch (_) {}
    return null;
  }

  String _resolveCurrentAlias() {
    final stats = _avatarData?['stats'] as Map<String, dynamic>? ?? {};
    final rawAlias = (_avatarData?['alias']?.toString().isNotEmpty == true)
        ? _avatarData!['alias'].toString()
        : (stats['alias']?.toString() ?? '');
    return rawAlias.trim();
  }

  // =========================================================================
  // SECCIÓN 3: INVITACIONES ZK REUTILIZABLES, LINAJE REAL Y REVOCACIÓN DE AVAL
  // =========================================================================

  /// Recupera el código de invitación activo del usuario o genera uno nuevo si no tiene pendientes
  Future<void> _fetchOrGenerateInviteCode({bool forceNew = false}) async {
    try {
      final userId = await _loadLocalUserId();
      if (userId == null || userId.isEmpty) return;

      final alias = _resolveCurrentAlias();
      final cleanBase = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;
      final url = Uri.parse('$cleanBase/api/v1/invite/generate');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'alias': alias,
          'force_new': forceNew,
        }),
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['invite_code'] != null) {
          setState(() {
            _inviteCode = data['invite_code'].toString();
            _isInviteReused = data['reused'] == true;
          });
        }
      }
    } catch (_) {}
  }

  /// Consulta el árbol de linaje real (avalista y avalados) desde PostgreSQL
  Future<void> _fetchLineageAudit() async {
    if (_isLoadingLineage) return;
    setState(() {
      _isLoadingLineage = true;
      _lineageSyncError = null;
    });

    try {
      final cleanBase = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;

      final localId = await _loadLocalUserId();
      final alias = _resolveCurrentAlias();
      final cleanParam = (localId != null && localId.isNotEmpty)
          ? localId
          : (alias.isNotEmpty ? alias : "LOCAL_USER");

      final uri = Uri.parse('$cleanBase/api/v1/boveda/lineage/${Uri.encodeComponent(cleanParam)}').replace(
        queryParameters: alias.isNotEmpty ? {'alias': alias} : null,
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _lineageNodes = List<dynamic>.from(data['invitees'] as List? ?? []);
          _sponsorInfo = data['sponsor'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(data['sponsor'])
              : null;
          _totalLineagePenalty = (data['total_penalty_pct'] as num?)?.toDouble() ?? 0.0;
          if (data['current_reputation_score'] is num) {
            _reputationScore = (data['current_reputation_score'] as num).toDouble().clamp(0.0, 1.0);
          }
          _isLoadingLineage = false;
        });
        return;
      } else {
        setState(() {
          _lineageSyncError = "No se pudo sincronizar el árbol ZK (${response.statusCode}).";
          _isLoadingLineage = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _lineageSyncError = "Sin conexión con el servidor ZKA. Pulsa CALIBRAR para reintentar.";
          _isLoadingLineage = false;
        });
      }
    }
  }

  /// Ejecuta la revocación formal de un aval en PostgreSQL tras confirmación del usuario
  Future<void> _confirmAndRevokeAval(String inviteCode, String inviteeHandle) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VinkiarColors.abyssBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: VinkiarColors.panicRed, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.link_off, color: VinkiarColors.panicRed, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "RETIRAR AVAL ZK // DESVINCULACIÓN",
                style: GoogleFonts.jetBrainsMono(
                  color: VinkiarColors.panicRed,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "Vas a retirar tu aval criptográfico a $inviteeHandle (código $inviteCode).\n\n"
          "• Esta acción es irreversible y quedará registrada en el historial de linaje.\n"
          "• Cortarás el vínculo de corresponsabilidad y eliminarás su penalización sobre tu halo reputacional.",
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              "CANCELAR",
              style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 10),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VinkiarColors.panicRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              "CONFIRMAR RETIRADA",
              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final cleanBase = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;

      final localId = await _loadLocalUserId();
      final alias = _resolveCurrentAlias();

      final res = await http.post(
        Uri.parse('$cleanBase/api/v1/boveda/aval/revocar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'invite_code': inviteCode,
          'host_id': localId ?? '',
          'host_handle': alias.isNotEmpty ? (alias.startsWith('#') ? alias : '#$alias') : '',
        }),
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VinkiarColors.panelDark,
            content: Text(
              "🛡️ AVAL RETIRADO: Vínculo con $inviteeHandle revocado y reputación recalculada.",
              style: GoogleFonts.jetBrainsMono(color: VinkiarColors.hackingGreen, fontSize: 10),
            ),
          ),
        );
        await _fetchLineageAudit();
      } else {
        String err = "No se pudo revocar el aval.";
        try {
          final parsed = jsonDecode(res.body);
          if (parsed['detail'] != null) err = parsed['detail'].toString();
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: VinkiarColors.panicRed),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error de red al revocar aval: $e"),
            backgroundColor: VinkiarColors.panicRed,
          ),
        );
      }
    }
  }

  Future<void> _copyInviteCode() async {
    await Clipboard.setData(ClipboardData(text: _inviteCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "CÓDIGO COPIADO AL PORTAPAPELES: $_inviteCode",
          style: GoogleFonts.jetBrainsMono(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        backgroundColor: VinkiarColors.aegisCyan,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareInviteCode() async {
    await Clipboard.setData(ClipboardData(text: _inviteCode));
    await Share.share(
      "Te envío mi llave de acceso avalada para entrar en Vinkiar OS (Zero-Knowledge): $_inviteCode",
    );
  }

  void _onAvatarChanged() {
    if (mounted) _loadSecureData();
  }

  void reload() {
    _loadSecureData();
    _fetchLineageAudit();
  }

  // =========================================================================
  // SECCIÓN 4: CÁLCULO DE ALINEACIÓN SOMÁTICA Y CARGA DE BÓVEDA LOCAL
  // =========================================================================

  Future<void> _restorePioneerProfile() async {
    final db = VinkiarSecureDatabase();
    await db.saveAvatarSheet("LOCAL_USER", {
      "character_class": "TANQUE DE LA ÉGIDA",
      "level": 4,
      "experience_points": 1850,
      "reputation_score": 0.95,
      "stats": {
        "alias": "Master",
        "bio": "Arquitecto y pionero del ecosistema Vinkiar OS.",
        "natural_archetype": "TANQUE DE LA ÉGIDA",
        "chosen_archetype": "TANQUE DE LA ÉGIDA",
        "alignment_percentage": 98.2,
        "empathy": 80,
        "willpower": 88,
        "erotism": 70,
        "sovereignty": 92,
        "safeword": "MANGO",
        "safe_pin": "9999",
        "duress_pin": "1111",
        "anchor_handle": "#Kaelen_Void",
        "anchor_phone": "",
        "anchor_email": "",
        "decoy_type": "calculator",
        "limites_verdes": "Diálogo abierto, Co-regulación somática",
        "limites_amarillos": "Exposición de secretos de clan",
        "limites_rojos": "Sincericidio destructivo, Privación sensorial no pactada",
        "is_simulation_mode": 0,
      }
    });
    await db.saveUserVector("8-1-5");

    await SafetyConfigService().saveConfig(SafetyConfig(
      safePinHash: SafetyConfigService().hashPin("9999"),
      duressPinHash: SafetyConfigService().hashPin("1111"),
      decoyType: DecoyType.calculator,
      safeword: "MANGO",
      anchorHandle: "#Kaelen_Void",
    ));

    await _loadSecureData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚡ IDENTIDAD DE 'MASTER' Y PROTOCOLOS RESTAURADOS"),
          backgroundColor: VinkiarColors.hackingGreen,
        ),
      );
    }
  }

  Map<String, dynamic> _computeAlignment({
    required String natural,
    required String chosen,
    required int empathy,
    required int willpower,
    required int erotism,
    required int sovereignty,
  }) {
    if (chosen == "NINGUNO" || chosen.isEmpty || natural == "POR DEFINIR") {
      return {
        "percentage": 0.0,
        "advice": "Elige un Rol Social para evaluar la tensión con tu Arquetipo Natural.",
      };
    }

    final Map<String, Map<String, int>> roleIdeals = {
      "BARDO REVOLUCIONARIO": {"empathy": 80, "erotism": 75, "sovereignty": 70, "willpower": 55},
      "TANQUE DE LA ÉGIDA": {"willpower": 85, "sovereignty": 80, "empathy": 50, "erotism": 50},
      "TECNOMANTE INFILTRADOR": {"erotism": 85, "willpower": 75, "sovereignty": 65, "empathy": 50},
      "SANADOR SOMÁTICO": {"empathy": 85, "sovereignty": 75, "willpower": 60, "erotism": 50},
      "ILUSIONISTA HÁPTICO": {"erotism": 85, "empathy": 70, "sovereignty": 65, "willpower": 60},
      "BIO-HACKER SOMÁTICO": {"willpower": 80, "erotism": 80, "sovereignty": 75, "empathy": 50},
    };

    String matchedRoleKey = "TANQUE DE LA ÉGIDA";
    for (var k in roleIdeals.keys) {
      if (chosen.toUpperCase().contains(k)) {
        matchedRoleKey = k;
        break;
      }
    }

    final ideals = roleIdeals[matchedRoleKey]!;

    bool isSame = false;
    for (var k in roleIdeals.keys) {
      if (natural.toUpperCase().contains(k) && chosen.toUpperCase().contains(k)) {
        isSame = true;
        break;
      }
    }

    final double baseAffinity = isSame ? 0.95 : 0.65;

    final userStats = {
      "empathy": empathy,
      "willpower": willpower,
      "erotism": erotism,
      "sovereignty": sovereignty,
    };

    final statLabels = {
      "empathy": "Empatía",
      "willpower": "Voluntad",
      "erotism": "Astucia",
      "sovereignty": "Soberanía",
    };

    double totalFit = 0.0;
    int maxGap = -1;
    String gapStatLabel = "";
    int currStatVal = 0;
    int targetStatVal = 0;

    ideals.forEach((statKey, targetVal) {
      final int curr = userStats[statKey] ?? 0;
      final double fit = (curr / targetVal).clamp(0.0, 1.0);
      totalFit += fit;

      final int gap = targetVal - curr;
      if (gap > maxGap) {
        maxGap = gap;
        gapStatLabel = statLabels[statKey] ?? statKey;
        currStatVal = curr;
        targetStatVal = targetVal;
      }
    });

    final double somaticFitness = totalFit / ideals.length;
    double alignment = (baseAffinity * 0.35 + somaticFitness * 0.65) * 100.0;
    alignment = alignment.clamp(15.0, 99.0);

    String advice;
    if (maxGap > 0) {
      advice = "Vinki sugiere entrenar tu $gapStatLabel ($currStatVal/$targetStatVal) para sostener esta máscara sin drenaje.";
    } else {
      advice = "Resonancia óptima: tus atributos somáticos dominan plenamente este rol.";
    }

    return {
      "percentage": double.parse(alignment.toStringAsFixed(1)),
      "advice": advice,
    };
  }

  Color _getAlignmentColor() {
    if (_chosenArchetype == "NINGUNO" || _alignmentPercentage == 0.0) {
      return Colors.grey;
    }
    if (_alignmentPercentage >= 80.0) {
      return VinkiarColors.hackingGreen;
    }
    if (_alignmentPercentage >= 55.0) {
      return VinkiarColors.vertigoGold;
    }
    return VinkiarColors.panicRed;
  }

  Color _getReputationColor() {
    if (_reputationScore >= 0.85) return VinkiarColors.hackingGreen;
    if (_reputationScore >= 0.50) return VinkiarColors.vertigoGold;
    return VinkiarColors.panicRed;
  }

  String _getReputationTier() {
    if (_reputationScore >= 0.85) return "LINAJE CONFIABLE";
    if (_reputationScore >= 0.50) return "EN EVALUACIÓN";
    return "DISONANCIA RELACIONAL";
  }

  Future<void> _loadSecureData() async {
    try {
      final db = VinkiarSecureDatabase();
      final avatar = await db.getAvatarSheet("LOCAL_USER");
      final soul = await db.getSoulSheet("LOCAL_USER");
      final vectorStr = await db.getUserVector();

      final safetyConfig = await SafetyConfigService().getConfig();

      final stats = avatar?['stats'] as Map<String, dynamic>? ?? {};
      final bool isSim = (stats['is_simulation_mode'] ?? avatar?['is_simulation_mode'] ?? 1) == 1;

      if (mounted) {
        final natural = stats['natural_archetype'] ?? "POR DEFINIR";
        final chosen = stats['chosen_archetype'] ?? "NINGUNO";
        final emp = stats['empathy'] ?? (isSim ? 0 : 82);
        final will = stats['willpower'] ?? (isSim ? 0 : 74);
        final ero = stats['erotism'] ?? (isSim ? 0 : 88);
        final sov = stats['sovereignty'] ?? (isSim ? 0 : 91);

        final alignResult = _computeAlignment(
          natural: natural,
          chosen: chosen,
          empathy: emp,
          willpower: will,
          erotism: ero,
          sovereignty: sov,
        );

        setState(() {
          _avatarData = avatar;
          _soulSheetData = soul;
          _userVector = vectorStr ?? (isSim ? "0-0-0" : "5-8-2");

          _egoVector = EgoVector.fromMap(stats['ego_vector']);
          _erosVector = ErosVector.fromMap(stats['eros_vector']);
          _philiaVector = PhiliaVector.fromMap(stats['philia_vector']);

          _empathy = emp;
          _willpower = will;
          _erotism = ero;
          _sovereignty = sov;

          _naturalArchetype = natural;
          _chosenArchetype = chosen;
          _alignmentPercentage = alignResult['percentage'] as double;
          _alignmentAdvice = alignResult['advice'] as String;

          _currentDecoyType = safetyConfig.decoyType;
          _anchorHandle = safetyConfig.anchorHandle.isNotEmpty ? safetyConfig.anchorHandle : "#ANCLA_SIN_DESIGNAR";
          _anchorPhone = safetyConfig.anchorPhone;
          _anchorEmail = safetyConfig.anchorEmail;

          final repVal = stats['reputation_score'] ?? avatar?['reputation_score'];
          if (repVal is num) {
            _reputationScore = repVal.toDouble().clamp(0.0, 1.0);
          } else {
            _reputationScore = 0.95;
          }

          _loading = false;
        });

        _fetchLineageAudit();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateChosenRole(String newRole) async {
    final alignResult = _computeAlignment(
      natural: _naturalArchetype,
      chosen: newRole,
      empathy: _empathy,
      willpower: _willpower,
      erotism: _erotism,
      sovereignty: _sovereignty,
    );

    final double newPct = alignResult['percentage'] as double;
    final String newAdv = alignResult['advice'] as String;

    setState(() {
      _chosenArchetype = newRole;
      _alignmentPercentage = newPct;
      _alignmentAdvice = newAdv;
    });

    final db = VinkiarSecureDatabase();
    await db.updateAvatarData({
      "chosen_archetype": newRole,
      "alignment_percentage": newPct,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("ROL ACTUALIZADO A: $newRole (Alineación: ${newPct.toStringAsFixed(1)}%)"),
          backgroundColor: _getAlignmentColor(),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // =========================================================================
  // SECCIÓN 5: DIÁLOGOS DE ENEAGRAMA, ANCLA Y CENTINELA
  // =========================================================================

  void _showZoomableEneagramDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: VinkiarColors.abyssBlack,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: VinkiarColors.aegisCyan, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "PROYECCIÓN DEL TRIPLE ENEAGRAMA",
                    style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: VinkiarColors.aegisCyan, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: EneagramChart(
                  vector: _userVector,
                  egoVector: _egoVector,
                  erosVector: _erosVector,
                  philiaVector: _philiaVector,
                  size: 290,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAnchorSelectionModal() async {
    final db = VinkiarSecureDatabase();
    final contacts = await db.getContacts();

    if (!mounted) return;

    final nameController = TextEditingController(
      text: _anchorHandle.startsWith('#') ? _anchorHandle.substring(1) : _anchorHandle,
    );
    final emailController = TextEditingController(text: _anchorEmail);
    final phoneController = TextEditingController(text: _anchorPhone);

    int activeTab = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.vertigoGold, width: 1.5),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 20.0,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.anchor, color: VinkiarColors.vertigoGold, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "DESIGNAR CONTACTO DE CONFIANZA // EL ANCLA",
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        color: VinkiarColors.vertigoGold,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "En caso de alarma SOS o coacción, El Ancla recibirá un email y un mensaje prioritario con tu GPS en tiempo real y la grabación forense en streaming.",
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10.5, height: 1.35),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setModalState(() => activeTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: activeTab == 0 ? VinkiarColors.vertigoGold.withOpacity(0.15) : VinkiarColors.panelDark,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: activeTab == 0 ? VinkiarColors.vertigoGold : Colors.white12,
                            width: activeTab == 0 ? 1.5 : 1.0,
                          ),
                        ),
                        child: Text(
                          "EXTERNO (RECOMENDADO)",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(
                            color: activeTab == 0 ? VinkiarColors.vertigoGold : Colors.white54,
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setModalState(() => activeTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: activeTab == 1 ? VinkiarColors.aegisCyan.withOpacity(0.15) : VinkiarColors.panelDark,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: activeTab == 1 ? VinkiarColors.aegisCyan : Colors.white12,
                            width: activeTab == 1 ? 1.5 : 1.0,
                          ),
                        ),
                        child: Text(
                          "CÉLULA VINKIAR",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(
                            color: activeTab == 1 ? VinkiarColors.aegisCyan : Colors.white54,
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (activeTab == 1) ...[
                if (contacts.isNotEmpty) ...[
                  Text(
                    "SELECCIONA UN MIEMBRO DE TU CÉLULA:",
                    style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 9.0, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: VinkiarColors.panelDark,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: contacts.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (_, index) {
                        final c = contacts[index];
                        final handle = c['alias'] ?? c['id'];
                        final isCurrent = _anchorHandle == handle;
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.person_pin, color: isCurrent ? VinkiarColors.aegisCyan : Colors.white54, size: 18),
                            title: Text(handle, style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11)),
                            subtitle: Text(c['character_class'] ?? 'Vínculo ZKA', style: const TextStyle(color: Colors.white38, fontSize: 9)),
                            trailing: isCurrent ? const Icon(Icons.check_circle, color: VinkiarColors.aegisCyan, size: 16) : null,
                            onTap: () {
                              setModalState(() {
                                nameController.text = handle.toString().replaceAll('#', '');
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: VinkiarColors.panelDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "No tienes contactos agregados en tu Célula ZKA todavía. Puedes introducir los datos de un contacto externo en la pestaña izquierda.",
                      style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],

              TextField(
                controller: nameController,
                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11),
                decoration: const InputDecoration(
                  labelText: "NOMBRE / ALIAS DEL ANCLA (ej. Elena, Carlos)",
                  labelStyle: TextStyle(color: Colors.white38, fontSize: 9.5),
                  filled: true,
                  fillColor: VinkiarColors.panelDark,
                  isDense: true,
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.vertigoGold)),
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11),
                decoration: const InputDecoration(
                  labelText: "CORREO ELECTRÓNICO (RECIBIRÁ LA CARTA DE ANCLAJE)",
                  labelStyle: TextStyle(color: Colors.white38, fontSize: 9.5),
                  filled: true,
                  fillColor: VinkiarColors.panelDark,
                  isDense: true,
                  prefixIcon: Icon(Icons.email_outlined, color: VinkiarColors.vertigoGold, size: 16),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.vertigoGold)),
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11),
                decoration: const InputDecoration(
                  labelText: "TELÉFONO MÓVIL (WHATSAPP / SMS CONTINGENCIA)",
                  labelStyle: TextStyle(color: Colors.white38, fontSize: 9.5),
                  filled: true,
                  fillColor: VinkiarColors.panelDark,
                  isDense: true,
                  prefixIcon: Icon(Icons.phone_outlined, color: VinkiarColors.vertigoGold, size: 16),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.vertigoGold)),
                ),
              ),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VinkiarColors.vertigoGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    "GUARDAR Y ENVIAR PROTOCOLO AL ANCLA",
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10.5),
                  ),
                  onPressed: () async {
                    final rawName = nameController.text.trim();
                    final email = emailController.text.trim();
                    final phone = phoneController.text.trim();

                    if (rawName.isEmpty && email.isEmpty && phone.isEmpty) {
                      return;
                    }

                    final formattedHandle = rawName.startsWith('#') ? rawName : '#$rawName';
                    final victimAlias = (_avatarData?['alias']?.isNotEmpty == true)
                        ? _avatarData!['alias']
                        : "Master";

                    final emailDispatched = await SafetyConfigService().saveAnchorAndNotifyServer(
                      victimHandle: victimAlias,
                      anchorHandle: formattedHandle,
                      anchorEmail: email,
                      anchorPhone: phone,
                      anchorName: rawName.replaceAll('#', ''),
                    );

                    await VinkiarSecureDatabase().updateAvatarData({
                      'anchor_handle': formattedHandle,
                      'anchor_phone': phone,
                      'anchor_email': email,
                    });

                    await _loadSecureData();

                    if (modalCtx.mounted) Navigator.pop(modalCtx);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: emailDispatched ? VinkiarColors.hackingGreen : VinkiarColors.vertigoGold,
                          content: Text(
                            email.isNotEmpty
                                ? (emailDispatched
                                    ? "🛡️ Ancla guardada. Email explicativo despachado a $email."
                                    : "🛡️ Ancla guardada localmente (pendiente de conexión SMTP).")
                                : "🛡️ Ancla guardada para telemetría telefónica.",
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSentinelControlDialog(String currentSafeword) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.panicRed, width: 1.5),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 20.0,
            right: 20.0,
            top: 20.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_moon_outlined, color: VinkiarColors.panicRed, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "CENTINELA // PROTOCOLO DE DEFENSA",
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        color: VinkiarColors.panicRed,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Configura la palabra de seguridad acústica, El Ancla de confianza y los códigos de marcación de desarme o coacción.",
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, height: 1.4),
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VinkiarColors.panelDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("PALABRA DE SEGURIDAD (SAFEWORD):", style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 8.5)),
                          const SizedBox(height: 2),
                          Text(
                            "\"${currentSafeword.toUpperCase()}\"",
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              color: VinkiarColors.vertigoGold,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: VinkiarColors.vertigoGold),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      icon: const Icon(Icons.edit, size: 14, color: VinkiarColors.vertigoGold),
                      label: Text("EDITAR", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 10)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showEditDialog("EDITAR PALABRA DE SEGURIDAD", currentSafeword, "safeword");
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  _showAnchorSelectionModal();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VinkiarColors.panelDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.anchor, color: VinkiarColors.vertigoGold, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "CONTACTO DE CONFIANZA // EL ANCLA:",
                                    style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 8.5),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _anchorHandle,
                                    style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 12, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_anchorEmail.isNotEmpty)
                                    Text(
                                      _anchorEmail,
                                      style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 9),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.edit, size: 14, color: VinkiarColors.vertigoGold),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: VinkiarColors.panelDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            _currentDecoyType == DecoyType.clock
                                ? Icons.access_time
                                : (_currentDecoyType == DecoyType.notes ? Icons.sticky_note_2 : Icons.calculate_outlined),
                            size: 16,
                            color: VinkiarColors.aegisCyan,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "SEÑUELO:",
                              style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 9.0, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<DecoyType>(
                            value: _currentDecoyType,
                            isExpanded: true,
                            dropdownColor: VinkiarColors.abyssBlack,
                            isDense: true,
                            alignment: AlignmentDirectional.centerEnd,
                            style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 9.0, fontWeight: FontWeight.bold),
                            items: const [
                              DropdownMenuItem(
                                value: DecoyType.calculator,
                                child: Text("CALCULADORA", overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
                              ),
                              DropdownMenuItem(
                                value: DecoyType.clock,
                                child: Text("RELOJ ANALÓGICO", overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
                              ),
                              DropdownMenuItem(
                                value: DecoyType.notes,
                                child: Text("BLOC DE NOTAS", overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
                              ),
                            ],
                            onChanged: (newType) async {
                              if (newType != null) {
                                setModalState(() => _currentDecoyType = newType);
                                setState(() => _currentDecoyType = newType);
                                await SafetyConfigService().updateDecoyType(newType);
                                await VinkiarSecureDatabase().updateAvatarData({'decoy_type': newType.name});
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: VinkiarColors.hackingGreen),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      ),
                      icon: const Icon(Icons.lock_open, size: 14, color: VinkiarColors.hackingGreen),
                      label: Text(
                        "PIN SEGURO (DESARME)",
                        style: GoogleFonts.jetBrainsMono(color: VinkiarColors.hackingGreen, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        final currentSafe = (_avatarData?['stats'] as Map<String, dynamic>?)?['safe_pin'] ?? "9999";
                        _showEditDialog("CONFIGURAR PIN SEGURO", currentSafe.toString(), "safe_pin");
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: VinkiarColors.panicRed),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      ),
                      icon: const Icon(Icons.warning_amber_rounded, size: 14, color: VinkiarColors.panicRed),
                      label: Text(
                        "PIN DE COACCIÓN (SILENTE)",
                        style: GoogleFonts.jetBrainsMono(color: VinkiarColors.panicRed, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        final currentDuress = (_avatarData?['stats'] as Map<String, dynamic>?)?['duress_pin'] ?? "1111";
                        _showEditDialog("CONFIGURAR PIN DE COACCIÓN", currentDuress.toString(), "duress_pin");
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSentinelListening ? VinkiarColors.panelDark : VinkiarColors.hackingGreen,
                    foregroundColor: _isSentinelListening ? Colors.white70 : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(_isSentinelListening ? Icons.pause_circle_outline : Icons.sensors, size: 18),
                  label: Text(
                    _isSentinelListening ? "DESACTIVAR VIGILANCIA ACÚSTICA" : "ACTIVAR VIGILANCIA ACÚSTICA",
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 9.5),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _isSentinelListening = !_isSentinelListening;
                    });
                    final sentinel = AcousticSentinelService();
                    if (_isSentinelListening) {
                      sentinel.startVigilance();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: VinkiarColors.hackingGreen,
                          content: Text("🛡️ Centinela activo: monitorizando Safeword y caída de objeto."),
                        ),
                      );
                    } else {
                      sentinel.stopVigilance();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: VinkiarColors.panelDark,
                          content: Text("Centinela en reposo."),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),

              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: VinkiarColors.panicRed),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      ),
                      icon: const Icon(Icons.emergency_outlined, size: 15, color: VinkiarColors.panicRed),
                      label: Text(
                        "SIMULAR PAUSA SSC",
                        style: GoogleFonts.jetBrainsMono(color: VinkiarColors.panicRed, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SmokeScreenOverlay(
                              reason: SentinelTriggerReason.safewordSpoken,
                              isEmergencySOS: false,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: VinkiarColors.vertigoGold),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      ),
                      icon: const Icon(Icons.visibility_off, size: 15, color: VinkiarColors.vertigoGold),
                      label: Text(
                        "PROBAR SEÑUELO",
                        style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 9.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SmokeScreenOverlay(
                              reason: SentinelTriggerReason.hardwarePanic,
                              isEmergencySOS: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // SECCIÓN 6: COMPONENTES DE INTERFAZ Y TARJETAS DE LINAJE / AVALES
  // =========================================================================

  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    required Color accentColor,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget child,
    String? badgeText,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExpanded ? accentColor.withOpacity(0.8) : accentColor.withOpacity(0.3),
          width: isExpanded ? 1.4 : 1.0,
        ),
      ),
      child: Material(
        color: VinkiarColors.panelDark,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(icon, color: accentColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.jetBrainsMono(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: accentColor.withOpacity(0.6), width: 0.8),
                              ),
                              child: Text(
                                badgeText,
                                style: GoogleFonts.jetBrainsMono(
                                  color: accentColor,
                                  fontSize: 8.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: accentColor,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              const Divider(color: Colors.white12, height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Material(
                  color: Colors.transparent,
                  child: child,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Tarjeta de origen de linaje (Avalista que introdujo al usuario actual)
  Widget _buildSponsorCard() {
    final sponsorHandle = (_sponsorInfo?['handle'] ?? 'GENESIS // NODO FUNDADOR').toString();
    final sponsorCode = (_sponsorInfo?['invite_code'] ?? '').toString();
    final sponsorStatus = (_sponsorInfo?['estado_aval'] ?? 'ACTIVO').toString().toUpperCase();
    final isRevoked = sponsorStatus == 'REVOCADO';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: VinkiarColors.abyssBlack,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isRevoked
              ? VinkiarColors.panicRed.withOpacity(0.5)
              : VinkiarColors.aegisCyan.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_tree_outlined,
            color: isRevoked ? VinkiarColors.panicRed : VinkiarColors.aegisCyan,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AVALADO EN LA RED POR:",
                  style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 8.5),
                ),
                const SizedBox(height: 2),
                Text(
                  sponsorHandle,
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (sponsorCode.isNotEmpty)
                  Text(
                    "Llave de entrada: $sponsorCode",
                    style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 9),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: isRevoked
                  ? VinkiarColors.panicRed.withOpacity(0.15)
                  : VinkiarColors.hackingGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isRevoked ? VinkiarColors.panicRed : VinkiarColors.hackingGreen,
              ),
            ),
            child: Text(
              isRevoked ? "AVAL REVOCADO" : "AVAL ACTIVO",
              style: GoogleFonts.jetBrainsMono(
                color: isRevoked ? VinkiarColors.panicRed : VinkiarColors.hackingGreen,
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta individual de cada avatar avalado por el usuario, con botón Retirar Aval
  Widget _buildLineageNodeItem(dynamic node) {
    final String level = (node['conduct_level'] ?? 'GREEN').toString().toUpperCase();
    final int penalty = (node['penalty_pct'] as num?)?.toInt() ?? 0;
    final String handle = node['invitee_handle']?.toString() ?? '#Avatar';
    final String inviteCode = node['invite_code']?.toString() ?? '';
    final String archetype = node['character_class']?.toString() ?? 'INICIADO ZKA';
    final String reason = node['reason']?.toString() ?? '';
    final bool isRevoked = level == 'REVOKED';

    Color statusColor = VinkiarColors.hackingGreen;
    if (level == 'RED') statusColor = VinkiarColors.panicRed;
    if (level == 'YELLOW') statusColor = VinkiarColors.vertigoGold;
    if (isRevoked) statusColor = Colors.purpleAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: VinkiarColors.abyssBlack,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            handle,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              color: isRevoked ? Colors.white54 : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "$archetype${inviteCode.isNotEmpty ? ' · $inviteCode' : ''}",
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 8.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isRevoked
                    ? "AVAL RETIRADO"
                    : (penalty > 0 ? "-$penalty% HALO" : "EN REGLA"),
                style: GoogleFonts.jetBrainsMono(
                  color: isRevoked
                      ? Colors.purpleAccent
                      : (penalty > 0 ? VinkiarColors.panicRed : VinkiarColors.hackingGreen),
                  fontSize: 9.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            reason,
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10),
          ),
          if (!isRevoked) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (penalty > 0) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: statusColor.withOpacity(0.7)),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(Icons.handshake_outlined, size: 13, color: statusColor),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "CO-REGULACIÓN ZK",
                          style: GoogleFonts.jetBrainsMono(
                            color: statusColor,
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatQAScreen(
                              initialGuildId: "COREGULACION_${handle.replaceAll('#', '')}",
                              initialTargetName: "CO-REGULACIÓN // $handle",
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (inviteCode.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: VinkiarColors.panicRed.withOpacity(0.7)),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.link_off, size: 13, color: VinkiarColors.panicRed),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "RETIRAR AVAL",
                          style: GoogleFonts.jetBrainsMono(
                            color: VinkiarColors.panicRed,
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      onPressed: () => _confirmAndRevokeAval(inviteCode, handle),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccessibilitySlider(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final double currentScale = appState.textScaleFactor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.text_fields, color: VinkiarColors.aegisCyan, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "ESCALA VISUAL DE TEXTO",
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        color: VinkiarColors.aegisCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "${(currentScale * 100).toInt()}%",
              style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: currentScale,
          min: 0.8,
          max: 1.4,
          divisions: 6,
          activeColor: VinkiarColors.aegisCyan,
          inactiveColor: Colors.white12,
          onChanged: (val) => appState.updateTextScaleFactor(val),
        ),
      ],
    );
  }

  Widget _buildUnifiedMetricsDashboard() {
    final bool isCalibrating = _userVector == "0-0-0" || _userVector == null;

    final int egoLoad = isCalibrating ? 0 : ((_egoVector?.lider ?? 0) > 0 ? 85 : 30);
    final int erosLoad = isCalibrating ? 0 : ((_erosVector?.kinky ?? 0) > 0 ? 90 : 40);
    final int philiaLoad = isCalibrating ? 0 : ((_philiaVector?.seguro ?? 0) > 0 ? 80 : 35);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VinkiarColors.abyssBlack,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "SINTONIZACIÓN DE HOJA DE ALMA",
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    color: VinkiarColors.aegisCyan,
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isCalibrating ? "ESTADO: EN FORJA" : "ESTADO: CALIBRADO",
                style: GoogleFonts.jetBrainsMono(
                  color: isCalibrating ? VinkiarColors.vertigoGold : VinkiarColors.hackingGreen,
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text("ATRIBUTOS SOMÁTICOS:", style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 8.5)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatIndicator("EMPATÍA", _empathy, VinkiarColors.aegisCyan),
              _buildStatIndicator("VOLUNTAD", _willpower, VinkiarColors.vertigoGold),
              _buildStatIndicator("ASTUCIA", _erotism, VinkiarColors.lotusPink),
              _buildStatIndicator("SOBERANÍA", _sovereignty, VinkiarColors.hackingGreen),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),

          Text("RESONANCIA POR ÓRBITA:", style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 8.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildWheelIndicator(
                  "I: EGO",
                  isCalibrating ? "0%" : "$egoLoad%",
                  VinkiarColors.vertigoGold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildWheelIndicator(
                  "II: EROS",
                  isCalibrating ? "0%" : "$erosLoad%",
                  VinkiarColors.lotusPink,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildWheelIndicator(
                  "III: PHILIA",
                  isCalibrating ? "0%" : "$philiaLoad%",
                  VinkiarColors.aegisCyan,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWheelIndicator(String wheelTitle, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: VinkiarColors.panelDark,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(wheelTitle, style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 7.5)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatIndicator(String label, int value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.jetBrainsMono(color: VinkiarColors.textDim, fontSize: 8.5)),
        const SizedBox(height: 4),
        Text("$value/100", style: GoogleFonts.jetBrainsMono(color: color, fontSize: 11.5, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLimitBox(String title, List<dynamic> items, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VinkiarColors.abyssBlack,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 2.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: VinkiarTheme.labelCaps.copyWith(color: color, fontSize: 8.5),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.edit, color: color.withOpacity(0.7), size: 13),
            ],
          ),
          const SizedBox(height: 6),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: color.withOpacity(0.5), size: 5),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.toString(),
                        style: const TextStyle(fontSize: 11, color: VinkiarColors.textHdr),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _showEditDialog(String title, String currentValue, String dbKey, {int maxLines = 1}) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: VinkiarColors.inkBlack,
          shape: const Border(top: BorderSide(color: VinkiarColors.aegisCyan, width: 2)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: VinkiarTheme.labelCaps.copyWith(color: VinkiarColors.aegisCyan, fontSize: 12)),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  maxLines: maxLines,
                  keyboardType: (dbKey == "safe_pin" || dbKey == "duress_pin") ? TextInputType.number : TextInputType.text,
                  style: VinkiarTheme.terminalData.copyWith(color: VinkiarColors.textHdr, fontSize: 11),
                  decoration: const InputDecoration(
                    filled: true,
                    fillColor: VinkiarColors.panelDark,
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.aegisCyan, width: 1)),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.aegisCyan, width: 2)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("CANCELAR", style: TextStyle(color: VinkiarColors.textDim)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VinkiarColors.aegisCyan,
                        foregroundColor: VinkiarColors.abyssBlack,
                      ),
                      onPressed: () async {
                        final newValue = controller.text.trim();
                        await VinkiarSecureDatabase().updateAvatarData({dbKey: newValue});

                        if (dbKey == "safeword") {
                          AcousticSentinelService().updateSafeword(newValue);
                          await SafetyConfigService().updateSafeword(newValue);
                        } else if (dbKey == "safe_pin") {
                          await SafetyConfigService().updateSafePin(newValue);
                        } else if (dbKey == "duress_pin") {
                          await SafetyConfigService().updateDuressPin(newValue);
                        }

                        await _loadSecureData();
                        if (mounted) Navigator.of(context).pop();
                      },
                      child: const Text("GUARDAR", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // SECCIÓN 7: CONSTRUCCIÓN DE PANTALLA PRINCIPAL (BUILD)
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: VinkiarColors.abyssBlack,
        body: Center(child: CircularProgressIndicator(color: VinkiarColors.aegisCyan)),
      );
    }

    final characterClass = _avatarData?['character_class'] ?? "INICIADO ZKA";
    final level = _avatarData?['level'] ?? 1;
    final stats = _avatarData?['stats'] as Map<String, dynamic>? ?? {};

    final displayAlias = (_avatarData?['alias']?.isNotEmpty == true)
        ? _avatarData!['alias']
        : ((stats['alias']?.isNotEmpty == true) ? stats['alias'] : characterClass);

    final defaultGreen = ["Diálogo abierto", "Co-regulación"];
    final defaultYellow = ["Exposición de secretos"];
    final defaultRed = ["Sincericidio destructivo"];

    final greenItems = (stats['limites_verdes']?.isNotEmpty == true)
        ? stats['limites_verdes'].toString().split(',').map((e) => e.trim()).toList()
        : defaultGreen;

    final yellowItems = (stats['limites_amarillos']?.isNotEmpty == true)
        ? stats['limites_amarillos'].toString().split(',').map((e) => e.trim()).toList()
        : defaultYellow;

    final redItems = (stats['limites_rojos']?.isNotEmpty == true)
        ? stats['limites_rojos'].toString().split(',').map((e) => e.trim()).toList()
        : defaultRed;

    final displaySafeword = (stats['safeword']?.isNotEmpty == true) ? stats['safeword'] : "MANGO";
    final reputationColor = _getReputationColor();
    final reputationTier = _getReputationTier();

    return Scaffold(
      backgroundColor: VinkiarColors.abyssBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HUD SUPERIOR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("LA BÓVEDA", style: VinkiarTheme.labelCaps.copyWith(fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          "Búnker Criptográfico ZKA",
                          style: VinkiarTheme.terminalSm,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ZkpSovereignVaultKeyButton(),
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: const EdgeInsets.all(4),
                        tooltip: "Exportar Backup Cifrado",
                        icon: const Icon(Icons.qr_code, color: VinkiarColors.vertigoGold, size: 20),
                        onPressed: () async {
                          try {
                            final path = await VinkiarSecureDatabase().getDatabasePath();
                            await Share.shareXFiles([XFile(path)], text: 'Backup Vinkiar OS');
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error al exportar: $e"), backgroundColor: VinkiarColors.panicRed),
                            );
                          }
                        },
                      ),
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: const EdgeInsets.all(4),
                        tooltip: "Acceder a La Armería",
                        icon: const Icon(Icons.storefront, color: VinkiarColors.vertigoGold, size: 22),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ArmeriaScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // =========================================================
              // MÓDULO 1: MÁSCARA PÚBLICA & PERFIL (DESPLEGABLE)
              // =========================================================
              _buildCollapsibleSection(
                title: "MÁSCARA PÚBLICA & PERFIL",
                icon: Icons.person_outline,
                accentColor: VinkiarColors.aegisCyan,
                badgeText: "LVL $level",
                isExpanded: _isProfileExpanded,
                onToggle: () => setState(() => _isProfileExpanded = !_isProfileExpanded),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: VinkiarColors.abyssBlack,
                                border: Border.all(color: reputationColor, width: 2.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: reputationColor.withOpacity(0.55),
                                    blurRadius: 14,
                                    spreadRadius: 2.5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.shield_moon_outlined,
                                  color: reputationColor,
                                  size: 32,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () => _showEditDialog("EDITAR ALIAS", displayAlias, "alias"),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayAlias,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.edit, color: VinkiarColors.aegisCyan, size: 14),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                characterClass,
                                style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 9.5),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: reputationColor),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "$reputationTier (${(_reputationScore * 100).toInt()}%)",
                                    style: GoogleFonts.jetBrainsMono(
                                      color: reputationColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () => _showEditDialog(
                        "MANIFIESTO / BIO DEL AVATAR",
                        stats['bio'] ?? "Explorador somático ZKA.",
                        "bio",
                        maxLines: 4,
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: VinkiarColors.abyssBlack,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                stats['bio'] ?? "Añade una descripción o manifiesto para tu Avatar...",
                                style: GoogleFonts.outfit(
                                  color: stats['bio'] != null ? Colors.white70 : Colors.white30,
                                  fontSize: 11,
                                  fontStyle: stats['bio'] == null ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ),
                            const Icon(Icons.edit, size: 13, color: VinkiarColors.aegisCyan),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VinkiarColors.abyssBlack,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("ARQUETIPO NATURAL:", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.textDim, fontSize: 9.0)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _naturalArchetype,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: _naturalArchetype == "POR DEFINIR" ? Colors.grey : VinkiarColors.vertigoGold,
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "ROL ELEGIDO:",
                                style: GoogleFonts.jetBrainsMono(
                                  color: VinkiarColors.aegisCyan,
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _availableChosenRoles.contains(_chosenArchetype) ? _chosenArchetype : "NINGUNO",
                                      dropdownColor: VinkiarColors.panelDark,
                                      isDense: true,
                                      isExpanded: true,
                                      alignment: AlignmentDirectional.centerEnd,
                                      style: GoogleFonts.jetBrainsMono(
                                        color: VinkiarColors.aegisCyan,
                                        fontSize: 9.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      items: _availableChosenRoles.map((role) {
                                        return DropdownMenuItem<String>(
                                          value: role,
                                          child: Text(
                                            role,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.end,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) _updateChosenRole(val);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  "ALINEACIÓN SOMÁTICA:",
                                  style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 9.0),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _chosenArchetype == "NINGUNO"
                                    ? "SIN ROL"
                                    : "${_alignmentPercentage.toStringAsFixed(1)}%",
                                style: GoogleFonts.jetBrainsMono(
                                  color: _getAlignmentColor(),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (_chosenArchetype != "NINGUNO") ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (_alignmentPercentage / 100.0).clamp(0.0, 1.0),
                                backgroundColor: Colors.white12,
                                valueColor: AlwaysStoppedAnimation<Color>(_getAlignmentColor()),
                                minHeight: 4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: VinkiarColors.panelDark,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _getAlignmentColor().withOpacity(0.35)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.tips_and_updates_outlined, color: _getAlignmentColor(), size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _alignmentAdvice,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white70,
                                      fontSize: 10.0,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: VinkiarColors.aegisCyan),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.face_retouching_natural, color: VinkiarColors.aegisCyan, size: 16),
                        label: Text(
                          "CONFIGURAR MÁSCARA PÚBLICA & VISIBILIDAD",
                          style: GoogleFonts.jetBrainsMono(
                            color: VinkiarColors.aegisCyan,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          final formattedHandle = displayAlias.toString().startsWith('#')
                              ? displayAlias.toString()
                              : '#$displayAlias';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MascaraPublicaScreen(
                                handle: formattedHandle,
                                archetype: _chosenArchetype != "NINGUNO" ? _chosenArchetype : characterClass,
                                level: level,
                                reputationScore: _reputationScore,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // =========================================================
              // MÓDULO 2: GEOMETRÍA DEL ALMA & TRIPLE ENEAGRAMA
              // =========================================================
              _buildCollapsibleSection(
                title: "GEOMETRÍA DEL ALMA & ENEAGRAMA",
                icon: Icons.all_inclusive,
                accentColor: VinkiarColors.vertigoGold,
                badgeText: _userVector == "0-0-0" ? "0-0-0" : _userVector,
                isExpanded: _isEneagramExpanded,
                onToggle: () => setState(() => _isEneagramExpanded = !_isEneagramExpanded),
                child: Column(
                  children: [
                    _buildUnifiedMetricsDashboard(),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _showZoomableEneagramDialog(context),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Center(
                            child: EneagramChart(
                              vector: _userVector,
                              egoVector: _egoVector,
                              erosVector: _erosVector,
                              philiaVector: _philiaVector,
                              size: 240,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: VinkiarColors.abyssBlack.withOpacity(0.85),
                              shape: BoxShape.circle,
                              border: Border.all(color: VinkiarColors.vertigoGold),
                            ),
                            child: const Icon(Icons.zoom_in, color: VinkiarColors.vertigoGold, size: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "PULSA PARA AMPLIAR LA PROYECCIÓN",
                      style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 8.5),
                    ),
                  ],
                ),
              ),

              // =========================================================
              // MÓDULO 3: CÉLULA DE CONFIANZA & AUDITORÍA DE LINAJE REAL
              // =========================================================
              _buildCollapsibleSection(
                title: "CÉLULA DE CONFIANZA & LINAJE",
                icon: Icons.group_outlined,
                accentColor: VinkiarColors.vertigoGold,
                badgeText: _totalLineagePenalty > 0 ? "-${_totalLineagePenalty.toInt()}% HALO" : "ARMÓNICO",
                isExpanded: _isTribeExpanded,
                onToggle: () {
                  setState(() => _isTribeExpanded = !_isTribeExpanded);
                  if (_isTribeExpanded) {
                    _fetchLineageAudit();
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tu reputación lúdica está ligada a la conducta de los avatares que accedan con tu código ZK firmado. Si un invitado genera disonancia, puedes iniciar co-regulación o retirar tu aval.",
                      style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, height: 1.35),
                    ),
                    const SizedBox(height: 12),

                    // Avalista que te introdujo en la red
                    _buildSponsorCard(),

                    // Tu código de invitación activo (reutilizado desde PostgreSQL)
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _copyInviteCode,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: VinkiarColors.abyssBlack,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isInviteReused ? "TU CÓDIGO ZK ACTIVO (REUTILIZADO):" : "TU CÓDIGO ZK ACTIVO:",
                                    style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 8.0),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _inviteCode,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.jetBrainsMono(
                                      color: VinkiarColors.vertigoGold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          tooltip: "Copiar código",
                          icon: const Icon(Icons.copy, color: VinkiarColors.aegisCyan, size: 18),
                          onPressed: _copyInviteCode,
                          style: IconButton.styleFrom(
                            side: BorderSide(color: VinkiarColors.aegisCyan.withOpacity(0.5)),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: "Compartir invitación",
                          icon: const Icon(Icons.share, color: VinkiarColors.vertigoGold, size: 18),
                          onPressed: _shareInviteCode,
                          style: IconButton.styleFrom(
                            side: BorderSide(color: VinkiarColors.vertigoGold.withOpacity(0.5)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            "AVATARES AVALADOS POR TI (${_lineageNodes.length})",
                            style: GoogleFonts.jetBrainsMono(
                              color: VinkiarColors.aegisCyan,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _fetchLineageAudit,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.refresh, color: VinkiarColors.aegisCyan, size: 12),
                              const SizedBox(width: 4),
                              Text("CALIBRAR", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 9)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingLineage)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2, color: VinkiarColors.aegisCyan),
                      ))
                    else if (_lineageSyncError != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: VinkiarColors.abyssBlack,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: VinkiarColors.panicRed.withOpacity(0.4)),
                        ),
                        child: Text(
                          _lineageSyncError!,
                          style: GoogleFonts.jetBrainsMono(color: VinkiarColors.panicRed, fontSize: 9.5),
                        ),
                      )
                    else if (_lineageNodes.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: VinkiarColors.abyssBlack,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          "Aún no has introducido invitados en la red con tu código ZK. Comparte tu código activo cuando quieras avalar a alguien de confianza.",
                          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10.5),
                        ),
                      )
                    else if (_lineageNodes.length > 3)
                      Container(
                        height: 270,
                        padding: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: VinkiarColors.abyssBlack.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: RawScrollbar(
                          thumbColor: VinkiarColors.vertigoGold.withOpacity(0.5),
                          thumbVisibility: true,
                          radius: const Radius.circular(4),
                          thickness: 3,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(6),
                            itemCount: _lineageNodes.length,
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (ctx, i) => _buildLineageNodeItem(_lineageNodes[i]),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _lineageNodes.map((node) => _buildLineageNodeItem(node)).toList(),
                      ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.diversity_3, color: VinkiarColors.aegisCyan, size: 20),
                        title: Text(
                          "GESTIONAR CONTACTOS & CÉLULA",
                          style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("Historial de pings y semáforo relacional SSC", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 9.5)),
                        trailing: const Icon(Icons.chevron_right, color: VinkiarColors.aegisCyan, size: 18),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsScreen())),
                      ),
                    ),
                  ],
                ),
              ),

              // =========================================================
              // MÓDULO 4: NÚCLEO PRIVADO & SALVAGUARDAS SSC (DESPLEGABLE)
              // =========================================================
              _buildCollapsibleSection(
                title: "NÚCLEO PRIVADO & LÍMITES SSC",
                icon: Icons.shield_outlined,
                accentColor: VinkiarColors.panicRed,
                isExpanded: _isSscExpanded,
                onToggle: () => setState(() => _isSscExpanded = !_isSscExpanded),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _showEditDialog("EDITAR LÍMITES VERDES (DESEADO)", greenItems.join(", "), "limites_verdes", maxLines: 3),
                      child: _buildLimitBox("LÍMITES VERDES (DESEADO)", greenItems, VinkiarColors.hackingGreen),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _showEditDialog("EDITAR LÍMITES AMARILLOS (NEGOCIABLE)", yellowItems.join(", "), "limites_amarillos", maxLines: 3),
                      child: _buildLimitBox("LÍMITES AMARILLOS (NEGOCIABLE)", yellowItems, VinkiarColors.vertigoGold),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _showEditDialog("EDITAR LÍMITES ROJOS (PROHIBIDO)", redItems.join(", "), "limites_rojos", maxLines: 3),
                      child: _buildLimitBox("LÍMITES ROJOS (PROHIBIDO)", redItems, VinkiarColors.panicRed),
                    ),
                    const SizedBox(height: 14),

                    InkWell(
                      onTap: _showAnchorSelectionModal,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VinkiarColors.abyssBlack,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.anchor, color: VinkiarColors.vertigoGold, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "CONTACTO DE CONFIANZA // EL ANCLA:",
                                          style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 8.5),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _anchorHandle,
                                          style: GoogleFonts.jetBrainsMono(
                                            color: VinkiarColors.vertigoGold,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (_anchorEmail.isNotEmpty)
                                          Text(
                                            _anchorEmail,
                                            style: GoogleFonts.jetBrainsMono(
                                              color: Colors.white38,
                                              fontSize: 9.0,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right, color: VinkiarColors.vertigoGold, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    InkWell(
                      onTap: () => _showSentinelControlDialog(displaySafeword),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VinkiarColors.abyssBlack,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _isSentinelListening ? VinkiarColors.hackingGreen : VinkiarColors.panicRed.withOpacity(0.5),
                            width: _isSentinelListening ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    _isSentinelListening ? Icons.sensors : Icons.shield_moon_outlined,
                                    color: _isSentinelListening ? VinkiarColors.hackingGreen : VinkiarColors.panicRed,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "CENTINELA // SAFEWORD: \"${displaySafeword.toString().toUpperCase()}\"",
                                          style: GoogleFonts.jetBrainsMono(
                                            color: VinkiarColors.vertigoGold,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          "SEÑUELO ACTIVO: ${_currentDecoyType == DecoyType.clock ? 'RELOJ ANALÓGICO' : (_currentDecoyType == DecoyType.notes ? 'BLOC DE NOTAS' : 'CALCULADORA')}",
                                          style: GoogleFonts.jetBrainsMono(
                                            color: VinkiarColors.aegisCyan,
                                            fontSize: 8.5,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.tune,
                              color: _isSentinelListening ? VinkiarColors.hackingGreen : VinkiarColors.panicRed,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // =========================================================
              // MÓDULO 5: HERRAMIENTAS & DIARIO DE BÓVEDA (DESPLEGABLE)
              // =========================================================
              _buildCollapsibleSection(
                title: "HERRAMIENTAS & BITÁCORA",
                icon: Icons.tune,
                accentColor: VinkiarColors.aegisCyan,
                isExpanded: _isToolsExpanded,
                onToggle: () => setState(() => _isToolsExpanded = !_isToolsExpanded),
                child: Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.auto_stories, color: VinkiarColors.vertigoGold, size: 18),
                        title: Text(
                          "BITÁCORA CLANDESTINA (DIARIO)",
                          style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("Reflexiones íntimas que calibran el Eneagrama", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 9.5)),
                        trailing: const Icon(Icons.chevron_right, color: VinkiarColors.vertigoGold, size: 18),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const VaultDiaryScreen()),
                          ).then((_) => _loadSecureData());
                        },
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 16),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.storefront, color: VinkiarColors.vertigoGold, size: 18),
                        title: Text(
                          "SUMINISTROS EN LA ARMERÍA",
                          style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("Recarga de energía somática y alijos de Vinks", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 9.5)),
                        trailing: const Icon(Icons.chevron_right, color: VinkiarColors.vertigoGold, size: 18),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ArmeriaScreen()),
                          );
                        },
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 16),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.vpn_key_outlined, color: VinkiarColors.vertigoGold, size: 18),
                        title: Text(
                          "LLAVES SOBERANAS, 2FA & SEMILLA",
                          style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("Conectar/desconectar Keyfile, método de acceso y 12 palabras", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 9.5)),
                        trailing: const Icon(Icons.chevron_right, color: VinkiarColors.vertigoGold, size: 18),
                        onTap: () => ZkpSovereignSecuritySheet.show(context),
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 16),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.help_outline, color: VinkiarColors.aegisCyan, size: 18),
                        title: Text(
                          "GUÍAS CONTEXTUALES DE VINKIAR OS",
                          style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text("Explorar manual por secciones o reactivar popups", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 9.5)),
                        trailing: const Icon(Icons.chevron_right, color: VinkiarColors.aegisCyan, size: 18),
                        onTap: () => _openContextualGuidesHub(context),
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 16),
                    _buildAccessibilitySlider(context),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // BOTÓN PERMANENTE: SINTONIZAR CON VINKI
              InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const VinkiChatModal(userId: "LOCAL_USER"),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: VinkiarColors.abyssBlack,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: VinkiarColors.aegisCyan, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: VinkiarColors.aegisCyan.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.psychology, color: VinkiarColors.aegisCyan, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "SINTONIZAR CON VINKI",
                              style: GoogleFonts.jetBrainsMono(
                                color: VinkiarColors.aegisCyan,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Diálogo libre para explorar tu Eneagrama y ajustar stats.",
                              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 9.5),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.forum_outlined, color: VinkiarColors.aegisCyan, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openContextualGuidesHub(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: VinkiarColors.abyssBlack,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: VinkiarColors.aegisCyan, width: 1.8)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "CÓDICE DE GUÍAS CONTEXTUALES",
                      style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  "Pulsa cualquier módulo para abrir su ficha táctica o reactiva los avisos automáticos de primer uso.",
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11.5),
                ),
                const SizedBox(height: 14),
                ...OnboardingGuideService.specs.values.map((spec) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        tileColor: VinkiarColors.panelDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: spec.accentColor.withOpacity(0.35)),
                        ),
                        leading: Icon(spec.icon, color: spec.accentColor, size: 20),
                        title: Text(
                          spec.title,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          spec.codeTag,
                          style: GoogleFonts.jetBrainsMono(color: spec.accentColor, fontSize: 9),
                        ),
                        trailing: Icon(Icons.open_in_new, color: spec.accentColor, size: 16),
                        onTap: () {
                          Navigator.pop(ctx);
                          OnboardingGuideService().showIfFirstTime(context, spec.topic, forceShow: true);
                        },
                      ),
                    )),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VinkiarColors.hackingGreen,
                      side: const BorderSide(color: VinkiarColors.hackingGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(
                      "REACTIVAR POPUPS EN TODAS LAS PANTALLAS",
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      await OnboardingGuideService().resetAllGuides();
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: VinkiarColors.hackingGreen,
                            content: Text(
                              "Guías contextuales reactivadas para cada sección.",
                              style: GoogleFonts.jetBrainsMono(color: Colors.black, fontSize: 10.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
