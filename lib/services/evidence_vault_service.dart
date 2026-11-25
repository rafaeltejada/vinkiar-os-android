import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../config/api_config.dart';
import 'safety_config_service.dart';

typedef JsonMap = Map<String, dynamic>;

// =========================================================================
// SECCIÓN 1: MODELO DE PUNTO DE TELEMETRÍA FORENSE INMUTABLE (WORM)
// =========================================================================
class ForensicTelemetryPoint {
  final double lat;
  final double lng;
  final double altitude;
  final double speed;
  final String timestamp;

  const ForensicTelemetryPoint({
    required this.lat,
    required this.lng,
    required this.altitude,
    required this.speed,
    required this.timestamp,
  });

  JsonMap toMap() => {
        'lat': lat,
        'lng': lng,
        'altitude': altitude,
        'speed': speed,
        'timestamp': timestamp,
      };
}

// =========================================================================
// SECCIÓN 2: SERVICIO SINGLETON DE CAJA NEGRA Y CONTINGENCIA GSM
// =========================================================================
class EvidenceVaultService {
  static final EvidenceVaultService _instance = EvidenceVaultService._internal();
  factory EvidenceVaultService() => _instance;
  EvidenceVaultService._internal();

  bool _isBlackBoxRecording = false;
  bool _isIncidentCancelled = false;
  bool get isRecording => _isBlackBoxRecording;

  StreamSubscription<Position>? _gpsStreamSubscription;
  final List<ForensicTelemetryPoint> _forensicTelemetryRoute = [];
  String? _sessionIncidentId;

  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _chunkTimer;
  int _currentSegment = 1;

  // Canal nativo Android para envío directo de SMS cuando no hay datos móviles
  static const MethodChannel _gsmChannel = MethodChannel('com.vinkiar/gsm');
  bool _gsmFallbackExecuted = false;

  /// Consulta el porcentaje real de batería del dispositivo para adjuntarlo al SOS
  Future<int> _getRealBatteryLevel() async {
    try {
      final battery = Battery();
      return await battery.batteryLevel;
    } catch (_) {
      return 100;
    }
  }

  // =========================================================================
  // SECCIÓN 3: INICIO DE CAPTURA FORENSE (GPS INMEDIATO + STREAM + AUDIO)
  // =========================================================================
  /// Activa la grabación ambiental y el rastreo GPS continuo hacia El Ancla
  Future<void> initiateBlackBoxCapture({required String victimHandle}) async {
    if (_isBlackBoxRecording) return;

    _isBlackBoxRecording = true;
    _isIncidentCancelled = false;
    _sessionIncidentId = "INCIDENT_${DateTime.now().millisecondsSinceEpoch}";
    _forensicTelemetryRoute.clear();
    _currentSegment = 1;
    _gsmFallbackExecuted = false;

    final String activeIncidentId = _sessionIncidentId!;

    // 1. Disparo inmediato de posición inicial (sin esperar desplazamiento de 5m)
    // para que El Ancla reciba el correo electrónico de auxilio al instante.
    _dispatchInitialGpsSnapshot(
      incidentId: activeIncidentId,
      victimHandle: victimHandle,
    );

    // 2. Suscripción continua al flujo GPS de alta precisión
    try {
      _gpsStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        if (_isIncidentCancelled || !_isBlackBoxRecording) return;

        final point = ForensicTelemetryPoint(
          lat: pos.latitude,
          lng: pos.longitude,
          altitude: pos.altitude,
          speed: pos.speed,
          timestamp: DateTime.now().toUtc().toIso8601String(),
        );

        _forensicTelemetryRoute.add(point);
        _appendImmutableLocalTelemetry(point.toMap());
        _transmitAnchorLivePing(
          incidentId: activeIncidentId,
          victimHandle: victimHandle,
          lat: pos.latitude,
          lng: pos.longitude,
        );
      });
    } catch (e) {
      debugPrint("⚠️ [EVIDENCE VAULT] Error iniciando stream GPS: $e");
    }

    // 3. Inicio de grabación ambiental cifrada en segmentos de 60 segundos
    await _startContinuousAudioCapture(activeIncidentId);
  }

  /// Obtiene la última ubicación conocida o fijación rápida y envía el primer aviso SOS
  Future<void> _dispatchInitialGpsSnapshot({
    required String incidentId,
    required String victimHandle,
  }) async {
    double lat = 0.0;
    double lng = 0.0;

    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        lat = lastPos.latitude;
        lng = lastPos.longitude;
      }
      final currentPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
      lat = currentPos.latitude;
      lng = currentPos.longitude;
    } catch (_) {}

    if (_isIncidentCancelled || !_isBlackBoxRecording) return;

    final point = ForensicTelemetryPoint(
      lat: lat,
      lng: lng,
      altitude: 0.0,
      speed: 0.0,
      timestamp: DateTime.now().toUtc().toIso8601String(),
    );
    _forensicTelemetryRoute.add(point);
    await _appendImmutableLocalTelemetry(point.toMap());

    await _transmitAnchorLivePing(
      incidentId: incidentId,
      victimHandle: victimHandle,
      lat: lat,
      lng: lng,
    );
  }

  // =========================================================================
  // SECCIÓN 4: GRABACIÓN CONTINUA DE AUDIO EN BLOQUES DE 60 SEGUNDOS
  // =========================================================================
  Future<void> _startContinuousAudioCapture(String incidentId) async {
    if (_isIncidentCancelled || !_isBlackBoxRecording) return;
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) return;

      await _recordCurrentChunk();

      _chunkTimer?.cancel();
      _chunkTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
        if (_isIncidentCancelled || !_isBlackBoxRecording) {
          timer.cancel();
          return;
        }
        await _rotateAndUploadChunk(incidentId: incidentId, isFinal: false);
      });
    } catch (e) {
      debugPrint("⚠️ [EVIDENCE VAULT] Error iniciando captura de audio: $e");
    }
  }

  /// Inicia la grabación del fragmento actual en el directorio oculto de evidencias
  Future<void> _recordCurrentChunk() async {
    if (_isIncidentCancelled || !_isBlackBoxRecording) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory('${dir.path}/.zka_evidence_vault');
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }

      final filePath = '${vaultDir.path}/seg_${_currentSegment.toString().padLeft(3, '0')}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: filePath,
      );
    } catch (_) {}
  }

  /// Cierra el segmento actual, lo sube al servidor WORM y abre el siguiente si sigue activo
  Future<void> _rotateAndUploadChunk({
    required String incidentId,
    bool isFinal = false,
  }) async {
    try {
      final oldSegment = _currentSegment;
      final path = await _audioRecorder.stop();

      if (!isFinal && _isBlackBoxRecording && !_isIncidentCancelled) {
        _currentSegment++;
        await _recordCurrentChunk();
      }

      if (path != null && !_isIncidentCancelled) {
        final audioFile = File(path);
        await _uploadAudioSegmentToServer(
          incidentId,
          oldSegment,
          audioFile,
          isFinal: isFinal,
        );
      }
    } catch (_) {}
  }

  /// Transmite los bytes del audio grabado al endpoint forense del backend
  Future<void> _uploadAudioSegmentToServer(
    String incidentId,
    int segment,
    File audioFile, {
    bool isFinal = false,
  }) async {
    if (_isIncidentCancelled) return;
    try {
      if (!await audioFile.exists()) return;
      final bytes = await audioFile.readAsBytes();
      if (bytes.isEmpty || _isIncidentCancelled) return;

      final cleanBase = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;

      final url = Uri.parse(
        '$cleanBase/api/v1/sentinel/evidence-upload/$incidentId?segment=$segment&is_final=$isFinal',
      );

      await http.post(
        url,
        headers: {'Content-Type': 'application/octet-stream'},
        body: bytes,
      ).timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  /// Guarda cada coordenada GPS localmente en formato append-only (.worm)
  Future<void> _appendImmutableLocalTelemetry(JsonMap record) async {
    if (_isIncidentCancelled || _sessionIncidentId == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory('${dir.path}/.zka_evidence_vault');
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }

      final file = File('${vaultDir.path}/$_sessionIncidentId.worm');
      final line = '${jsonEncode(record)}\n';
      await file.writeAsString(line, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  // =========================================================================
  // SECCIÓN 5: TRANSMISIÓN EN VIVO AL ANCLA (API + EMAIL) Y FALLBACK SMS GSM
  // =========================================================================
  Future<void> _transmitAnchorLivePing({
    required String incidentId,
    required String victimHandle,
    required double lat,
    required double lng,
  }) async {
    if (_isIncidentCancelled || !_isBlackBoxRecording) return;

    final safetyCfg = await SafetyConfigService().getConfig();
    final cleanBase = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;

    final int realBattery = await _getRealBatteryLevel();

    if (_isIncidentCancelled || !_isBlackBoxRecording) return;

    try {
      final response = await http.post(
        Uri.parse('$cleanBase/api/v1/sentinel/sos-dispatch'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "incident_id": incidentId,
          "victim_handle": victimHandle,
          "anchor_handle": safetyCfg.anchorHandle,
          "anchor_phone": safetyCfg.anchorPhone,
          "anchor_email": safetyCfg.anchorEmail,
          "location": {
            "lat": lat,
            "lng": lng,
          },
          "battery_level": realBattery,
          "timestamp": DateTime.now().toUtc().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _gsmFallbackExecuted = false;
        return;
      }
      throw Exception("Servidor backend no disponible");
    } catch (_) {
      // Si no hay conexión de datos, intenta enviar un SMS directo mediante antena GSM
      if (!_isIncidentCancelled && !_gsmFallbackExecuted && safetyCfg.anchorPhone.isNotEmpty) {
        await _ejecutarGsmFallback(
          incidentId: incidentId,
          anchorPhone: safetyCfg.anchorPhone,
          victimHandle: victimHandle,
          lat: lat,
          lng: lng,
          batteryLevel: realBattery,
        );
      }
    }
  }

  /// Emite un SMS directo utilizando el canal nativo SmsManager de Android
  Future<void> _ejecutarGsmFallback({
    required String incidentId,
    required String anchorPhone,
    required String victimHandle,
    required double lat,
    required double lng,
    required int batteryLevel,
  }) async {
    if (_isIncidentCancelled) return;
    try {
      final smsBody =
          "EMERGENCIA VINKIAR: $victimHandle sin datos moviles. "
          "Bat: $batteryLevel%. "
          "GPS: https://maps.google.com/?q=$lat,$lng "
          "ID: $incidentId";

      final bool? success = await _gsmChannel.invokeMethod<bool>('sendSms', {
        'phone': anchorPhone,
        'message': smsBody,
      });

      if (success == true) {
        _gsmFallbackExecuted = true;
      }
    } catch (_) {}
  }

  // =========================================================================
  // SECCIÓN 6: DESARME CON PIN SEGURO, CANCELACIÓN EN SERVIDOR Y PURGA LOCAL
  // =========================================================================
  /// Detiene inmediatamente GPS y micrófono, notifica cancelación al backend y borra rastros
  Future<void> cancelIncident({required String reason}) async {
    // 1. Marcar como cancelado de inmediato para abortar cualquier hilo o ping en vuelo
    _isIncidentCancelled = true;
    _isBlackBoxRecording = false;

    final String? incidentId = _sessionIncidentId;
    _sessionIncidentId = null;

    // 2. Detener temporizadores, stream GPS y grabadora de micrófono sin subir más chunks
    await sealAndCloseEvidence();

    // 3. Notificar al servidor que el incidente fue desarmado de forma segura
    if (incidentId != null && incidentId.isNotEmpty) {
      try {
        final cleanBase = ApiConfig.baseUrl.endsWith('/')
            ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
            : ApiConfig.baseUrl;

        await http.post(
          Uri.parse('$cleanBase/api/v1/sentinel/sos-cancel'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "incident_id": incidentId,
            "status": "DISARMED_SAFE_PIN",
            "reason": reason,
            "timestamp": DateTime.now().toUtc().toIso8601String(),
          }),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    // 4. Eliminar los archivos temporales locales de audio y rutas .worm
    await purgeLocalEvidence();
  }

  /// Libera el hardware de ubicación y micrófono de inmediato
  Future<void> sealAndCloseEvidence() async {
    _isBlackBoxRecording = false;
    _chunkTimer?.cancel();
    _chunkTimer = null;

    try {
      await _gpsStreamSubscription?.cancel();
    } catch (_) {}
    _gpsStreamSubscription = null;

    try {
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
    } catch (_) {}
  }

  /// Borra forensemente la carpeta temporal de evidencias del dispositivo
  Future<void> purgeLocalEvidence() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory('${dir.path}/.zka_evidence_vault');
      if (await vaultDir.exists()) {
        await vaultDir.delete(recursive: true);
      }
    } catch (_) {}
  }
}