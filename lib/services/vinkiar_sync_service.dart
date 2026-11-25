import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import 'vinkiar_push_service.dart';
import 'vinkiar_secure_database.dart';

// =========================================================================
// SECCIÓN 1: ESTADOS DE CONEXIÓN Y MODELO DE PAYLOAD ZKA
// =========================================================================

enum SyncConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class ZKAMessagePayload {
  final String id;
  final String guildId;
  final String senderId;
  final String encryptedBlobB64;
  final String nonce;
  final String timestamp;
  final String? decryptedContent;

  ZKAMessagePayload({
    required this.id,
    required this.guildId,
    required this.senderId,
    required this.encryptedBlobB64,
    required this.nonce,
    required this.timestamp,
    this.decryptedContent,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'guild_id': guildId,
        'sender_id': senderId,
        'encrypted_blob_b64': encryptedBlobB64,
        'nonce': nonce,
        'timestamp': timestamp,
      };

  factory ZKAMessagePayload.fromJson(Map<String, dynamic> json) {
    return ZKAMessagePayload(
      id: json['id'] ?? const Uuid().v4(),
      guildId: json['guild_id'] ?? '',
      senderId: json['sender_id'] ?? 'unknown',
      encryptedBlobB64: json['encrypted_blob_b64'] ?? json['ciphertext'] ?? '',
      nonce: json['nonce'] ?? '',
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }
}

// =========================================================================
// SECCIÓN 2: SINGLETON, CONFIGURACIÓN DE SERVIDOR Y LLAVES
// =========================================================================

/// Servicio de Red y Sincronización ZKA (Zero-Knowledge Architecture).
/// Gestiona la comunicación HTTP REST y el túnel cifrado en tiempo real vía WebSockets.
class VinkiarSyncService extends ChangeNotifier {
  static final VinkiarSyncService _instance = VinkiarSyncService._internal();
  factory VinkiarSyncService() => _instance;
  VinkiarSyncService._internal();

  static final ValueNotifier<int> tribuBolsaChangeNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> decisionChangeNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<Map<String, dynamic>?> bondCrystallizedNotifier = ValueNotifier<Map<String, dynamic>?>(null);

  /// Genera un ID de canal simétrico idéntico para ambos miembros de una Célula 1-a-1
  static String buildCanonicalCellGuildId(String handleA, String handleB) {
    final a = handleA.replaceAll('#', '').trim().toLowerCase();
    final b = handleB.replaceAll('#', '').trim().toLowerCase();
    final sorted = [a, b]..sort();
    return 'CELL_${sorted[0]}_${sorted[1]}';
  }

  String _httpHost = ApiConfig.baseUrl;
  String _wsHost = ApiConfig.wsUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  SyncConnectionState _state = SyncConnectionState.disconnected;
  String _activeGuildId = '';
  String _activeUserId = '';
  String _guildSecretKey = 'VINKIAR_ZKA_DEFAULT_KEY';

  final _messageController = StreamController<ZKAMessagePayload>.broadcast();
  final List<ZKAMessagePayload> _messageHistory = [];

  SyncConnectionState get state => _state;
  String get httpHost => _httpHost;
  String get wsHost => _wsHost;
  String get activeGuildId => _activeGuildId;
  String get activeUserId => _activeUserId;
  Stream<ZKAMessagePayload> get messageStream => _messageController.stream;
  List<ZKAMessagePayload> get messageHistory => List.unmodifiable(_messageHistory);

  /// Configura el servidor de destino (útil para cambiar de entorno local a producción)
  void setServerHost(String httpUrl) {
    _httpHost = httpUrl.replaceAll(RegExp(r'/$'), '');
    if (_httpHost.startsWith('https://')) {
      _wsHost = _httpHost.replaceFirst('https://', 'wss://');
    } else {
      _wsHost = _httpHost.replaceFirst('http://', 'ws://');
    }
    notifyListeners();
  }

  /// Establece la llave local de encriptación del Gremio
  void setGuildSecretKey(String key) {
    _guildSecretKey = key;
  }

  // =========================================================================
  // SECCIÓN 3: ENDPOINTS HTTP REST (REGISTRO Y HANDSHAKE)
  // =========================================================================

  /// Registro anónimo ZKA con token de pago
  Future<Map<String, dynamic>> registerAnonym({
    required String userId,
    required String inviteCode,
    String paymentToken = 'pi_mock_pionero_vinkiar',
  }) async {
    final url = Uri.parse('$_httpHost/api/v1/register-anonym');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'invite_code': inviteCode,
        'payment_token': paymentToken,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error en Registro Anónimo (${response.statusCode}): ${response.body}');
    }
  }

  /// Apretón de Manos de Gremio
  Future<Map<String, dynamic>> gremioHandshake({
    required String guildId,
    required String userId,
  }) async {
    final url = Uri.parse('$_httpHost/api/v1/gremio/handshake');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'guild_id': guildId,
        'user_id': userId,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error en Handshake de Gremio (${response.statusCode}): ${response.body}');
    }
  }

  // =========================================================================
  // SECCIÓN 4: GESTIÓN DEL TÚNEL WEBSOCKET EN TIEMPO REAL
  // =========================================================================

  /// Inicia la conexión WebSocket cifrada para el gremio activo
  Future<void> connectWebSocket({
    required String guildId,
    required String userId,
  }) async {
    disconnect();

    _activeGuildId = guildId;
    _activeUserId = userId;
    unawaited(VinkiarPushService().syncOfflineInbox());
    _state = SyncConnectionState.connecting;
    notifyListeners();

    String wsBase = _httpHost.replaceAll('http://', 'ws://').replaceAll('https://', 'wss://');
    if (!wsBase.startsWith('ws://') && !wsBase.startsWith('wss://')) {
      wsBase = 'ws://$wsBase';
    }
    if (wsBase.endsWith('/')) {
      wsBase = wsBase.substring(0, wsBase.length - 1);
    }

    final wsUrl = '$wsBase/ws/gremio/$guildId/$userId';
    print(">>> [ZKA WS] Conectando a Túnel: $wsUrl");

    try {
      final wsUri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(wsUri);

      _subscription = _channel!.stream.listen(
        (data) {
          _handleIncomingData(data.toString());
        },
        onError: (error) {
          print('>>> [ZKA WS SILENCED ERROR]: $error');
          _state = SyncConnectionState.error;
          notifyListeners();
        },
        onDone: () {
          print('>>> [ZKA WS DONE]: Conexión cerrada.');
          _state = SyncConnectionState.disconnected;
          notifyListeners();
        },
        cancelOnError: true,
      );

      await _channel!.ready.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw Exception("Timeout de respuesta en el túnel ZKA");
        },
      );

      _state = SyncConnectionState.connected;
      notifyListeners();
    } catch (e) {
      print('>>> [ZKA WS HANDLED EXCEPTION]: Túnel P2P no disponible actualmente ($e)');
      _state = SyncConnectionState.error;
      notifyListeners();
    }
  }

  // =========================================================================
  // SECCIÓN 5: PROCESAMIENTO ENTRADA/SALIDA ZKA Y PAQUETES DE CONTROL
  // =========================================================================

  /// Procesa los datos opacos recibidos por el túnel WebSocket
  void _handleIncomingData(String rawData) async {
    try {
      final Map<String, dynamic> jsonMap = jsonDecode(rawData);
      final payload = ZKAMessagePayload.fromJson(jsonMap);

      final decrypted = VinkiarSecureDatabase().decryptZKAPayload(
        payload.encryptedBlobB64,
        _guildSecretKey,
      );

      // Interceptar paquetes de control ZKA (Doble Semáforo SSC y Bolsa Común de Tribu)
      if (decrypted.trim().startsWith('{')) {
        try {
          final controlMap = jsonDecode(decrypted);
          if (controlMap is Map<String, dynamic>) {
            if (controlMap['type'] == 'SSC_DISCLOSURE_SYNC') {
              final sender = (controlMap['sender_handle'] ?? payload.senderId).toString();
              await VinkiarSecureDatabase().applyIncomingSscDisclosure(
                senderHandleOrId: sender,
                disclosurePacket: controlMap,
              );
              notifyListeners();
              return;
            }
            if (controlMap['type'] == 'TRIBU_BOLSA_UPDATED') {
              tribuBolsaChangeNotifier.value++;
              notifyListeners();
              return;
            }
            if (controlMap['type'] == 'DECISION_UPDATED') {
              decisionChangeNotifier.value++;
              notifyListeners();
              return;
            }
            if (controlMap['type'] == 'BOND_CRYSTALLIZED_SYNC') {
              bondCrystallizedNotifier.value = Map<String, dynamic>.from(controlMap);
              notifyListeners();
              return;
            }
          }
        } catch (_) {}
      }

      final fullPayload = ZKAMessagePayload(
        id: payload.id,
        guildId: payload.guildId,
        senderId: payload.senderId,
        encryptedBlobB64: payload.encryptedBlobB64,
        nonce: payload.nonce,
        timestamp: payload.timestamp,
        decryptedContent: decrypted,
      );

      await VinkiarSecureDatabase().saveLocalMessage(
        id: fullPayload.id,
        guildId: fullPayload.guildId,
        senderId: fullPayload.senderId,
        encryptedBlobB64: fullPayload.encryptedBlobB64,
        ciphertext: fullPayload.encryptedBlobB64,
        decryptedContent: fullPayload.decryptedContent,
        nonce: fullPayload.nonce,
        timestamp: fullPayload.timestamp,
      );

      _messageHistory.add(fullPayload);
      _messageController.add(fullPayload);
      notifyListeners();
    } catch (e) {
      print('VINKIAR_ZKA_DECRYPT_ERROR: No se pudo parsear el mensaje ($e)');
    }
  }

  /// Cifra localmente un texto plano y lo transmite como blob opaco Base64
  Future<void> sendEncryptedMessage({
    required String plaintextMessage,
    String? senderId,
  }) async {
    final sender = senderId ?? _activeUserId;
    if (sender.isEmpty || _activeGuildId.isEmpty) {
      throw Exception('No hay una sesión activa de Gremio en el WebSocket.');
    }

    final messageId = const Uuid().v4();
    final timestamp = DateTime.now().toIso8601String();
    final nonce = DateTime.now().millisecondsSinceEpoch.toString();

    final String encryptedB64 = VinkiarSecureDatabase().encryptZKAPayload(
      plaintextMessage,
      _guildSecretKey,
    );

    final payload = ZKAMessagePayload(
      id: messageId,
      guildId: _activeGuildId,
      senderId: sender,
      encryptedBlobB64: encryptedB64,
      nonce: nonce,
      timestamp: timestamp,
      decryptedContent: plaintextMessage,
    );

    await VinkiarSecureDatabase().saveLocalMessage(
      id: payload.id,
      guildId: payload.guildId,
      senderId: payload.senderId,
      encryptedBlobB64: payload.encryptedBlobB64,
      ciphertext: payload.encryptedBlobB64,
      decryptedContent: payload.decryptedContent,
      nonce: payload.nonce,
      timestamp: payload.timestamp,
    );

    _messageHistory.add(payload);
    notifyListeners();

    if (_channel != null && _state == SyncConnectionState.connected) {
      _channel!.sink.add(jsonEncode(payload.toJson()));
    } else {
      print('VINKIAR_SYNC_WARNING: WebSocket no conectado. Encolando en relevo Push ZKA.');
    }

    // Relevo asíncrono cifrado para despertar dispositivos en segundo plano o pantalla bloqueada
    unawaited(_relayToOfflinePushQueue(
      messageId: messageId,
      guildId: _activeGuildId,
      encryptedBlobB64: encryptedB64,
      nonce: nonce,
      plaintextPreviewForTagOnly: plaintextMessage,
    ));
  }

  /// Despacha el blob cifrado al buzón Store-and-Forward para notificación Push en segundo plano
  Future<void> _relayToOfflinePushQueue({
    required String messageId,
    required String guildId,
    required String encryptedBlobB64,
    required String nonce,
    required String plaintextPreviewForTagOnly,
  }) async {
    try {
      final avatar = await VinkiarSecureDatabase().getAvatarSheet("LOCAL_USER");
      final stats = avatar?['stats'] as Map<String, dynamic>? ?? {};
      final rawAlias = (avatar?['alias']?.toString().isNotEmpty == true)
          ? avatar!['alias'].toString()
          : (stats['alias']?.toString() ?? 'Pionero');
      final senderHandle = rawAlias.startsWith('#') ? rawAlias.trim() : '#${rawAlias.trim()}';

      String packetType = 'ZKA_MSG';
      if (plaintextPreviewForTagOnly.startsWith('[NOTARIA_2DE2|')) {
        packetType = 'ZKA_ESCROW';
      } else if (plaintextPreviewForTagOnly.startsWith('[DECISION_ZKA|')) {
        packetType = 'ZKA_DECISION';
      }

      await http.post(
        Uri.parse('$_httpHost/api/v1/push/dispatch-encrypted'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message_id': messageId,
          'guild_id': guildId,
          'sender_handle': senderHandle,
          'recipient_handles': [],
          'encrypted_blob_b64': encryptedBlobB64,
          'nonce': nonce,
          'packet_type': packetType,
        }),
      ).timeout(const Duration(seconds: 6));
    } catch (_) {}
  }


  /// Transmite un paquete de control cifrado (ej. matriz SSC) sin guardarlo como mensaje de chat
  Future<bool> sendZkaControlPacket(String jsonPayload) async {
    if (_channel == null || _state != SyncConnectionState.connected || _activeGuildId.isEmpty) {
      return false;
    }
    final sender = _activeUserId.isEmpty ? 'LOCAL_AVATAR' : _activeUserId;
    final encryptedB64 = VinkiarSecureDatabase().encryptZKAPayload(
      jsonPayload,
      _guildSecretKey,
    );
    final packet = ZKAMessagePayload(
      id: const Uuid().v4(),
      guildId: _activeGuildId,
      senderId: sender,
      encryptedBlobB64: encryptedB64,
      nonce: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now().toIso8601String(),
    );
    _channel!.sink.add(jsonEncode(packet.toJson()));
    return true;
  }

  // =========================================================================
  // SECCIÓN 6: HISTORIAL PERSISTIDO Y LIMPIEZA DE RECURSOS
  // =========================================================================

  /// Carga el historial de mensajes persistidos localmente en la Bóveda para un Gremio
  Future<List<ZKAMessagePayload>> loadPersistedHistory(String guildId) async {
    try {
      final rows = await VinkiarSecureDatabase().getLocalMessages(guildId);
      final List<ZKAMessagePayload> loadedMessages = [];

      for (final row in rows) {
        final String blob = (row['encrypted_blob'] ?? row['ciphertext'] ?? '') as String;
        String? decrypted = row['decrypted_content'] as String?;

        if (decrypted == null || decrypted.isEmpty) {
          if (blob.isNotEmpty) {
            decrypted = VinkiarSecureDatabase().decryptZKAPayload(blob, _guildSecretKey);
          }
        }

        loadedMessages.add(ZKAMessagePayload(
          id: (row['id'] ?? '') as String,
          guildId: (row['guild_id'] ?? guildId) as String,
          senderId: (row['sender_id'] ?? '') as String,
          encryptedBlobB64: blob,
          nonce: (row['nonce'] ?? '') as String,
          timestamp: (row['timestamp'] ?? '') as String,
          decryptedContent: decrypted,
        ));
      }

      _messageHistory.clear();
      _messageHistory.addAll(loadedMessages);
      notifyListeners();
      return _messageHistory;
    } catch (e) {
      print('VINKIAR_SYNC_LOAD_HISTORY_ERROR: $e');
      return [];
    }
  }

  /// Desconecta el WebSocket y limpia los recursos del servicio
  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    _state = SyncConnectionState.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
    super.dispose();
  }
}
