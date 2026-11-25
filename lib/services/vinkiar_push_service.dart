import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'vinkiar_secure_database.dart';
import 'vinkiar_sync_service.dart';

const AndroidNotificationChannel kVinkiarHighPriorityChannel = AndroidNotificationChannel(
  'vinkiar_zka_high_priority',
  'Vinkiar OS · Alertas y Mensajes Cifrados',
  description: 'Notificaciones de mensajes cifrados, contratos Escrow 2-de-2 y alertas de Célula.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

/// Handler aislado ejecutado por Android cuando la app está en segundo plano o cerrada (pantalla bloqueada)
@pragma('vm:entry-point')
Future<void> vinkiarFirebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  final data = message.data;
  final eventType = (data['zka_event'] ?? 'ZKA_MSG').toString();

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
  await plugin.initialize(const InitializationSettings(android: androidInit));

  final androidImpl = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidImpl?.createNotificationChannel(kVinkiarHighPriorityChannel);

  String title = message.notification?.title ?? 'Vinkiar OS · Pulso Cifrado';
  String body = message.notification?.body ?? 'Nueva actividad cifrada en tu Bóveda.';

  if (eventType == 'ZKA_ESCROW') {
    title = 'Vinkiar OS · Notaría 2-de-2';
    body = 'Tienes un contrato o firma pendiente en Escrow.';
  } else if (eventType == 'ZKA_DECISION') {
    title = 'Vinkiar OS · Mesa de Tribu';
    body = 'Se ha abierto una votación colectiva en tu Célula.';
  } else if (eventType == 'ZKA_SOS') {
    title = '🚨 Vinkiar OS · Alerta Centinela';
    body = 'Tu contacto protegido requiere verificación inmediata.';
  }

  await plugin.show(
    DateTime.now().millisecondsSinceEpoch.remainder(100000),
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        kVinkiarHighPriorityChannel.id,
        kVinkiarHighPriorityChannel.name,
        channelDescription: kVinkiarHighPriorityChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        fullScreenIntent: eventType == 'ZKA_SOS',
        category: eventType == 'ZKA_SOS'
            ? AndroidNotificationCategory.alarm
            : AndroidNotificationCategory.message,
      ),
    ),
    payload: jsonEncode(data),
  );
}

class VinkiarPushService {
  static final VinkiarPushService _instance = VinkiarPushService._internal();
  factory VinkiarPushService() => _instance;
  VinkiarPushService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _firebaseReady = false;
  String? _currentToken;
  String? _pendingNavigationGuildId;

  String? consumePendingNavigationGuildId() {
    final gid = _pendingNavigationGuildId;
    _pendingNavigationGuildId = null;
    return gid;
  }

  String get _baseUrl => ApiConfig.baseUrl.endsWith('/')
      ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
      : ApiConfig.baseUrl;

  /// Inicializa Firebase Messaging y notificaciones locales de alta prioridad de forma segura
  Future<void> initialize() async {
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
      await _localNotifications.initialize(
        const InitializationSettings(android: androidInit),
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null && details.payload!.isNotEmpty) {
            try {
              final parsed = jsonDecode(details.payload!) as Map<String, dynamic>;
              _pendingNavigationGuildId = parsed['guild_id']?.toString();
            } catch (_) {}
          }
        },
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(kVinkiarHighPriorityChannel);
      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      debugPrint("⚠️ [PUSH_LOCAL] Error inicializando notificaciones locales: $e");
    }

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(vinkiarFirebaseBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
      );

      _currentToken = await messaging.getToken();
      _firebaseReady = true;
      debugPrint("🔔 [PUSH_FCM] Token FCM obtenido (${_currentToken?.substring(0, 12) ?? 'null'}...)");

      messaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        syncDeviceTokenWithBackend();
      });

      // Mensajes recibidos con la app abierta en primer plano
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        await syncOfflineInbox();
        final data = message.data;
        final guildId = (data['guild_id'] ?? '').toString();
        final activeGuild = VinkiarSyncService().activeGuildId;

        if (guildId.isEmpty || guildId != activeGuild) {
          final title = message.notification?.title ?? 'Vinkiar OS · Pulso Cifrado';
          final body = message.notification?.body ?? 'Nueva actividad cifrada recibida.';
          await _localNotifications.show(
            DateTime.now().millisecondsSinceEpoch.remainder(100000),
            title,
            body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                kVinkiarHighPriorityChannel.id,
                kVinkiarHighPriorityChannel.name,
                channelDescription: kVinkiarHighPriorityChannel.description,
                importance: Importance.max,
                priority: Priority.high,
                visibility: NotificationVisibility.public,
              ),
            ),
            payload: jsonEncode(data),
          );
        }
      });

      // Usuario pulsa la notificación con la app en segundo plano
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
        _pendingNavigationGuildId = message.data['guild_id']?.toString();
        await syncOfflineInbox();
      });

      // Usuario abre la app desde estado cerrado al pulsar una notificación
      final initialMsg = await messaging.getInitialMessage();
      if (initialMsg != null) {
        _pendingNavigationGuildId = initialMsg.data['guild_id']?.toString();
      }
    } catch (e) {
      _firebaseReady = false;
      debugPrint("ℹ️ [PUSH_FCM] Firebase no configurado o sin Google Play Services ($e). Usando buzón Store-and-Forward por polling.");
    }
  }

  /// Vincula el token FCM actual con el #Handle del avatar en FastAPI
  Future<void> syncDeviceTokenWithBackend() async {
    final db = VinkiarSecureDatabase();
    if (db.db == null) return;

    final avatar = await db.getAvatarSheet("LOCAL_USER");
    final stats = avatar?['stats'] as Map<String, dynamic>? ?? {};
    final rawAlias = (avatar?['alias']?.toString().isNotEmpty == true)
        ? avatar!['alias'].toString()
        : (stats['alias']?.toString() ?? '');
    if (rawAlias.trim().isEmpty) return;

    final handle = rawAlias.startsWith('#') ? rawAlias.trim() : '#${rawAlias.trim()}';

    if (_firebaseReady) {
      try {
        _currentToken ??= await FirebaseMessaging.instance.getToken();
      } catch (_) {}
    }

    if (_currentToken != null && _currentToken!.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('$_baseUrl/api/v1/push/register-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_handle': handle,
            'fcm_token': _currentToken,
            'platform': Platform.isAndroid ? 'android' : 'ios',
            'app_version': '1.0.0',
          }),
        ).timeout(const Duration(seconds: 8));
      } catch (e) {
        debugPrint("⚠️ [PUSH_FCM] No se pudo registrar token en servidor: $e");
      }
    }

    await syncOfflineInbox();
  }

  /// Descarga los blobs cifrados pendientes del buzón Store-and-Forward, los guarda en SQLCipher y los purga del servidor
  Future<int> syncOfflineInbox() async {
    final db = VinkiarSecureDatabase();
    if (db.db == null) return 0;

    final avatar = await db.getAvatarSheet("LOCAL_USER");
    final stats = avatar?['stats'] as Map<String, dynamic>? ?? {};
    final rawAlias = (avatar?['alias']?.toString().isNotEmpty == true)
        ? avatar!['alias'].toString()
        : (stats['alias']?.toString() ?? '');
    if (rawAlias.trim().isEmpty) return 0;

    final handle = rawAlias.startsWith('#') ? rawAlias.trim() : '#${rawAlias.trim()}';

    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/v1/push/inbox/${Uri.encodeComponent(handle)}'))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode != 200) return 0;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final msgs = (data['messages'] as List<dynamic>? ?? []);
      if (msgs.isEmpty) return 0;

      final ackIds = <String>[];
      for (final raw in msgs) {
        final m = Map<String, dynamic>.from(raw as Map);
        final msgId = (m['id'] ?? '').toString();
        final guildId = (m['guild_id'] ?? '').toString();
        final senderId = (m['sender_id'] ?? 'Avatar').toString();
        final blob = (m['encrypted_blob_b64'] ?? '').toString();
        final ts = (m['timestamp'] ?? DateTime.now().toIso8601String()).toString();

        final decrypted = db.decryptZKAPayload(blob, 'VINKIAR_ZKA_DEFAULT_KEY');

        await db.saveLocalMessage(
          id: msgId,
          guildId: guildId,
          senderId: senderId,
          encryptedBlobB64: blob,
          decryptedContent: decrypted,
          timestamp: ts,
        );

        if (msgId.isNotEmpty) ackIds.add(msgId);
      }

      if (ackIds.isNotEmpty) {
        await http.post(
          Uri.parse('$_baseUrl/api/v1/push/inbox/ack'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'recipient_handle': handle,
            'message_ids': ackIds,
          }),
        ).timeout(const Duration(seconds: 6));
      }

      final activeGid = VinkiarSyncService().activeGuildId;
      if (activeGid.isNotEmpty) {
        await VinkiarSyncService().loadPersistedHistory(activeGid);
      }

      return ackIds.length;
    } catch (e) {
      debugPrint("⚠️ [PUSH_INBOX] Error sincronizando buzón offline: $e");
      return 0;
    }
  }
}
