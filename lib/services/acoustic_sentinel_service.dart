import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../main.dart';
import '../ui/smoke_screen_overlay.dart';
import 'safety_config_service.dart';

enum SentinelTriggerReason {
  safewordSpoken,
  objectDropImpact,
  prolongedDistress,
  hardwarePanic,
}

class AcousticSentinelService {
  static final AcousticSentinelService _instance = AcousticSentinelService._internal();
  factory AcousticSentinelService() => _instance;
  AcousticSentinelService._internal();

  static const MethodChannel _nativeChannel = MethodChannel('com.vinkiar.os/hardware_sos');

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isSurveillanceActive = false;
  bool isOverlayActive = false;
  bool _isRestarting = false;
  String _cachedSafeword = "CANDELERO";

  void Function(SentinelTriggerReason reason)? onSecurityBlackout;
  void Function()? onEmergencyLockdown;

  bool get isSurveillanceActive => _isSurveillanceActive;
  bool get isVigilanceActive => _isSurveillanceActive;
  bool get isVigilant => _isSurveillanceActive;
  bool get isListening => _speechToText.isListening;
  String get currentSafeword => _cachedSafeword;

  Timer? _restartTimer;

  void updateSafeword(String newWord) {
    if (newWord.trim().isNotEmpty) {
      _cachedSafeword = _normalizeText(newWord);
    }
  }

  Future<void> _refreshCachedSafeword() async {
    try {
      final config = await SafetyConfigService().getConfig();
      if (config.safeword.trim().isNotEmpty) {
        _cachedSafeword = _normalizeText(config.safeword);
      }
    } catch (_) {}
  }

  String _normalizeText(String text) {
    return text
        .toUpperCase()
        .trim()
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ñ', 'N');
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      debugPrint("🎙️ [CENTINELA] Inicializando motor SpeechToText...");
      _isInitialized = await _speechToText.initialize(
        onError: _handleSpeechError,
        onStatus: _handleSpeechStatus,
        debugLogging: false,
      );
      debugPrint("🎙️ [CENTINELA] Resultado inicialización: $_isInitialized");
      return _isInitialized;
    } catch (e) {
      debugPrint("❌ [CENTINELA] Excepción en initialize(): $e");
      return false;
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    debugPrint("⚠️ [CENTINELA ERROR] ${error.errorMsg} (permanent: ${error.permanent})");
    _scheduleListenRestart();
  }

  void _handleSpeechStatus(String status) {
    debugPrint("📊 [CENTINELA STATUS] $status");
    if (!_isSurveillanceActive || isOverlayActive) return;
    if (status == 'done' || status == 'notListening') {
      _scheduleListenRestart();
    }
  }

  void _scheduleListenRestart() {
    if (_isRestarting || !_isSurveillanceActive || isOverlayActive) return;
    _isRestarting = true;
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 600), () async {
      _isRestarting = false;
      if (_isSurveillanceActive && !isOverlayActive) {
        await _startListening();
      }
    });
  }

  Future<void> startSurveillance() async {
    if (_isSurveillanceActive) return;

    await _refreshCachedSafeword();
    debugPrint("🎙️ [CENTINELA] Arrancando vigilancia. Safeword activa: '$_cachedSafeword'");

    try {
      await _nativeChannel.invokeMethod('muteSystemAudio');
      // 🛡️ CRÍTICO: Arranca el Foreground Service para retener micrófono en segundo plano
      await _nativeChannel.invokeMethod('startSentinelForegroundService');
    } catch (e) {
      debugPrint("⚠️ [CENTINELA NATIVO] Error mute/service: $e");
    }

    final ready = await initialize();
    if (!ready) {
      debugPrint("❌ [CENTINELA] El reconocedor no está listo.");
      try {
        await _nativeChannel.invokeMethod('unmuteSystemAudio');
        await _nativeChannel.invokeMethod('stopSentinelForegroundService');
      } catch (_) {}
      return;
    }

    _isSurveillanceActive = true;
    await _startListening();
  }

  Future<void> startVigilance() => startSurveillance();

  Future<void> stopSurveillance() async {
    debugPrint("🛑 [CENTINELA] Deteniendo vigilancia acústica.");
    _isSurveillanceActive = false;
    _isRestarting = false;
    _restartTimer?.cancel();

    try {
      await _speechToText.stop();
      await _nativeChannel.invokeMethod('unmuteSystemAudio');
      await _nativeChannel.invokeMethod('stopSentinelForegroundService');
    } catch (_) {}
  }

  Future<void> stopVigilance() => stopSurveillance();

  Future<void> _startListening() async {
    if (!_isSurveillanceActive || isOverlayActive) return;
    if (_speechToText.isListening) {
      debugPrint("ℹ️ [CENTINELA] Ya está escuchando.");
      return;
    }

    debugPrint("👂 [CENTINELA] Abriendo micrófono para escuchar...");

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 45),
        pauseFor: const Duration(seconds: 8),
        partialResults: true,
        localeId: 'es_ES',
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );
    } catch (e) {
      debugPrint("❌ [CENTINELA] Excepción en listen(): $e");
      _scheduleListenRestart();
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!_isSurveillanceActive || isOverlayActive) return;

    final rawWords = result.recognizedWords;
    final words = _normalizeText(rawWords);
    final target = _normalizeText(_cachedSafeword);

    debugPrint("🗣️ [CENTINELA CAPTURA] Escuchado: '$rawWords' | Normalizado: '$words'");

    bool matches = false;
    if (target.isNotEmpty && words.contains(target)) matches = true;
    if (words.contains("CANDELERO") || words.contains("CANDELABRO")) matches = true;
    if (words.contains("MANGO")) matches = true;
    if (words.contains("ROJO")) matches = true;
    if (words.contains("PINA") || words.contains("PINIA") || words.contains("PIÑA")) matches = true;

    if (matches) {
      debugPrint("🚨 [CENTINELA MATCH] Palabra clave detectada! Disparando pausa de seguridad.");
      triggerSafetyPause(SentinelTriggerReason.safewordSpoken);
    }
  }

  void triggerSafetyPause(SentinelTriggerReason reason) {
    if (isOverlayActive) return;
    isOverlayActive = true;

    HapticFeedback.heavyImpact();

    try {
      onSecurityBlackout?.call(reason);
    } catch (e) {
      debugPrint("⚠️ [CENTINELA] Error en callback onSecurityBlackout: $e");
    }

    debugPrint("🖥️ [CENTINELA] Desplegando SmokeScreenOverlay...");

    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => SmokeScreenOverlay(
          reason: reason,
          isEmergencySOS: false,
        ),
      ),
    ).then((_) {
      debugPrint("↩️ [CENTINELA] Salida de SmokeScreenOverlay. Reanudando vigilancia.");
      isOverlayActive = false;
      if (_isSurveillanceActive) {
        _scheduleListenRestart();
      }
    });
  }

  void triggerEmergencyProtocol({bool fromInsideOverlay = false}) {
    HapticFeedback.heavyImpact();

    try {
      onEmergencyLockdown?.call();
    } catch (_) {}

    if (!fromInsideOverlay && !isOverlayActive) {
      isOverlayActive = true;
      rootNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const SmokeScreenOverlay(
            reason: SentinelTriggerReason.hardwarePanic,
            isEmergencySOS: true,
          ),
        ),
      ).then((_) {
        isOverlayActive = false;
      });
    }
  }
}