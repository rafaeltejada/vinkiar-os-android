import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/acoustic_sentinel_service.dart';
import '../services/evidence_vault_service.dart';
import '../services/safety_config_service.dart';
import '../services/vinkiar_secure_database.dart';
import 'aftercare_screen.dart';
import 'theme.dart';
import 'unlock_bunker_screen.dart';
import 'widgets/analog_clock_decoy.dart';

typedef JsonMap = Map<String, dynamic>;

// =========================================================================
// SECCIÓN 1: DECLARACIÓN DEL WIDGET DE PANTALLA DE HUMO Y SEÑUELO TÁCTICO
// =========================================================================
class SmokeScreenOverlay extends StatefulWidget {
  final SentinelTriggerReason reason;
  final bool isEmergencySOS;

  /// Bandera global para evitar duplicar superposiciones si llegan múltiples gatillos
  static bool isOverlayOpen = false;

  const SmokeScreenOverlay({
    Key? key,
    required this.reason,
    this.isEmergencySOS = false,
  }) : super(key: key);

  @override
  State<SmokeScreenOverlay> createState() => _SmokeScreenOverlayState();
}

class _SmokeScreenOverlayState extends State<SmokeScreenOverlay> {
  // =========================================================================
  // SECCIÓN 2: CANAL NATIVO ANDROID, ESTADO DEL SEÑUELO Y TEMPORIZADORES
  // =========================================================================
  static const MethodChannel _nativeChannel = MethodChannel('com.vinkiar.os/hardware_sos');

  bool _isDecoyActive = false;
  bool _isDisarmed = false; // Impide que tareas asíncronas reactiven GPS/audio tras cancelar
  bool _isVerifyingPin = false;
  String _calcDisplay = "0";
  String _pinBuffer = "";
  double? _calcFirstOperand;
  String? _calcPendingOp;
  bool _calcResetOnNextDigit = false;
  DecoyType _currentDecoyType = DecoyType.calculator;
  String? _simulatedCrashMessage;

  Timer? _protocol3Timer;
  static const Duration _protocol3Duration = Duration(minutes: 10);
  bool _protocol3Activated = false;
  Timer? _autoExitTimer;

  final TextEditingController _pinController = TextEditingController();
  final List<String> _notes = [
    "Comprar café en grano y leche de avena",
    "Revisar presupuesto del mes antes del viernes",
    "Llamar al taller sobre los frenos del coche",
    "Cita médica el martes a las 11:30",
  ];

  // =========================================================================
  // SECCIÓN 3: CICLO DE VIDA Y SILENCIAMIENTO INMEDIATO DEL SISTEMA
  // =========================================================================
  @override
  void initState() {
    super.initState();
    SmokeScreenOverlay.isOverlayOpen = true;
    AcousticSentinelService().isOverlayActive = true;

    _loadDecoyPreference();

    if (widget.isEmergencySOS) {
      _isDecoyActive = true;
      // Paso 1: Silenciar de inmediato cualquier sonido/pitido de notificación en Android
      // y emitir únicamente confirmación táctil por vibración.
      _activateSilentModeAndVibrate();

      // Paso 2: Despachar alerta inmediata al Ancla e iniciar captura forense GPS/audio
      _dispatchImmediateEmergencyAlert();

      // Paso 3: Iniciar cuenta atrás de 10 minutos para escalada máxima (Protocolo 3)
      _startProtocol3Timer();
    }
  }

  @override
  void dispose() {
    SmokeScreenOverlay.isOverlayOpen = false;
    AcousticSentinelService().isOverlayActive = false;
    _protocol3Timer?.cancel();
    _autoExitTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  /// Silencia el canal multimedia/notificaciones de Android y vibra discretamente
  Future<void> _activateSilentModeAndVibrate() async {
    try {
      await _nativeChannel.invokeMethod('muteSystemAudio');
    } catch (_) {}
    await _triggerHardwareVibration();
  }

  // =========================================================================
  // SECCIÓN 4: SINCRONIZACIÓN DE PREFERENCIA DE SEÑUELO (SQLCIPHER + CONFIG)
  // =========================================================================
  /// Recupera el señuelo elegido por el usuario (Calculadora, Reloj o Notas)
  /// contrastando SafetyConfigService con la Bóveda cifrada para evitar reinicios.
  Future<void> _loadDecoyPreference() async {
    DecoyType resolvedType = DecoyType.calculator;

    try {
      final cfg = await SafetyConfigService().getConfig();
      resolvedType = cfg.decoyType;
    } catch (_) {}

    try {
      final avatar = await VinkiarSecureDatabase().getAvatarSheet("LOCAL_USER");
      final stats = avatar?['stats'] as JsonMap? ?? {};
      final dbDecoy = stats['decoy_type']?.toString().toLowerCase() ?? '';
      if (dbDecoy == 'clock') {
        resolvedType = DecoyType.clock;
      } else if (dbDecoy == 'notes') {
        resolvedType = DecoyType.notes;
      } else if (dbDecoy == 'calculator') {
        resolvedType = DecoyType.calculator;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentDecoyType = resolvedType;
      });
    }
  }

  // =========================================================================
  // SECCIÓN 5: DESPACHO DE ALERTA SOS AL ANCLA Y CAPTURA FORENSE WORM
  // =========================================================================
  /// Inicia la grabación ambiental continua y el envío de telemetría GPS al Ancla
  Future<void> _dispatchImmediateEmergencyAlert() async {
    if (_isDisarmed) return;
    try {
      final db = VinkiarSecureDatabase();
      final avatar = await db.getAvatarSheet("LOCAL_USER");
      final stats = avatar?['stats'] as JsonMap? ?? {};
      final alias = avatar?['alias'] ?? stats['alias'] ?? "#LOCAL_AVATAR";

      final cfg = await SafetyConfigService().getConfig();
      final anchor = cfg.anchorHandle.isNotEmpty
          ? cfg.anchorHandle
          : (stats['anchor_handle'] ?? "#ANCLA_SIN_DESIGNAR");

      if (_isDisarmed) return;
      debugPrint("🚨 [GATILLO SOS] Señuelo desplegado en silencio. Notificando a El Ancla ($anchor)...");

      await EvidenceVaultService().initiateBlackBoxCapture(victimHandle: alias.toString());
    } catch (e) {
      debugPrint("⚠️ [EL ANCLA ERROR] Error en despacho inicial de emergencia: $e");
    }
  }

  // =========================================================================
  // SECCIÓN 6: PROTOCOLO 3 (ESCALADA A 10 MINUTOS) Y CIERRE SIMULADO
  // =========================================================================
  void _startProtocol3Timer() {
    _protocol3Timer?.cancel();
    _protocol3Timer = Timer(_protocol3Duration, () {
      if (!_isDisarmed) {
        _detonateProtocol3();
      }
    });
  }

  /// Ejecuta el sellado definitivo de evidencias y purga llaves RAM si no hubo desarme
  Future<void> _detonateProtocol3() async {
    if (_protocol3Activated || _isDisarmed) return;
    _protocol3Activated = true;

    await _triggerHardwareVibration();

    try {
      final db = VinkiarSecureDatabase();
      final avatar = await db.getAvatarSheet("LOCAL_USER");
      final stats = avatar?['stats'] as JsonMap? ?? {};
      final alias = avatar?['alias'] ?? stats['alias'] ?? "#LOCAL_AVATAR";

      if (!_isDisarmed) {
        await EvidenceVaultService().initiateBlackBoxCapture(victimHandle: alias.toString());
      }
    } catch (_) {}

    try {
      VinkiarSecureDatabase().clearKeys();
    } catch (_) {}

    try {
      await _nativeChannel.invokeMethod('muteSystemAudio');
    } catch (_) {}
  }

  Future<void> _triggerHardwareVibration() async {
    try {
      await _nativeChannel.invokeMethod('vibrateEmergencyPattern');
    } catch (_) {
      HapticFeedback.vibrate();
    }
  }

  /// Simula cierre inesperado de la app señuelo tras introducir PIN de Coacción
  void _executeFakeCrashExit() {
    _autoExitTimer?.cancel();
    AcousticSentinelService().isOverlayActive = false;
    SmokeScreenOverlay.isOverlayOpen = false;
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UnlockBunkerScreen()),
        (route) => false,
      );
    }
    try {
      _nativeChannel.invokeMethod('exitToHome');
    } catch (_) {}
  }

  // =========================================================================
  // SECCIÓN 7: VALIDACIÓN DE PIN SEGURO (DESARME TOTAL) Y PIN DE COACCIÓN
  // =========================================================================
  void _showSafePinDialog() {
    _pinController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          "Desbloqueo de Búnker",
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Ingresa tu PIN Seguro para desarmar el señuelo y detener el envío de GPS y audio.",
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 18, letterSpacing: 8),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  counterText: "",
                  hintText: "••••",
                  hintStyle: TextStyle(color: Colors.white30),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF))),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("CANCELAR", style: GoogleFonts.outfit(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final pin = _pinController.text.trim();
              Navigator.pop(ctx);
              if (pin.isNotEmpty) {
                await _verifyPin(pin);
              }
            },
            child: Text("DESARMAR", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool> _matchesSafePin(String candidate) async {
    final clean = candidate.trim();
    if (clean.length < 4) return false;

    final safety = SafetyConfigService();
    if (await safety.verifySafePin(clean)) return true;
    if (clean.length > 4 && await safety.verifySafePin(clean.substring(clean.length - 4))) {
      return true;
    }

    try {
      final avatar = await VinkiarSecureDatabase().getAvatarSheet("LOCAL_USER");
      final stats = avatar?['stats'] as JsonMap? ?? {};
      final dbSafe = (stats['safe_pin']?.toString().trim().isNotEmpty == true)
          ? stats['safe_pin'].toString().trim()
          : "9999";
      if (clean == dbSafe || (clean.length > dbSafe.length && clean.endsWith(dbSafe))) {
        return true;
      }
    } catch (_) {
      if (clean == "9999" || clean.endsWith("9999")) return true;
    }
    return false;
  }

  Future<bool> _matchesDuressPin(String candidate) async {
    final clean = candidate.trim();
    if (clean.length < 4) return false;

    final safety = SafetyConfigService();
    if (await safety.verifyDuressPin(clean)) return true;
    if (clean.length > 4 && await safety.verifyDuressPin(clean.substring(clean.length - 4))) {
      return true;
    }

    try {
      final avatar = await VinkiarSecureDatabase().getAvatarSheet("LOCAL_USER");
      final stats = avatar?['stats'] as JsonMap? ?? {};
      final dbDuress = (stats['duress_pin']?.toString().trim().isNotEmpty == true)
          ? stats['duress_pin'].toString().trim()
          : "1111";
      if (clean == dbDuress || (clean.length > dbDuress.length && clean.endsWith(dbDuress))) {
        return true;
      }
    } catch (_) {
      if (clean == "1111" || clean.endsWith("1111")) return true;
    }
    return false;
  }

  /// Comprueba si el código introducido en el señuelo corresponde al PIN Seguro o Coacción
  Future<void> _verifyPin(String pin) async {
    if (_isVerifyingPin || _isDisarmed) return;
    _isVerifyingPin = true;

    try {
      // 1. DESARME LEGÍTIMO CON PIN SEGURO
      if (await _matchesSafePin(pin)) {
        _isDisarmed = true;
        _protocol3Timer?.cancel();
        _protocol3Timer = null;
        _autoExitTimer?.cancel();

        // Detener inmediatamente la grabación de audio y transmisión GPS (con protección ante fallos de red)
        try {
          await EvidenceVaultService().cancelIncident(reason: "DESARME_PIN_SEGURO");
        } catch (e) {
          debugPrint("⚠️ [DESARME] Error cancelando incidente en servidor: $e");
        }

        try {
          await AcousticSentinelService().stopSurveillance();
        } catch (_) {}

        // Detener servicios nativos en segundo plano y restaurar volumen del sistema
        try {
          await _nativeChannel.invokeMethod('stopSentinelForegroundService');
        } catch (_) {}
        try {
          await _nativeChannel.invokeMethod('stopHardwareSosService');
        } catch (_) {}
        try {
          await _nativeChannel.invokeMethod('unmuteSystemAudio');
        } catch (_) {}

        HapticFeedback.lightImpact();

        if (mounted) {
          SmokeScreenOverlay.isOverlayOpen = false;
          AcousticSentinelService().isOverlayActive = false;
          try {
            Provider.of<AppState>(context, listen: false).logout();
          } catch (_) {}

          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const UnlockBunkerScreen()),
            (route) => false,
          );
        }
        return;
      }

      // 2. PIN DE COACCIÓN (SIMULA FALLO DE APP MIENTRAS MANTIENE AUXILIO ACTIVO)
      if (await _matchesDuressPin(pin)) {
        _protocol3Timer?.cancel();
        _protocol3Timer = null;

        await _detonateProtocol3();

        String crashPackage = "com.android.calculator2";
        if (_currentDecoyType == DecoyType.clock) crashPackage = "com.android.deskclock";
        if (_currentDecoyType == DecoyType.notes) crashPackage = "com.android.notes";

        if (mounted) {
          setState(() {
            _calcDisplay = "0";
            _pinBuffer = "";
            _simulatedCrashMessage = "El proceso $crashPackage se ha detenido inesperadamente.";
          });
        }

        _autoExitTimer?.cancel();
        _autoExitTimer = Timer(const Duration(milliseconds: 2500), () {
          _executeFakeCrashExit();
        });
        return;
      }
    } finally {
      _isVerifyingPin = false;
    }
  }

  void _onDecoyDigit(String digit) async {
    if (_simulatedCrashMessage != null) return;

    setState(() {
      _pinBuffer += digit;
      if (_pinBuffer.length > 8) {
        _pinBuffer = _pinBuffer.substring(_pinBuffer.length - 8);
      }

      if (_calcDisplay == "0" || _calcResetOnNextDigit) {
        _calcDisplay = digit;
        _calcResetOnNextDigit = false;
      } else {
        _calcDisplay += digit;
      }
    });

    await _verifyPin(_pinBuffer);
  }

  void _onCalculatorOperator(String op) {
    if (_simulatedCrashMessage != null) return;
    HapticFeedback.selectionClick();
    final currentVal = double.tryParse(_calcDisplay) ?? 0.0;

    setState(() {
      _pinBuffer = "";
      if (op == 'C') {
        _calcDisplay = "0";
        _calcFirstOperand = null;
        _calcPendingOp = null;
        _calcResetOnNextDigit = false;
        return;
      }

      if (_calcFirstOperand != null && _calcPendingOp != null && !_calcResetOnNextDigit) {
        double res = currentVal;
        switch (_calcPendingOp) {
          case '+':
            res = _calcFirstOperand! + currentVal;
            break;
          case '-':
            res = _calcFirstOperand! - currentVal;
            break;
          case '*':
            res = _calcFirstOperand! * currentVal;
            break;
          case '/':
            res = currentVal != 0 ? _calcFirstOperand! / currentVal : 0.0;
            break;
        }
        _calcDisplay = (res == res.roundToDouble()) ? res.toInt().toString() : res.toStringAsFixed(2);
        _calcFirstOperand = res;
      } else {
        _calcFirstOperand = currentVal;
      }

      if (op == '=') {
        _calcPendingOp = null;
      } else {
        _calcPendingOp = op;
      }
      _calcResetOnNextDigit = true;
    });
  }

  // =========================================================================
  // SECCIÓN 8: INTERFACES VISUALES DE SEÑUELO Y PAUSA DE SEGURIDAD SSC
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    if (_isDecoyActive) {
      return Stack(
        children: [
          if (_currentDecoyType == DecoyType.clock)
            WillPopScope(
              onWillPop: () async => false,
              child: AnalogClockDecoy(
                dialedCount: _pinBuffer.length,
                onDigitDialed: _onDecoyDigit,
                onClear: () {
                  setState(() {
                    _calcDisplay = "0";
                    _pinBuffer = "";
                  });
                  HapticFeedback.selectionClick();
                },
              ),
            )
          else if (_currentDecoyType == DecoyType.notes)
            _buildDecoyNotes()
          else
            _buildDecoyCalculator(),

          if (_simulatedCrashMessage != null)
            Container(
              color: Colors.black.withOpacity(0.82),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF262626),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white70, size: 38),
                      const SizedBox(height: 14),
                      Text(
                        _simulatedCrashMessage!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _executeFakeCrashExit,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Text(
                                "CERRAR APLICACIÓN",
                                style: GoogleFonts.outfit(
                                  color: Colors.blueAccent,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return _buildFundidoANegro();
  }

  /// Señuelo tipo Bloc de Notas (mantener pulsado el título abre el PIN de desarme)
  Widget _buildDecoyNotes() {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white70),
            onPressed: _showSafePinDialog,
          ),
          title: GestureDetector(
            onLongPress: _showSafePinDialog,
            child: Text(
              "Mis Notas",
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white70),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              onPressed: _showSafePinDialog,
            ),
          ],
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _notes.length,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: Colors.white38),
                  title: Text(
                    _notes[index],
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                  ),
                  trailing: const Icon(Icons.drag_handle, color: Colors.white24, size: 18),
                  onTap: () {
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF2C2C2C),
          foregroundColor: Colors.white,
          onPressed: () {
            HapticFeedback.selectionClick();
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  /// Señuelo tipo Calculadora (marcar el PIN Seguro desarma directamente)
  Widget _buildDecoyCalculator() {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Container(
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _calcDisplay,
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w300),
                  ),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                padding: const EdgeInsets.all(16),
                children: [
                  ..."789/456*123-0C=+ ".split('').where((s) => s != ' ').map((btn) {
                    final isOp = const {'/', '*', '-', '+', '=', 'C'}.contains(btn);
                    return InkWell(
                      onTap: () {
                        if (isOp) {
                          _onCalculatorOperator(btn);
                        } else {
                          _onDecoyDigit(btn);
                        }
                      },
                      child: Center(
                        child: Text(
                          btn,
                          style: GoogleFonts.jetBrainsMono(
                            color: isOp ? const Color(0xFF00E5FF) : Colors.white70,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pantalla de Pausa de Seguridad SSC (Safeword o Dead Man Switch)
  Widget _buildFundidoANegro() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.shield_outlined, color: VinkiarColors.panicRed, size: 54),
              const SizedBox(height: 16),
              Text(
                "PAUSA DE SEGURIDAD OBLIGATORIA",
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(
                  color: VinkiarColors.panicRed,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VinkiarColors.panelDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: VinkiarColors.panicRed.withOpacity(0.4)),
                ),
                child: Text(
                  widget.reason == SentinelTriggerReason.safewordSpoken
                      ? "DETECCIÓN ACÚSTICA: Se ha pronunciado la Palabra de Seguridad pactada."
                      : (widget.reason == SentinelTriggerReason.objectDropImpact
                          ? "DEAD MAN SWITCH: Se ha registrado la caída del testigo metálico al suelo."
                          : "DISONANCIA: Parada preventiva de juego."),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11.5, height: 1.4),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Misión pausada sin pérdida de Vinks ni experiencia.\nPrioridad: Co-regulación y chequeo mutuo de bienestar.",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VinkiarColors.aegisCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.favorite_outline, size: 20),
                  label: Text(
                    "VALIDAR BIENESTAR // ABRIR AFTERCARE",
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AftercareScreen(
                          triggerReason: widget.reason,
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
    );
  }
}
