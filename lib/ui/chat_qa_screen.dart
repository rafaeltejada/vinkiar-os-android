import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';
import '../services/vinkiar_secure_database.dart';
import '../services/vinkiar_sync_service.dart';
import '../services/santuarios_service.dart';
import '../models/relational_tag.dart';
import 'widgets/ephemeral_media_viewer.dart';
import 'widgets/ephemeral_audio_player.dart';
import 'widgets/vinki_chat_modal.dart';
import 'widgets/tribu_bolsa_comun_sheet.dart';
import 'widgets/tribu_edit_sheet.dart';
import 'widgets/decision_engine_sheet.dart';
import 'widgets/decision_poll_card.dart';
import 'ritual_cristalizacion_screen.dart';
import 'theme.dart';

import '../services/notaria_escrow_service.dart';
import 'widgets/notaria_escrow_card.dart';

typedef JsonMap = Map<String, dynamic>;

class ChatQAScreen extends StatefulWidget {
  final String? initialGuildId;
  final String? initialTargetName;

  const ChatQAScreen({
    Key? key,
    this.initialGuildId,
    this.initialTargetName,
  }) : super(key: key);

  @override
  State<ChatQAScreen> createState() => _ChatQAScreenState();
}

class _ChatQAScreenState extends State<ChatQAScreen> {
  // =========================================================================
  // SECCIÓN 1: CONTROLADORES, ESTADO DE RED Y VARIABLES DE SESIÓN
  // =========================================================================
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _targetSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _showEncryptedBlob = false;
  bool _isFullScreen = false;
  bool _isConsultingVinki = false;
  late VinkiarSyncService _syncService;

  String? _activeProvisionalGuildId;
  List<JsonMap> _availableTargets = [];
  JsonMap? _selectedTarget;
  String _currentContactSSC = 'GREEN';
  String _myHandle = "Pionero";

  // Control de Túnel Efímero Volátil (24 horas)
  bool _isVolatileTunnel = false;
  int _tunnelSecondsLeft = 86400;
  Timer? _tunnelCountdownTimer;

  // Control de grabación de notas de voz efímeras
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isRecordingIntent = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  String? _tempAudioFilePath;

  // =========================================================================
  // SECCIÓN 2: CICLO DE VIDA E INICIALIZACIÓN
  // =========================================================================
  @override
  void initState() {
    super.initState();
    _activeProvisionalGuildId = widget.initialGuildId;
    _isVolatileTunnel = (_activeProvisionalGuildId != null && _activeProvisionalGuildId!.startsWith("TUNEL_PROV_"));

    _syncService = VinkiarSyncService();
    _syncService.addListener(_onSyncStateChange);
    _syncService.setServerHost(ApiConfig.baseUrl);

    _messageController.addListener(() {
      if (mounted) setState(() {});
    });

    _loadMyIdentity();
    _loadAvailableTargets();

    if (_isVolatileTunnel) {
      _startTunnelCountdown();
    }

    NotariaEscrowService().escrowSettledNotifier.addListener(_onEscrowSettled);
    VinkiarSyncService.bondCrystallizedNotifier.addListener(_onRemoteBondCrystallized);
  }

  @override
  void dispose() {
    VinkiarSyncService.bondCrystallizedNotifier.removeListener(_onRemoteBondCrystallized);
    NotariaEscrowService().escrowSettledNotifier.removeListener(_onEscrowSettled);
    _tunnelCountdownTimer?.cancel();
    _syncService.removeListener(_onSyncStateChange);
    _messageController.dispose();
    _targetSearchController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _onEscrowSettled() {
    if (mounted) setState(() {});
  }

  void _onRemoteBondCrystallized() {
    if (!mounted) return;
    final data = VinkiarSyncService.bondCrystallizedNotifier.value;
    if (data == null) return;
    setState(() {});
  }

  /// Abre el Ritual de Cristalización Phygital para convertir el túnel en contacto permanente de Célula
  Future<void> _openRitualCristalizacion() async {
    final targetName = _selectedTarget?['name']?.toString() ?? widget.initialTargetName ?? "Avatar ZKA";
    final cleanHandle = targetName.replaceAll("TÚNEL //", "").replaceAll("#", "").trim();
    final tunnelId = _selectedTarget?['guild_id']?.toString() ?? _activeProvisionalGuildId ?? "TUNEL_PROV";

    final crystallized = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RitualCristalizacionScreen(
          targetHandle: "#$cleanHandle",
          targetAlias: cleanHandle,
          provisionalGuildId: tunnelId,
        ),
      ),
    );

    if (crystallized == true && mounted) {
      _tunnelCountdownTimer?.cancel();
      await _loadAvailableTargets();
      final contactId = "CONTACT_$cleanHandle";
      final targetMap = _availableTargets.firstWhere(
        (t) => t['id'] == contactId,
        orElse: () => _availableTargets.isNotEmpty ? _availableTargets.first : {},
      );
      if (targetMap.isNotEmpty) {
        setState(() {
          _isVolatileTunnel = false;
          _activeProvisionalGuildId = null;
          NotariaEscrowService().escrowSettledNotifier.value = null;
        });
        _connectToTarget(targetMap);
      }
    }
  }


  void _onSyncStateChange() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  /// Carga el alias/handle del avatar local desde SQLCipher
  Future<void> _loadMyIdentity() async {
    final avatar = await VinkiarSecureDatabase().getAvatarSheet("LOCAL_USER");
    final stats = avatar?['stats'] as JsonMap? ?? {};
    final alias = avatar?['alias'] ?? stats['alias'] ?? "Pionero";
    if (mounted) {
      setState(() {
        _myHandle = alias.toString().startsWith('#') ? alias.toString() : '#$alias';
      });
    }
  }

  // =========================================================================
  // SECCIÓN 3: GESTIÓN DE TÚNEL VOLÁTIL (24H) Y CRISTALIZACIÓN DE CÉLULA
  // =========================================================================
  void _startTunnelCountdown() {
    _tunnelCountdownTimer?.cancel();
    _tunnelCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_tunnelSecondsLeft <= 1) {
        timer.cancel();
        _selfDestructProvisionalTunnel();
      } else {
        setState(() => _tunnelSecondsLeft--);
      }
    });
  }

  void _selfDestructProvisionalTunnel() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: VinkiarColors.abyssBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: VinkiarColors.panicRed, width: 2),
        ),
        title: Text(
          "TÚNEL VOLÁTIL PURGADO",
          style: GoogleFonts.jetBrainsMono(color: VinkiarColors.panicRed, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "La ventana de negociación de 24 horas ha expirado. Por amnesia ZKA, el enlace en memoria RAM ha sido destruido sin residuos.",
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: VinkiarColors.panicRed),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("SALIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  /// Convierte un túnel provisional en un contacto permanente de Célula tras acuerdo Phygital
  Future<void> _ejecutarCristalizacionAutomatica() async {
    HapticFeedback.heavyImpact();
    final db = VinkiarSecureDatabase();

    final targetName = _selectedTarget?['name']?.toString() ?? widget.initialTargetName ?? "Avatar ZKA";
    final cleanHandle = targetName.replaceAll("TÚNEL //", "").replaceAll("#", "").trim();
    final contactId = "CONTACT_$cleanHandle";

    await db.saveContact({
      "id": contactId,
      "alias": "#$cleanHandle",
      "character_class": "COMPAÑERO DE CÉLULA",
      "relationship_type": "FRIEND",
      "ssc_level": "GREEN",
      "is_active": 1,
      "reputation_score": 1.0,
      "last_interaction": DateTime.now().toIso8601String(),
      "created_at": DateTime.now().toIso8601String(),
    });

    if (_activeProvisionalGuildId != null) {
      await db.purgeOldMessages(_activeProvisionalGuildId!);
    }

    await _loadAvailableTargets();
    _tunnelCountdownTimer?.cancel();

    if (mounted) {
      setState(() {
        _isVolatileTunnel = false;
        _activeProvisionalGuildId = null;
        NotariaEscrowService().escrowSettledNotifier.value = null;
      });

      final targetMap = _availableTargets.firstWhere((t) => t['id'] == contactId, orElse: () => _availableTargets.first);
      _connectToTarget(targetMap);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: VinkiarColors.hackingGreen,
          content: Text(
            "TÚNEL DESMANTELADO. CÉLULA CRISTALIZADA EN LA BÓVEDA.",
            style: GoogleFonts.jetBrainsMono(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ),
      );
    }
  }

  String _formatCountdown(int sec) {
    final h = (sec ~/ 3600).toString().padLeft(2, '0');
    final m = ((sec % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  // =========================================================================
  // SECCIÓN 4: SELECTOR DE CANALES (CONTACTOS, TRIBUS, MISIONES Y TÚNELES)
  // =========================================================================
  Future<void> _loadAvailableTargets() async {
    final db = VinkiarSecureDatabase();
    final contacts = await db.getContacts();
    final quests = await db.getQuests(status: 'IN_PROGRESS');
    final guilds = await db.getGuilds();

    final List<JsonMap> targets = [];

    if (_activeProvisionalGuildId != null) {
      targets.add({
        "id": _activeProvisionalGuildId!,
        "name": widget.initialTargetName ?? "Túnel Provisional ZKA",
        "subtitle": "⚡ Enlace de Sintonía Doble Ciego (24h)",
        "type": "PROVISIONAL_TUNNEL",
        "guild_id": _activeProvisionalGuildId!,
        "ssc_level": "GREEN",
      });
    }

    for (var g in guilds) {
      targets.add({
        "id": g['guild_id'],
        "name": g['name'] ?? 'Tribu ZKA',
        "subtitle": "🛡️ Canal Grupal Comunitario",
        "type": "GUILD",
        "guild_id": g['guild_id'],
        "ssc_level": g['ssc_baseline'] ?? 'GREEN',
      });
    }

    for (var c in contacts) {
      if (c['ssc_level'] != 'REVOKED') {
        final tagDef = VinkiarRelationalTags.find(c['relationship_type']);
        final aliasStr = (c['alias'] ?? 'Contacto ZKA').toString();
        final canonicalCellId = VinkiarSyncService.buildCanonicalCellGuildId(_myHandle, aliasStr);
        targets.add({
          "id": c['id'],
          "name": aliasStr,
          "subtitle": "${tagDef.shortLabel} · Célula Relacional",
          "type": "CONTACT",
          "guild_id": canonicalCellId,
          "ssc_level": c['ssc_level'] ?? 'GREEN',
        });
      }
    }

    for (var q in quests) {
      targets.add({
        "id": q['id'],
        "name": q['title'] ?? 'Misión en curso',
        "subtitle": "📜 Contrato / Misión activa",
        "type": "QUEST",
        "guild_id": "GUILD_QUEST_${q['id']}",
        "ssc_level": "GREEN",
      });
    }

    if (mounted) {
      setState(() {
        _availableTargets = targets;
        if (_selectedTarget == null && _availableTargets.isNotEmpty) {
          _connectToTarget(_availableTargets.first);
        }
      });
    }
  }

  void _connectToTarget(JsonMap target) async {
    final db = VinkiarSecureDatabase();
    final contacts = await db.getContacts();
    final String targetId = target['id'];

    final freshContact = contacts.firstWhere(
      (c) => c['id'] == targetId,
      orElse: () => {'ssc_level': target['ssc_level'] ?? 'GREEN'},
    );
    final String guildId = target['guild_id'];

    setState(() {
      _selectedTarget = target;
      _targetSearchController.text = target['name'];
      _currentContactSSC = freshContact['ssc_level'] ?? 'GREEN';
      _isVolatileTunnel = guildId.startsWith("TUNEL_PROV_");
    });

    if (!_isVolatileTunnel) {
      await db.purgeOldMessages(guildId);
    }

    _syncService.setServerHost(ApiConfig.baseUrl);
    _syncService.connectWebSocket(guildId: guildId, userId: "LOCAL_AVATAR");

    if (!_isVolatileTunnel) {
      await _syncService.loadPersistedHistory(guildId);
    }

    if (_isVolatileTunnel) {
      _startTunnelCountdown();
    } else {
      _tunnelCountdownTimer?.cancel();
    }

    if (mounted) setState(() {});
  }

  // =========================================================================
  // SECCIÓN 5: INTEGRACIÓN DE VINKI AI (BOTÓN DIRECTO Y MENCIÓN @vinki)
  // =========================================================================

  /// Abre el modal flotante de consulta directa con Vinki AI desde el Chat ZKA
  void _openVinkiAssistantModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VinkiChatModal(userId: "LOCAL_USER"),
    );
  }

  /// Invoca a Vinki AI en línea dentro del canal actual cuando se escribe "@vinki"
  Future<void> _invokeVinkiInThread(String rawPrompt) async {
    if (_isConsultingVinki) return;
    setState(() => _isConsultingVinki = true);

    try {
      final db = VinkiarSecureDatabase();
      final vector = await db.getUserVector() ?? "0-0-0";
      final avatar = await db.getAvatarSheet("LOCAL_USER");
      final archetype = avatar?['character_class']?.toString() ?? "INICIADO ZKA";

      // 1. Extraer los últimos 6 mensajes del historial (Memoria Conversacional)
      final recentHistory = _syncService.messageHistory
          .take(6)
          .toList()
          .reversed
          .map((m) => {
                'sender': m.senderId == "LOCAL_AVATAR" ? "TÚ" : m.senderId,
                'text': m.decryptedContent ?? m.encryptedBlobB64 ?? ""
              })
          .where((m) => m['text']!.isNotEmpty && !m['text']!.startsWith("🤖"))
          .toList();

      final cleanBase = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;

      final cleanQuestion = rawPrompt.replaceAll(RegExp(r'@vinki', caseSensitive: false), '').trim();
      final channelName = _selectedTarget?['name'] ?? 'Canal ZKA';

      final res = await http.post(
        Uri.parse('$cleanBase/api/v1/vinki/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _myHandle,
          'message': "[Mediación en sala '$channelName']: ${cleanQuestion.isEmpty ? 'Analiza nuestra dinámica actual.' : cleanQuestion}",
          'current_vector': vector,
          'character_class': archetype,
          'history': recentHistory, // 2. Inyección del contexto
        }),
      ).timeout(const Duration(seconds: 15)); // Ampliamos timeout por precaución con LLMs

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply = (data['reply'] ?? data['vinki_response'] ?? '').toString().trim();
        if (reply.isNotEmpty) {
          _syncService.sendEncryptedMessage(
            plaintextMessage: "🤖 [ORÁCULO VINKI]: $reply",
          );
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint("❌ [VINKI INVOCATION ERROR] $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VinkiarColors.panelDark,
            content: Text(
              "Vinki no pudo sincronizar con la nube. Reintentando o red saturada.",
              style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConsultingVinki = false);
    }
  }

  // =========================================================================
  // SECCIÓN 6: BOLSA COMÚN, EDICIÓN DE TRIBU Y MESA DE DECISIONES COLECTIVAS
  // =========================================================================
  Future<void> _showBolsaComunModal() async {
    if (_selectedTarget == null || _selectedTarget!['type'] != 'GUILD') return;

    final String guildId = _selectedTarget!['guild_id'];
    final String guildName = _selectedTarget!['name'] ?? 'Tribu ZKA';
    final guilds = await VinkiarSecureDatabase().getGuilds();
    final currentGuild = guilds.firstWhere((g) => g['guild_id'] == guildId, orElse: () => {});
    final bool isCreator = currentGuild['is_creator'] == true;
    final List<String> admins = (currentGuild['admins'] as List? ?? []).map((e) => e.toString().toLowerCase()).toList();
    final bool canManage = isCreator || admins.contains(_myHandle.toLowerCase());

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TribuBolsaComunSheet(
        guildId: guildId,
        guildName: guildName,
        myHandle: _myHandle,
        isCreator: canManage,
        onBroadcastChatNote: (note) {
          _syncService.sendEncryptedMessage(plaintextMessage: note);
          _scrollToBottom();
        },
      ),
    );
  }

  /// Abre la edición del gremio/tribu (nombre, manifiesto, SSC, co-administradores)
  Future<void> _showEditTribuModal() async {
    if (_selectedTarget == null || _selectedTarget!['type'] != 'GUILD') return;
    final String guildId = _selectedTarget!['guild_id'];
    final guilds = await VinkiarSecureDatabase().getGuilds();
    final currentGuild = guilds.firstWhere(
      (g) => g['guild_id'] == guildId,
      orElse: () => {'guild_id': guildId, 'name': _selectedTarget!['name'] ?? 'Tribu ZKA', 'is_creator': true},
    );

    if (!mounted) return;

    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TribuEditSheet(
        guild: currentGuild,
        myHandle: _myHandle,
        onSaved: () => _loadAvailableTargets(),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _selectedTarget = {
          ..._selectedTarget!,
          'name': updated['name'] ?? _selectedTarget!['name'],
          'ssc_level': updated['ssc_baseline'] ?? _selectedTarget!['ssc_level'],
        };
        _targetSearchController.text = updated['name']?.toString() ?? _targetSearchController.text;
      });
    }
  }

  /// Abre la Mesa Universal de Decisiones (Mínima Miseria, Quórum, Cremallera, Subasta Ciega)
  void _showDecisionEngineModal() {
    if (_selectedTarget == null) return;
    final String guildId = _selectedTarget!['guild_id']?.toString() ?? 'GLOBAL_ZKA';
    final String channelName = _selectedTarget!['name']?.toString() ?? 'Sala ZKA';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DecisionEngineSheet(
        guildId: guildId,
        channelName: channelName,
        myHandle: _myHandle,
        onPublishToChat: (packet) {
          _syncService.sendEncryptedMessage(plaintextMessage: packet);
          _scrollToBottom();
        },
      ),
    );
  }

  // =========================================================================
  // SECCIÓN 7: CÁPSULAS EFÍMERAS (AUDIO, FOTO Y VÍDEO CON AMNESIA)
  // =========================================================================
  Future<void> _markMessageAsBurned(dynamic msg) async {
    await VinkiarSecureDatabase().burnMessage(msg.id);
    await _syncService.loadPersistedHistory(msg.guildId);
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _startRecordingIntent() {
    _isRecordingIntent = true;
    _startRecording();
  }

  void _stopRecordingIntent() {
    _isRecordingIntent = false;
    _stopRecordingAndProcess();
  }

  void _cancelRecordingIntent() {
    _isRecordingIntent = false;
    _cancelRecording();
  }

  Future<void> _startRecording() async {
    if (_currentContactSSC == 'RED' || _currentContactSSC == 'REVOKED') return;
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de micrófono denegado.'), backgroundColor: VinkiarColors.panicRed),
          );
        }
        return;
      }
      if (!_isRecordingIntent) return;

      HapticFeedback.mediumImpact();
      final Directory tempDir = await getTemporaryDirectory();
      _tempAudioFilePath = '${tempDir.path}/vinkiar_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000), path: _tempAudioFilePath!);
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
        if (mounted) setState(() => _recordingDuration++);
      });
    } catch (e) {
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopRecordingAndProcess() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();

    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordingDuration = 0;
      });

      if (path != null) {
        final File audioFile = File(path);
        if (await audioFile.exists()) {
          final Uint8List bytes = await audioFile.readAsBytes();
          await audioFile.delete();
          _showTimerConfigurationModal(bytes, mediaType: "VOZ");
        }
      }
    } catch (e) {
      setState(() => _isRecording = false);
    }
  }

  void _cancelRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordingDuration = 0;
    });
    if (_tempAudioFilePath != null) {
      final file = File(_tempAudioFilePath!);
      if (await file.exists()) await file.delete();
    }
    HapticFeedback.lightImpact();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _pickAndSendEphemeralMedia() async {
    if (_currentContactSSC == 'RED' || _currentContactSSC == 'REVOKED') return;
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.aegisCyan, width: 1.5),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("TRANSMITIR MEDIOS ZKA", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: VinkiarColors.aegisCyan),
                title: Text("TOMAR FOTO EFÍMERA", style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                  if (photo != null) {
                    final bytes = await photo.readAsBytes();
                    _showTimerConfigurationModal(bytes, mediaType: "IMG");
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: VinkiarColors.hackingGreen),
                title: Text("GRABAR VIDEOMENSAJE EFÍMERO", style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? video = await picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(seconds: 60));
                  if (video != null) {
                    final bytes = await video.readAsBytes();
                    _showTimerConfigurationModal(bytes, mediaType: "VID");
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: VinkiarColors.vertigoGold),
                title: Text("GALERÍA DE DISPOSITIVO", style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? media = await picker.pickMedia(imageQuality: 70);
                  if (media != null) {
                    final bytes = await media.readAsBytes();
                    final isVideo = media.path.toLowerCase().endsWith('.mp4') || media.path.toLowerCase().endsWith('.mov');
                    _showTimerConfigurationModal(bytes, mediaType: isVideo ? "VID" : "IMG");
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimerConfigurationModal(Uint8List bytes, {required String mediaType}) {
    int selectedDuration = mediaType == "IMG" ? 5 : -1;

    showModalBottomSheet(
      context: context,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.vertigoGold, width: 1.5),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("CONFIGURACIÓN DE AMNESIA", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  mediaType == "IMG"
                      ? "Selecciona el tiempo de exposición en pantalla:"
                      : "Selecciona el tipo de cápsula (Autodestrucción o Permanente):",
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 16),
                if (mediaType == "IMG")
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [5, 10, 30].map((seconds) {
                      final bool isSelected = selectedDuration == seconds;
                      return ChoiceChip(
                        label: Text("${seconds}s", style: GoogleFonts.jetBrainsMono(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                        selected: isSelected,
                        selectedColor: VinkiarColors.vertigoGold,
                        backgroundColor: VinkiarColors.panelDark,
                        onSelected: (val) {
                          if (val) setModalState(() => selectedDuration = seconds);
                        },
                      );
                    }).toList(),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ChoiceChip(
                        label: Text("1 USO (AUTO-PURGA)", style: GoogleFonts.jetBrainsMono(color: selectedDuration == -1 ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                        selected: selectedDuration == -1,
                        selectedColor: VinkiarColors.panicRed,
                        backgroundColor: VinkiarColors.panelDark,
                        onSelected: (val) {
                          if (val) setModalState(() => selectedDuration = -1);
                        },
                      ),
                    ],
                  ),
                if (_currentContactSSC == 'GREEN') ...[
                  const Divider(color: Colors.white24, height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.warning_amber_rounded, color: VinkiarColors.aegisCyan),
                    title: Text("ENVÍO PERMANENTE", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                    subtitle: Text("El medio no se destruirá y quedará persistente en la Bóveda.", style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _processAndSendMediaBytes(bytes, durationSeconds: 0, type: mediaType);
                    },
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: VinkiarColors.panicRed, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: Text(
                      selectedDuration == -1 ? "TRANSMITIR EFÍMERO (1 USO)" : "TRANSMITIR EFÍMERO ($selectedDuration SEG)",
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _processAndSendMediaBytes(bytes, durationSeconds: selectedDuration, type: mediaType);
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

  void _processAndSendMediaBytes(Uint8List bytes, {required int durationSeconds, required String type}) {
    final String base64Media = base64Encode(bytes);
    final String tagType = durationSeconds == 0 ? "PERMANENT" : "EFIMERO";
    final String tag = "[$tagType\_$type\_$durationSeconds]";

    final String payload = "$tag $base64Media";
    _syncService.sendEncryptedMessage(plaintextMessage: payload);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: durationSeconds != 0 ? VinkiarColors.panicRed : VinkiarColors.hackingGreen,
        content: Row(
          children: [
            Icon(durationSeconds != 0 ? Icons.local_fire_department : Icons.save, color: Colors.black, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                durationSeconds != 0 ? "Cápsula Efímera transmitida en la red." : "Cápsula Permanente transmitida en la red.",
                style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
    _scrollToBottom();
  }

  // =========================================================================
  // SECCIÓN 8: ENVÍO DE MENSAJES Y CONTRATOS NOTARIALES (CRISTALIZACIÓN / SUBASTA)
  // =========================================================================
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_currentContactSSC == 'RED' || _currentContactSSC == 'REVOKED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comunicación restringida por protocolo SSC.'), backgroundColor: VinkiarColors.panicRed),
      );
      return;
    }

    _syncService.sendEncryptedMessage(plaintextMessage: text);
    _messageController.clear();
    _scrollToBottom();

    // Si el mensaje incluye @vinki, el Oráculo responde directamente en el hilo
    if (text.toLowerCase().contains('@vinki')) {
      _invokeVinkiInThread(text);
    }
  }

  Future<void> _showCristalizacionModal() async {
    final santuarios = await SantuariosService().fetchRadarNodes();
    if (!mounted) return;

    SantuarioNode? santuarioSeleccionado = santuarios.isNotEmpty ? santuarios.first : null;
    final List<String> opcionesHora = ["Hoy · En 30 min", "Hoy · 18:30", "Hoy · 19:30", "Hoy · 20:30", "Hoy · 21:30", "Mañana · 18:00"];
    String horaSeleccionada = opcionesHora[2];
    int escrowVinks = 20;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.vertigoGold, width: 2),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.handshake_outlined, color: VinkiarColors.vertigoGold, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "PACTAR ENCUENTRO // CRISTALIZACIÓN",
                      style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Selecciona el Santuario neutral y la franja horaria. Se retendrán $escrowVinks Ѵ en Escrow hasta que ambos firméis el encuentro.",
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, height: 1.35),
              ),
              const SizedBox(height: 14),
              Text("1. SANTUARIO NEUTRAL:", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 9.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (santuarios.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: VinkiarColors.panelDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<SantuarioNode>(
                      value: santuarioSeleccionado,
                      isExpanded: true,
                      dropdownColor: VinkiarColors.abyssBlack,
                      style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11),
                      items: santuarios.map((s) {
                        return DropdownMenuItem<SantuarioNode>(
                          value: s,
                          child: Text("${s.alias} (${s.tipoSantuario})"),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => santuarioSeleccionado = val);
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Text("2. FRANJA HORARIA ESTIMADA:", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 9.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: opcionesHora.map((hora) {
                  final bool selected = horaSeleccionada == hora;
                  return ChoiceChip(
                    label: Text(
                      hora,
                      style: GoogleFonts.jetBrainsMono(color: selected ? Colors.black : Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    selected: selected,
                    selectedColor: VinkiarColors.aegisCyan,
                    backgroundColor: VinkiarColors.panelDark,
                    onSelected: (val) {
                      if (val) setModalState(() => horaSeleccionada = hora);
                    },
                  );
                }).toList(),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("RETENCIÓN NOTARIAL EN ESCROW:", style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 9)),
                        const SizedBox(height: 2),
                        Text("Liberación tras Doble Firma 2-de-2", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                    Text("$escrowVinks Ѵ", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VinkiarColors.vertigoGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.lock_outline, size: 18),
                  label: Text(
                    isSubmitting ? "BLOQUEANDO ESCROW..." : "BLOQUEAR ESCROW Y NOTIFICAR LOCAL",
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10.5),
                  ),
                  onPressed: isSubmitting || santuarioSeleccionado == null
                      ? null
                      : () async {
                          setModalState(() => isSubmitting = true);

                          final cleanBase = ApiConfig.baseUrl.endsWith('/')
                              ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
                              : ApiConfig.baseUrl;

                          final otherHandle = (_selectedTarget?['name'] ?? "Avatar").toString().replaceAll("TÚNEL // ", "").replaceAll('#', '');
                          final questId = "QST_${DateTime.now().millisecondsSinceEpoch}";

                          await NotariaEscrowService().freezeEscrow(
                            questId: questId,
                            vinksAmount: escrowVinks,
                            santuarioId: santuarioSeleccionado!.id,
                            santuarioAlias: santuarioSeleccionado!.alias,
                            horaEstimada: horaSeleccionada,
                            targetHandle: "#$otherHandle",
                          );

                          try {
                            final res = await http.post(
                              Uri.parse('$cleanBase/api/v1/santuarios/notificar-encuentro'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                "santuario_id": santuarioSeleccionado!.id,
                                "user_a_handle": _myHandle,
                                "user_b_handle": "#$otherHandle",
                                "provisional_guild_id": _selectedTarget?['guild_id'] ?? _activeProvisionalGuildId ?? "TUNEL_PROV",
                                "fecha_estimada": horaSeleccionada,
                                "escrow_vinks": escrowVinks,
                                "protocolo_ssc": "GREEN"
                              }),
                            ).timeout(const Duration(seconds: 6));

                            if (modalCtx.mounted) Navigator.pop(modalCtx);

                            if (res.statusCode == 201 || res.statusCode == 200) {
                              HapticFeedback.heavyImpact();
                              _syncService.sendEncryptedMessage(
                                plaintextMessage: "[NOTARIA_2DE2|$questId|${santuarioSeleccionado!.id}|${santuarioSeleccionado!.alias}|$horaSeleccionada|$escrowVinks|#$otherHandle]",
                              );
                            }
                          } catch (_) {
                            if (modalCtx.mounted) setModalState(() => isSubmitting = false);
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

  Future<void> _showSubastaInversaModal() async {
    if (_activeProvisionalGuildId != null || _selectedTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: VinkiarColors.panicRed,
          content: Text("Las subastas solo están disponibles en canales de Célula cristalizados.", style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 10)),
        ),
      );
      return;
    }

    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    int currentVinks = 0;

    final db = VinkiarSecureDatabase();
    final avatar = await db.getAvatarSheet("LOCAL_USER");
    if (avatar != null && avatar['stats'] != null) {
      currentVinks = (avatar['stats']['vinks'] as int?) ?? 0;
    }

    int vinksOfrecidos = 50;
    bool isSubmitting = false;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.vertigoGold, width: 2),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.gavel_rounded, color: VinkiarColors.vertigoGold, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "SUBASTA INVERSA DE TAREA",
                      style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Delega carga mental ofreciendo Vinks. Si tu compañero/a acepta, el presupuesto queda retenido en Escrow Notarial hasta completarse (Firma 2-de-2).",
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, height: 1.35),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                onChanged: (_) => setModalState(() {}),
                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  labelText: "Resumen de la Tarea",
                  labelStyle: TextStyle(color: Colors.white70, fontSize: 10.5),
                  hintText: "Ej. Hacer la compra semanal",
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 10),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.vertigoGold)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  labelText: "Detalles o condiciones de entrega",
                  labelStyle: TextStyle(color: Colors.white70, fontSize: 10.5),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: VinkiarColors.vertigoGold)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VinkiarColors.panelDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: currentVinks >= vinksOfrecidos ? VinkiarColors.vertigoGold.withOpacity(0.4) : VinkiarColors.panicRed),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("PRESUPUESTO A BLOQUEAR:", style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 9)),
                        Text(
                          "$vinksOfrecidos Ѵ",
                          style: GoogleFonts.jetBrainsMono(
                            color: currentVinks >= vinksOfrecidos ? VinkiarColors.vertigoGold : VinkiarColors.panicRed,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Slider(
                      value: vinksOfrecidos.toDouble(),
                      min: 10,
                      max: 200,
                      divisions: 19,
                      activeColor: currentVinks >= vinksOfrecidos ? VinkiarColors.vertigoGold : VinkiarColors.panicRed,
                      inactiveColor: Colors.white12,
                      onChanged: (val) => setModalState(() => vinksOfrecidos = val.toInt()),
                    ),
                    if (currentVinks < vinksOfrecidos)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text("Saldo insuficiente (Tienes $currentVinks Ѵ)", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.panicRed, fontSize: 9)),
                      )
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VinkiarColors.vertigoGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    isSubmitting ? "PUBLICANDO..." : "LANZAR SUBASTA A LA CÉLULA",
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10.5),
                  ),
                  onPressed: isSubmitting || currentVinks < vinksOfrecidos || titleCtrl.text.trim().isEmpty
                      ? null
                      : () async {
                          setModalState(() => isSubmitting = true);

                          final cleanBase = ApiConfig.baseUrl.endsWith('/')
                              ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
                              : ApiConfig.baseUrl;

                          final questId = "QST_P2P_${DateTime.now().millisecondsSinceEpoch}";
                          final titulo = titleCtrl.text.trim();
                          final descripcion = descCtrl.text.trim();

                          await NotariaEscrowService().freezeEscrow(
                            questId: questId,
                            vinksAmount: vinksOfrecidos,
                            santuarioId: "TAREA_DOMESTICA",
                            santuarioAlias: "Resolución P2P",
                            horaEstimada: "Límite: Hoy 22:00",
                            targetHandle: _selectedTarget!['name'],
                          );

                          final payloadStr = "[NOTARIA_2DE2|$questId|TAREA_DOMESTICA|SUBASTA DE TAREA|Límite: Hoy 22:00|$vinksOfrecidos|${_selectedTarget!['name']}|$titulo|$descripcion]";
                          _syncService.sendEncryptedMessage(plaintextMessage: payloadStr);

                          try {
                            await http.post(
                              Uri.parse('$cleanBase/api/v1/gremio/subasta-tarea'),
                              headers: {'Content-Type': 'application/json'},
                              body: jsonEncode({
                                "guild_id": _selectedTarget!['guild_id'],
                                "creator_id": _myHandle,
                                "titulo": titulo,
                                "descripcion": descripcion,
                                "vinks_ofrecidos": vinksOfrecidos,
                              }),
                            );
                          } catch (_) {}

                          if (modalCtx.mounted) Navigator.pop(modalCtx);
                          HapticFeedback.heavyImpact();
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // SECCIÓN 9: AJUSTES DE AMNESIA Y SEMÁFORO SSC EN CALIENTE
  // =========================================================================
  void _openChatSettings() {
    if (_selectedTarget == null) return;
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
          children: [
            Text("CONFIGURACIÓN DE AMNESIA DEL CHAT", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 11, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white24, height: 20),
            ListTile(
              leading: const Icon(Icons.timer, color: VinkiarColors.vertigoGold),
              title: Text("Autodestruir historial > 1 Día", style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11)),
              onTap: () async {
                Navigator.pop(ctx);
                await VinkiarSecureDatabase().setChatTTL(_selectedTarget!['guild_id'], 1);
                await VinkiarSecureDatabase().purgeOldMessages(_selectedTarget!['guild_id']);
                await _syncService.loadPersistedHistory(_selectedTarget!['guild_id']);
                setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer, color: VinkiarColors.hackingGreen),
              title: Text("Autodestruir historial > 7 Días", style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11)),
              onTap: () async {
                Navigator.pop(ctx);
                await VinkiarSecureDatabase().setChatTTL(_selectedTarget!['guild_id'], 7);
                await VinkiarSecureDatabase().purgeOldMessages(_selectedTarget!['guild_id']);
                await _syncService.loadPersistedHistory(_selectedTarget!['guild_id']);
                setState(() {});
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer, color: VinkiarColors.aegisCyan),
              title: Text("Autodestruir historial > 30 Días", style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11)),
              onTap: () async {
                Navigator.pop(ctx);
                await VinkiarSecureDatabase().setChatTTL(_selectedTarget!['guild_id'], 30);
                await VinkiarSecureDatabase().purgeOldMessages(_selectedTarget!['guild_id']);
                await _syncService.loadPersistedHistory(_selectedTarget!['guild_id']);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  void _changeSSCLevelDirectly() {
    if (_selectedTarget == null || _selectedTarget!['type'] != 'CONTACT') return;
    final String contactId = _selectedTarget!['id'];

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
            Text("AJUSTAR CONSENTIMIENTO EN CALIENTE (SSC)", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            _buildSSCOption(contactId, "NIVEL VERDE (ACCESO TOTAL)", "GREEN", VinkiarColors.hackingGreen),
            _buildSSCOption(contactId, "NIVEL AMARILLO (CAUTELA)", "YELLOW", VinkiarColors.vertigoGold),
            _buildSSCOption(contactId, "NIVEL ROJO (PAUSA)", "RED", VinkiarColors.panicRed),
            const Divider(color: Colors.white24, height: 20),
            _buildSSCOption(contactId, "REVOCAR CONSENTIMIENTO Y EXILIAR", "REVOKED", Colors.purpleAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildSSCOption(String contactId, String label, String sscKey, Color color) {
    return ListTile(
      leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      title: Text(label, style: GoogleFonts.jetBrainsMono(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      onTap: () async {
        await VinkiarSecureDatabase().updateContactSSC(contactId, sscKey);
        if (mounted) Navigator.pop(context);
        setState(() {
          _currentContactSSC = sscKey;
        });
        await _loadAvailableTargets();
      },
    );
  }

  Color _getSSCColor(String level) {
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

  Widget _buildSSCBadge() {
    Color sscColor = _getSSCColor(_currentContactSSC);
    return InkWell(
      onTap: _changeSSCLevelDirectly,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: sscColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: sscColor, width: 1)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: sscColor, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text("SSC: $_currentContactSSC", style: GoogleFonts.jetBrainsMono(color: sscColor, fontSize: 8.5, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // SECCIÓN 10: INTERFAZ DE USUARIO PRINCIPAL (BUILD)
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final reversedHistory = _syncService.messageHistory.reversed.toList();
    final bool isGuildChannel = _selectedTarget?['type'] == 'GUILD';

    return Scaffold(
      backgroundColor: VinkiarColors.abyssBlack,
      appBar: AppBar(
        backgroundColor: VinkiarColors.panelDark,
        title: Row(
          children: [
            Expanded(
              child: Text(
                _selectedTarget?['name'] ?? 'TÚNEL ZKA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
            _buildSSCBadge(),
          ],
        ),
        actions: [
          // Mesa de Decisiones Colectivas (Mínima Miseria / Quórum / Cremallera / Subasta)
          IconButton(
            tooltip: "Mesa de Decisiones (Mínima Miseria / Quórum)",
            icon: const Icon(Icons.balance, color: VinkiarColors.hackingGreen, size: 21),
            onPressed: _showDecisionEngineModal,
          ),
          // Botón de acceso directo a Vinki AI
          IconButton(
            tooltip: "Consultar a Vinki AI",
            icon: _isConsultingVinki
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: VinkiarColors.aegisCyan))
                : const Icon(Icons.psychology, color: VinkiarColors.aegisCyan, size: 22),
            onPressed: _openVinkiAssistantModal,
          ),
          if (isGuildChannel)
            IconButton(
              tooltip: "Bolsa Común de Tribu",
              icon: const Icon(Icons.account_balance_wallet_outlined, color: VinkiarColors.vertigoGold, size: 21),
              onPressed: _showBolsaComunModal,
            ),
          if (_isVolatileTunnel) ...[
            IconButton(
              tooltip: "Cristalizar vínculo en Célula",
              icon: const Icon(Icons.verified_user, color: VinkiarColors.hackingGreen, size: 22),
              onPressed: _openRitualCristalizacion,
            ),
            IconButton(
              tooltip: "Pactar encuentro en Santuario",
              icon: const Icon(Icons.handshake_outlined, color: VinkiarColors.vertigoGold, size: 22),
              onPressed: _showCristalizacionModal,
            ),
          ],
          IconButton(
            tooltip: "Alternar vista cifrada",
            icon: Icon(_showEncryptedBlob ? Icons.lock : Icons.lock_open, color: _showEncryptedBlob ? VinkiarColors.vertigoGold : VinkiarColors.aegisCyan, size: 20),
            onPressed: () => setState(() => _showEncryptedBlob = !_showEncryptedBlob),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: VinkiarColors.aegisCyan),
            color: VinkiarColors.abyssBlack,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: VinkiarColors.aegisCyan, width: 1.5),
            ),
            onSelected: (value) {
              if (value == 'decision') _showDecisionEngineModal();
              if (value == 'vinki') _openVinkiAssistantModal();
              if (value == 'edit_tribu') _showEditTribuModal();
              if (value == 'pool') _showBolsaComunModal();
              if (value == 'settings') _openChatSettings();
              if (value == 'auction') _showSubastaInversaModal();
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'decision',
                child: Row(
                  children: [
                    const Icon(Icons.balance, color: VinkiarColors.hackingGreen, size: 16),
                    const SizedBox(width: 8),
                    Text("Mesa de Decisiones (AVM)", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.hackingGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'vinki',
                child: Row(
                  children: [
                    const Icon(Icons.psychology, color: VinkiarColors.aegisCyan, size: 16),
                    const SizedBox(width: 8),
                    Text("Sintonizar con Vinki AI", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (isGuildChannel) ...[
                PopupMenuItem<String>(
                  value: 'edit_tribu',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, color: VinkiarColors.aegisCyan, size: 16),
                      const SizedBox(width: 8),
                      Text("Editar Tribu / Manifiesto", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'pool',
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, color: VinkiarColors.vertigoGold, size: 16),
                      const SizedBox(width: 8),
                      Text("Bolsa Común de Tribu", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              if (!_isVolatileTunnel)
                PopupMenuItem<String>(
                  value: 'auction',
                  child: Row(
                    children: [
                      const Icon(Icons.gavel_rounded, color: VinkiarColors.vertigoGold, size: 16),
                      const SizedBox(width: 8),
                      Text("Subasta Inversa P2P", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: VinkiarColors.aegisCyan, size: 16),
                    const SizedBox(width: 8),
                    Text("Ajustes de Amnesia", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de Túnel Volátil 24h con acceso directo al Ritual de Cristalización
          if (_isVolatileTunnel)
            InkWell(
              onTap: _openRitualCristalizacion,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: (NotariaEscrowService().escrowSettledNotifier.value != null ||
                          VinkiarSyncService.bondCrystallizedNotifier.value != null)
                      ? VinkiarColors.hackingGreen
                      : const Color(0xFF0E1B16),
                  border: const Border(bottom: BorderSide(color: VinkiarColors.hackingGreen, width: 1.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.fingerprint,
                            color: (NotariaEscrowService().escrowSettledNotifier.value != null ||
                                    VinkiarSyncService.bondCrystallizedNotifier.value != null)
                                ? Colors.black
                                : VinkiarColors.hackingGreen,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "CRISTALIZAR VÍNCULO EN CÉLULA (PULSA AQUÍ)",
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.jetBrainsMono(
                                color: (NotariaEscrowService().escrowSettledNotifier.value != null ||
                                        VinkiarSyncService.bondCrystallizedNotifier.value != null)
                                    ? Colors.black
                                    : VinkiarColors.hackingGreen,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatCountdown(_tunnelSecondsLeft),
                      style: GoogleFonts.jetBrainsMono(
                        color: (NotariaEscrowService().escrowSettledNotifier.value != null ||
                                VinkiarSyncService.bondCrystallizedNotifier.value != null)
                            ? Colors.black
                            : VinkiarColors.vertigoGold,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Buscador rápido de sala / contacto
          if (!_isFullScreen)
            Container(
              color: VinkiarColors.panelDark.withOpacity(0.85),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: RawAutocomplete<JsonMap>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) return _availableTargets;
                  return _availableTargets.where((t) => t['name'].toString().toLowerCase().contains(textEditingValue.text.toLowerCase()));
                },
                displayStringForOption: (option) => option['name'],
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: "🔍 Buscar contacto, tribu o misión...",
                      hintStyle: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 10.5),
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, color: VinkiarColors.aegisCyan, size: 16),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: VinkiarColors.aegisCyan.withOpacity(0.3))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: VinkiarColors.aegisCyan)),
                    ),
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: MediaQuery.of(context).size.width - 28,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(color: VinkiarColors.abyssBlack, borderRadius: BorderRadius.circular(8), border: Border.all(color: VinkiarColors.aegisCyan, width: 1.2)),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final option = options.elementAt(index);
                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                dense: true,
                                title: Text(option['name'], style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                subtitle: Text(option['subtitle'], style: GoogleFonts.outfit(color: VinkiarColors.textDim, fontSize: 10)),
                                onTap: () => onSelected(option),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                onSelected: (selection) => _connectToTarget(selection),
              ),
            ),

          // Hilo de mensajes cifrados
          Expanded(
            child: reversedHistory.isEmpty
                ? Center(
                    child: Text(
                      'No hay mensajes.\nEscribe un texto, menciona @vinki o envía una cápsula.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                    ),
                  )
                : Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      ListView.builder(
                        reverse: true,
                        controller: _scrollController,
                        padding: const EdgeInsets.only(left: 12, right: 12, top: 12, bottom: 80),
                        itemCount: reversedHistory.length,
                        itemBuilder: (context, index) {
                          final msg = reversedHistory[index];
                          final bool isMe = msg.senderId == "LOCAL_AVATAR";
                          final String msgContent = msg.decryptedContent ?? msg.encryptedBlobB64;

                          final RegExp tagRegExp = RegExp(r'\[(EFIMERO|PERMANENT)_(IMG|VID|VOZ)(?:_(\-?\d+))?\]');
                          final match = tagRegExp.firstMatch(msgContent);
                          final bool isAlreadyPurged = msgContent.contains("[ 💨 CÁPSULA PURGADA ]");
                          final bool isVinkiReply = msgContent.startsWith("🤖 [ORÁCULO VINKI]:");

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                              decoration: BoxDecoration(
                                color: isVinkiReply
                                    ? VinkiarColors.aegisCyan.withOpacity(0.1)
                                    : (isMe ? VinkiarColors.aegisCyan.withOpacity(0.15) : VinkiarColors.panelDark),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isVinkiReply
                                      ? VinkiarColors.aegisCyan
                                      : (isMe ? VinkiarColors.aegisCyan.withOpacity(0.5) : Colors.white12),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isVinkiReply ? "🤖 VINKI AI" : (isMe ? "TÚ" : msg.senderId),
                                        style: GoogleFonts.jetBrainsMono(
                                          color: isVinkiReply || isMe ? VinkiarColors.aegisCyan : VinkiarColors.vertigoGold,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        msg.timestamp.length > 19 ? msg.timestamp.substring(11, 19) : msg.timestamp,
                                        style: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 8.5),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (_showEncryptedBlob)
                                    Text(msg.encryptedBlobB64, style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 11.5))
                                  else if (isAlreadyPurged)
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.white24)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.cloud_off, color: Colors.grey, size: 14),
                                          const SizedBox(width: 6),
                                          Text("[ 💨 CÁPSULA PURGADA ]", style: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    )
                                  else if (match != null)
                                    Builder(builder: (context) {
                                      final bool isEphemeral = match.group(1) == "EFIMERO";
                                      final String mediaType = match.group(2)!;
                                      final int duration = match.group(3) != null ? int.parse(match.group(3)!) : 0;
                                      final String cleanBase64 = msgContent.replaceAll(match.group(0)!, "").trim();
                                      final Color btnColor = isEphemeral ? VinkiarColors.panicRed : VinkiarColors.hackingGreen;

                                      if (mediaType == "VOZ") {
                                        return EphemeralAudioPlayer(
                                          base64Audio: cleanBase64,
                                          isPermanent: !isEphemeral,
                                          onBurn: () => _markMessageAsBurned(msg),
                                        );
                                      } else {
                                        final bool isVideo = mediaType == "VID";
                                        IconData iconData = isVideo ? Icons.videocam : Icons.image;
                                        if (isEphemeral && !isVideo) iconData = Icons.local_fire_department;

                                        String label;
                                        if (!isEphemeral) {
                                          label = isVideo ? "▶️ VER VÍDEO (FIJO)" : "🖼️ VER FOTO (FIJA)";
                                        } else if (isVideo) {
                                          label = "▶️ VER VÍDEO (1 USO)";
                                        } else {
                                          label = "🔥 VER FOTO (${duration}s)";
                                        }

                                        return ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: btnColor.withOpacity(0.2),
                                            foregroundColor: btnColor,
                                            side: BorderSide(color: btnColor),
                                          ),
                                          icon: Icon(iconData, size: 16),
                                          label: Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold)),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => EphemeralMediaViewer(
                                                  mediaBytes: base64Decode(cleanBase64),
                                                  durationSeconds: isEphemeral ? duration : 0,
                                                  isVideo: isVideo,
                                                  onBurn: () {
                                                    if (isEphemeral) _markMessageAsBurned(msg);
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      }
                                    })
                                  else if (msgContent.startsWith("[DECISION_ZKA|"))
                                    Builder(builder: (context) {
                                      final clean = msgContent.replaceAll("[", "").replaceAll("]", "");
                                      final parts = clean.split("|");
                                      if (parts.length >= 4) {
                                        return DecisionPollCard(
                                          decisionId: parts[1],
                                          fallbackTitle: parts[2],
                                          fallbackMode: parts[3],
                                          myHandle: _myHandle,
                                          onResolvedBroadcast: (note) {
                                            _syncService.sendEncryptedMessage(plaintextMessage: note);
                                            _scrollToBottom();
                                          },
                                        );
                                      }
                                      return Text(msgContent, style: GoogleFonts.outfit(color: Colors.white, fontSize: 12.5));
                                    })
                                  else if (msgContent.startsWith("[NOTARIA_2DE2|"))
                                    Builder(builder: (context) {
                                      final clean = msgContent.replaceAll("[", "").replaceAll("]", "");
                                      final parts = clean.split("|");
                                      if (parts.length >= 7) {
                                        return NotariaEscrowCard(
                                          questId: parts[1],
                                          santuarioId: parts[2],
                                          santuarioAlias: parts.length >= 9 ? parts[7] : parts[3],
                                          horaPactada: parts.length >= 9 ? parts[8] : parts[4],
                                          escrowVinks: int.tryParse(parts[5]) ?? 20,
                                          myHandle: _myHandle,
                                          targetHandle: parts[6],
                                          isP2PTask: parts[2] == "TAREA_DOMESTICA",
                                        );
                                      }
                                      return Text(msgContent, style: GoogleFonts.outfit(color: Colors.white, fontSize: 12.5));
                                    })
                                  else
                                    Text(msgContent, style: GoogleFonts.outfit(color: Colors.white, fontSize: 12.5)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: FloatingActionButton.small(
                          backgroundColor: VinkiarColors.panelDark,
                          foregroundColor: VinkiarColors.aegisCyan,
                          onPressed: _scrollToBottom,
                          child: const Icon(Icons.arrow_downward),
                        ),
                      ),
                    ],
                  ),
          ),

          // Barra inferior de escritura, botón @vinki y cápsulas multimedia
          Container(
            padding: const EdgeInsets.all(8.0),
            color: VinkiarColors.panelDark,
            child: Row(
              children: [
                if (!_isRecording) ...[
                  IconButton(
                    tooltip: "Adjuntar cápsula efímera",
                    icon: const Icon(Icons.attach_file, color: VinkiarColors.aegisCyan),
                    onPressed: _pickAndSendEphemeralMedia,
                  ),
                  IconButton(
                    tooltip: "Insertar mención @vinki",
                    icon: const Icon(Icons.auto_awesome, color: VinkiarColors.vertigoGold, size: 20),
                    onPressed: () {
                      final curr = _messageController.text;
                      _messageController.text = curr.isEmpty ? "@vinki " : "$curr @vinki ";
                      _messageController.selection = TextSelection.fromPosition(TextPosition(offset: _messageController.text.length));
                    },
                  ),
                ],
                Expanded(
                  child: _isRecording
                      ? Container(
                          height: 48,
                          decoration: BoxDecoration(color: VinkiarColors.panicRed.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: VinkiarColors.panicRed)),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              const Icon(Icons.mic, color: VinkiarColors.panicRed, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text("GRABANDO... ${_formatDuration(_recordingDuration)}", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.panicRed, fontWeight: FontWeight.bold, fontSize: 11))),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.grey, size: 18), onPressed: _cancelRecordingIntent),
                            ],
                          ),
                        )
                      : TextField(
                          controller: _messageController,
                          onSubmitted: (_) => _sendMessage(),
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Mensaje cifrado o @vinki... 🔒',
                            hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                            filled: true,
                            fillColor: VinkiarColors.abyssBlack,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                if (_messageController.text.isNotEmpty && !_isRecording)
                  IconButton(icon: const Icon(Icons.send, color: VinkiarColors.aegisCyan), onPressed: _sendMessage)
                else
                  GestureDetector(
                    onLongPressStart: (_) => _startRecordingIntent(),
                    onLongPressEnd: (_) => _stopRecordingIntent(),
                    onLongPressCancel: () => _cancelRecordingIntent(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: _isRecording ? VinkiarColors.panicRed : VinkiarColors.vertigoGold, shape: BoxShape.circle),
                      child: Icon(_isRecording ? Icons.mic : Icons.mic_none, color: Colors.black, size: 20),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}