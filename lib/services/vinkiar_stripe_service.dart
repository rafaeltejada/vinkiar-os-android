import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// VinkiarStripeService — Integración con Stripe para el muro financiero y La Armería de Vinkiar.
class VinkiarStripeService {
  final String backendBaseUrl;

  VinkiarStripeService({String? backendBaseUrl})
      : backendBaseUrl = backendBaseUrl ?? ApiConfig.baseUrl;

  String get _cleanBase => backendBaseUrl.replaceAll(RegExp(r'/+$'), '');

  /// Obtiene el catálogo activo de suministros de La Armería desde PostgreSQL.
  Future<List<Map<String, dynamic>>> fetchArmeriaCatalogo() async {
    try {
      final response = await http
          .get(Uri.parse('$_cleanBase/api/v1/armeria/catalogo'))
          .timeout(const Duration(seconds: 7));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final raw = data['items'] as List? ?? [];
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Valida un código promocional o de afiliado antes de iniciar el cobro.
  Future<Map<String, dynamic>> validateDiscountCode({
    required String productId,
    required String discountCode,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_cleanBase/api/v1/armeria/validate-discount'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'product_id': productId,
            'discount_code': discountCode.trim().toUpperCase(),
          }),
        )
        .timeout(const Duration(seconds: 7));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['detail'] ?? 'Código no válido.');
    }
  }

  /// Solicita al backend la creación de un PaymentIntent para La Armería.
  Future<Map<String, dynamic>> createArmeriaPaymentIntent({
    required String userUuid,
    required String productId,
    String? discountCode,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_cleanBase/api/v1/armeria/create-intent'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userUuid,
            'product_id': productId,
            if (discountCode != null && discountCode.trim().isNotEmpty)
              'discount_code': discountCode.trim().toUpperCase(),
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Error al crear orden en Armería (${response.statusCode}): ${response.body}');
    }
  }

  /// Confirma la entrega y registra pedidos físicos en el módulo de Logística del Super Admin.
  Future<Map<String, dynamic>> confirmArmeriaOrder({
    required String userUuid,
    required String productId,
    required String paymentIntentId,
    String? discountCode,
    String? recipientName,
    Map<String, dynamic>? shippingAddress,
    String? contactPhone,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_cleanBase/api/v1/armeria/confirm-order'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userUuid,
            'product_id': productId,
            'payment_intent_id': paymentIntentId,
            'discount_code': discountCode,
            'recipient_name': recipientName,
            'shipping_address': shippingAddress ?? {},
            'contact_phone': contactPhone,
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {'status': 'LOCAL_ONLY'};
  }

  /// Solicita al backend la creación de un PaymentIntent para la matrícula Génesis en la Forja.
  Future<String> createMatriculaPaymentIntent({
    required String userUuid,
    String currency = 'eur',
    int amountCents = 100,
  }) async {
    final response = await http
        .post(
          Uri.parse('$_cleanBase/api/v1/stripe/create-intent'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userUuid,
            'currency': currency,
            'amount': amountCents,
            'metadata': {
              'product': 'vinkiar_matricula',
              'version': '4.9',
            }
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['clientSecret'] ?? data['client_secret']) as String;
    } else {
      throw Exception('Error al crear el PaymentIntent: ${response.body}');
    }
  }

  /// Verifica con el backend si un PaymentIntent fue completado exitosamente.
  Future<bool> verifyPayment(String paymentIntentId) async {
    final response = await http
        .post(
          Uri.parse('$_cleanBase/api/v1/stripe/verify-payment'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'payment_intent_id': paymentIntentId}),
        )
        .timeout(const Duration(seconds: 6));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'] == 'succeeded';
    }
    return false;
  }
}

/// Mock del servicio de Stripe para pruebas locales y emuladores sin pasarela activa.
class VinkiarStripeMock implements VinkiarStripeService {
  @override
  final String backendBaseUrl = 'mock://localhost';

  @override
  String get _cleanBase => backendBaseUrl;

  @override
  Future<List<Map<String, dynamic>>> fetchArmeriaCatalogo() async => [];

  @override
  Future<Map<String, dynamic>> validateDiscountCode({
    required String productId,
    required String discountCode,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'status': 'VALID',
      'code': discountCode.toUpperCase(),
      'tipo_descuento': 'PORCENTAJE',
      'valor': 15.0,
      'final_amount': 250,
    };
  }

  @override
  Future<Map<String, dynamic>> createArmeriaPaymentIntent({
    required String userUuid,
    required String productId,
    String? discountCode,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return {
      'client_secret': 'pi_mock_${productId}_secret',
      'payment_intent_id': 'pi_mock_$productId',
      'mock': true,
      'product_type': productId.startsWith('recarga_')
          ? 'ENERGY'
          : (productId.startsWith('alijo_') ? 'VINKS' : 'LICENSE'),
      'product_val': productId.contains('100') ? 100 : (productId.contains('5000') ? 5000 : 50),
    };
  }

  @override
  Future<Map<String, dynamic>> confirmArmeriaOrder({
    required String userUuid,
    required String productId,
    required String paymentIntentId,
    String? discountCode,
    String? recipientName,
    Map<String, dynamic>? shippingAddress,
    String? contactPhone,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {'status': 'CONFIRMED', 'order_id': 'ORD_MOCK_01'};
  }

  @override
  Future<String> createMatriculaPaymentIntent({
    required String userUuid,
    String currency = 'eur',
    int amountCents = 100,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    return 'pi_mock_${userUuid.replaceAll('-', '')}_secret';
  }

  @override
  Future<bool> verifyPayment(String paymentIntentId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return paymentIntentId.startsWith('pi_mock_');
  }
}
