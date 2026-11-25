import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/vinkiar_secure_database.dart';
import '../services/vinkiar_zkp_sovereignty_service.dart';
import 'avatar_onboarding_screen.dart';
import 'main_dashboard_screen.dart';
import 'theme.dart';

class UnlockBunkerScreen extends StatefulWidget {
  const UnlockBunkerScreen({Key? key}) : super(key: key);

  @override
  State<UnlockBunkerScreen> createState() => _UnlockBunkerScreenState();
}

class _UnlockBunkerScreenState extends State<UnlockBunkerScreen> {
  static const MethodChannel _nativeChannel = MethodChannel('com.vinkiar.os/hardware_sos');
  final TextEditingController _masterKeyController = TextEditingController();

  bool _isLoading = false;
  bool _isNewRegistration = false;
  bool _obscureInput = true;

  // Identidad y selector de método de acceso
  String _avatarAlias = 'Pionero ZKA';
  ZkpLoginMethod _selectedMethod = ZkpLoginMethod.biometric2FA;
  bool _biometricAvailable = false;
  bool _devicePinAvailable = false;
  bool _hasKeystorePinVault = false;
  bool _keyfile2FAEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadAuthPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.pendingMasterKey != null) {
        setState(() => _isNewRegistration = true);
        _masterKeyController.text = appState.pendingMasterKey!;
        _sealNewVault(appState.pendingMasterKey!, appState.pendingAlias);
      }
    });
  }

  Future<void> _loadAuthPreferences() async {
    final caps = await VinkiarZkpSovereigntyService.checkDeviceCapabilities();
    final hasHwVault = await VinkiarZkpSovereigntyService.hasHardwareSealedVault();
    final kfEnabled = await VinkiarZkpSovereigntyService.isKeyfile2FAEnabled();
    final savedMethod = await VinkiarZkpSovereigntyService.getPreferredLoginMethod();
    final savedAlias = await VinkiarZkpSovereigntyService.getSavedAvatarAlias();

    if (!mounted) return;
    setState(() {
      _biometricAvailable = caps['biometricStrongAvailable'] == true;
      _devicePinAvailable = caps['deviceCredentialAvailable'] == true;
      _hasKeystorePinVault = hasHwVault;
      _keyfile2FAEnabled = kfEnabled;
      _selectedMethod = savedMethod;
      if (savedAlias != null && savedAlias.isNotEmpty) {
        _avatarAlias = savedAlias.startsWith('#') ? savedAlias : '#$savedAlias';
      }
      _obscureInput = _selectedMethod != ZkpLoginMethod.mnemonic12;
    });
  }

  Future<void> _sealNewVault(String masterKey, String? alias) async {
    setState(() => _isLoading = true);
    try {
      final salt = VinkiarSecureDatabase.defaultSalt;
      await VinkiarSecureDatabase().initializeVault(
        masterPassword: masterKey,
        userEmail: alias != null ? '$alias@vinkiar.zka' : 'pionero@vinkiar.org',
        salt: salt,
        skipBiometrics: true,
      );

      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.pendingVector != null) {
        await VinkiarSecureDatabase().saveUserVector(appState.pendingVector!);
        appState.clearPendingVector();
      }
      appState.clearPendingMasterKey();

      if (alias != null && alias.trim().isNotEmpty) {
        await VinkiarZkpSovereigntyService.saveAvatarAlias(alias.trim());
      }
      await VinkiarSecureDatabase().markAvatarRegistered();

      if (_devicePinAvailable) {
        final secretBytes = VinkiarZkpSovereigntyService.encodeSecretTextToBytes(masterKey);
        try {
          await VinkiarZkpSovereigntyService.sealVaultWithDevicePin(
            vaultSecretBytes: secretBytes,
            pinOnly: true,
          );
        } catch (_) {
        } finally {
          secretBytes.fillRange(0, secretBytes.length, 0);
        }
      }

      if (mounted) {
        _showSnackBar("BÓVEDA SELLADA CON ÉXITO. BIENVENIDO, PIONERO.", VinkiarColors.aegisCyan);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainDashboardScreen()),
        );
      }
    } catch (e) {
      _showSnackBar("ERROR AL SELLAR LA BÓVEDA: $e", VinkiarColors.panicRed);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _masterKeyController.dispose();
    super.dispose();
  }

  Future<void> _restoreBackup() async {
    VinkiarApp.isSystemDialogActive = true;
    try {
      final List<PlatformFile>? files = await FilePicker.pickFiles();
      if (files != null && files.isNotEmpty && files.first.path != null) {
        await VinkiarSecureDatabase().replaceDatabase(files.first.path!);
        if (!mounted) return;
        _showSnackBar(
          "BÓVEDA RESTAURADA. ELIGE TU MÉTODO DE ACCESO PARA ABRIRLA.",
          VinkiarColors.aegisCyan,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar("Error al restaurar bóveda: $e", VinkiarColors.panicRed);
    } finally {
      VinkiarApp.isSystemDialogActive = false;
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: VinkiarColors.textHdr,
            fontFamily: 'JetBrains Mono',
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _executeSelectedUnlock() async {
    setState(() => _isLoading = true);

    try {
      try {
        await _nativeChannel.invokeMethod('dismissKeyguard');
        await Future.delayed(const Duration(milliseconds: 120));
      } catch (_) {}

      final db = VinkiarSecureDatabase();
      if (!_isNewRegistration) {
        final hasAvatar = await db.hasRegisteredAvatar();
        if (!hasAvatar) {
          _showSnackBar(
            "ACCESO DENEGADO: NO HAY AVATAR REGISTRADO. INICIA LA FORJA.",
            VinkiarColors.panicRed,
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      await VinkiarZkpSovereigntyService.setPreferredLoginMethod(_selectedMethod);

      // =====================================================================
      // MODO A: PIN / PATRÓN DEL DISPOSITIVO (SIN BIOMETRÍA, ANDROID KEYSTORE)
      // =====================================================================
      if (_selectedMethod == ZkpLoginMethod.devicePin && _hasKeystorePinVault) {
        final bundle = await VinkiarZkpSovereigntyService.unlockWithDevicePinOnly();
        await VinkiarSecureDatabase().initializeVault(
          masterPassword: bundle.rawSecretText,
          userEmail: 'pionero@vinkiar.org',
          salt: VinkiarSecureDatabase.defaultSalt,
          skipBiometrics: true,
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainDashboardScreen()),
          );
        }
        return;
      }

      // =====================================================================
      // MODOS B, C, D: CONTRASEÑA + HUELLA (2FA) / SEMILLA 12 PALABRAS / SOLO LLAVE
      // =====================================================================
      final inputSecret = _masterKeyController.text.trim();
      if (inputSecret.isEmpty) {
        _showSnackBar(
          _selectedMethod == ZkpLoginMethod.mnemonic12
              ? "INTRODUCE TUS 12 PALABRAS SEMILLA BIP-39"
              : "INTRODUCE TU LLAVE MAESTRA PARA CONTINUAR",
          VinkiarColors.panicRed,
        );
        setState(() => _isLoading = false);
        return;
      }

      // Paso 2 Biométrico (si el método elegido es Contraseña + Huella Biométrica)
      if (_selectedMethod == ZkpLoginMethod.biometric2FA) {
        await VinkiarZkpSovereigntyService.authenticateBiometric2FAStep(
          title: 'Segundo Paso Biométrico (2FA)',
          subtitle: 'Confirma tu huella dactilar para abrir la Bóveda de $_avatarAlias',
        );
      }

      // Verificar Keyfile 2FA si está activo
      Uint8List keyfileDigest = Uint8List(0);
      if (await VinkiarZkpSovereigntyService.isKeyfile2FAEnabled()) {
        keyfileDigest = await VinkiarZkpSovereigntyService.verifyLinkedKeyfileOrThrow();
      }

      final words = inputSecret
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      final bool isBip39 =
          _selectedMethod == ZkpLoginMethod.mnemonic12 || words.length == 12;

      String effectiveSqlCipherPassword = inputSecret;
      if (isBip39) {
        if (!VinkiarZkpSovereigntyService.validateMnemonic(inputSecret)) {
          if (keyfileDigest.isNotEmpty) {
            keyfileDigest.fillRange(0, keyfileDigest.length, 0);
          }
          _showSnackBar(
            "FRASE SEMILLA BIP-39 INVÁLIDA (REVISA LAS 12 PALABRAS).",
            VinkiarColors.panicRed,
          );
          setState(() => _isLoading = false);
          return;
        }
        final rootKey =
            VinkiarZkpSovereigntyService.deriveVaultMasterKeyFromMnemonic(inputSecret);
        final derived = VinkiarZkpSovereigntyService.deriveSessionKeys(
          rawSecretText: '',
          vaultMasterKey: rootKey,
          keyfileSha256: keyfileDigest,
        );
        effectiveSqlCipherPassword = derived.sqlCipherHexKey;
        rootKey.fillRange(0, rootKey.length, 0);
      } else if (keyfileDigest.isNotEmpty) {
        // Combinar Llave Maestra + Keyfile 2FA vía HKDF-SHA256
        final rawPwdBytes = VinkiarZkpSovereigntyService.encodeSecretTextToBytes(inputSecret);
        final derived = VinkiarZkpSovereigntyService.deriveSessionKeys(
          rawSecretText: inputSecret,
          vaultMasterKey: rawPwdBytes,
          keyfileSha256: keyfileDigest,
        );
        effectiveSqlCipherPassword = derived.sqlCipherHexKey;
        rawPwdBytes.fillRange(0, rawPwdBytes.length, 0);
      }

      if (keyfileDigest.isNotEmpty) {
        keyfileDigest.fillRange(0, keyfileDigest.length, 0);
      }

      try {
        await VinkiarSecureDatabase().initializeVault(
          masterPassword: effectiveSqlCipherPassword,
          userEmail: 'pionero@vinkiar.org',
          salt: VinkiarSecureDatabase.defaultSalt,
          skipBiometrics: true,
        );

        // Si el usuario eligió vincular PIN del dispositivo por primera vez, sellarlo en Keystore ahora
        if (_selectedMethod == ZkpLoginMethod.devicePin &&
            _devicePinAvailable &&
            !_hasKeystorePinVault) {
          final bytesToSeal =
              VinkiarZkpSovereigntyService.encodeSecretTextToBytes(effectiveSqlCipherPassword);
          try {
            await VinkiarZkpSovereigntyService.sealVaultWithDevicePin(
              vaultSecretBytes: bytesToSeal,
              pinOnly: true,
            );
          } catch (_) {
          } finally {
            bytesToSeal.fillRange(0, bytesToSeal.length, 0);
          }
        }

        try {
          final appState = Provider.of<AppState>(context, listen: false);
          if (appState.pendingVector != null) {
            await VinkiarSecureDatabase().saveUserVector(appState.pendingVector!);
            appState.clearPendingVector();
          }
        } catch (_) {}
      } on VaultSecurityException catch (e) {
        _showSnackBar(
          "ACCESO DENEGADO: ${e.message.replaceAll('VaultSecurityException: ', '')}",
          VinkiarColors.panicRed,
        );
        setState(() => _isLoading = false);
        return;
      } catch (_) {
        _showSnackBar("CREDENCIALES INCORRECTAS O ACCESO DENEGADO", VinkiarColors.panicRed);
        setState(() => _isLoading = false);
        return;
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainDashboardScreen()),
        );
      }
    } catch (e) {
      _showSnackBar(
        e.toString().replaceAll('Bad state: ', '').replaceAll('Exception: ', ''),
        VinkiarColors.panicRed,
      );
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _iconForMethod(ZkpLoginMethod method) {
    switch (method) {
      case ZkpLoginMethod.biometric2FA:
        return Icons.fingerprint;
      case ZkpLoginMethod.devicePin:
        return Icons.pin_outlined;
      case ZkpLoginMethod.mnemonic12:
        return Icons.vpn_key_outlined;
      case ZkpLoginMethod.passwordOnly:
        return Icons.lock_outline;
    }
  }

  String _buttonLabelForMethod(ZkpLoginMethod method) {
    switch (method) {
      case ZkpLoginMethod.biometric2FA:
        return "CONTINUAR A HUELLA (2FA)";
      case ZkpLoginMethod.devicePin:
        return _hasKeystorePinVault
            ? "ENTRAR CON PIN DEL DISPOSITIVO"
            : "VINCULAR Y ENTRAR CON PIN";
      case ZkpLoginMethod.mnemonic12:
        return "DESBLOQUEAR CON 12 PALABRAS";
      case ZkpLoginMethod.passwordOnly:
        return "DESBLOQUEAR BÓVEDA";
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool needsTextField =
        _selectedMethod != ZkpLoginMethod.devicePin || !_hasKeystorePinVault;

    final List<ZkpLoginMethod> availableMethods = [
      if (_biometricAvailable) ZkpLoginMethod.biometric2FA,
      if (_devicePinAvailable) ZkpLoginMethod.devicePin,
      ZkpLoginMethod.mnemonic12,
      ZkpLoginMethod.passwordOnly,
    ];

    final ZkpLoginMethod effectiveDropdownValue = availableMethods.contains(_selectedMethod)
        ? _selectedMethod
        : availableMethods.first;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(context).clamp(minScaleFactor: 0.8, maxScaleFactor: 1.25),
        ),
        child: Scaffold(
          backgroundColor: VinkiarColors.abyssBlack,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/Logo_Vinkiar_03.5.png',
                      height: 68,
                      fit: BoxFit.contain,
                      color: VinkiarColors.aegisCyan,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "SISTEMA OPERATIVO RELACIONAL",
                      style: VinkiarTheme.terminalSm.copyWith(
                        color: VinkiarColors.textDim,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // CABECERA + TARJETA USUARIO / AVATAR
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "APERTURA DEL BÚNKER",
                            style: VinkiarTheme.terminalData.copyWith(
                              color: VinkiarColors.aegisCyan,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          if (_keyfile2FAEnabled)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: VinkiarColors.vertigoGold.withOpacity(0.15),
                                border: Border.all(color: VinkiarColors.vertigoGold),
                              ),
                              child: const Text(
                                "2FA KEYFILE",
                                style: TextStyle(
                                  color: VinkiarColors.vertigoGold,
                                  fontFamily: 'JetBrains Mono',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: VinkiarColors.panelDark,
                        border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: VinkiarColors.aegisCyan.withOpacity(0.12),
                              border: Border.all(color: VinkiarColors.aegisCyan),
                            ),
                            child: const Icon(Icons.shield_outlined, color: VinkiarColors.aegisCyan, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "IDENTIDAD SOBERANA LOCAL",
                                  style: TextStyle(
                                    color: VinkiarColors.textDim,
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 9.5,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _avatarAlias,
                                  style: const TextStyle(
                                    color: VinkiarColors.textHdr,
                                    fontFamily: 'JetBrains Mono',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // SELECTOR DESPLEGABLE DE MÉTODO DE ACCESO
                    DropdownButtonFormField<ZkpLoginMethod>(
                      value: effectiveDropdownValue,
                      dropdownColor: VinkiarColors.panelDark,
                      iconEnabledColor: VinkiarColors.aegisCyan,
                      style: const TextStyle(
                        color: VinkiarColors.textHdr,
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        labelText: "MÉTODO DE VERIFICACIÓN",
                        labelStyle: VinkiarTheme.terminalSm.copyWith(
                          color: VinkiarColors.vertigoGold,
                          fontSize: 11,
                        ),
                        filled: true,
                        fillColor: VinkiarColors.panelDark,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: VinkiarColors.vertigoGold.withOpacity(0.7), width: 1),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.zero,
                          borderSide: BorderSide(color: VinkiarColors.vertigoGold, width: 1.5),
                        ),
                      ),
                      items: availableMethods.map((method) {
                        return DropdownMenuItem<ZkpLoginMethod>(
                          value: method,
                          child: Row(
                            children: [
                              Icon(_iconForMethod(method), size: 17, color: VinkiarColors.aegisCyan),
                              const SizedBox(width: 10),
                              Text(method.label, style: const TextStyle(fontSize: 11.5)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: _isLoading
                          ? null
                          : (val) {
                              if (val == null) return;
                              setState(() {
                                _selectedMethod = val;
                                _masterKeyController.clear();
                                _obscureInput = val != ZkpLoginMethod.mnemonic12;
                              });
                            },
                    ),
                    const SizedBox(height: 16),

                    // CAMPO DE CONTRASEÑA O SEMILLA (SEGÚN MÉTODO ELEGIDO)
                    if (needsTextField) ...[
                      TextField(
                        controller: _masterKeyController,
                        obscureText: _obscureInput,
                        maxLines: _selectedMethod == ZkpLoginMethod.mnemonic12 ? 3 : 1,
                        style: VinkiarTheme.terminalData.copyWith(color: VinkiarColors.textHdr, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: _selectedMethod == ZkpLoginMethod.mnemonic12
                              ? "FRASE SEMILLA BIP-39 (12 PALABRAS)"
                              : "LLAVE MAESTRA (CONTRASEÑA)",
                          hintText: _selectedMethod == ZkpLoginMethod.mnemonic12
                              ? "palabra1 palabra2 palabra3 ... palabra12"
                              : null,
                          hintStyle: TextStyle(color: VinkiarColors.textDim.withOpacity(0.5), fontSize: 11),
                          labelStyle: VinkiarTheme.terminalSm.copyWith(color: VinkiarColors.textDim, fontSize: 11),
                          filled: true,
                          fillColor: VinkiarColors.panelDark,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureInput ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: VinkiarColors.textDim,
                              size: 19,
                            ),
                            onPressed: () => setState(() => _obscureInput = !_obscureInput),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(color: VinkiarColors.aegisCyan, width: 1),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.zero,
                            borderSide: BorderSide(color: VinkiarColors.aegisCyan, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_selectedMethod == ZkpLoginMethod.biometric2FA)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Paso 1: Introduce tu contraseña · Paso 2: Confirma con tu huella",
                            style: TextStyle(
                              color: VinkiarColors.textDim,
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                            ),
                          ),
                        ),
                      if (_selectedMethod == ZkpLoginMethod.devicePin && !_hasKeystorePinVault)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Introduce tu contraseña una vez para vincular el PIN de este terminal",
                            style: TextStyle(
                              color: VinkiarColors.vertigoGold,
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VinkiarColors.panelDark,
                          border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.35)),
                        ),
                        child: const Text(
                          "Desbloqueo hardware listo: se solicitará únicamente el PIN o patrón de tu dispositivo (sin huella ni rostro).",
                          style: TextStyle(
                            color: VinkiarColors.textDim,
                            fontFamily: 'JetBrains Mono',
                            fontSize: 10.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 26),

                    // BOTÓN PRINCIPAL DE ACCESO
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VinkiarColors.aegisCyan,
                        foregroundColor: VinkiarColors.abyssBlack,
                        minimumSize: const Size(double.infinity, 54),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                        elevation: 4,
                      ),
                      onPressed: _isLoading ? null : _executeSelectedUnlock,
                      icon: _isLoading
                          ? const SizedBox.shrink()
                          : Icon(_iconForMethod(effectiveDropdownValue), size: 20),
                      label: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: VinkiarColors.abyssBlack,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              _buttonLabelForMethod(effectiveDropdownValue),
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                letterSpacing: 0.9,
                              ),
                            ),
                    ),

                    const SizedBox(height: 20),

                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AvatarOnboardingScreen(),
                                ),
                              );
                            },
                      child: const Text(
                        "REGISTRAR NUEVA CUENTA (PIONERO)",
                        style: TextStyle(
                          color: VinkiarColors.vertigoGold,
                          fontFamily: 'JetBrains Mono',
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : _restoreBackup,
                      child: const Text(
                        "RESTAURAR BÓVEDA EXTERNA",
                        style: TextStyle(
                          color: VinkiarColors.textDim,
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11.5,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
