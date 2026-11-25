import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../main.dart';

enum ZkpLoginMethod {
  biometric2FA,
  devicePin,
  mnemonic12,
  passwordOnly,
}

extension ZkpLoginMethodX on ZkpLoginMethod {
  String get storageValue {
    switch (this) {
      case ZkpLoginMethod.biometric2FA:
        return 'BIOMETRIC_2FA';
      case ZkpLoginMethod.devicePin:
        return 'DEVICE_PIN';
      case ZkpLoginMethod.mnemonic12:
        return 'MNEMONIC_12';
      case ZkpLoginMethod.passwordOnly:
        return 'PASSWORD_ONLY';
    }
  }

  String get label {
    switch (this) {
      case ZkpLoginMethod.biometric2FA:
        return 'Contraseña + Huella Biométrica (2FA)';
      case ZkpLoginMethod.devicePin:
        return 'PIN del Dispositivo (Sin Biometría)';
      case ZkpLoginMethod.mnemonic12:
        return 'Semilla Maestra (12 Palabras BIP-39)';
      case ZkpLoginMethod.passwordOnly:
        return 'Solo Llave Maestra';
    }
  }

  static ZkpLoginMethod fromStorage(String? raw) {
    switch (raw) {
      case 'DEVICE_PIN':
      case 'DEVICE_PIN_ONLY':
        return ZkpLoginMethod.devicePin;
      case 'MNEMONIC_12':
        return ZkpLoginMethod.mnemonic12;
      case 'PASSWORD_ONLY':
      case 'LOCAL_PASSWORD':
        return ZkpLoginMethod.passwordOnly;
      case 'BIOMETRIC_2FA':
      case 'BIOMETRIC_OR_PIN':
      default:
        return ZkpLoginMethod.biometric2FA;
    }
  }
}

class ZkpDerivedBundle {
  final String rawSecretText;
  final String sqlCipherHexKey;
  final String zkpIdentityPrivHex;
  final String zkpIdentityPubFingerprint;
  final String backupEncryptionHexKey;

  const ZkpDerivedBundle({
    required this.rawSecretText,
    required this.sqlCipherHexKey,
    required this.zkpIdentityPrivHex,
    required this.zkpIdentityPubFingerprint,
    required this.backupEncryptionHexKey,
  });
}

class VinkiarZkpSovereigntyService {
  static const MethodChannel _channel = MethodChannel('com.vinkiar.os/zkp_auth');
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _kWrappedIv = 'vnk_zkp_hw_iv_v1';
  static const String _kWrappedCipher = 'vnk_zkp_hw_cipher_v1';
  static const String _kAuthMode = 'vnk_zkp_auth_mode_v1';
  static const String _kStoredAlias = 'vnk_zkp_avatar_alias_v1';
  static const String _kKeyfileEnabled = 'vnk_zkp_keyfile_enabled_v1';
  static const String _kKeyfileVerifier = 'vnk_zkp_keyfile_verifier_v1';
  static const String _kKeyfileLabel = 'vnk_zkp_keyfile_label_v1';

  // =========================================================================
  // SECCIÓN 1: CAPACIDADES DEL DISPOSITIVO Y PREFERENCIAS DE ACCESO
  // =========================================================================
  static Future<Map<String, bool>> checkDeviceCapabilities() async {
    bool devicePin = false;
    bool bioStrong = false;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('checkCredentialCapabilities');
      devicePin = res?['deviceCredentialAvailable'] == true;
      bioStrong = res?['biometricStrongAvailable'] == true;
    } catch (_) {}

    if (!bioStrong) {
      try {
        final localAuth = LocalAuthentication();
        bioStrong = await localAuth.canCheckBiometrics;
      } catch (_) {}
    }

    return {
      'deviceCredentialAvailable': devicePin,
      'biometricStrongAvailable': bioStrong,
    };
  }

  static Future<bool> hasHardwareSealedVault() async {
    final iv = await _storage.read(key: _kWrappedIv);
    final cipher = await _storage.read(key: _kWrappedCipher);
    return iv != null && iv.isNotEmpty && cipher != null && cipher.isNotEmpty;
  }

  static Future<ZkpLoginMethod> getPreferredLoginMethod() async {
    final stored = await _storage.read(key: _kAuthMode);
    if (stored != null && stored.isNotEmpty) {
      return ZkpLoginMethodX.fromStorage(stored);
    }
    final caps = await checkDeviceCapabilities();
    if (caps['biometricStrongAvailable'] == true) {
      return ZkpLoginMethod.biometric2FA;
    }
    if (caps['deviceCredentialAvailable'] == true) {
      return ZkpLoginMethod.devicePin;
    }
    return ZkpLoginMethod.passwordOnly;
  }

  static Future<void> setPreferredLoginMethod(ZkpLoginMethod method) async {
    await _storage.write(key: _kAuthMode, value: method.storageValue);
  }

  static Future<void> saveAvatarAlias(String alias) async {
    final clean = alias.trim();
    if (clean.isNotEmpty) {
      await _storage.write(key: _kStoredAlias, value: clean);
    }
  }

  static Future<String?> getSavedAvatarAlias() async {
    return await _storage.read(key: _kStoredAlias);
  }

  static Future<bool> isKeyfile2FAEnabled() async {
    return (await _storage.read(key: _kKeyfileEnabled)) == 'true';
  }

  static Future<String?> getLinkedKeyfileName() async {
    return await _storage.read(key: _kKeyfileLabel);
  }

  // =========================================================================
  // SECCIÓN 2: SEMILLA MAESTRA BIP-39 (12 PALABRAS) Y DERIVACIÓN DETERMINISTA
  // =========================================================================
  static String generateMnemonic12Words() {
    return bip39.generateMnemonic(strength: 128);
  }

  static bool validateMnemonic(String mnemonic) {
    final normalized = mnemonic.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return bip39.validateMnemonic(normalized);
  }

  static Uint8List deriveVaultMasterKeyFromMnemonic(String mnemonic, {String passphrase = ''}) {
    final normalized = mnemonic.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (!bip39.validateMnemonic(normalized)) {
      throw ArgumentError('La frase semilla de 12 palabras no es válida.');
    }
    final seedBytes = bip39.mnemonicToSeed(normalized, passphrase: passphrase);
    return hkdfSha256(
      ikm: seedBytes,
      salt: utf8.encode('VINKIAR_ZKP_ROOT_SALT_2026'),
      info: utf8.encode('vinkiar-vault-master-key-v1'),
      length: 32,
    );
  }

  static Uint8List encodeSecretTextToBytes(String secretText) {
    return Uint8List.fromList(utf8.encode(secretText.trim()));
  }

  // =========================================================================
  // SECCIÓN 3: BIOMETRÍA 2FA Y SELLADO HARDWARE EN ANDROID KEYSTORE
  // =========================================================================
  static Future<bool> authenticateBiometric2FAStep({
    String title = 'Verificación Biométrica (2FA)',
    String subtitle = 'Confirma tu huella dactilar para desbloquear la Bóveda',
  }) async {
    VinkiarApp.isSystemDialogActive = true;
    try {
      try {
        final ok = await _channel.invokeMethod<bool>('authenticateBiometricStep', {
          'title': title,
          'subtitle': subtitle,
        });
        if (ok == true) return true;
      } on PlatformException catch (e) {
        if (e.code.startsWith('BIO_ERROR_')) {
          throw StateError(e.message ?? 'Huella biométrica denegada o cancelada.');
        }
      }

      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics;
      if (!canCheck) {
        throw StateError('No hay sensor biométrico configurado en este dispositivo.');
      }
      final valid = await localAuth.authenticate(
        localizedReason: subtitle,
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      if (!valid) {
        throw StateError('Autenticación biométrica cancelada.');
      }
      return true;
    } finally {
      VinkiarApp.isSystemDialogActive = false;
    }
  }

  static Future<void> sealVaultWithDevicePin({
    required Uint8List vaultSecretBytes,
    bool pinOnly = true,
  }) async {
    final secretB64 = base64Encode(vaultSecretBytes);
    VinkiarApp.isSystemDialogActive = true;
    try {
      final wrapped = await _channel.invokeMapMethod<String, dynamic>(
        'wrapVaultKeyWithDeviceCredential',
        {
          'secretB64': secretB64,
          'pinOnly': pinOnly,
        },
      );
      if (wrapped == null || wrapped['ivB64'] == null || wrapped['cipherB64'] == null) {
        throw StateError('No se recibió respuesta del Android Keystore.');
      }
      await _storage.write(key: _kWrappedIv, value: wrapped['ivB64'] as String);
      await _storage.write(key: _kWrappedCipher, value: wrapped['cipherB64'] as String);
    } finally {
      VinkiarApp.isSystemDialogActive = false;
    }
  }

  static Future<void> clearHardwareVault() async {
    await _storage.delete(key: _kWrappedIv);
    await _storage.delete(key: _kWrappedCipher);
    try {
      await _channel.invokeMethod('deleteHardwareVaultKey');
    } catch (_) {}
  }

  static Future<ZkpDerivedBundle> unlockWithDevicePinOnly() async {
    final ivB64 = await _storage.read(key: _kWrappedIv);
    final cipherB64 = await _storage.read(key: _kWrappedCipher);
    if (ivB64 == null || cipherB64 == null) {
      throw StateError(
        'El acceso por PIN aún no está vinculado en este dispositivo. Entra una vez con tu Contraseña o Semilla para vincularlo.',
      );
    }

    Uint8List? vaultSecretBytes;
    VinkiarApp.isSystemDialogActive = true;
    try {
      final plainB64 = await _channel.invokeMethod<String>(
        'unwrapVaultKeyWithDeviceCredential',
        {
          'ivB64': ivB64,
          'cipherB64': cipherB64,
          'pinOnly': true,
        },
      );
      if (plainB64 == null || plainB64.isEmpty) {
        throw StateError('Desbloqueo con PIN cancelado.');
      }
      vaultSecretBytes = base64Decode(plainB64);
    } finally {
      VinkiarApp.isSystemDialogActive = false;
    }

    Uint8List keyfileDigest = Uint8List(0);
    if (await isKeyfile2FAEnabled()) {
      keyfileDigest = await verifyLinkedKeyfileOrThrow();
    }

    try {
      String decodedSecret;
      try {
        decodedSecret = utf8.decode(vaultSecretBytes);
      } catch (_) {
        decodedSecret = _bytesToHex(vaultSecretBytes);
      }
      return deriveSessionKeys(
        rawSecretText: decodedSecret,
        vaultMasterKey: vaultSecretBytes,
        keyfileSha256: keyfileDigest,
      );
    } finally {
      vaultSecretBytes.fillRange(0, vaultSecretBytes.length, 0);
      if (keyfileDigest.isNotEmpty) {
        keyfileDigest.fillRange(0, keyfileDigest.length, 0);
      }
    }
  }

  // =========================================================================
  // SECCIÓN 4: KEYFILE 2FA POR STREAMING SAF (LOCAL, MICROSD, GOOGLE DRIVE)
  // =========================================================================
  static Uint8List generateSovereignKeyfileBytes() {
    final rng = Random.secure();
    return Uint8List.fromList(List<int>.generate(64, (_) => rng.nextInt(256)));
  }

  static Future<Uint8List> computeSha256OfBytes(Uint8List bytes) async {
    return Uint8List.fromList(sha256.convert(bytes).bytes);
  }

  static Future<String?> saveKeyfileBytesViaSaf({
    required Uint8List keyBytes,
    String fileName = 'vinkiar_sovereign.key',
  }) async {
    VinkiarApp.isSystemDialogActive = true;
    try {
      final Uri? savedUri = await FilePicker.saveFile(
        dialogTitle: 'Guardar Keyfile 2FA (Local, MicroSD o Google Drive)',
        fileName: fileName,
        bytes: keyBytes,
      );
      if (savedUri == null) return null;
      return fileName;
    } finally {
      VinkiarApp.isSystemDialogActive = false;
    }
  }

  static Future<String?> generateSaveAndBindKeyfile({
    String fileName = 'vinkiar_sovereign.key',
  }) async {
    final keyBytes = generateSovereignKeyfileBytes();
    final digestBytes = await computeSha256OfBytes(keyBytes);

    try {
      final savedName = await saveKeyfileBytesViaSaf(
        keyBytes: keyBytes,
        fileName: fileName,
      );
      if (savedName == null) {
        return null;
      }
      await bindKeyfileHash(digestBytes, fileName: savedName);
      return savedName;
    } finally {
      keyBytes.fillRange(0, keyBytes.length, 0);
      digestBytes.fillRange(0, digestBytes.length, 0);
    }
  }

  static Future<({Uint8List sha256Bytes, String fileName})?> pickAndHashKeyfileStream() async {
    VinkiarApp.isSystemDialogActive = true;
    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (files.isEmpty) return null;

      final PlatformFile pickedFile = files.first;
      final String? filePath = pickedFile.path;
      if (filePath == null || filePath.isEmpty) {
        throw StateError('No se pudo obtener la ruta local del archivo seleccionado.');
      }
      final stream = File(filePath).openRead();
      final Digest digest = await sha256.bind(stream).first;

      return (
        sha256Bytes: Uint8List.fromList(digest.bytes),
        fileName: pickedFile.name,
      );
    } finally {
      VinkiarApp.isSystemDialogActive = false;
    }
  }

  static Future<Uint8List> verifyLinkedKeyfileOrThrow() async {
    final expectedVerifier = await _storage.read(key: _kKeyfileVerifier);
    final picked = await pickAndHashKeyfileStream();
    if (picked == null) {
      throw StateError('Debes seleccionar tu Keyfile 2FA para completar el acceso.');
    }
    final actualVerifier = _computeKeyfileVerifier(picked.sha256Bytes);
    if (expectedVerifier != null && expectedVerifier != actualVerifier) {
      picked.sha256Bytes.fillRange(0, picked.sha256Bytes.length, 0);
      throw StateError('El archivo seleccionado no coincide con el Keyfile vinculado (o fue alterado).');
    }
    return picked.sha256Bytes;
  }

  static Future<void> bindKeyfileHash(Uint8List fileSha256, {String fileName = 'Keyfile Vinculado'}) async {
    final verifier = _computeKeyfileVerifier(fileSha256);
    await _storage.write(key: _kKeyfileVerifier, value: verifier);
    await _storage.write(key: _kKeyfileEnabled, value: 'true');
    await _storage.write(key: _kKeyfileLabel, value: fileName);
  }

  static Future<void> disableKeyfile2FA() async {
    await _storage.delete(key: _kKeyfileVerifier);
    await _storage.delete(key: _kKeyfileLabel);
    await _storage.write(key: _kKeyfileEnabled, value: 'false');
  }

  static String _computeKeyfileVerifier(Uint8List fileSha256) {
    final mac = Hmac(sha256, fileSha256).convert(utf8.encode('VNK_KEYFILE_VERIFIER_TAG_V1'));
    return base64Encode(mac.bytes);
  }

  // =========================================================================
  // SECCIÓN 5: DERIVACIÓN HKDF-SHA256 DE CLAVES EN RAM (SQLCIPHER / ZKP / BACKUP)
  // =========================================================================
  static ZkpDerivedBundle deriveSessionKeys({
    required String rawSecretText,
    required Uint8List vaultMasterKey,
    Uint8List? keyfileSha256,
  }) {
    final salt = (keyfileSha256 != null && keyfileSha256.isNotEmpty)
        ? keyfileSha256
        : utf8.encode('VNK_NO_KEYFILE_DEFAULT_SALT_V1');

    final dbKeyBytes = hkdfSha256(
      ikm: vaultMasterKey,
      salt: salt,
      info: utf8.encode('vinkiar-sqlcipher-db-key-v1'),
      length: 32,
    );
    final zkpPrivBytes = hkdfSha256(
      ikm: vaultMasterKey,
      salt: utf8.encode('VNK_ZKP_IDENTITY_SALT_V1'),
      info: utf8.encode('vinkiar-zkp-identity-eddsa-v1'),
      length: 32,
    );
    final backupKeyBytes = hkdfSha256(
      ikm: vaultMasterKey,
      salt: utf8.encode('VNK_BACKUP_CIPHER_SALT_V1'),
      info: utf8.encode('vinkiar-encrypted-backup-aes-v1'),
      length: 32,
    );

    final pubFingerprint = sha256.convert(zkpPrivBytes).toString().substring(0, 16).toUpperCase();

    final bundle = ZkpDerivedBundle(
      rawSecretText: rawSecretText,
      sqlCipherHexKey: _bytesToHex(dbKeyBytes),
      zkpIdentityPrivHex: _bytesToHex(zkpPrivBytes),
      zkpIdentityPubFingerprint: pubFingerprint,
      backupEncryptionHexKey: _bytesToHex(backupKeyBytes),
    );

    dbKeyBytes.fillRange(0, dbKeyBytes.length, 0);
    zkpPrivBytes.fillRange(0, zkpPrivBytes.length, 0);
    backupKeyBytes.fillRange(0, backupKeyBytes.length, 0);
    return bundle;
  }

  static Uint8List hkdfSha256({
    required List<int> ikm,
    required List<int> salt,
    required List<int> info,
    int length = 32,
  }) {
    final effectiveSalt = salt.isEmpty ? Uint8List(32) : salt;
    final prk = Hmac(sha256, effectiveSalt).convert(ikm).bytes;

    final int n = (length / 32).ceil();
    final okm = BytesBuilder();
    List<int> prevT = const [];

    for (int i = 1; i <= n; i++) {
      final input = BytesBuilder()
        ..add(prevT)
        ..add(info)
        ..addByte(i);
      prevT = Hmac(sha256, prk).convert(input.toBytes()).bytes;
      okm.add(prevT);
    }

    return Uint8List.fromList(okm.toBytes().sublist(0, length));
  }

  static String _bytesToHex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
