import 'package:flutter/foundation.dart';

/// Configuración centralizada de Red y Pasarela de Pagos (Vinkiar OS v4.4)
abstract class ApiConfig {
  /// Base URL para peticiones REST de producción (o fallback por entorno)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.vinkiar.com',
  );

  /// URL derivada dinámicamente para el túnel WebSocket cifrado
  static String get wsUrl {
    if (baseUrl.startsWith('https://')) {
      return baseUrl.replaceFirst('https://', 'wss://');
    }
    return baseUrl.replaceFirst('http://', 'ws://');
  }

  /// Llave pública de Stripe inyectada exclusivamente en tiempo de compilación (--dart-define)
  static const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// Indica si la pasarela Stripe dispone de clave pública configurada en el build
  static bool get isStripeConfigured => stripePublishableKey.trim().isNotEmpty;
}
