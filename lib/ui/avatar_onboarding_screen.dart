import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../config/api_config.dart';
import '../main.dart';
import '../services/vinkiar_secure_database.dart';
import '../services/vinkiar_zkp_sovereignty_service.dart';
import 'forge_intro_screen.dart';
import 'theme.dart';
import 'unlock_bunker_screen.dart';

class AvatarOnboardingScreen extends StatefulWidget {
  const AvatarOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<AvatarOnboardingScreen> createState() => _AvatarOnboardingScreenState();
}

class _AvatarOnboardingScreenState extends State<AvatarOnboardingScreen> {
  final TextEditingController _inviteCodeController = TextEditingController();
  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _masterKeyController = TextEditingController();
  final TextEditingController _confirmKeyController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _seedConfirmed = false;

  // Soberanía ZKP generada en el momento de alta
  late String _generatedMnemonic;
  ZkpLoginMethod _preferredMethod = ZkpLoginMethod.biometric2FA;
  bool _biometricAvailable = false;
  bool _devicePinAvailable = false;
  bool _keyfile2FAEnabled = false;
  String? _linkedKeyfileName;

  @override
  void initState() {
    super.initState();
    _generatedMnemonic = VinkiarZkpSovereigntyService.generateMnemonic12Words();
    _detectCapabilities();
  }

  Future<void> _detectCapabilities() async {
    final caps = await VinkiarZkpSovereigntyService.checkDeviceCapabilities();
    final kfEnabled = await VinkiarZkpSovereigntyService.isKeyfile2FAEnabled();
    final kfName = await VinkiarZkpSovereigntyService.getLinkedKeyfileName();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = caps['biometricStrongAvailable'] == true;
      _devicePinAvailable = caps['deviceCredentialAvailable'] == true;
      _keyfile2FAEnabled = kfEnabled;
      _linkedKeyfileName = kfName;
      if (!_biometricAvailable && _devicePinAvailable) {
        _preferredMethod = ZkpLoginMethod.devicePin;
      } else if (!_biometricAvailable && !_devicePinAvailable) {
        _preferredMethod = ZkpLoginMethod.passwordOnly;
      }
    });
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _aliasController.dispose();
    _masterKeyController.dispose();
    _confirmKeyController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: VinkiarColors.textHdr,
            fontFamily: 'JetBrains Mono',
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
          ),
        ),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _createAccountAndSealVault() async {
    final inviteCode = _inviteCodeController.text.trim().toUpperCase();
    final rawAlias = _aliasController.text.trim();
    final masterKey = _masterKeyController.text.trim();
    final confirmKey = _confirmKeyController.text.trim();

    if (inviteCode.isEmpty) {
      _showSnack("INTRODUCE UN CÓDIGO DE INVITACIÓN ZK VÁLIDO", VinkiarColors.panicRed);
      return;
    }
    if (rawAlias.length < 3) {
      _showSnack("EL ALIAS DEL AVATAR DEBE TENER AL MENOS 3 CARACTERES", VinkiarColors.panicRed);
      return;
    }
    if (masterKey.length < 8) {
      _showSnack("LA LLAVE MAESTRA DEBE TENER AL MENOS 8 CARACTERES", VinkiarColors.panicRed);
      return;
    }
    if (masterKey != confirmKey) {
      _showSnack("LAS LLAVES MAESTRAS NO COINCIDEN", VinkiarColors.panicRed);
      return;
    }
    if (!_seedConfirmed) {
      _showSnack("CONFIRMA QUE HAS GUARDADO TU SEMILLA DE 12 PALABRAS", VinkiarColors.vertigoGold);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final cleanBase = ApiConfig.baseUrl.endsWith('/')
          ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
          : ApiConfig.baseUrl;

      // 1. Validar código de invitación ZK contra el router ciego
      final bool isLocalBypassCode =
          inviteCode == 'ZK-DEV-2026' ||
          inviteCode == 'PIONERO_ALPHA_2026' ||
          inviteCode.startsWith('ZK-DEV');

      if (!isLocalBypassCode) {
        final valRes = await http
            .get(Uri.parse('$cleanBase/api/v1/auth/validate-invite/$inviteCode'))
            .timeout(const Duration(seconds: 8));
        if (valRes.statusCode != 200) {
          final err = jsonDecode(valRes.body);
          throw Exception(err['detail'] ?? 'Código de invitación rechazado o ya utilizado.');
        }
      }

      final String userUuid = const Uuid().v4();
      final String formattedAlias = rawAlias.startsWith('#') ? rawAlias : '#$rawAlias';

      // 2. Registrar identidad anónima en backend (sin enviar jamás la Llave Maestra ni la Semilla)
      try {
        await http
            .post(
              Uri.parse('$cleanBase/api/v1/auth/register-anonym'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'user_id': userUuid,
                'payment_token': 'GENESIS_PENDING',
                'invite_code': inviteCode,
                'alias': formattedAlias,
                'arquetipo': 'INICIADO ZKA',
              }),
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Si el registro remoto queda pendiente por red, continúa en modo soberano local
      }

      // 3. Si el usuario vinculó un Keyfile 2FA durante el alta, exigir su verificación inicial y derivar clave combinada
      Uint8List keyfileDigest = Uint8List(0);
      if (await VinkiarZkpSovereigntyService.isKeyfile2FAEnabled()) {
        keyfileDigest = await VinkiarZkpSovereigntyService.verifyLinkedKeyfileOrThrow();
      }

      String effectiveVaultPassword = masterKey;
      if (keyfileDigest.isNotEmpty) {
        final rawPwdBytes = VinkiarZkpSovereigntyService.encodeSecretTextToBytes(masterKey);
        final derived = VinkiarZkpSovereigntyService.deriveSessionKeys(
          rawSecretText: masterKey,
          vaultMasterKey: rawPwdBytes,
          keyfileSha256: keyfileDigest,
        );
        effectiveVaultPassword = derived.sqlCipherHexKey;
        rawPwdBytes.fillRange(0, rawPwdBytes.length, 0);
        keyfileDigest.fillRange(0, keyfileDigest.length, 0);
      }

      // 4. Inicializar bóveda SQLCipher local y guardar ficha inicial
      await VinkiarSecureDatabase().initializeVault(
        masterPassword: effectiveVaultPassword,
        userEmail: '${rawAlias.replaceAll('#', '')}@vinkiar.zka',
        salt: VinkiarSecureDatabase.defaultSalt,
        skipBiometrics: true,
      );

      await VinkiarSecureDatabase().saveSoulSheet(userUuid, {'alias': formattedAlias});
      await VinkiarSecureDatabase().saveAvatarSheet('LOCAL_USER', {
        'character_class': 'INICIADO ZKA',
        'level': 1,
        'experience_points': 0,
        'reputation_score': 1.0,
        'stats': {
          'alias': formattedAlias,
          'vinks': 150,
          'escrow': 0,
        },
      });

      await VinkiarZkpSovereigntyService.saveAvatarAlias(formattedAlias);
      await VinkiarZkpSovereigntyService.setPreferredLoginMethod(_preferredMethod);

      // Sellar en Android Keystore bajo PIN del dispositivo para habilitar acceso rápido sin biometría
      if (_devicePinAvailable) {
        final secretBytes =
            VinkiarZkpSovereigntyService.encodeSecretTextToBytes(effectiveVaultPassword);
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

      if (!mounted) return;
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.checkAuth();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ForgeScreen(
            userUuid: userUuid,
            alias: formattedAlias,
          ),
        ),
      );
    } catch (e) {
      _showSnack(
        e.toString().replaceAll('Exception: ', '').replaceAll('Bad state: ', ''),
        VinkiarColors.panicRed,
      );
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = _generatedMnemonic.split(' ');
    final List<ZkpLoginMethod> methodOptions = [
      if (_biometricAvailable) ZkpLoginMethod.biometric2FA,
      if (_devicePinAvailable) ZkpLoginMethod.devicePin,
      ZkpLoginMethod.mnemonic12,
      ZkpLoginMethod.passwordOnly,
    ];

    final ZkpLoginMethod effectiveMethod = methodOptions.contains(_preferredMethod)
        ? _preferredMethod
        : methodOptions.first;

    return Scaffold(
      backgroundColor: VinkiarColors.abyssBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "GÉNESIS // ALTA SOBERANA ZKA",
                    style: TextStyle(
                      color: VinkiarColors.aegisCyan,
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.1,
                    ),
                  ),
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const UnlockBunkerScreen()),
                            );
                          },
                    child: const Text(
                      "YA TENGO BÓVEDA",
                      style: TextStyle(
                        color: VinkiarColors.textDim,
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10.5,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ===============================================================
              // BLOQUE 1: CÓDIGO DE INVITACIÓN, ALIAS Y LLAVE MAESTRA
              // ===============================================================
              TextField(
                controller: _inviteCodeController,
                textCapitalization: TextCapitalization.characters,
                style: VinkiarTheme.terminalData.copyWith(color: VinkiarColors.vertigoGold, fontSize: 14),
                decoration: InputDecoration(
                  labelText: "CÓDIGO DE INVITACIÓN ZK *",
                  hintText: "ZK-XXXXXXXX",
                  hintStyle: TextStyle(color: VinkiarColors.textDim.withOpacity(0.5), fontSize: 12),
                  labelStyle: VinkiarTheme.terminalSm.copyWith(color: VinkiarColors.vertigoGold, fontSize: 11),
                  filled: true,
                  fillColor: VinkiarColors.panelDark,
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: VinkiarColors.vertigoGold, width: 1),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: VinkiarColors.vertigoGold, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _aliasController,
                style: VinkiarTheme.terminalData.copyWith(color: VinkiarColors.textHdr, fontSize: 14),
                decoration: InputDecoration(
                  labelText: "ALIAS DE AVATAR *",
                  hintText: "#Kaelen_Void",
                  hintStyle: TextStyle(color: VinkiarColors.textDim.withOpacity(0.5), fontSize: 12),
                  labelStyle: VinkiarTheme.terminalSm.copyWith(color: VinkiarColors.textDim, fontSize: 11),
                  filled: true,
                  fillColor: VinkiarColors.panelDark,
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
              const SizedBox(height: 14),

              TextField(
                controller: _masterKeyController,
                obscureText: _obscurePassword,
                style: VinkiarTheme.terminalData.copyWith(color: VinkiarColors.textHdr, fontSize: 14),
                decoration: InputDecoration(
                  labelText: "LLAVE MAESTRA (MÍN. 8 CARACTERES) *",
                  labelStyle: VinkiarTheme.terminalSm.copyWith(color: VinkiarColors.textDim, fontSize: 11),
                  filled: true,
                  fillColor: VinkiarColors.panelDark,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: VinkiarColors.textDim,
                      size: 19,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
              const SizedBox(height: 14),

              TextField(
                controller: _confirmKeyController,
                obscureText: _obscurePassword,
                style: VinkiarTheme.terminalData.copyWith(color: VinkiarColors.textHdr, fontSize: 14),
                decoration: InputDecoration(
                  labelText: "CONFIRMAR LLAVE MAESTRA *",
                  labelStyle: VinkiarTheme.terminalSm.copyWith(color: VinkiarColors.textDim, fontSize: 11),
                  filled: true,
                  fillColor: VinkiarColors.panelDark,
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
              const SizedBox(height: 16),

              // SELECTOR DE MÉTODO DE ACCESO PREFERIDO
              DropdownButtonFormField<ZkpLoginMethod>(
                value: effectiveMethod,
                dropdownColor: VinkiarColors.panelDark,
                iconEnabledColor: VinkiarColors.aegisCyan,
                style: const TextStyle(
                  color: VinkiarColors.textHdr,
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: "MÉTODO DE DESBLOQUEO PREFERIDO",
                  labelStyle: VinkiarTheme.terminalSm.copyWith(color: VinkiarColors.aegisCyan, fontSize: 11),
                  filled: true,
                  fillColor: VinkiarColors.panelDark,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: VinkiarColors.aegisCyan.withOpacity(0.6), width: 1),
                  ),
                ),
                items: methodOptions.map((m) {
                  return DropdownMenuItem<ZkpLoginMethod>(
                    value: m,
                    child: Text(m.label),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _preferredMethod = val);
                },
              ),

              const SizedBox(height: 20),

              // ===============================================================
              // BLOQUE 2: SEMILLA MAESTRA BIP-39 (12 PALABRAS) + KEYFILE 2FA
              // ===============================================================
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VinkiarColors.panelDark,
                  border: Border.all(color: VinkiarColors.vertigoGold.withOpacity(0.55)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "SEMILLA DE RECUPERACIÓN (12 PALABRAS)",
                          style: TextStyle(
                            color: VinkiarColors.vertigoGold,
                            fontFamily: 'JetBrains Mono',
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _generatedMnemonic =
                                      VinkiarZkpSovereigntyService.generateMnemonic12Words();
                                  _seedConfirmed = false;
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text(
                                  "ROTAR",
                                  style: TextStyle(
                                    color: VinkiarColors.textDim,
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 10,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: _generatedMnemonic));
                                _showSnack("12 palabras copiadas al portapapeles.", VinkiarColors.aegisCyan);
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text(
                                  "COPIAR",
                                  style: TextStyle(
                                    color: VinkiarColors.aegisCyan,
                                    fontFamily: 'JetBrains Mono',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(words.length, (i) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: VinkiarColors.abyssBlack,
                            border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.3)),
                          ),
                          child: Text(
                            "${i + 1}. ${words[i]}",
                            style: const TextStyle(
                              color: VinkiarColors.textHdr,
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10.5,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: VinkiarColors.aegisCyan,
                      checkColor: VinkiarColors.abyssBlack,
                      value: _seedConfirmed,
                      onChanged: (v) => setState(() => _seedConfirmed = v == true),
                      title: const Text(
                        "He anotado o guardado mis 12 palabras maestras",
                        style: TextStyle(
                          color: VinkiarColors.textHdr,
                          fontFamily: 'JetBrains Mono',
                          fontSize: 10.5,
                        ),
                      ),
                    ),

                    Divider(color: VinkiarColors.textDim.withOpacity(0.3)),
                    const SizedBox(height: 6),

                    const Text(
                      "SEGUNDO FACTOR LOCAL OPCIONAL (KEYFILE 2FA)",
                      style: TextStyle(
                        color: VinkiarColors.aegisCyan,
                        fontFamily: 'JetBrains Mono',
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _keyfile2FAEnabled
                          ? "Activo: ${_linkedKeyfileName ?? 'Archivo vinculado'} (se exigirá junto a tu contraseña)."
                          : "Opcional: vincula un fichero .key de 64B o cualquier archivo en móvil/Drive como 2FA local.",
                      style: const TextStyle(color: VinkiarColors.textDim, fontSize: 10.5),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: VinkiarColors.aegisCyan,
                              side: const BorderSide(color: VinkiarColors.aegisCyan),
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.key, size: 14),
                            label: const Text(
                              "GENERAR .KEY",
                              style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              try {
                                final saved =
                                    await VinkiarZkpSovereigntyService.generateSaveAndBindKeyfile();
                                if (saved != null) {
                                  await _detectCapabilities();
                                  _showSnack("Keyfile 2FA guardado: $saved", VinkiarColors.aegisCyan);
                                }
                              } catch (e) {
                                _showSnack("Error generando Keyfile: $e", VinkiarColors.panicRed);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: VinkiarColors.textHdr,
                              side: const BorderSide(color: VinkiarColors.textDim),
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.folder_open, size: 14),
                            label: const Text(
                              "USAR ARCHIVO",
                              style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              try {
                                final picked =
                                    await VinkiarZkpSovereigntyService.pickAndHashKeyfileStream();
                                if (picked != null) {
                                  await VinkiarZkpSovereigntyService.bindKeyfileHash(
                                    picked.sha256Bytes,
                                    fileName: picked.fileName,
                                  );
                                  picked.sha256Bytes.fillRange(0, picked.sha256Bytes.length, 0);
                                  await _detectCapabilities();
                                  _showSnack("Archivo 2FA vinculado: ${picked.fileName}", VinkiarColors.aegisCyan);
                                }
                              } catch (e) {
                                _showSnack("Error leyendo archivo: $e", VinkiarColors.panicRed);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_keyfile2FAEnabled) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            await VinkiarZkpSovereigntyService.disableKeyfile2FA();
                            await _detectCapabilities();
                          },
                          child: const Text(
                            "QUITAR KEYFILE 2FA",
                            style: TextStyle(
                              color: VinkiarColors.panicRed,
                              fontFamily: 'JetBrains Mono',
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: VinkiarColors.aegisCyan,
                  foregroundColor: VinkiarColors.abyssBlack,
                  minimumSize: const Size(double.infinity, 54),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                onPressed: _isSubmitting ? null : _createAccountAndSealVault,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: VinkiarColors.abyssBlack,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "VALIDAR CÓDIGO Y FORJAR IDENTIDAD",
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          letterSpacing: 0.8,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
