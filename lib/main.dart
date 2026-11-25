import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:path/path.dart' hide context;
import 'package:provider/provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'config/api_config.dart';
import 'services/vinkiar_secure_database.dart';
import 'services/vinkiar_secure_heap.dart';
import 'services/hardware_sos_service.dart';
import 'services/acoustic_sentinel_service.dart';
import 'services/vinkiar_push_service.dart';
import 'theme/vinkiar_theme.dart';
import 'ui/avatar_onboarding_screen.dart';
import 'ui/boveda_screen.dart';
import 'ui/chat_qa_screen.dart';
import 'ui/contacts_screen.dart';
import 'ui/main_dashboard_screen.dart';
import 'ui/radar_screen.dart';
import 'ui/taberna_screen.dart';
import 'ui/smoke_screen_overlay.dart';
import 'ui/theme.dart' as ui_theme show VinkiarTheme;
import 'ui/theme.dart' show VinkiarColors;
import 'ui/unlock_bunker_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  VinkiarSecureDatabase.setupSqlCipher();

  // Clave pública de Stripe homologada con el entorno de pruebas
  const String defaultStripeKey =
      'pk_test_51TuGGD6jGrMB730L4T0bm7kXz3a0uZAXE4LLS8eTa1A3214C79WxR40Oaz4HMpZ4XpPoIQciFwhfXlIfC5w1f7TE004APrbSrE';

  const String stripePublishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: defaultStripeKey,
  );

  Stripe.publishableKey = stripePublishableKey;
  await Stripe.instance.applySettings();

  VinkiarSecureHeap().init();
  await VinkiarPushService().initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..checkAuth(),
      child: const VinkiarApp(),
    ),
  );
}

class AppState extends ChangeNotifier {
  bool _isInitialized = false;
  bool _isVaultOpen = false;
  String? _pendingVector;
  String? _pendingMasterKey;
  String? _pendingAlias;

  double _textScaleFactor = 1.0;

  bool get isInitialized => _isInitialized;
  bool get isVaultOpen => _isVaultOpen;
  String? get pendingVector => _pendingVector;
  String? get pendingMasterKey => _pendingMasterKey;
  String? get pendingAlias => _pendingAlias;
  double get textScaleFactor => _textScaleFactor;

  void updateTextScaleFactor(double newScale) {
    _textScaleFactor = newScale.clamp(0.8, 1.4);
    notifyListeners();
  }

  void setPendingVector(String vector) {
    _pendingVector = vector;
    notifyListeners();
  }

  void clearPendingVector() {
    _pendingVector = null;
    notifyListeners();
  }

  void setPendingMasterKey(String key, {String? alias}) {
    _pendingMasterKey = key;
    _pendingAlias = alias;
    notifyListeners();
  }

  void clearPendingMasterKey() {
    _pendingMasterKey = null;
    _pendingAlias = null;
    notifyListeners();
  }

  Future<void> checkAuth() async {
    final db = VinkiarSecureDatabase();
    _isVaultOpen = db.db != null;
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> openVault(String password) async {
    final db = VinkiarSecureDatabase();
    final salt = Uint8List.fromList("VINKIAR_LOCAL_SALT_2026".codeUnits);

    try {
      await db.initializeVault(
        masterPassword: password,
        userEmail: "pionero@vinkiar.org",
        salt: salt,
      );
      _isVaultOpen = true;
      notifyListeners();
      unawaited(VinkiarPushService().syncDeviceTokenWithBackend());
    } catch (e) {
      debugPrint("Error opening vault: $e");
      rethrow;
    }
  }

  void logout() {
    VinkiarSecureDatabase().clearKeys();
    _isVaultOpen = false;
    notifyListeners();
  }
}

class VinkiarApp extends StatefulWidget {
  /// Bandera global para evitar bloqueo de bóveda al abrir Stripe PaymentSheet nativo
  static bool isStripeCheckoutActive = false;

  /// Bandera global para evitar bloqueo de bóveda al abrir diálogos nativos (PIN dispositivo / SAF Keyfile)
  static bool isSystemDialogActive = false;

  const VinkiarApp({Key? key}) : super(key: key);

  @override
  State<VinkiarApp> createState() => _VinkiarAppState();
}

class _VinkiarAppState extends State<VinkiarApp> with WidgetsBindingObserver {
  Widget? _initialScreen;
  bool _shouldLockOnResume = false;
  static bool isDecoyActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _determineInitialRoute();
    _initHardwareSos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (!isDecoyActive &&
          !SmokeScreenOverlay.isOverlayOpen &&
          !VinkiarApp.isStripeCheckoutActive &&
          !VinkiarApp.isSystemDialogActive) {
        _shouldLockOnResume = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (VinkiarSecureDatabase().db != null) {
        unawaited(VinkiarPushService().syncOfflineInbox());
      }
      if (isDecoyActive ||
          SmokeScreenOverlay.isOverlayOpen ||
          VinkiarApp.isStripeCheckoutActive ||
          VinkiarApp.isSystemDialogActive) {
        _shouldLockOnResume = false;
        return;
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted ||
            isDecoyActive ||
            SmokeScreenOverlay.isOverlayOpen ||
            VinkiarApp.isStripeCheckoutActive ||
            VinkiarApp.isSystemDialogActive) return;
        if (_shouldLockOnResume) {
          _shouldLockOnResume = false;
          _lockAndRequireAuth();
        }
      });
    }
  }

  void _lockAndRequireAuth() {
    if (isDecoyActive ||
        SmokeScreenOverlay.isOverlayOpen ||
        VinkiarApp.isStripeCheckoutActive ||
        VinkiarApp.isSystemDialogActive ||
        _initialScreen == null ||
        !mounted) {
      debugPrint("🛡️ [AUTH] Bloqueo cancelado: Señuelo activo.");
      return;
    }

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      if (!appState.isVaultOpen) return;

      appState.logout();

      rootNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const UnlockBunkerScreen()),
        (route) => false,
      );
    } catch (_) {}
  }

  void _initHardwareSos() {
    HardwareSosService().initialize(
      onEmergency: () {
        if (isDecoyActive || SmokeScreenOverlay.isOverlayOpen) return;
        isDecoyActive = true;
        SmokeScreenOverlay.isOverlayOpen = true;
        _shouldLockOnResume = false;
        AcousticSentinelService().isOverlayActive = true;

        rootNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => const SmokeScreenOverlay(
              reason: SentinelTriggerReason.hardwarePanic,
              isEmergencySOS: true,
            ),
          ),
        ).then((_) {
          isDecoyActive = false;
          SmokeScreenOverlay.isOverlayOpen = false;
          AcousticSentinelService().isOverlayActive = false;
        });
      },
    );
  }

  Future<void> _determineInitialRoute() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'vinkiar_vault_v4.db');
    final exists = await File(path).exists();

    if (mounted) {
      setState(() {
        _initialScreen =
            exists ? const UnlockBunkerScreen() : const AvatarOnboardingScreen();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialScreen == null) {
      return MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const Scaffold(
          backgroundColor: VinkiarColors.abyssBlack,
          body: Center(
            child: CircularProgressIndicator(color: VinkiarColors.aegisCyan),
          ),
        ),
      );
    }

    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Vinkiar OS',
      theme: VinkiarTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            HardwareSosService().exitToHome();
          }
        },
        child: _initialScreen!,
      ),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Selector<AppState, double>(
          selector: (_, state) => state.textScaleFactor,
          builder: (context, scale, _) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale).clamp(
                  minScaleFactor: 0.8,
                  maxScaleFactor: 1.4,
                ),
              ),
              child: child!,
            );
          },
        );
      },
    );
  }
}