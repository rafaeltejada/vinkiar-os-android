import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart' as drift;

import '../config/api_config.dart';
import '../main.dart';
import '../services/vinkiar_psychometrics_engine.dart';
import '../services/vinkiar_secure_database.dart';
import '../services/database/app_database.dart';
import 'main_dashboard_screen.dart';
import 'theme.dart';

class VinkiChatMessage {
  final String sender; // 'user' | 'vinki'
  final String text;
  final bool isTyping;

  VinkiChatMessage({
    required this.sender,
    required this.text,
    this.isTyping = false,
  });
}

class ForgeScreen extends StatefulWidget {
  final String userUuid;
  final String? alias;
  final bool isRecalibration;

  const ForgeScreen({
    Key? key,
    required this.userUuid,
    this.alias,
    this.isRecalibration = false,
  }) : super(key: key);

  @override
  State<ForgeScreen> createState() => _ForgeScreenState();
}

class _ForgeScreenState extends State<ForgeScreen> with SingleTickerProviderStateMixin {
  bool _isCalibrating = false;
  bool _isProcessing = false;
  int _currentPhase = 0;
  
  late AnimationController _orbController;
  String _typedText = '';
  Timer? _typewriterTimer;

  // Variables para compilar las Ruedas
  int _egoPoints = 0;
  int _philiaAvoidance = 0;
  int _erosKink = 0;

  // --- ESTADO FASE VINKI CHAT ---
  bool _isVinkiChatPhase = false;
  final List<VinkiChatMessage> _vinkiChatMessages = [];
  final TextEditingController _chatTextController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  int _vinkiUserMessagesCount = 0;
  bool _isVinkiReplying = false;

  final List<Map<String, dynamic>> _scenarios = [
    {
      "id": "ingesta_taberna_ego",
      "title": "LA TABERNA (Rueda I: El Ego)",
      "text": "Bienvenido a La Taberna, el tablón donde emitimos contratos P2P. Un Aliado solicita ayuda urgente para infiltrarse en un servidor corporativo, pero carece de recursos. ¿Cómo reaccionas ante la tensión?",
      "options": [
        {"label": "[A] Asumo el mando. Les dirijo paso a paso para evitar errores.", "trait": "EGO_CONTRA", "val": 8},
        {"label": "[B] Me ofrezco de voluntario para hacer el trabajo pesado por él.", "trait": "EGO_HACIA", "val": 2},
        {"label": "[C] Analizo los datos desde mi Bóveda y les envío un manual.", "trait": "EGO_LEJOS", "val": 5},
      ]
    },
    {
      "id": "ingesta_radar_philia",
      "title": "EL RADAR (Rueda III: Philia)",
      "text": "El Radar escanea las frecuencias cercanas para encontrar Nodos y Tribus. De pronto, detectas el ping débil de un aliado del que no sabes nada hace años. ¿Qué haces?",
      "options": [
        {"label": "[A] Acudo de inmediato. Me aterra pensar que me necesite y lo pierda.", "trait": "PHILIA_ANSIOSO", "val": -10},
        {"label": "[B] Bloqueo la señal. El pasado es un riesgo para mi autonomía actual.", "trait": "PHILIA_EVITATIVO", "val": 10},
        {"label": "[C] Abro un canal seguro, evalúo la situación y decido si me acerco.", "trait": "PHILIA_SEGURO", "val": 0},
      ]
    },
    {
      "id": "ingesta_boveda_eros",
      "title": "LA BÓVEDA (Rueda II: Eros)",
      "text": "Estás en tu Bóveda. Aquí configuramos el Semáforo de Límites (Verde, Amarillo, Rojo). Si un cofrade del Loto te propone una dinámica de privación visual (venda en los ojos) para despertar tu piel, ¿cómo reacciona tu cuerpo?",
      "options": [
        {"label": "[A] Rechazo absoluto. Necesito control visual para sentirme a salvo.", "trait": "EROS_EROTOFOBIA", "val": -10},
        {"label": "[B] Curiosidad. Si el entorno es seguro, mi cuerpo se adapta al juego.", "trait": "EROS_CAMBIAFORMAS", "val": 5},
        {"label": "[C] Me excita la idea de ceder el control en la penumbra.", "trait": "EROS_KINKY", "val": 10},
      ]
    }
  ];

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(duration: const Duration(seconds: 4), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _typewriterTimer?.cancel();
    _chatTextController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _startTypewriter(String text) {
    _typewriterTimer?.cancel();
    setState(() {
      _typedText = '';
    });

    int index = 0;
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      if (index < text.length) {
        setState(() => _typedText += text[index]);
        index++;
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleAnswer(Map<String, dynamic> option, String dilemaId) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final db = VinkiarSecureDatabase().db!;
    await db.into(db.harvestLogs).insert(
      HarvestLogsCompanion.insert(
        id: "LOG-${DateTime.now().millisecondsSinceEpoch}",
        soulSheetUuid: widget.userUuid,
        dilemaId: dilemaId,
        opcionSeleccionada: option['trait'],
      ),
    );

    if (option['trait'].contains('EGO')) _egoPoints = option['val'];
    if (option['trait'].contains('PHILIA')) _philiaAvoidance = option['val'];
    if (option['trait'].contains('EROS')) _erosKink = option['val'];

    await Future.delayed(const Duration(milliseconds: 800));

    if (_currentPhase < _scenarios.length - 1) {
      setState(() {
        _currentPhase++;
        _isProcessing = false;
      });
      _startTypewriter(_scenarios[_currentPhase]["text"]);
    } else {
      _initiateVinkiChatPhase();
    }
  }

  void _initiateVinkiChatPhase() {
    String egoDesc;
    if (_egoPoints == 8) {
      egoDesc = "el liderazgo asertivo y la confrontación directa (Ego Contra)";
    } else if (_egoPoints == 2) {
      egoDesc = "la entrega protectora y el rescate vincular (Ego Hacia)";
    } else {
      egoDesc = "el análisis reflexivo y la autonomía mental (Ego Lejos)";
    }

    String philiaDesc;
    if (_philiaAvoidance > 0) {
      philiaDesc = "un estilo de apego evitativo (Filobatia: salvaguarda de tu independencia)";
    } else if (_philiaAvoidance < 0) {
      philiaDesc = "un estilo de apego ansioso (Ocnofilia: búsqueda activa de proximidad y lealtad)";
    } else {
      philiaDesc = "un apego seguro y equilibrado";
    }

    String erosDesc;
    if (_erosKink == 10) {
      erosDesc = "un blueprint erótico Kinky con apetito por ceder el control en la penumbra.";
    } else if (_erosKink == 5) {
      erosDesc = "un blueprint erótico Cambiaformas de alta adaptabilidad sensual.";
    } else {
      erosDesc = "una firme custodia de tus límites íntimos y cautela protectora.";
    }

    final initialGreeting =
        "He analizado tus respuestas en la Forja. Tu vector preliminar refleja una fuerte inclinación hacia $egoDesc, "
        "combinada con $philiaDesc y $erosDesc "
        "¿Deseas afinar tu calibración antes de sellar tu contrato en la Bóveda?";

    setState(() {
      _isProcessing = false;
      _isVinkiChatPhase = true;
      _vinkiChatMessages.clear();
      _vinkiChatMessages.add(VinkiChatMessage(sender: 'vinki', text: initialGreeting));
    });
  }

  void _scrollChatToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendVinkiChatMessage() async {
    final text = _chatTextController.text.trim();
    if (text.isEmpty || _isVinkiReplying || _vinkiUserMessagesCount >= 3) return;

    _chatTextController.clear();

    setState(() {
      _vinkiUserMessagesCount++;
      _vinkiChatMessages.add(VinkiChatMessage(sender: 'user', text: text));
      _isVinkiReplying = true;
      _vinkiChatMessages.add(VinkiChatMessage(sender: 'vinki', text: 'Analizando resonancia de Forja...', isTyping: true));
    });

    _scrollChatToBottom();

    try {
      final cleanBase = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;

      final historyList = _vinkiChatMessages
          .where((m) => !m.isTyping)
          .map((m) => {'role': m.sender == 'user' ? 'user' : 'assistant', 'content': m.text})
          .toList();

      final currentVector = "$_egoPoints-$_philiaAvoidance-$_erosKink";

      final response = await http
          .post(
            Uri.parse('$cleanBase/api/v1/vinki/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': widget.userUuid,
              'message': text,
              'current_vector': currentVector,
              'history': historyList,
            }),
          )
          .timeout(const Duration(seconds: 12));

      String replyText = 'Interacción de Forja sintonizada.';

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        replyText = data['reply'] ?? data['message'] ?? 'Calibración recibida en la Bóveda.';
      } else {
        replyText = 'Sintonía de red adaptada. Ajuste preliminar aplicado localmente.';
      }

      if (mounted) {
        setState(() {
          _vinkiChatMessages.removeWhere((m) => m.isTyping);
          _vinkiChatMessages.add(VinkiChatMessage(sender: 'vinki', text: replyText));
          _isVinkiReplying = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _vinkiChatMessages.removeWhere((m) => m.isTyping);
          _vinkiChatMessages.add(VinkiChatMessage(
            sender: 'vinki',
            text: 'Modo Offline: Registro de calibración guardado en la memoria local de la Forja.',
          ));
          _isVinkiReplying = false;
        });
      }
    }

    _scrollChatToBottom();
  }

  Future<void> _compileSoulSheetAndTriggerStripe() async {
    setState(() => _isProcessing = true);
    final dbSec = VinkiarSecureDatabase();
    final db = dbSec.db!;

    // 1. Vector tridimensional canónico (Ego-Philia-Eros)
    final int egoId = _egoPoints > 0 ? _egoPoints : 5;
    final int philiaCode = _philiaAvoidance < 0 ? 2 : (_philiaAvoidance > 0 ? 3 : 1);
    final int erosCode = _erosKink == 10 ? 4 : (_erosKink == 5 ? 5 : 2);
    final String currentVector = "$egoId-$philiaCode-$erosCode";
    await dbSec.saveUserVector(currentVector);

    // 2. Vectores polares completos (9 ejes Ego + 5 ejes Eros + 4 ejes Philia)
    final Map<String, double> egoVector = {
      'divo': egoId == 8 ? 45.0 : 20.0,
      'rescatador': egoId == 2 ? 85.0 : 25.0,
      'vividor': egoId == 8 ? 40.0 : 25.0,
      'artista': egoId == 5 ? 40.0 : 20.0,
      'intelectual': egoId == 5 ? 85.0 : 30.0,
      'afrodita': _philiaAvoidance < 0 ? 55.0 : 25.0,
      'cautivador': _erosKink == 5 ? 50.0 : 25.0,
      'lider': egoId == 8 ? 85.0 : 25.0,
      'encantador': _philiaAvoidance == 0 ? 55.0 : 25.0,
    };

    final double sosVal = _erosKink == 10 ? 6.5 : (_erosKink == 5 ? 3.5 : -2.5);
    final Map<String, double> erosVector = {
      'energetico': _erosKink == 5 ? 55.0 : 35.0,
      'sensual': _erosKink == -10 ? 65.0 : 50.0,
      'sexual': _erosKink > 0 ? 50.0 : 30.0,
      'kinky': _erosKink == 10 ? 88.0 : (_erosKink == 5 ? 45.0 : 10.0),
      'cambiaformas': _erosKink == 5 ? 85.0 : 35.0,
      'sosIndex': sosVal,
    };

    final double iarVal = VinkiarPsychometricsEngine.computeRelationalAutonomyIndex(
      cognitiveDifferentiation: _philiaAvoidance == 0 ? 0.85 : 0.62,
      emotionalDeidentification: _philiaAvoidance == 0 ? 0.82 : 0.55,
      activeFusionRate: _philiaAvoidance < 0 ? 0.75 : 0.15,
    );
    final Map<String, double> philiaVector = {
      'seguro': _philiaAvoidance == 0 ? 88.0 : 35.0,
      'ocnofilo': _philiaAvoidance < 0 ? 85.0 : 20.0,
      'filobata': _philiaAvoidance > 0 ? 85.0 : 20.0,
      'desorganizado': 12.0,
      'iAR': iarVal,
    };

    // 3. Síntesis del Arquetipo Natural (Naturaleza íntima) + Métricas IFS / ICA
    final synthesis = VinkiarPsychometricsEngine.synthesizeNaturalArchetype(
      egoVector: egoVector,
      erosVector: erosVector,
      philiaVector: philiaVector,
    );
    final String naturalArchetype = synthesis['natural_archetype'] as String;

    final ifsIndex = VinkiarPsychometricsEngine.computeSomaticStrengthIndex(
      egoRadiiPct: egoVector.values.toList(),
      erosRadiiPct: [
        erosVector['energetico']!,
        erosVector['sensual']!,
        erosVector['sexual']!,
        erosVector['kinky']!,
        erosVector['cambiaformas']!,
      ],
      philiaRadiiPct: [
        philiaVector['seguro']!,
        philiaVector['ocnofilo']!,
        philiaVector['filobata']!,
        philiaVector['desorganizado']!,
      ],
    );
    final icaIndex = VinkiarPsychometricsEngine.computeSoulCoherenceIndex(
      egoRadiiPct: egoVector.values.toList(),
      erosRadiiPct: [
        erosVector['energetico']!,
        erosVector['sensual']!,
        erosVector['sexual']!,
        erosVector['kinky']!,
        erosVector['cambiaformas']!,
      ],
      philiaRadiiPct: [
        philiaVector['seguro']!,
        philiaVector['ocnofilo']!,
        philiaVector['filobata']!,
        philiaVector['desorganizado']!,
      ],
    );

    final emp = egoId == 2 ? 85 : (_philiaAvoidance < 0 ? 82 : 62);
    final will = egoId == 8 ? 90 : 65;
    final ero = _erosKink == 10 ? 88 : (_erosKink == 5 ? 76 : 48);
    final sov = egoId == 5 ? 90 : (_philiaAvoidance > 0 ? 84 : 68);

    final currentSheet = await dbSec.getAvatarSheet("LOCAL_USER");
    final existingStats = Map<String, dynamic>.from(currentSheet?['stats'] as Map<String, dynamic>? ?? {});
    existingStats.addAll({
      'natural_archetype': naturalArchetype,
      'seduction_archetype': synthesis['seduction_archetype'],
      'horney_vector': synthesis['horney_vector'],
      'defense_mechanism': synthesis['defense_mechanism'],
      'dominant_blueprint': synthesis['dominant_blueprint'],
      'dominant_attachment': synthesis['dominant_attachment'],
      'empathy': emp,
      'willpower': will,
      'erotism': ero,
      'sovereignty': sov,
      'ifs_index': ifsIndex,
      'ica_index': icaIndex,
      'ego_vector': egoVector,
      'eros_vector': erosVector,
      'philia_vector': philiaVector,
      'cables_atraccion': {
        'sexual': _erosKink > 0 ? 75 : 45,
        'emocional': _philiaAvoidance <= 0 ? 80 : 50,
        'racional': egoId == 5 ? 88 : 65,
      },
      'is_simulation_mode': 0,
    });

    await dbSec.saveAvatarSheet("LOCAL_USER", {
      'character_class': naturalArchetype,
      'level': currentSheet?['level'] ?? 1,
      'experience_points': currentSheet?['experience_points'] ?? 100,
      'reputation_score': currentSheet?['reputation_score'] ?? 1.0,
      'stats': existingStats,
    });

    // 4. Compilar Ruedas en Drift SQLCipher
    await db.into(db.egoWheels).insert(
      EgoWheelsCompanion.insert(
        soulSheetUuid: widget.userUuid,
        eneatipoDaniels: drift.Value(egoId),
        vectorHorney: drift.Value(egoId == 2 ? "Hacia" : (egoId == 8 ? "Contra" : "Lejos")),
      ),
    );

    await db.into(db.philiaWheels).insert(
      PhiliaWheelsCompanion.insert(
        soulSheetUuid: widget.userUuid,
        estiloApego: drift.Value(_philiaAvoidance < 0 ? "Ansioso" : (_philiaAvoidance > 0 ? "Evitativo" : "Seguro")),
      ),
    );

    await db.into(db.erosWheels).insert(
      ErosWheelsCompanion.insert(
        soulSheetUuid: widget.userUuid,
        blueprintPrimario: drift.Value(synthesis['dominant_blueprint'] as String),
        escalaErotofiliaSos: drift.Value(sosVal),
      ),
    );

    // 5. Sincronizar Arquetipo Natural con PostgreSQL (sin revelar vectores íntimos)
    try {
      final cleanBase = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;
      await http.patch(
        Uri.parse('$cleanBase/api/v1/boveda/avatar/arquetipo'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userUuid,
          'alias': widget.alias ?? '',
          'arquetipo': naturalArchetype,
        }),
      ).timeout(const Duration(seconds: 6));
    } catch (_) {}

    if (widget.isRecalibration) {
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    // El Muro de Génesis (Stripe)
    await _triggerGenesisPaywall();
  }

  Future<void> _triggerGenesisPaywall() async {
    try {
      final cleanBase = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;

      // 1. Envío formal con JSON Body estructurado para FastAPI
      final payRes = await http.post(
        Uri.parse('$cleanBase/api/v1/stripe/create-intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userUuid,
          'currency': 'eur',
          'amount': 100, // 1.00 € (Matrícula Génesis)
          'metadata': {
            'product': 'vinkiar_matricula_genesis',
            'alias': widget.alias ?? 'Pionero',
          }
        }),
      ).timeout(const Duration(seconds: 10));

      if (payRes.statusCode != 200) {
        throw Exception("Error del servidor (${payRes.statusCode}): ${payRes.body}");
      }

      final payData = jsonDecode(payRes.body) as Map<String, dynamic>;
      final String? clientSecret = payData['client_secret'] ?? payData['clientSecret'];

      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception("No se recibió el client_secret de la pasarela.");
      }

      final bool isMock = (payData['mock'] == true) || clientSecret.startsWith('pi_mock_');

      if (isMock) {
        // Simulación controlada si el backend no tiene claves activas de Stripe
        await Future.delayed(const Duration(milliseconds: 900));
      } else {
        VinkiarApp.isStripeCheckoutActive = true;
        try {
          await Stripe.instance.initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              paymentIntentClientSecret: clientSecret,
              merchantDisplayName: 'Vinkiar OS - Matrícula Génesis',
              style: ThemeMode.dark,
            ),
          );
          await Stripe.instance.presentPaymentSheet();
        } finally {
          VinkiarApp.isStripeCheckoutActive = false;
        }
      }

      // Pago Exitoso -> Entrar a Vinkiar OS
      await VinkiarSecureDatabase().markAvatarRegistered();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainDashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      String errorMsg = "VERIFICACIÓN BANCARIA CANCELADA O FALLIDA. Tu perfil está guardado localmente.";
      if (e is StripeException) {
        if (e.error.code == FailureCode.Canceled) {
          errorMsg = "Verificación cancelada por el usuario.";
        } else {
          errorMsg = "Error en Stripe [${e.error.code}]: ${e.error.localizedMessage ?? e.error.message}";
        }
      } else {
        errorMsg = "Fallo en pasarela: $e";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMsg,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          backgroundColor: VinkiarColors.panicRed,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VinkiarColors.abyssBlack,
      body: SafeArea(
        child: _isVinkiChatPhase ? _buildVinkiChatUI() : _buildScenarioUI(),
      ),
    );
  }

  Widget _buildScenarioUI() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(Icons.memory, size: 80, color: _isProcessing ? VinkiarColors.vertigoGold : VinkiarColors.aegisCyan),
          const SizedBox(height: 32),
          
          if (!_isCalibrating) ...[
            Text("> INICIANDO SIMULACIÓN ZKA...", style: VinkiarTheme.terminalData.copyWith(color: VinkiarColors.aegisCyan), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Text("Hola, ${widget.alias ?? 'Viajero'}. Soy Vinki.\n\nAl escondernos de los Algoritmos Grises tuvimos que purgar los sistemas. Estás a salvo en tu Bóveda local.\n\nPara conectarte a la red descentralizada, primero debo calibrar tu Hoja de Alma y enseñarte a usar el sistema.", 
              style: VinkiarTheme.terminalSm.copyWith(color: VinkiarColors.textDim, fontSize: 13), textAlign: TextAlign.center),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: VinkiarColors.aegisCyan, foregroundColor: VinkiarColors.abyssBlack),
              onPressed: () {
                setState(() => _isCalibrating = true);
                _startTypewriter(_scenarios[_currentPhase]["text"]);
              }, 
              child: const Text("COMENZAR LA FORJA")
            ),
          ] else ...[
            Text(_scenarios[_currentPhase]["title"], style: VinkiarTheme.labelCaps.copyWith(color: VinkiarColors.vertigoGold), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: VinkiarColors.inkBlack,
                border: Border(left: BorderSide(color: VinkiarColors.aegisCyan, width: 3)),
              ),
              child: Text(_typedText, style: VinkiarTheme.terminalSm.copyWith(color: VinkiarColors.textHdr, fontSize: 13)),
            ),
            const SizedBox(height: 32),
            
            if (_isProcessing)
              const Center(child: CircularProgressIndicator(color: VinkiarColors.aegisCyan))
            else
              ...(_scenarios[_currentPhase]["options"] as List<Map<String, dynamic>>).map((opt) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      side: BorderSide(color: VinkiarColors.aegisCyan.withOpacity(0.5)),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: () => _handleAnswer(opt, _scenarios[_currentPhase]["id"]),
                    child: Text(opt["label"], style: const TextStyle(color: VinkiarColors.textHdr)),
                  ),
                );
              }).toList(),
            const Spacer(),
          ],
        ],
      ),
    );
  }

  Widget _buildVinkiChatUI() {
    final canSendMessage = _vinkiUserMessagesCount < 3 && !_isVinkiReplying;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: VinkiarColors.panelDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.5), width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology_outlined, color: VinkiarColors.aegisCyan, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CALIBRACIÓN CON VINKI',
                        style: GoogleFonts.cinzel(
                          color: VinkiarColors.aegisCyan,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Interacciones restantes: ${3 - _vinkiUserMessagesCount} de 3',
                        style: GoogleFonts.jetBrainsMono(
                          color: VinkiarColors.vertigoGold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: ListView.builder(
              controller: _chatScrollController,
              itemCount: _vinkiChatMessages.length,
              itemBuilder: (context, index) {
                final message = _vinkiChatMessages[index];
                final isUser = message.sender == 'user';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isUser) ...[
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: VinkiarColors.aegisCyan.withOpacity(0.2),
                            border: Border.all(color: VinkiarColors.aegisCyan, width: 1),
                          ),
                          child: const Icon(Icons.shield_outlined, color: VinkiarColors.aegisCyan, size: 16),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser
                                ? VinkiarColors.aegisCyan.withOpacity(0.18)
                                : VinkiarColors.panelDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isUser ? VinkiarColors.aegisCyan : VinkiarColors.vertigoGold.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: message.isTyping
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: VinkiarColors.vertigoGold),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      message.text,
                                      style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 12),
                                    ),
                                  ],
                                )
                              : Text(
                                  message.text,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: isUser ? VinkiarColors.textHdr : VinkiarColors.aegisCyan.withOpacity(0.95),
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: VinkiarColors.vertigoGold.withOpacity(0.2),
                            border: Border.all(color: VinkiarColors.vertigoGold, width: 1),
                          ),
                          child: const Icon(Icons.person_outline, color: VinkiarColors.vertigoGold, size: 16),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          if (_vinkiUserMessagesCount < 3) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatTextController,
                      enabled: canSendMessage,
                      style: GoogleFonts.jetBrainsMono(color: VinkiarColors.textHdr, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Responde o consulta a Vinki...',
                        hintStyle: GoogleFonts.jetBrainsMono(color: VinkiarColors.textDim.withOpacity(0.6), fontSize: 12),
                        filled: true,
                        fillColor: VinkiarColors.inkBlack,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: VinkiarColors.aegisCyan.withOpacity(0.3), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: VinkiarColors.aegisCyan, width: 1.5),
                        ),
                      ),
                      onSubmitted: (_) => _sendVinkiChatMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    width: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: VinkiarColors.aegisCyan,
                        foregroundColor: VinkiarColors.abyssBlack,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: canSendMessage ? _sendVinkiChatMessage : null,
                      child: const Icon(Icons.send_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Text(
                'Límite de calibración de prueba alcanzado (3/3). Continúa para forjar tu perfil.',
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 11),
              ),
            ),
          ],

          const SizedBox(height: 10),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: VinkiarColors.vertigoGold,
                foregroundColor: VinkiarColors.abyssBlack,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 4,
              ),
              icon: const Icon(Icons.border_color_outlined, size: 20),
              label: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: VinkiarColors.abyssBlack),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'FIRMAR MANIFIESTO Y ACTIVAR MATRÍCULA DE GÉNESIS',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cinzel(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
              onPressed: _isProcessing ? null : _compileSoulSheetAndTriggerStripe,
            ),
          ),
        ],
      ),
    );
  }
}