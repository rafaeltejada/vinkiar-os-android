import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';
import '../services/vinkiar_secure_database.dart';
import '../services/vinkiar_stripe_service.dart';
import 'theme.dart';

class ArmeriaScreen extends StatefulWidget {
  const ArmeriaScreen({Key? key}) : super(key: key);

  @override
  State<ArmeriaScreen> createState() => _ArmeriaScreenState();
}

class _ArmeriaScreenState extends State<ArmeriaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentEnergy = 100;
  int _currentVinks = 0;
  String _myHandle = '#Pionero';
  Set<String> _unlockedItems = {'licencia_genesis'};
  List<Map<String, dynamic>> _remoteCatalog = [];
  bool _isLoading = true;
  bool _isProcessingCheckout = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserBalancesAndCatalog();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserBalancesAndCatalog() async {
    final db = VinkiarSecureDatabase();
    final energy = await db.getEnergyLevel();
    final avatar = await db.getAvatarSheet("LOCAL_USER");
    final stats = avatar?['stats'] as Map<String, dynamic>? ?? {};
    final vinks = (stats['vinks'] as int?) ?? (avatar?['vinks'] as int?) ?? 150;
    final rawAlias = (avatar?['alias']?.toString().isNotEmpty == true)
        ? avatar!['alias'].toString()
        : (stats['alias']?.toString() ?? 'Pionero');
    final formattedHandle = rawAlias.startsWith('#') ? rawAlias : '#$rawAlias';

    Set<String> unlocked = {'licencia_genesis'};
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/vinkiar_unlocked_purchases.json');
      if (await file.exists()) {
        final List<dynamic> list = jsonDecode(await file.readAsString());
        unlocked.addAll(list.map((e) => e.toString()));
      }
    } catch (_) {}

    final remoteItems = await VinkiarStripeService().fetchArmeriaCatalogo();

    if (mounted) {
      setState(() {
        _currentEnergy = energy;
        _currentVinks = vinks;
        _myHandle = formattedHandle;
        _unlockedItems = unlocked;
        _remoteCatalog = remoteItems;
        _isLoading = false;
      });
    }
  }

  Future<void> _recordUnlockedPurchase(String productId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/vinkiar_unlocked_purchases.json');
      _unlockedItems.add(productId);
      await file.writeAsString(jsonEncode(_unlockedItems.toList()));
    } catch (_) {}
  }

  Future<void> _processStripeTransaction({
    required Map<String, dynamic> item,
    String? discountCode,
    String? recipientName,
    Map<String, dynamic>? shippingAddress,
    String? contactPhone,
  }) async {
    if (_isProcessingCheckout) return;
    setState(() => _isProcessingCheckout = true);

    try {
      final stripeService = VinkiarStripeService();
      final String userIdentifier = _myHandle.isNotEmpty ? _myHandle : const Uuid().v4();
      final String productId = item['id'];

      // 1. Obtener la intención de pago desde FastAPI (aplicando código de descuento si existe)
      final orderData = await stripeService.createArmeriaPaymentIntent(
        userUuid: userIdentifier,
        productId: productId,
        discountCode: discountCode,
      );

      final String clientSecret = orderData['client_secret'];
      final String paymentIntentId = (orderData['payment_intent_id'] ?? '').toString();
      final bool isMock = orderData['mock'] == true || clientSecret.startsWith('pi_mock_');
      final bool isPhysical = item['is_physical'] == true;

      // 2. Ejecución: Si está en mock simula, si no levanta PaymentSheet nativo blindado contra auto-bloqueo
      if (isMock) {
        await Future.delayed(const Duration(milliseconds: 900));
      } else {
        VinkiarApp.isStripeCheckoutActive = true;
        try {
          await Stripe.instance.initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              paymentIntentClientSecret: clientSecret,
              merchantDisplayName: 'Vinkiar OS - La Armería',
              style: ThemeMode.dark,
              appearance: const PaymentSheetAppearance(
                colors: PaymentSheetAppearanceColors(
                  primary: VinkiarColors.vertigoGold,
                  background: VinkiarColors.abyssBlack,
                  componentBackground: VinkiarColors.panelDark,
                  componentBorder: VinkiarColors.aegisCyan,
                  componentDivider: Colors.white24,
                  primaryText: Colors.white,
                  secondaryText: Colors.white70,
                ),
              ),
              billingDetailsCollectionConfiguration: BillingDetailsCollectionConfiguration(
                name: isPhysical ? CollectionMode.always : CollectionMode.automatic,
                address: isPhysical ? AddressCollectionMode.full : AddressCollectionMode.never,
              ),
            ),
          );
          await Stripe.instance.presentPaymentSheet();
        } finally {
          VinkiarApp.isStripeCheckoutActive = false;
        }
      }

      // 3. Registrar confirmación y pedido físico en PostgreSQL (Super Admin)
      await stripeService.confirmArmeriaOrder(
        userUuid: userIdentifier,
        productId: productId,
        paymentIntentId: paymentIntentId,
        discountCode: discountCode,
        recipientName: recipientName,
        shippingAddress: shippingAddress,
        contactPhone: contactPhone,
      );

      // 4. Abono de recursos y beneficios en Bóveda local SQLCipher
      final db = VinkiarSecureDatabase();
      final String productType = (orderData['product_type'] ?? item['category'] ?? '').toString().toUpperCase();
      final dynamic productVal = orderData['product_val'];
      final Map<String, dynamic> beneficios =
          (orderData['beneficios'] is Map<String, dynamic>) ? orderData['beneficios'] : (item['beneficios'] ?? {});

      if (productType == 'ENERGY') {
        final int addVal = (productVal is num)
            ? productVal.toInt()
            : (int.tryParse(productVal?.toString() ?? '') ?? 50);
        final int targetEnergy = (_currentEnergy + addVal).clamp(0, 100);
        await db.setEnergyLevel(targetEnergy);
        await db.logActivityEvent(
          title: "Recarga Somática (+$addVal ⚡)",
          description: "Suministro '${item['title']}' inyectado desde La Armería.",
          type: "LEVEL_UP",
        );
      } else if (productType == 'VINKS') {
        final int addVinks = (productVal is num)
            ? productVal.toInt()
            : (int.tryParse(productVal?.toString() ?? '') ?? 500);
        await db.addAvatarRewards(addVinks, 25);
        await db.logActivityEvent(
          title: "Alijo de Vinks (+$addVinks Ѵ)",
          description: "Liquidez acreditada en tu Bóveda ZKA.",
          type: "LEVEL_UP",
        );
      } else if (productType == 'LICENSE') {
        await _recordUnlockedPurchase(productId);
        final int bonusVinks = (beneficios['vinks_bonus'] as num?)?.toInt() ?? 0;
        final int bonusEnergy = (beneficios['energia_bonus'] as num?)?.toInt() ?? 0;
        if (bonusVinks > 0) {
          await db.addAvatarRewards(bonusVinks, 50);
        }
        if (bonusEnergy > 0) {
          await db.setEnergyLevel((_currentEnergy + bonusEnergy).clamp(0, 100));
        }
        await db.logActivityEvent(
          title: "Membresía Activada: ${item['title']}",
          description: "Licencia ZKA verificada y vinculada a tu Bóveda.",
          type: "LEVEL_UP",
        );
      } else {
        await _recordUnlockedPurchase(productId);
        await db.logActivityEvent(
          title: "Adquisición: ${item['title']}",
          description: isPhysical
              ? "Artefacto físico preparado para envío soberano."
              : "Códice desbloqueado en tu Bóveda.",
          type: "LEVEL_UP",
        );
      }

      HapticFeedback.heavyImpact();
      await _loadUserBalancesAndCatalog();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VinkiarColors.hackingGreen,
            content: Row(
              children: [
                const Icon(Icons.verified, color: Colors.black, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "ADQUISICIÓN CONFIRMADA: ${item['title']} sellado en tu Bóveda.",
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VinkiarColors.panicRed,
            content: Text(
              e is StripeException
                  ? "Transacción cancelada: ${e.error.localizedMessage ?? ''}"
                  : "Error procesando suministro: $e",
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        );
      }
    } finally {
      VinkiarApp.isStripeCheckoutActive = false;
      if (mounted) setState(() => _isProcessingCheckout = false);
    }
  }

  void _onPurchaseInitiated(Map<String, dynamic> item) {
    final String productId = item['id'];
    final bool isPhysical = item['is_physical'] == true;
    final int stockActual = (item['stock_actual'] as num?)?.toInt() ?? 100;

    if (isPhysical && stockActual <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: VinkiarColors.panicRed,
          content: Text(
            "ARTEFACTO AGOTADO TEMPORALMENTE EN INVENTARIO.",
            style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    final bool isAlreadyUnlocked = _unlockedItems.contains(productId) &&
        (item['category'] == 'BOOK' || item['category'] == 'LICENSE');

    if (isAlreadyUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: VinkiarColors.panelDark,
          content: Text(
            "${item['title']} ya está activo en tu Bóveda.",
            style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 11),
          ),
        ),
      );
      return;
    }

    final discountCtrl = TextEditingController();
    final recipientCtrl = TextEditingController(text: _myHandle.replaceAll('#', ''));
    final addressCtrl = TextEditingController();
    final cityZipCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    int baseCents = (item['amount_cents'] as num?)?.toInt() ?? 0;
    int? discountedCents;
    String? appliedDiscountCode;
    String? discountFeedback;
    bool isValidatingCode = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VinkiarColors.abyssBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: VinkiarColors.vertigoGold, width: 1.5),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final String displayPrice = discountedCents != null
              ? "${(discountedCents! / 100.0).toStringAsFixed(2)} €"
              : (item['price'] ?? "${(baseCents / 100.0).toStringAsFixed(2)} €");

          return Padding(
            padding: EdgeInsets.only(
              left: 22,
              right: 22,
              top: 22,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(item['icon'] as IconData? ?? Icons.lock_open, color: VinkiarColors.vertigoGold, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item['title'] ?? 'SUMINISTRO ZKA',
                          style: GoogleFonts.jetBrainsMono(
                            color: VinkiarColors.vertigoGold,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item['description'] ?? '',
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 14),

                  // Campo de Código de Descuento / Afiliado
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: discountCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 11.5, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: "CÓDIGO PROMOCIONAL / AFILIADO",
                            labelStyle: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 9.5),
                            hintText: "Ej. FUNDADOR15",
                            hintStyle: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 10),
                            isDense: true,
                            filled: true,
                            fillColor: VinkiarColors.panelDark,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: VinkiarColors.aegisCyan),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                        ),
                        onPressed: isValidatingCode
                            ? null
                            : () async {
                                final code = discountCtrl.text.trim().toUpperCase();
                                if (code.isEmpty) return;
                                setModalState(() {
                                  isValidatingCode = true;
                                  discountFeedback = null;
                                });
                                try {
                                  final res = await VinkiarStripeService().validateDiscountCode(
                                    productId: productId,
                                    discountCode: code,
                                  );
                                  setModalState(() {
                                    discountedCents = (res['final_amount'] as num?)?.toInt();
                                    appliedDiscountCode = code;
                                    discountFeedback = "✅ Código $code aplicado (-${res['valor']}${res['tipo_descuento'] == 'PORCENTAJE' ? '%' : '€'})";
                                  });
                                } catch (e) {
                                  setModalState(() {
                                    discountedCents = null;
                                    appliedDiscountCode = null;
                                    discountFeedback = "⚠️ ${e.toString().replaceAll('Exception: ', '')}";
                                  });
                                } finally {
                                  setModalState(() => isValidatingCode = false);
                                }
                              },
                        child: Text(
                          isValidatingCode ? "..." : "APLICAR",
                          style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (discountFeedback != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      discountFeedback!,
                      style: GoogleFonts.jetBrainsMono(
                        color: discountedCents != null ? VinkiarColors.hackingGreen : VinkiarColors.panicRed,
                        fontSize: 9.5,
                      ),
                    ),
                  ],

                  if (isPhysical) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: VinkiarColors.panelDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_shipping_outlined, color: VinkiarColors.aegisCyan, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "ETIQUETA LOGÍSTICA ZKA (No vinculada a tu Bóveda):",
                                  style: GoogleFonts.jetBrainsMono(color: VinkiarColors.aegisCyan, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: recipientCtrl,
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: "Nombre destinatario *",
                              hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: addressCtrl,
                            style: GoogleFonts.outfit(color: Colors.white, fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: "Calle, número, piso *",
                              hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: cityZipCtrl,
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 12),
                                  decoration: const InputDecoration(
                                    hintText: "CP y Ciudad *",
                                    hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 12),
                                  decoration: const InputDecoration(
                                    hintText: "Teléfono aviso",
                                    hintStyle: TextStyle(color: Colors.white38, fontSize: 11),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("IMPORTE A LIQUIDAR:", style: GoogleFonts.jetBrainsMono(color: Colors.grey, fontSize: 11)),
                      Row(
                        children: [
                          if (discountedCents != null) ...[
                            Text(
                              item['price'] ?? '',
                              style: GoogleFonts.jetBrainsMono(
                                color: Colors.white38,
                                fontSize: 13,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            displayPrice,
                            style: GoogleFonts.jetBrainsMono(
                              color: VinkiarColors.hackingGreen,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VinkiarColors.vertigoGold,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.payment, size: 18),
                      label: Text(
                        "PROCEDER AL PAGO CON STRIPE",
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        if (isPhysical && (addressCtrl.text.trim().isEmpty || cityZipCtrl.text.trim().isEmpty)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: VinkiarColors.panicRed,
                              content: Text("Completa la dirección y ciudad para el envío físico."),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        _processStripeTransaction(
                          item: item,
                          discountCode: appliedDiscountCode,
                          recipientName: recipientCtrl.text.trim(),
                          shippingAddress: isPhysical
                              ? {
                                  'line1': addressCtrl.text.trim(),
                                  'city': cityZipCtrl.text.trim(),
                                  'postal_code': cityZipCtrl.text.trim(),
                                }
                              : null,
                          contactPhone: phoneCtrl.text.trim(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBarBalance() {
    return Container(
      color: VinkiarColors.panelDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront, color: VinkiarColors.vertigoGold, size: 22),
              const SizedBox(width: 8),
              Text(
                "LA ARMERÍA",
                style: GoogleFonts.jetBrainsMono(
                  color: VinkiarColors.vertigoGold,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VinkiarColors.abyssBlack,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: VinkiarColors.aegisCyan, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "$_currentEnergy%",
                      style: GoogleFonts.jetBrainsMono(
                        color: VinkiarColors.aegisCyan,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: VinkiarColors.abyssBlack,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.toll, color: VinkiarColors.vertigoGold, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "$_currentVinks Ѵ",
                      style: GoogleFonts.jetBrainsMono(
                        color: VinkiarColors.vertigoGold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: VinkiarColors.panelDark.withOpacity(0.7),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: VinkiarColors.vertigoGold,
        indicatorWeight: 2.5,
        labelColor: VinkiarColors.vertigoGold,
        unselectedLabelColor: Colors.grey,
        labelStyle: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: "⚡ ENERGÍA & VINKS"),
          Tab(text: "🛡️ LICENCIAS"),
          Tab(text: "📖 CÓDICES"),
          Tab(text: "📦 ARTEFACTOS"),
        ],
      ),
    );
  }

  IconData _resolveIconForProduct(String id, String type) {
    if (id.contains('energia_50')) return Icons.battery_charging_full;
    if (id.contains('energia_100')) return Icons.electric_bolt;
    if (id.contains('5000')) return Icons.diamond_outlined;
    if (id.contains('1200')) return Icons.savings_outlined;
    if (type == 'VINKS') return Icons.token;
    if (type == 'ENERGY') return Icons.bolt;
    if (id.contains('genesis')) return Icons.fingerprint;
    if (id.contains('anual')) return Icons.workspace_premium;
    if (type == 'LICENSE') return Icons.shield;
    if (id.contains('trilogia')) return Icons.collections_bookmark;
    if (type == 'BOOK') return Icons.menu_book;
    if (id.contains('pulsera')) return Icons.watch;
    if (id.contains('camiseta')) return Icons.checkroom;
    return Icons.military_tech;
  }

  Widget _buildItemCard({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
    required String description,
    required String price,
    required int amountCents,
    required String category,
    String? badgeText,
    Color accentColor = VinkiarColors.aegisCyan,
    bool isPhysical = false,
    int stockActual = 100,
    Map<String, dynamic> beneficios = const {},
  }) {
    final bool isUnlocked = _unlockedItems.contains(id);
    final bool isOutOfStock = isPhysical && stockActual <= 0;
    final String effectiveBadge = isOutOfStock
        ? 'AGOTADO'
        : (isUnlocked
            ? (category == 'BOOK' ? 'DESBLOQUEADO' : 'ACTIVA')
            : (badgeText ?? ''));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VinkiarColors.panelDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withOpacity(0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withOpacity(0.4)),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.jetBrainsMono(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (effectiveBadge.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOutOfStock
                                  ? VinkiarColors.panicRed.withOpacity(0.2)
                                  : (isUnlocked ? VinkiarColors.hackingGreen.withOpacity(0.2) : accentColor.withOpacity(0.2)),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isOutOfStock
                                    ? VinkiarColors.panicRed
                                    : (isUnlocked ? VinkiarColors.hackingGreen : accentColor),
                              ),
                            ),
                            child: Text(
                              effectiveBadge,
                              style: GoogleFonts.jetBrainsMono(
                                color: isOutOfStock
                                    ? VinkiarColors.panicRed
                                    : (isUnlocked ? VinkiarColors.hackingGreen : accentColor),
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.jetBrainsMono(color: accentColor, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11, height: 1.35),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                price,
                style: GoogleFonts.jetBrainsMono(
                  color: VinkiarColors.hackingGreen,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isUnlocked || isOutOfStock) ? VinkiarColors.panelDark : accentColor,
                  foregroundColor: isOutOfStock
                      ? VinkiarColors.panicRed
                      : (isUnlocked ? VinkiarColors.hackingGreen : Colors.black),
                  side: isOutOfStock
                      ? const BorderSide(color: VinkiarColors.panicRed)
                      : (isUnlocked ? const BorderSide(color: VinkiarColors.hackingGreen) : null),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  isOutOfStock
                      ? Icons.block
                      : (isUnlocked ? Icons.check_circle_outline : Icons.add_shopping_cart),
                  size: 14,
                ),
                label: Text(
                  isOutOfStock ? "AGOTADO" : (isUnlocked ? "ADQUIRIDO" : "ADQUIRIR"),
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                onPressed: _isProcessingCheckout
                    ? null
                    : () => _onPurchaseInitiated({
                          'id': id,
                          'title': title,
                          'description': description,
                          'price': price,
                          'amount_cents': amountCents,
                          'icon': icon,
                          'category': category,
                          'is_physical': isPhysical,
                          'stock_actual': stockActual,
                          'beneficios': beneficios,
                        }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _remoteByTypes(List<String> types) {
    return _remoteCatalog
        .where((item) => types.contains((item['type'] ?? '').toString().toUpperCase()))
        .toList();
  }

  Widget _buildEnergiaVinksTab() {
    final remote = _remoteByTypes(['ENERGY', 'VINKS']);
    if (remote.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text("// SUMINISTROS ENERGÉTICOS & LIQUIDEZ ZKA", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.textDim, fontSize: 10)),
          const SizedBox(height: 10),
          ...remote.map((r) {
            final t = (r['type'] ?? 'VINKS').toString().toUpperCase();
            final cents = (r['amount'] as num?)?.toInt() ?? 299;
            return _buildItemCard(
              id: r['product_id'],
              category: t,
              icon: _resolveIconForProduct(r['product_id'], t),
              title: r['name'] ?? '',
              subtitle: t == 'ENERGY' ? "Inyección Somática (+${r['val']} ⚡)" : "Liquidez ZKA (+${r['val']} Ѵ)",
              description: (r['description'] ?? '').toString().isNotEmpty
                  ? r['description']
                  : (t == 'ENERGY'
                      ? "Restaura la reserva energética de tu nodo para barridos de radar y pings."
                      : "Fichas de reputación para contratos P2P, subastas y bolsas de tribu."),
              price: "${(cents / 100.0).toStringAsFixed(2)} €",
              amountCents: cents,
              accentColor: t == 'ENERGY' ? VinkiarColors.aegisCyan : VinkiarColors.vertigoGold,
            );
          }),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text("// RECARGAS SOMÁTICAS & LIQUIDEZ", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.textDim, fontSize: 10)),
        const SizedBox(height: 10),
        _buildItemCard(
          id: "recarga_energia_50",
          category: "ENERGY",
          icon: Icons.battery_charging_full,
          title: "Célula de Recarga (+50%)",
          subtitle: "Inyección Somática Rápida",
          description: "Restaura el 50% de la energía de tu nodo para reanudar escaneos P2P en el Radar.",
          price: "0.99 €",
          amountCents: 99,
          accentColor: VinkiarColors.aegisCyan,
        ),
        _buildItemCard(
          id: "recarga_energia_100",
          category: "ENERGY",
          icon: Icons.electric_bolt,
          title: "Sobrecarga de Núcleo (100%)",
          subtitle: "Recarga Total Inmediata",
          description: "Rellena íntegramente la reserva energética de la Bóveda para expediciones prolongadas.",
          price: "1.49 €",
          amountCents: 149,
          badgeText: "POPULAR",
          accentColor: VinkiarColors.aegisCyan,
        ),
        const SizedBox(height: 8),
        Text("// FICHAS DE CÉLULA (VINKS)", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.textDim, fontSize: 10)),
        const SizedBox(height: 10),
        _buildItemCard(
          id: "alijo_vinks_500",
          category: "VINKS",
          icon: Icons.token,
          title: "Alijo Menor (500 Vinks)",
          subtitle: "Liquidez Básica",
          description: "Fondos de reputación para emitir contratos en la Taberna o recompensar aliados.",
          price: "2.99 €",
          amountCents: 299,
          accentColor: VinkiarColors.vertigoGold,
        ),
        _buildItemCard(
          id: "alijo_vinks_1200",
          category: "VINKS",
          icon: Icons.savings_outlined,
          title: "Alijo Táctico (1200 Vinks)",
          subtitle: "Volumen con Bonificación",
          description: "1000 Vinks base + 200 Vinks de gratificación por lealtad a la red.",
          price: "5.99 €",
          amountCents: 599,
          badgeText: "+20% GRATIS",
          accentColor: VinkiarColors.vertigoGold,
        ),
        _buildItemCard(
          id: "alijo_vinks_5000",
          category: "VINKS",
          icon: Icons.diamond_outlined,
          title: "Reserva de Gremio (5000 Vinks)",
          subtitle: "Alta Liquidez Operativa",
          description: "Fondo masivo para arquitectos de células y gremios activos en expediciones P2P.",
          price: "19.99 €",
          amountCents: 1999,
          badgeText: "MEJOR VALOR",
          accentColor: VinkiarColors.vertigoGold,
        ),
      ],
    );
  }

  Widget _buildLicenciasTab() {
    final remote = _remoteByTypes(['LICENSE']);
    if (remote.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text("// MEMBRESÍAS & SOBERANÍA PERMANENTE", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.textDim, fontSize: 10)),
          const SizedBox(height: 10),
          ...remote.map((r) {
            final cents = (r['amount'] as num?)?.toInt() ?? 499;
            final temp = (r['temporalidad'] ?? 'UNICO').toString().toUpperCase();
            final suffix = temp == 'MENSUAL' ? ' / mes' : (temp == 'ANUAL' ? ' / año' : '');
            return _buildItemCard(
              id: r['product_id'],
              category: "LICENSE",
              icon: _resolveIconForProduct(r['product_id'], 'LICENSE'),
              title: r['name'] ?? '',
              subtitle: "Modalidad: $temp",
              description: (r['description'] ?? '').toString().isNotEmpty
                  ? r['description']
                  : "Acceso soberano a capacidades avanzadas de red y respaldo criptográfico ZKA.",
              price: "${(cents / 100.0).toStringAsFixed(2)} €$suffix",
              amountCents: cents,
              accentColor: r['product_id'] == 'licencia_genesis' ? VinkiarColors.hackingGreen : VinkiarColors.vertigoGold,
              beneficios: (r['beneficios'] is Map<String, dynamic>) ? r['beneficios'] : {},
            );
          }),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text("// MEMBRESÍAS & SOBERANÍA PERMANENTE", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.textDim, fontSize: 10)),
        const SizedBox(height: 10),
        _buildItemCard(
          id: "licencia_genesis",
          category: "LICENSE",
          icon: Icons.fingerprint,
          title: "Licencia Génesis (Base)",
          subtitle: "Mantenimiento Anual ZKA",
          description: "Garantiza el mantenimiento del túnel ciego y actúa como filtro anti-bots (+18).",
          price: "1.00 € / año",
          amountCents: 100,
          badgeText: "ACTIVA",
          accentColor: VinkiarColors.hackingGreen,
        ),
        _buildItemCard(
          id: "pase_vanguardia_mensual",
          category: "LICENSE",
          icon: Icons.shield,
          title: "Pase de Vanguardia (Mensual)",
          subtitle: "Soberanía Desbloqueada",
          description: "Energía ilimitada en el Radar, prioridad de enlace P2P y métricas vectoriales avanzadas.",
          price: "4.99 € / mes",
          amountCents: 499,
          accentColor: VinkiarColors.vertigoGold,
        ),
        _buildItemCard(
          id: "pase_vanguardia_anual",
          category: "LICENSE",
          icon: Icons.workspace_premium,
          title: "Pase de Vanguardia (Anual)",
          subtitle: "Compromiso de Élite",
          description: "Acceso total sin límites energéticos durante 12 meses con 2 meses de descuento incluidos.",
          price: "49.99 € / año",
          amountCents: 4999,
          badgeText: "AHORRA 17%",
          accentColor: VinkiarColors.vertigoGold,
        ),
      ],
    );
  }

  Widget _buildCodicesTab() {
    final remote = _remoteByTypes(['BOOK']);
    if (remote.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text("// REGISTROS NARRATIVOS DESCLASIFICADOS", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.textDim, fontSize: 10)),
          const SizedBox(height: 10),
          ...remote.map((r) {
            final cents = (r['amount'] as num?)?.toInt() ?? 699;
            return _buildItemCard(
              id: r['product_id'],
              category: "BOOK",
              icon: _resolveIconForProduct(r['product_id'], 'BOOK'),
              title: r['name'] ?? '',
              subtitle: "Códice Digital ZKA",
              description: (r['description'] ?? '').toString().isNotEmpty
                  ? r['description']
                  : "Desbloqueo inmediato de lectura y descarga cifrada en tu Bóveda.",
              price: "${(cents / 100.0).toStringAsFixed(2)} €",
              amountCents: cents,
              accentColor: Colors.purpleAccent,
            );
          }),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Text("// REGISTROS NARRATIVOS DESCLASIFICADOS", style: GoogleFonts.jetBrainsMono(color: VinkiarColors.textDim, fontSize: 10)),
        const SizedBox(height: 10),
        _buildItemCard(
          id: "codice_vol_1",
          category: "BOOK",
          icon: Icons.menu_book,
          title: "Sombras en el Búnker ZKA",
          subtitle: "Novela Volumen I (E-book)",
          description: "El inicio de la insurgencia criptográfica. Desbloqueo en lector integrado y archivo EPUB descargable.",
          price: "6.99 €",
          amountCents: 699,
          accentColor: Colors.purpleAccent,
        ),
        _buildItemCard(
          id: "codice_vol_2",
          category: "BOOK",
          icon: Icons.auto_stories,
          title: "El Manifiesto de Faraday",
          subtitle: "Novela Volumen II (E-book)",
          description: "Investigación sobre la pérdida del consentimiento y el nacimiento de las jaulas electromagnéticas.",
          price: "6.99 €",
          amountCents: 699,
          accentColor: Colors.purpleAccent,
        ),
        _buildItemCard(
          id: "codice_trilogia",
          category: "BOOK",
          icon: Icons.collections_bookmark,
          title: "Compendio: Trilogía de la Red Oscura",
          subtitle: "Edición Definitiva (Saga Completa)",
          description: "Los 3 volúmenes completos con apéndices técnicos y arte conceptual exclusivo de la Forja.",
          price: "16.99 €",
          amountCents: 1699,
          badgeText: "PACK COMPLETO",
          accentColor: Colors.purpleAccent,
        ),
      ],
    );
  }

  Widget _buildArtefactosTab() {
    final remote = _remoteByTypes(['PHYSICAL']);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VinkiarColors.panelDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.privacy_tip_outlined, color: VinkiarColors.vertigoGold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "ENTREGA DE ARTEFACTOS FÍSICOS: Tu privacidad sigue blindada. Tu dirección postal solo es transmitida a la pasarela logística y nunca se vincula a tu Bóveda.",
                  style: GoogleFonts.jetBrainsMono(color: VinkiarColors.vertigoGold, fontSize: 9.5, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        if (remote.isNotEmpty)
          ...remote.map((r) {
            final cents = (r['amount'] as num?)?.toInt() ?? 1499;
            final stock = (r['stock_actual'] as num?)?.toInt() ?? 50;
            return _buildItemCard(
              id: r['product_id'],
              category: "PHYSICAL",
              icon: _resolveIconForProduct(r['product_id'], 'PHYSICAL'),
              title: r['name'] ?? '',
              subtitle: "Stock disponible: $stock uds",
              description: (r['description'] ?? '').toString().isNotEmpty
                  ? r['description']
                  : "Equipamiento físico táctico con envío certificado ZKA.",
              price: "${(cents / 100.0).toStringAsFixed(2)} €",
              amountCents: cents,
              badgeText: stock > 0 ? "STOCK: $stock" : "AGOTADO",
              accentColor: VinkiarColors.aegisCyan,
              isPhysical: true,
              stockActual: stock,
            );
          })
        else ...[
          _buildItemCard(
            id: "merch_pulsera_nfc",
            category: "PHYSICAL",
            icon: Icons.watch,
            title: "Pulsera Somática NFC",
            subtitle: "Hardware de Identidad P2P",
            description: "Silicona quirúrgica con chip NFC pasivo para transmitir tu ping de sintonía en encuentros presenciales.",
            price: "14.99 €",
            amountCents: 1499,
            badgeText: "HARDWARE",
            accentColor: VinkiarColors.aegisCyan,
            isPhysical: true,
          ),
          _buildItemCard(
            id: "merch_camiseta_zk",
            category: "PHYSICAL",
            icon: Icons.checkroom,
            title: "Camiseta Táctica 'Zero-Knowledge'",
            subtitle: "Prenda de Resistencia",
            description: "Algodón peinado 100% orgánico con serigrafía reflectante del glifo de la Hoja de Alma.",
            price: "26.99 €",
            amountCents: 2699,
            accentColor: VinkiarColors.vertigoGold,
            isPhysical: true,
          ),
          _buildItemCard(
            id: "merch_pack_parches",
            category: "PHYSICAL",
            icon: Icons.military_tech,
            title: "Pack de Emblemas & Parches Antirrastreo",
            subtitle: "Personalización Física",
            description: "Set de 4 parches tácticos con velcro militar y pegatinas bloqueadoras de cámara/sensores.",
            price: "6.99 €",
            amountCents: 699,
            accentColor: VinkiarColors.hackingGreen,
            isPhysical: true,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VinkiarColors.abyssBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBarBalance(),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: VinkiarColors.vertigoGold))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildEnergiaVinksTab(),
                        _buildLicenciasTab(),
                        _buildCodicesTab(),
                        _buildArtefactosTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
