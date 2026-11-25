import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:uuid/uuid.dart';

import '../config/api_config.dart';
import '../services/vinkiar_secure_database.dart';
import '../services/vinkiar_stripe_service.dart';
import 'taberna_screen.dart';
import 'radar_screen.dart';
import 'boveda_screen.dart';
import 'chat_qa_screen.dart';
import 'contacts_screen.dart';
import '../main.dart';
import 'main_dashboard_screen.dart';
import 'theme.dart';
import 'widgets/vinki_chat_modal.dart';

class SimulationDashboardScreen extends StatefulWidget {
  const SimulationDashboardScreen({Key? key}) : super(key: key);

  @override
  State<SimulationDashboardScreen> createState() => _SimulationDashboardScreenState();
}

class _SimulationDashboardScreenState extends State<SimulationDashboardScreen> {
  int _currentIndex = 2; // Pestaña central: La Bóveda
  int _eneagramProgress = 0;
  String _userAlias = "Pionero";
  String _detectedArchetype = "POR DEFINIR";

  final Set<int> _completedNodes = {};
  final GlobalKey<BovedaScreenState> _bovedaKey = GlobalKey<BovedaScreenState>();

  int _egoScore = 0;
  int _erosScore = 0;
  int _philiaScore = 0;

  int _empathy = 0;
  int _willpower = 0;
  int _erotism = 0;
  int _sovereignty = 0;

  String _naturalArchetype = "POR DEFINIR";
  String _chosenArchetype = "NINGUNO";
  double _alignmentPercentage = 0.0;

  Map<String, dynamic> _egoVectorMap = {};
  Map<String, dynamic> _erosVectorMap = {};
  Map<String, dynamic> _philiaVectorMap = {};

  bool _isProcessingPayment = false; // Candado para evitar doble-click en Stripe

  @override
  void initState() {
    super.initState();
    _initSimulationState();
  }

  Future<void> _initSimulationState() async {
    final db = VinkiarSecureDatabase();
    final avatar = await db.getAvatarSheet("LOCAL_USER");
    final stats = avatar?['stats'] as Map<String, dynamic>? ?? {};

    if (mounted) {
      setState(() {
        _userAlias = stats['alias'] ?? avatar?['alias'] ?? 'Pionero';
        _empathy = 0;
        _willpower = 0;
        _erotism = 0;
        _sovereignty = 0;
        _naturalArchetype = "POR DEFINIR";
        _chosenArchetype = "NINGUNO";
        _alignmentPercentage = 0.0;
        _eneagramProgress = 0;
      });

      // Disparar bienvenida de Vinki
      WidgetsBinding.instance.addPostFrameCallback((_) => _showVinkiWelcomeDialog());
    }
  }

  void _showVinkiWelcomeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: VinkiarColors.abyssBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: VinkiarColors.aegisCyan, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.smart_toy, color: VinkiarColors.aegisCyan, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    "CALIBRACIÓN VIVA DE LA FORJA",
                    style: GoogleFonts.jetBrainsMono(
                      color: VinkiarColors.aegisCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                "Hola, $_userAlias. Tu Triple Eneagrama y tus atributos se encuentran en reposo (0%).\n\nConforme resuelvas los dilemas de cada nodo, la geometría de tus tres órbitas (Ego, Eros y Philia) comenzará a proyectarse en tiempo real.",
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VinkiarColors.panelDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.5)),
                ),
                child: Text(
                  "• Arquetipo Natural y Rol Social: BLOQUEADOS hasta sintonizar con Vinki.\n• Responde los 5 dilemas para definir tu vector.\n• Al 100%, Vinki perfilará tu Hoja de Alma antes del pago.",
                  style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 10.5, height: 1.3),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VinkiarColors.aegisCyan,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (!_completedNodes.contains(2)) {
                      _triggerDilemmaModal(2);
                    }
                  },
                  child: Text(
                    "INICIAR FORJA EN LA BÓVEDA",
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 10.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    if (index == 2) _bovedaKey.currentState?.reload();
    if (!_completedNodes.contains(index)) _triggerDilemmaModal(index);
  }

  void _triggerDilemmaModal(int nodeIndex) {
    Map<String, dynamic> scenario;
    switch (nodeIndex) {
      case 2:
        scenario = {
          "title": "NODO 1: LA BÓVEDA (Rueda II: Eros)",
          "lore": "Un cofrade de La Corte del Loto te propone una dinámica de privación visual (venda en los ojos) y focalización sensorial en la penumbra. ¿Cómo responde tu cuerpo?",
          "options": [
            {"label": "[A] Exijo control visual. Tensión ante la pérdida de control.", "wheel": "EROS", "val": -10, "astucia": 10, "soberania": 25, "color": VinkiarColors.panicRed},
            {"label": "[B] Curiosidad. En entorno consensuado y seguro, mi cuerpo se adapta.", "wheel": "EROS", "val": 5, "astucia": 20, "soberania": 20, "color": VinkiarColors.aegisCyan},
            {"label": "[C] Me excita explorar el juego de poder y ceder la guía en la sombra.", "wheel": "EROS", "val": 10, "astucia": 30, "soberania": 15, "color": Colors.purpleAccent}
          ]
        };
        break;
      case 0:
        scenario = {
          "title": "NODO 2: LA TABERNA (Rueda I: Ego)",
          "lore": "Un aliado perseguido solicita ayuda P2P para infiltrarse en un servidor corporativo. No tiene recursos y la mesa vacila. ¿Cuál es tu reacción instintiva?",
          "options": [
            {"label": "[A] Asumo el mando de la mesa. Dirijo la estrategia con rigor absoluto.", "wheel": "EGO", "val": 8, "voluntad": 30, "empatia": 10, "archetype": "TANQUE DE LA ÉGIDA (E8/E1)", "color": VinkiarColors.vertigoGold},
            {"label": "[B] Me ofrezco de voluntario para el trabajo pesado. Priorizo cuidarlo.", "wheel": "EGO", "val": 2, "voluntad": 15, "empatia": 30, "archetype": "SANADOR SOMÁTICO (E2/E9)", "color": VinkiarColors.aegisCyan},
            {"label": "[C] Analizo los datos desde mi Bóveda en silencio y les envío un manual.", "wheel": "EGO", "val": 5, "voluntad": 20, "empatia": 15, "archetype": "TECNOMANTE INFILTRADOR (E5/E3)", "color": Colors.blueAccent}
          ]
        };
        break;
      case 1:
        scenario = {
          "title": "NODO 3: EL RADAR (Rueda III: Philia)",
          "lore": "El Radar detecta el ping débil de un vínculo afectivo que desapareció sin explicación hace años. ¿Qué protocolo ejecutas ante la incertidumbre relacional?",
          "options": [
            {"label": "[A] Acudo de inmediato. Me aterra pensar que me necesite y perderlo de nuevo.", "wheel": "PHILIA", "val": -10, "empatia": 25, "voluntad": 10, "color": VinkiarColors.panicRed},
            {"label": "[B] Bloqueo la señal. El pasado compromete mi autonomía presente.", "wheel": "PHILIA", "val": 10, "empatia": 10, "soberania": 25, "color": VinkiarColors.vertigoGold},
            {"label": "[C] Abro un canal seguro ZKA, evalúo el contexto y respondo asertivamente.", "wheel": "PHILIA", "val": 0, "empatia": 25, "soberania": 25, "color": VinkiarColors.aegisCyan}
          ]
        };
        break;
      case 3:
        scenario = {
          "title": "NODO 4: CHAT ZKA (Defusión Cognitiva)",
          "lore": "Vinki analiza tu calibración: 'Veo cómo reaccionas a la presión, a la intimidad y al desapego. ¿Estás dispuesto a jugar con tu Máscara sin identificarte con ella?'",
          "options": [
            {"label": "[A] Acepto la Máscara como una herramienta lúdica y flexible.", "wheel": "ACT", "val": 10, "soberania": 20, "voluntad": 20, "color": VinkiarColors.aegisCyan},
            {"label": "[B] Deseo profundizar en las contradicciones entre mi mente y mi piel.", "wheel": "ACT", "val": 5, "astucia": 20, "empatia": 20, "color": VinkiarColors.vertigoGold}
          ]
        };
        break;
      case 4:
      default:
        scenario = {
          "title": "NODO 5: LA CÉLULA (Consolidación de Vectores)",
          "lore": "Llegas al epicentro de la red. Tus 3 órbitas han alcanzado resonancia completa. Vinki está lista para perfilar tu Hoja de Alma y evaluar tu arquetipo en diálogo directo.",
          "options": [
            {"label": "[A] Sellar Vectores y Abrir Diálogo de Calibración con Vinki.", "wheel": "TRIBE", "val": 100, "empatia": 10, "voluntad": 10, "astucia": 10, "soberania": 10, "color": VinkiarColors.vertigoGold}
          ]
        };
        break;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: VinkiarColors.abyssBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scenario['options'][0]['color'] as Color, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scenario['title'],
                  style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(scenario['lore'], style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, height: 1.4)),
                const SizedBox(height: 16),
                ...((scenario['options'] as List).map((opt) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: opt['color'] as Color),
                          padding: const EdgeInsets.all(12),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _processDilemmaAnswer(nodeIndex, opt);
                        },
                        child: Text(opt['label'], style: GoogleFonts.outfit(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  );
                }).toList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processDilemmaAnswer(int nodeIndex, Map<String, dynamic> option) async {
    _completedNodes.add(nodeIndex);

    final String wheel = option['wheel'] ?? '';
    final int val = option['val'] ?? 0;

    _empathy = (_empathy + (option['empatia'] as int? ?? 0)).clamp(0, 100);
    _willpower = (_willpower + (option['voluntad'] as int? ?? 0)).clamp(0, 100);
    _erotism = (_erotism + (option['astucia'] as int? ?? 0)).clamp(0, 100);
    _sovereignty = (_sovereignty + (option['soberania'] as int? ?? 0)).clamp(0, 100);

    if (wheel == 'EGO') _egoScore = val;
    if (wheel == 'EROS') _erosScore = val;
    if (wheel == 'PHILIA') _philiaScore = val;

    final newProgress = (_completedNodes.length * 20).clamp(0, 100);

    _egoVectorMap = {
      "divo": _egoScore == 8 ? 85 : (_completedNodes.contains(0) ? 20 : 0),
      "rescatador": _egoScore == 2 ? 90 : (_completedNodes.contains(0) ? 20 : 0),
      "vividor": _completedNodes.contains(0) ? 25 : 0,
      "artista": _completedNodes.contains(0) ? 35 : 0,
      "intelectual": _egoScore == 5 ? 85 : (_completedNodes.contains(0) ? 20 : 0),
      "cautivador": _completedNodes.contains(0) ? 30 : 0,
      "entusiasta": _completedNodes.contains(0) ? 40 : 0,
      "lider": _egoScore == 8 ? 90 : (_completedNodes.contains(0) ? 30 : 0),
      "encantador": _completedNodes.contains(0) ? 25 : 0,
    };

    _erosVectorMap = {
      "sensual": _erosScore == -10 ? 88 : (_completedNodes.contains(2) ? 30 : 0),
      "kinky": _erosScore == 10 ? 92 : (_completedNodes.contains(2) ? 25 : 0),
      "energico": _completedNodes.contains(2) ? 35 : 0,
      "sexual": _completedNodes.contains(2) ? 40 : 0,
      "cambiaformas": _erosScore == 5 ? 85 : (_completedNodes.contains(2) ? 25 : 0),
      "sosIndex": _erosScore > 0 ? 7.8 : (_erosScore < 0 ? 2.5 : 5.0),
    };

    _philiaVectorMap = {
      "seguro": _philiaScore == 0 ? 82 : (_completedNodes.contains(1) ? 25 : 0),
      "ocnofilo": _philiaScore == -10 ? 85 : (_completedNodes.contains(1) ? 20 : 0),
      "desorganizado": _completedNodes.contains(1) ? 15 : 0,
      "filobata": _philiaScore == 10 ? 85 : (_completedNodes.contains(1) ? 20 : 0),
      "iAR": _philiaScore == 0 ? 0.78 : (_philiaScore == 10 ? 0.55 : 0.35),
    };

    int egoNode = _egoScore == 8 ? 8 : (_egoScore == 2 ? 2 : (_egoScore == 5 ? 5 : 0));
    int erosNode = _erosScore == 10 ? 8 : (_erosScore == 5 ? 5 : (_erosScore == -10 ? 2 : 0));
    int philiaNode = _philiaScore == -10 ? 2 : (_philiaScore == 10 ? 5 : (_philiaScore == 0 && _completedNodes.contains(1) ? 9 : 0));

    String vector3D = newProgress == 0 ? "0-0-0" : "$egoNode-$erosNode-$philiaNode";

    if (newProgress >= 100) {
      if (option['archetype'] != null) {
        _detectedArchetype = option['archetype'];
      } else if (_egoScore == 8) {
        _detectedArchetype = "TANQUE DE LA ÉGIDA (E8/E1)";
      } else if (_egoScore == 2) {
        _detectedArchetype = "SANADOR SOMÁTICO (E2/E9)";
      } else {
        _detectedArchetype = "TECNOMANTE INFILTRADOR (E5/E3)";
      }
      _naturalArchetype = _detectedArchetype;
      _alignmentPercentage = 75.0;
    }

    final db = VinkiarSecureDatabase();
    await db.saveAvatarSheet("LOCAL_USER", {
      "alias": _userAlias,
      "character_class": _detectedArchetype,
      "xp": newProgress,
      "is_simulation_mode": 1,
      "stats": {
        "alias": _userAlias,
        "is_simulation_mode": 1,
        "empathy": _empathy,
        "willpower": _willpower,
        "erotism": _erotism,
        "sovereignty": _sovereignty,
        "natural_archetype": _naturalArchetype,
        "chosen_archetype": _chosenArchetype,
        "alignment_percentage": _alignmentPercentage,
        "ego_vector": _egoVectorMap,
        "eros_vector": _erosVectorMap,
        "philia_vector": _philiaVectorMap,
      }
    });

    await db.saveUserVector(vector3D);
    setState(() => _eneagramProgress = newProgress);
    _bovedaKey.currentState?.reload();

    if (newProgress >= 100) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const VinkiChatModal(userId: "LOCAL_USER"),
      ).then((_) {
        if (mounted) _showGenesisUnlockModal();
      });
    }
  }

  void _showGenesisUnlockModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.vertigoGold, width: 1.5),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SELLAR HOJA DE ALMA Y ACTIVAR RED REAL",
                style: GoogleFonts.jetBrainsMono(
                  color: VinkiarColors.vertigoGold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "¡Forja completada, $_userAlias!\n\nVinki ha integrado tus respuestas. Tu Arquetipo Natural es $_naturalArchetype.\n\nPara activar tus canales P2P y salir de la simulación hacia la red física, sella tu matrícula de Génesis (1.00 € / año).",
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11.5, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VinkiarColors.vertigoGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: _isProcessingPayment 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.lock_open, size: 18),
                  label: Text(
                    _isProcessingPayment ? "PROCESANDO MATRÍCULA..." : "PAGAR 1.00 € Y ACCEDER A VINKIAR OS",
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  onPressed: _isProcessingPayment ? null : () async {
                    setModalState(() => _isProcessingPayment = true);
                    await _executeStripeGenesisPayment(ctx);
                    if (mounted) setModalState(() => _isProcessingPayment = false);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executeStripeGenesisPayment(BuildContext modalContext) async {
    try {
      final userId = const Uuid().v4();
      final stripeService = VinkiarStripeService();
      
      // 1. Pedimos el secreto al backend
      final clientSecret = await stripeService.createMatriculaPaymentIntent(
        userUuid: userId,
        amountCents: 100,
        currency: 'eur',
      );

      if (clientSecret.startsWith('pi_mock_')) {
        await Future.delayed(const Duration(milliseconds: 900));
      } else {
        VinkiarApp.isStripeCheckoutActive = true;
        try {
          // 2. Inicializamos la PaymentSheet de Stripe
          await Stripe.instance.initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              paymentIntentClientSecret: clientSecret,
              merchantDisplayName: 'Vinkiar OS',
              style: ThemeMode.dark,
            ),
          );

          // 3. Mostramos la pantalla nativa de pago
          await Stripe.instance.presentPaymentSheet();
        } finally {
          VinkiarApp.isStripeCheckoutActive = false;
        }
      }

      // --- PAGO EXISTOSO ---
      final db = VinkiarSecureDatabase();

      // Guardamos el Avatar validado, quitamos is_simulation_mode
      await db.saveAvatarSheet("LOCAL_USER", {
        "alias": _userAlias,
        "character_class": _detectedArchetype,
        "xp": 100,
        "is_simulation_mode": 0,
        "stats": {
          "alias": _userAlias,
          "is_simulation_mode": 0,
          "empathy": _empathy,
          "willpower": _willpower,
          "erotism": _erotism,
          "sovereignty": _sovereignty,
          "natural_archetype": _naturalArchetype,
          "chosen_archetype": _chosenArchetype,
          "alignment_percentage": _alignmentPercentage,
          "ego_vector": _egoVectorMap,
          "eros_vector": _erosVectorMap,
          "philia_vector": _philiaVectorMap,
        }
      });

      await db.markAvatarRegistered();

      // Cerramos el modal
      if (mounted) Navigator.pop(modalContext);

      // Limpiamos todo el árbol y lanzamos el Dashboard real
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainDashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: VinkiarColors.panicRed,
            content: Text("PAGO CANCELADO O FALLIDO. Tu forja permanece en memoria local."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      const TabernaScreen(),
      const RadarScreen(),
      BovedaScreen(key: _bovedaKey),
      const ChatQAScreen(),
      const ContactsScreen(),
    ];

    return Scaffold(
      backgroundColor: VinkiarColors.abyssBlack,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(54),
        child: SafeArea(
          child: Container(
            color: VinkiarColors.panelDark,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.smart_toy, color: VinkiarColors.vertigoGold, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "FORJA DEMO: $_eneagramProgress% (${_completedNodes.length}/5 NODOS)",
                    style: GoogleFonts.jetBrainsMono(
                      color: VinkiarColors.vertigoGold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_eneagramProgress >= 100)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VinkiarColors.vertigoGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    onPressed: _showGenesisUnlockModal,
                    child: Text("ACTIVAR (1.00 €)", style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        backgroundColor: VinkiarColors.panelDark,
        selectedItemColor: VinkiarColors.aegisCyan,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: "Taberna"),
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: "Radar"),
          BottomNavigationBarItem(icon: Icon(Icons.shield), label: "Bóveda"),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Chat ZKA"),
          BottomNavigationBarItem(icon: Icon(Icons.group_outlined), label: "Célula"),
        ],
      ),
    );
  }
}