import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/vinkiar_secure_database.dart';
import '../../services/vinkiar_zkp_sovereignty_service.dart';
import '../theme.dart';

/// Botón con icono de llave para gestionar métodos de acceso, Keyfile 2FA y Semilla BIP-39 desde La Bóveda
class ZkpSovereignVaultKeyButton extends StatefulWidget {
  const ZkpSovereignVaultKeyButton({Key? key}) : super(key: key);

  @override
  State<ZkpSovereignVaultKeyButton> createState() => _ZkpSovereignVaultKeyButtonState();
}

class _ZkpSovereignVaultKeyButtonState extends State<ZkpSovereignVaultKeyButton> {
  bool _hasKeyfile = false;

  @override
  void initState() {
    super.initState();
    _refreshBadge();
  }

  Future<void> _refreshBadge() async {
    final enabled = await VinkiarZkpSovereigntyService.isKeyfile2FAEnabled();
    if (mounted) setState(() => _hasKeyfile = enabled);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: const EdgeInsets.all(4),
          tooltip: _hasKeyfile
              ? "Llaves Soberanas (2FA Keyfile Activo)"
              : "Llaves Soberanas, 2FA y Semilla BIP-39",
          icon: const Icon(
            Icons.vpn_key_outlined,
            color: VinkiarColors.vertigoGold,
            size: 20,
          ),
          onPressed: () async {
            await ZkpSovereignSecuritySheet.show(context);
            await _refreshBadge();
          },
        ),
        if (_hasKeyfile)
          Positioned(
            right: 5,
            top: 5,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: VinkiarColors.aegisCyan,
                shape: BoxShape.circle,
                border: Border.all(color: VinkiarColors.abyssBlack, width: 1.2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Modal interno de La Bóveda para gestionar Método de Acceso, Keyfile 2FA y Semilla BIP-39
class ZkpSovereignSecuritySheet extends StatefulWidget {
  const ZkpSovereignSecuritySheet({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VinkiarColors.panelDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
        side: BorderSide(color: VinkiarColors.vertigoGold, width: 1),
      ),
      builder: (_) => const ZkpSovereignSecuritySheet(),
    );
  }

  @override
  State<ZkpSovereignSecuritySheet> createState() => _ZkpSovereignSecuritySheetState();
}

class _ZkpSovereignSecuritySheetState extends State<ZkpSovereignSecuritySheet> {
  late String _mnemonic;
  ZkpLoginMethod _selectedMethod = ZkpLoginMethod.biometric2FA;
  bool _biometricAvailable = false;
  bool _devicePinAvailable = false;
  bool _keyfileEnabled = false;
  String? _keyfileName;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _mnemonic = VinkiarZkpSovereigntyService.generateMnemonic12Words();
    _loadState();
  }

  Future<void> _loadState() async {
    final caps = await VinkiarZkpSovereigntyService.checkDeviceCapabilities();
    final method = await VinkiarZkpSovereigntyService.getPreferredLoginMethod();
    final kfEnabled = await VinkiarZkpSovereigntyService.isKeyfile2FAEnabled();
    final kfName = await VinkiarZkpSovereigntyService.getLinkedKeyfileName();

    if (!mounted) return;
    setState(() {
      _biometricAvailable = caps['biometricStrongAvailable'] == true;
      _devicePinAvailable = caps['deviceCredentialAvailable'] == true;
      _selectedMethod = method;
      _keyfileEnabled = kfEnabled;
      _keyfileName = kfName;
    });
  }

  void _notify(String msg, Color color) {
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

  /// Solicita la Llave Maestra actual para recifrar SQLCipher + Keystore al activar o desconectar Keyfile 2FA
  Future<String?> _promptMasterPasswordForRekey({
    required String title,
    required String subtitle,
  }) async {
    final controller = TextEditingController();
    bool obscure = true;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: VinkiarColors.abyssBlack,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide(color: VinkiarColors.vertigoGold, width: 1.2),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  color: VinkiarColors.vertigoGold,
                  fontFamily: 'JetBrains Mono',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: const TextStyle(color: VinkiarColors.textDim, fontSize: 11.5, height: 1.4),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    autofocus: true,
                    style: const TextStyle(
                      color: VinkiarColors.textHdr,
                      fontFamily: 'JetBrains Mono',
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      labelText: "LLAVE MAESTRA ACTUAL",
                      labelStyle: const TextStyle(
                        color: VinkiarColors.aegisCyan,
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10.5,
                      ),
                      filled: true,
                      fillColor: VinkiarColors.panelDark,
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: VinkiarColors.textDim,
                          size: 18,
                        ),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: VinkiarColors.aegisCyan),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: VinkiarColors.aegisCyan, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, null),
                  child: const Text(
                    "CANCELAR",
                    style: TextStyle(color: VinkiarColors.textDim, fontFamily: 'JetBrains Mono', fontSize: 11),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VinkiarColors.aegisCyan,
                    foregroundColor: VinkiarColors.abyssBlack,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  onPressed: () {
                    final val = controller.text.trim();
                    if (val.isNotEmpty) {
                      Navigator.pop(dialogCtx, val);
                    }
                  },
                  child: const Text(
                    "CONFIRMAR",
                    style: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<void> _handleBindKeyfile({required bool generateNew}) async {
    final masterKey = await _promptMasterPasswordForRekey(
      title: "VINCULAR KEYFILE 2FA",
      subtitle: "Introduce tu Llave Maestra para recifrar la Bóveda combinándola con tu nuevo segundo factor.",
    );
    if (masterKey == null || masterKey.isEmpty) return;

    setState(() => _isBusy = true);
    try {
      String? boundName;
      Uint8List fileDigest = Uint8List(0);

      if (generateNew) {
        final keyBytes = VinkiarZkpSovereigntyService.generateSovereignKeyfileBytes();
        fileDigest = await VinkiarZkpSovereigntyService.computeSha256OfBytes(keyBytes);
        final saved = await VinkiarZkpSovereigntyService.saveKeyfileBytesViaSaf(
          keyBytes: keyBytes,
          fileName: 'vinkiar_sovereign.key',
        );
        keyBytes.fillRange(0, keyBytes.length, 0);
        if (saved == null) {
          fileDigest.fillRange(0, fileDigest.length, 0);
          setState(() => _isBusy = false);
          return;
        }
        boundName = saved;
      } else {
        final picked = await VinkiarZkpSovereigntyService.pickAndHashKeyfileStream();
        if (picked == null) {
          setState(() => _isBusy = false);
          return;
        }
        fileDigest = picked.sha256Bytes;
        boundName = picked.fileName;
      }

      final rawPwdBytes = VinkiarZkpSovereigntyService.encodeSecretTextToBytes(masterKey);
      final derived = VinkiarZkpSovereigntyService.deriveSessionKeys(
        rawSecretText: masterKey,
        vaultMasterKey: rawPwdBytes,
        keyfileSha256: fileDigest,
      );
      rawPwdBytes.fillRange(0, rawPwdBytes.length, 0);

      // Recifrar SQLCipher con la nueva clave combinada (Llave Maestra + Keyfile)
      await VinkiarSecureDatabase().rekeyVault(newMasterPassword: derived.sqlCipherHexKey);

      // Re-sellar Android Keystore si hay soporte de PIN del dispositivo
      if (_devicePinAvailable) {
        final sealBytes = VinkiarZkpSovereigntyService.encodeSecretTextToBytes(derived.sqlCipherHexKey);
        try {
          await VinkiarZkpSovereigntyService.sealVaultWithDevicePin(
            vaultSecretBytes: sealBytes,
            pinOnly: true,
          );
        } catch (_) {
        } finally {
          sealBytes.fillRange(0, sealBytes.length, 0);
        }
      }

      await VinkiarZkpSovereigntyService.bindKeyfileHash(fileDigest, fileName: boundName);
      fileDigest.fillRange(0, fileDigest.length, 0);

      await _loadState();
      _notify("Keyfile 2FA vinculado y Bóveda recifrada: $boundName", VinkiarColors.aegisCyan);
    } catch (e) {
      _notify("Error vinculando Keyfile: $e", VinkiarColors.panicRed);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handleUnlinkKeyfile() async {
    final masterKey = await _promptMasterPasswordForRekey(
      title: "DESCONECTAR KEYFILE 2FA",
      subtitle: "Introduce tu Llave Maestra para recifrar la Bóveda sin el segundo factor y volver a abrirla solo con tus credenciales.",
    );
    if (masterKey == null || masterKey.isEmpty) return;

    setState(() => _isBusy = true);
    try {
      // Recifrar SQLCipher usando únicamente la Llave Maestra
      await VinkiarSecureDatabase().rekeyVault(newMasterPassword: masterKey);

      // Re-sellar Android Keystore con la Llave Maestra sin Keyfile
      if (_devicePinAvailable) {
        final sealBytes = VinkiarZkpSovereigntyService.encodeSecretTextToBytes(masterKey);
        try {
          await VinkiarZkpSovereigntyService.sealVaultWithDevicePin(
            vaultSecretBytes: sealBytes,
            pinOnly: true,
          );
        } catch (_) {
        } finally {
          sealBytes.fillRange(0, sealBytes.length, 0);
        }
      }

      await VinkiarZkpSovereigntyService.disableKeyfile2FA();
      await _loadState();
      _notify("Keyfile 2FA desconectado. Ya puedes entrar sin el archivo.", VinkiarColors.vertigoGold);
    } catch (e) {
      _notify("Error al desconectar Keyfile: $e", VinkiarColors.panicRed);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = _mnemonic.split(' ');
    final List<ZkpLoginMethod> methods = [
      if (_biometricAvailable) ZkpLoginMethod.biometric2FA,
      if (_devicePinAvailable) ZkpLoginMethod.devicePin,
      ZkpLoginMethod.mnemonic12,
      ZkpLoginMethod.passwordOnly,
    ];

    final ZkpLoginMethod effectiveValue =
        methods.contains(_selectedMethod) ? _selectedMethod : methods.first;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.vpn_key_outlined, color: VinkiarColors.vertigoGold, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "LLAVES SOBERANAS Y 2FA",
                      style: TextStyle(
                        color: VinkiarColors.vertigoGold,
                        fontFamily: 'JetBrains Mono',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: VinkiarColors.textDim, size: 20),
                  onPressed: _isBusy ? null : () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(color: VinkiarColors.textDim.withOpacity(0.35)),
            if (_isBusy) ...[
              const LinearProgressIndicator(
                color: VinkiarColors.aegisCyan,
                backgroundColor: VinkiarColors.abyssBlack,
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),

            // 1. SELECTOR DE MÉTODO DE ACCESO POR DEFECTO
            const Text(
              "1. MÉTODO DE APERTURA POR DEFECTO",
              style: TextStyle(
                color: VinkiarColors.aegisCyan,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<ZkpLoginMethod>(
              value: effectiveValue,
              dropdownColor: VinkiarColors.abyssBlack,
              iconEnabledColor: VinkiarColors.aegisCyan,
              style: const TextStyle(
                color: VinkiarColors.textHdr,
                fontFamily: 'JetBrains Mono',
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: VinkiarColors.abyssBlack,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: VinkiarColors.aegisCyan.withOpacity(0.6)),
                ),
              ),
              items: methods.map((m) {
                return DropdownMenuItem<ZkpLoginMethod>(
                  value: m,
                  child: Text(m.label),
                );
              }).toList(),
              onChanged: _isBusy
                  ? null
                  : (val) async {
                      if (val == null) return;
                      await VinkiarZkpSovereigntyService.setPreferredLoginMethod(val);
                      setState(() => _selectedMethod = val);
                      _notify("Método de acceso actualizado: ${val.label}", VinkiarColors.aegisCyan);
                    },
            ),

            const SizedBox(height: 18),
            Divider(color: VinkiarColors.textDim.withOpacity(0.35)),
            const SizedBox(height: 10),

            // 2. SEGUNDO FACTOR LOCAL (KEYFILE 2FA)
            const Text(
              "2. SEGUNDO FACTOR LOCAL (KEYFILE 2FA)",
              style: TextStyle(
                color: VinkiarColors.aegisCyan,
                fontFamily: 'JetBrains Mono',
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _keyfileEnabled
                  ? "Estado: ACTIVO (${_keyfileName ?? 'Archivo vinculado'})."
                  : "Estado: DESACTIVADO. Vincula un fichero .key o cualquier archivo en móvil/Drive.",
              style: const TextStyle(color: VinkiarColors.textDim, fontSize: 11),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VinkiarColors.aegisCyan,
                      side: const BorderSide(color: VinkiarColors.aegisCyan),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(Icons.key, size: 15),
                    label: const Text(
                      "GENERAR .KEY",
                      style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isBusy ? null : () => _handleBindKeyfile(generateNew: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VinkiarColors.textHdr,
                      side: const BorderSide(color: VinkiarColors.textDim),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(Icons.folder_open, size: 15),
                    label: const Text(
                      "ELEGIR ARCHIVO",
                      style: TextStyle(fontFamily: 'JetBrains Mono', fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _isBusy ? null : () => _handleBindKeyfile(generateNew: false),
                  ),
                ),
              ],
            ),
            if (_keyfileEnabled) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VinkiarColors.panicRed,
                    side: const BorderSide(color: VinkiarColors.panicRed),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.link_off, color: VinkiarColors.panicRed, size: 16),
                  label: const Text(
                    "DESCONECTAR KEYFILE 2FA",
                    style: TextStyle(
                      color: VinkiarColors.panicRed,
                      fontFamily: 'JetBrains Mono',
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                    ),
                  ),
                  onPressed: _isBusy ? null : _handleUnlinkKeyfile,
                ),
              ),
            ],

            const SizedBox(height: 16),
            Divider(color: VinkiarColors.textDim.withOpacity(0.35)),
            const SizedBox(height: 10),

            // 3. GENERADOR / RESPALDO DE SEMILLA BIP-39 (12 PALABRAS)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "3. SEMILLA MAESTRA BIP-39 (12 PALABRAS)",
                  style: TextStyle(
                    color: VinkiarColors.aegisCyan,
                    fontFamily: 'JetBrains Mono',
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _mnemonic = VinkiarZkpSovereigntyService.generateMnemonic12Words();
                    });
                  },
                  child: const Text(
                    "NUEVA",
                    style: TextStyle(
                      color: VinkiarColors.vertigoGold,
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: VinkiarColors.abyssBlack,
                border: Border.all(color: VinkiarColors.textDim.withOpacity(0.35)),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(words.length, (i) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: VinkiarColors.panelDark,
                      border: Border.all(color: VinkiarColors.aegisCyan.withOpacity(0.35)),
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
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: VinkiarColors.vertigoGold,
                  foregroundColor: VinkiarColors.abyssBlack,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                icon: const Icon(Icons.copy, size: 15),
                label: const Text(
                  "COPIAR 12 PALABRAS AL PORTAPAPELES",
                  style: TextStyle(fontFamily: 'JetBrains Mono', fontWeight: FontWeight.bold, fontSize: 11),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _mnemonic));
                  _notify("Semilla de 12 palabras copiada.", VinkiarColors.aegisCyan);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
