import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:pointycastle/api.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/key_derivators/argon2.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import 'database/app_database.dart';
import 'vinkiar_psychometrics_engine.dart';
import 'vinkiar_secure_heap.dart';
import 'vinkiar_ssc_manager.dart';

// =========================================================================
// SECCIÓN 1: EXCEPCIONES, SINGLETON Y DERIVACIÓN ARGON2ID + SQLCIPHER
// =========================================================================

class VaultSecurityException implements Exception {
  final String message;
  VaultSecurityException(this.message);
  @override
  String toString() => "VaultSecurityException: $message";
}

class VinkiarSecureDatabase {
  static final VinkiarSecureDatabase _instance = VinkiarSecureDatabase._internal();
  factory VinkiarSecureDatabase() => _instance;

  static final ValueNotifier<int> questChangeNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> avatarChangeNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> contactChangeNotifier = ValueNotifier<int>(0);

  VinkiarSecureDatabase._internal() {
    setupSqlCipher();
  }

  AppDatabase? _driftDb;
  AppDatabase? get db => _driftDb;
  Uint8List? _activeDEK;

  static final Uint8List defaultSalt = Uint8List.fromList('VINKIAR_LOCAL_SALT_2026'.codeUnits);

  static void setupSqlCipher() {
    if (Platform.isAndroid) {
      open.overrideFor(OperatingSystem.android, () {
        return DynamicLibrary.open('libsqlcipher.so');
      });
    }
  }

  /// Sobrescribe y purga las llaves criptográficas activas en memoria RAM
  void clearKeys() {
    if (_activeDEK != null) {
      VinkiarSecureHeap().free(_activeDEK, 32);
      _activeDEK!.fillRange(0, _activeDEK!.length, 0);
      _activeDEK = null;
    }
    print("VINKIAR_SECURITY_ALERT: Llaves purgadas forensemente de la memoria RAM.");
  }

  Uint8List _deriveArgon2Dek(String masterPassword, Uint8List salt) {
    var salt16 = salt.length >= 16 ? salt.sublist(0, 16) : Uint8List(16);
    if (salt.length < 16) salt16.setAll(0, salt);

    final generator = Argon2BytesGenerator();
    generator.init(Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt16,
      version: Argon2Parameters.ARGON2_VERSION_13,
      iterations: 2,
      memoryPowerOf2: 16,
      lanes: 2,
      desiredKeyLength: 32,
    ));

    return generator.process(Uint8List.fromList(utf8.encode(masterPassword)));
  }

  /// Abre la bóveda local cifrada con SQLCipher tras derivar la DEK mediante Argon2id
  Future<void> initializeVault({
    required String masterPassword,
    required String userEmail,
    required Uint8List salt,
    bool skipBiometrics = false,
  }) async {
    if (!skipBiometrics) {
      final LocalAuthentication auth = LocalAuthentication();
      bool canAuthenticate = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canAuthenticate) throw VaultSecurityException("Biometría no disponible.");

      bool isBiometricValid = await auth.authenticate(
        localizedReason: 'Accediendo al búnker criptográfico de tu Hoja de Alma',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );

      if (!isBiometricValid) throw VaultSecurityException("Autenticación biométrica denegada.");
    }

    try {
      if (_driftDb != null) {
        await _driftDb!.close();
        _driftDb = null;
      }

      _activeDEK = _deriveArgon2Dek(masterPassword, salt);
      String dbPath = await getDatabasesPath();
      String path = join(dbPath, 'vinkiar_vault_v4.db');
      String sqlCipherPassword = _activeDEK!.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      final executor = drift.LazyDatabase(() async {
        return NativeDatabase.createInBackground(
          File(path),
          isolateSetup: () {
            if (Platform.isAndroid) {
              open.overrideFor(OperatingSystem.android, () => DynamicLibrary.open('libsqlcipher.so'));
            }
          },
          setup: (db) => db.execute("PRAGMA key = '$sqlCipherPassword';"),
        );
      });

      _driftDb = AppDatabase(executor);
      try {
        await _driftDb!.customSelect('PRAGMA user_version;').get();
      } catch (e) {
        await _driftDb!.close();
        _driftDb = null;
        throw VaultSecurityException("LLAVE MAESTRA INCORRECTA O DENEGADA.");
      }
      if (_activeDEK != null) _activeDEK!.fillRange(0, _activeDEK!.length, 0);
    } catch (e) {
      clearKeys();
      if (e is VaultSecurityException) {
        rethrow;
      }
      throw VaultSecurityException("Error en la verificación de llaves: ${e.toString()}");
    }
  }

  /// Recifra la base de datos SQLCipher abierta con una nueva clave derivada (ej. al vincular o desvincular Keyfile 2FA)
  Future<void> rekeyVault({
    required String newMasterPassword,
    Uint8List? salt,
  }) async {
    if (_driftDb == null) {
      throw VaultSecurityException("La bóveda debe estar abierta para cambiar su cifrado.");
    }
    final effectiveSalt = salt ?? defaultSalt;
    final newDek = _deriveArgon2Dek(newMasterPassword, effectiveSalt);
    final newSqlCipherHex = newDek.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    newDek.fillRange(0, newDek.length, 0);

    try {
      await _driftDb!.customStatement("PRAGMA rekey = '$newSqlCipherHex';");
      await _driftDb!.customSelect('PRAGMA user_version;').get();
    } catch (e) {
      throw VaultSecurityException("No se pudo recifrar la bóveda SQLCipher: $e");
    }
  }

  // =========================================================================
  // SECCIÓN 2: SISTEMA DE PURGA Y MENSAJERÍA LOCAL CIFRADA
  // =========================================================================

  Future<void> saveLocalMessage({
    String? id,
    required String guildId,
    required String senderId,
    String? encryptedBlob,
    String? encryptedBlobB64,
    String? ciphertext,
    String? decryptedContent,
    String? nonce,
    required String timestamp,
  }) async {
    if (_driftDb == null) return;

    final String blob = encryptedBlob ?? encryptedBlobB64 ?? ciphertext ?? '';
    final String messageId = id ?? DateTime.now().microsecondsSinceEpoch.toString();

    await _driftDb!.into(_driftDb!.localMessages).insert(
      LocalMessagesCompanion.insert(
        id: messageId,
        guildId: drift.Value(guildId),
        senderId: drift.Value(senderId),
        encryptedBlob: drift.Value(blob),
        decryptedContent: drift.Value(decryptedContent),
        timestamp: drift.Value(timestamp),
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
  }

  Future<void> burnMessage(String messageId) async {
    if (_driftDb == null) return;
    await (_driftDb!.update(_driftDb!.localMessages)..where((t) => t.id.equals(messageId)))
        .write(const LocalMessagesCompanion(
      encryptedBlob: drift.Value(''),
      decryptedContent: drift.Value('[ 💨 CÁPSULA PURGADA ]'),
    ));
  }

  Future<void> setChatTTL(String guildId, int days) async {
    if (_driftDb == null) return;
    await _driftDb!.into(_driftDb!.sysConfig).insert(
      SysConfigCompanion.insert(
        key: 'ttl_$guildId',
        value: drift.Value(days.toString()),
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
  }


  Future<String?> getConfigValue(String key) async {
    if (_driftDb == null) return null;
    try {
      final query = _driftDb!.select(_driftDb!.sysConfig)..where((t) => t.key.equals(key));
      final result = await query.getSingleOrNull();
      return result?.value;
    } catch (_) {
      return null;
    }
  }

  Future<void> setConfigValue(String key, String value) async {
    if (_driftDb == null) return;
    await _driftDb!.into(_driftDb!.sysConfig).insert(
      SysConfigCompanion.insert(
        key: key,
        value: drift.Value(value),
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
  }

  Future<void> deleteConfigByPrefix(String prefix) async {
    if (_driftDb == null) return;
    await (_driftDb!.delete(_driftDb!.sysConfig)
          ..where((t) => t.key.like('$prefix%')))
        .go();
  }

  Future<int> getChatTTL(String guildId) async {
    if (_driftDb == null) return 30;
    final query = _driftDb!.select(_driftDb!.sysConfig)..where((t) => t.key.equals('ttl_$guildId'));
    final result = await query.getSingleOrNull();
    return int.tryParse(result?.value ?? '30') ?? 30;
  }

  Future<void> purgeOldMessages(String guildId) async {
    if (_driftDb == null) return;
    final int days = await getChatTTL(guildId);
    final cutoff = DateTime.now().subtract(Duration(days: days)).toIso8601String();

    await (_driftDb!.delete(_driftDb!.localMessages)
          ..where((t) => t.guildId.equals(guildId) & t.timestamp.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<void> purgeMessagesOlderThan(String guildId, Duration maxAge) async {
    if (_driftDb == null) return;
    final cutoff = DateTime.now().subtract(maxAge).toIso8601String();
    await (_driftDb!.delete(_driftDb!.localMessages)
          ..where((t) => t.guildId.equals(guildId) & t.timestamp.isSmallerThanValue(cutoff)))
        .go();
  }

  Future<List<Map<String, dynamic>>> getLocalMessages(String guildId) async {
    if (_driftDb == null) return [];
    final query = _driftDb!.select(_driftDb!.localMessages)
      ..where((t) => t.guildId.equals(guildId))
      ..orderBy([(t) => drift.OrderingTerm.asc(t.timestamp)]);

    final results = await query.get();
    return results
        .map((m) => {
              'id': m.id,
              'guild_id': m.guildId,
              'sender_id': m.senderId,
              'encrypted_blob': m.encryptedBlob,
              'decrypted_content': m.decryptedContent,
              'timestamp': m.timestamp,
            })
        .toList();
  }

  Future<void> saveChatMessage(String sender, String message, {Map<String, dynamic>? deltas}) async {
    await saveLocalMessage(
      guildId: 'CHAT_ZKA_ORACLE',
      senderId: sender,
      decryptedContent: message,
      timestamp: DateTime.now().toIso8601String(),
    );
  }

  Future<List<Map<String, dynamic>>> getChatHistory() async {
    return await getLocalMessages('CHAT_ZKA_ORACLE');
  }

  Future<void> deleteLocalMessage(String messageId) async {
    if (_driftDb == null) return;
    await (_driftDb!.delete(_driftDb!.localMessages)..where((t) => t.id.equals(messageId))).go();
  }

  Future<void> clearOracleChatHistory() async {
    if (_driftDb == null) return;
    await (_driftDb!.delete(_driftDb!.localMessages)..where((t) => t.guildId.equals('CHAT_ZKA_ORACLE'))).go();
  }

  // =========================================================================
  // SECCIÓN 3: GESTIÓN DIÁDICA, DOBLE SEMÁFORO SSC Y BARRERAS
  // =========================================================================

  Future<List<Map<String, dynamic>>> getContacts() async {
    if (_driftDb == null) return [];
    try {
      final query = _driftDb!.select(_driftDb!.localContacts)
        ..orderBy([(t) => drift.OrderingTerm.desc(t.lastInteraction)]);
      final results = await query.get();
      return results
          .map((c) => {
                'id': c.id,
                'alias': c.alias,
                'character_class': c.characterClass,
                'relationship_type': c.relationshipType,
                'ssc_level': c.sscLevel,
                'is_active': c.isActive,
                'reputation_score': c.reputationScore,
                'last_interaction': c.lastInteraction,
                'created_at': c.createdAt,
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveContact(Map<String, dynamic> contact) async {
    if (_driftDb == null) return;
    await _driftDb!.into(_driftDb!.localContacts).insert(
      LocalContactsCompanion.insert(
        id: contact['id'],
        alias: contact['alias'],
        characterClass: drift.Value(contact['character_class']),
        relationshipType: drift.Value(contact['relationship_type'] ?? 'FRIEND'),
        sscLevel: drift.Value(contact['ssc_level'] ?? 'GREEN'),
        isActive: drift.Value(contact['is_active'] ?? 1),
        reputationScore: drift.Value((contact['reputation_score'] as num?)?.toDouble() ?? 1.0),
        lastInteraction: drift.Value(contact['last_interaction']),
        createdAt: drift.Value(contact['created_at']),
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
    contactChangeNotifier.value++;
  }

  Future<void> updateContactSSC(String contactId, String sscLevel) async {
    if (_driftDb == null) return;
    await (_driftDb!.update(_driftDb!.localContacts)..where((t) => t.id.equals(contactId)))
        .write(LocalContactsCompanion(
      sscLevel: drift.Value(sscLevel),
      isActive: drift.Value(sscLevel == 'REVOKED' ? 0 : 1),
    ));
    contactChangeNotifier.value++;
  }

  Future<void> saveContactBondSettings({
    required String contactId,
    required String sscGlobalLevel,
    required String relationalTag,
    required String bioDescription,
    required String avatarGlifo,
    required List<String> myGreenLimits,
    required List<String> myYellowLimits,
    required List<String> myRedLimits,
    required List<String> incomingGreenLimits,
    required List<String> incomingYellowLimits,
    required List<String> incomingRedLimits,
    required String privateNotes,
    required int completedQuests,
    required int failedQuests,
    required int sharedXP,
    required int jointVinks,
    required double ifsScore,
    required double icaScore,
  }) async {
    final existing = await getContactBondSettings(contactId);
    final String normalizedOp = (sscGlobalLevel == 'YELLOW')
        ? 'YELLOW'
        : (sscGlobalLevel == 'RED' || sscGlobalLevel == 'BARBECHO' || sscGlobalLevel == 'REVOKED')
            ? 'RED'
            : 'GREEN';

    final merged = <String, dynamic>{
      ...existing,
      'contact_id': contactId,
      'ssc_level': sscGlobalLevel,
      'operational_state': normalizedOp,
      'relational_tag': relationalTag,
      'bio_description': bioDescription,
      'avatar_glifo': avatarGlifo,
      'my_green': myGreenLimits,
      'my_yellow': myYellowLimits,
      'my_red': myRedLimits,
      'incoming_green': incomingGreenLimits,
      'incoming_yellow': incomingYellowLimits,
      'incoming_red': incomingRedLimits,
      'private_notes': privateNotes,
      'completed_quests': completedQuests,
      'failed_quests': failedQuests,
      'shared_xp': sharedXP,
      'joint_vinks': jointVinks,
      'ifs_score': ifsScore,
      'ica_score': icaScore,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (_driftDb != null) {
      await _driftDb!.into(_driftDb!.sysConfig).insert(
        SysConfigCompanion.insert(
          key: 'bond_settings_$contactId',
          value: drift.Value(jsonEncode(merged)),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
      await updateContactSSC(contactId, sscGlobalLevel);
    }
  }

  Future<Map<String, dynamic>> getContactBondSettings(String contactId) async {
    if (_driftDb == null) return {};
    try {
      final query = _driftDb!.select(_driftDb!.sysConfig)
        ..where((t) => t.key.equals('bond_settings_$contactId'));
      final result = await query.getSingleOrNull();
      if (result != null && result.value != null) {
        return jsonDecode(result.value!);
      }
    } catch (_) {}
    return {};
  }

  Future<DyadicSscProfile> getDyadicSscProfile(String contactId) async {
    final cleanId = contactId.trim();
    final existing = await getContactBondSettings(cleanId);

    if (existing.isEmpty) {
      final initial = VinkiarSSCManager.createDefaultProfile(cleanId);
      await saveDyadicSscProfile(initial);
      return initial;
    }

    if (existing['my_limits'] is List) {
      return DyadicSscProfile.fromJson(cleanId, existing);
    }

    final migratedMy = <SscLimitItem>[];
    int idx = 0;
    for (final g in (existing['my_green'] as List<dynamic>? ?? [])) {
      migratedMy.add(SscLimitItem(
        id: 'mig_g_${idx++}',
        label: g.toString(),
        tier: SscLimitTier.green,
        isVisible: true,
      ));
    }
    for (final y in (existing['my_yellow'] as List<dynamic>? ?? [])) {
      migratedMy.add(SscLimitItem(
        id: 'mig_y_${idx++}',
        label: y.toString(),
        tier: SscLimitTier.yellow,
        isVisible: false,
      ));
    }
    for (final r in (existing['my_red'] as List<dynamic>? ?? [])) {
      migratedMy.add(SscLimitItem(
        id: 'mig_r_${idx++}',
        label: r.toString(),
        tier: SscLimitTier.red,
        isVisible: false,
      ));
    }

    final migratedIncoming = <SscLimitItem>[];
    for (final g in (existing['incoming_green'] as List<dynamic>? ?? [])) {
      migratedIncoming.add(SscLimitItem(id: 'in_g_${idx++}', label: g.toString(), tier: SscLimitTier.green, isVisible: true));
    }
    for (final y in (existing['incoming_yellow'] as List<dynamic>? ?? [])) {
      migratedIncoming.add(SscLimitItem(id: 'in_y_${idx++}', label: y.toString(), tier: SscLimitTier.yellow, isVisible: true));
    }
    for (final r in (existing['incoming_red'] as List<dynamic>? ?? [])) {
      migratedIncoming.add(SscLimitItem(id: 'in_r_${idx++}', label: r.toString(), tier: SscLimitTier.red, isVisible: true));
    }

    final base = DyadicSscProfile.fromJson(cleanId, existing).copyWith(
      myLimits: migratedMy.isNotEmpty
          ? migratedMy
          : VinkiarSSCManager.createDefaultProfile(cleanId).myLimits,
      incomingLimits: migratedIncoming,
    );
    await saveDyadicSscProfile(base);
    return base;
  }

  Future<void> saveDyadicSscProfile(DyadicSscProfile profile) async {
    if (_driftDb == null) return;
    final cleanId = profile.contactId.trim();
    final existing = await getContactBondSettings(cleanId);

    final opLevel = profile.operationalState.name.toUpperCase();
    final merged = <String, dynamic>{
      ...existing,
      ...profile.toJson(),
      'ssc_level': opLevel,
      'my_green': profile.myLimits.where((e) => e.tier == SscLimitTier.green).map((e) => e.label).toList(),
      'my_yellow': profile.myLimits.where((e) => e.tier == SscLimitTier.yellow).map((e) => e.label).toList(),
      'my_red': profile.myLimits.where((e) => e.tier == SscLimitTier.red).map((e) => e.label).toList(),
      'incoming_green': profile.incomingLimits.where((e) => e.tier == SscLimitTier.green).map((e) => e.label).toList(),
      'incoming_yellow': profile.incomingLimits.where((e) => e.tier == SscLimitTier.yellow).map((e) => e.label).toList(),
      'incoming_red': profile.incomingLimits.where((e) => e.tier == SscLimitTier.red).map((e) => e.label).toList(),
    };

    await _driftDb!.into(_driftDb!.sysConfig).insert(
      SysConfigCompanion.insert(
        key: 'bond_settings_$cleanId',
        value: drift.Value(jsonEncode(merged)),
      ),
      mode: drift.InsertMode.insertOrReplace,
    );

    await updateContactSSC(cleanId, opLevel);
  }

  Future<void> applyIncomingSscDisclosure({
    required String senderHandleOrId,
    required Map<String, dynamic> disclosurePacket,
  }) async {
    final cleanSender = senderHandleOrId.replaceAll('#', '').trim().toLowerCase();
    if (cleanSender.isEmpty) return;

    final contacts = await getContacts();
    final matched = contacts.firstWhere(
      (c) {
        final idNorm = (c['id'] ?? '').toString().replaceAll('#', '').trim().toLowerCase();
        final aliasNorm = (c['alias'] ?? '').toString().replaceAll('#', '').replaceAll(' ', '_').trim().toLowerCase();
        return idNorm == cleanSender || aliasNorm == cleanSender;
      },
      orElse: () => {'id': senderHandleOrId.trim()},
    );

    final targetContactId = matched['id'].toString();
    final current = await getDyadicSscProfile(targetContactId);

    final rawList = (disclosurePacket['disclosed_limits'] as List<dynamic>? ?? []);
    final parsedIncoming = rawList.map((e) {
      final itemMap = Map<String, dynamic>.from(e);
      itemMap['is_visible'] = true;
      return SscLimitItem.fromJson(itemMap);
    }).toList();

    final updated = current.copyWith(
      incomingLimits: parsedIncoming,
      updatedAt: DateTime.now(),
    );
    await saveDyadicSscProfile(updated);
  }

  // =========================================================================
  // SECCIÓN 4: GESTIÓN DE MISIONES, AVATAR Y VECTOR ENEAGRAMA
  // =========================================================================

  Future<void> saveQuest(Map<String, dynamic> questData) async {
    if (_driftDb == null) return;
    final String questId = questData['id'] ?? 'QUEST_${DateTime.now().millisecondsSinceEpoch}';
    await _driftDb!.into(_driftDb!.localQuests).insert(
      LocalQuestsCompanion.insert(
        id: questId,
        title: drift.Value(questData['title'] ?? 'Sin Título'),
        description: drift.Value(questData['description'] ?? ''),
        sourceType: drift.Value(questData['source_type'] ?? 'P2P'),
        rewardVinks: drift.Value(questData['reward_vinks'] ?? 20),
        xpReward: drift.Value(questData['xp_reward'] ?? 100),
        status: drift.Value(questData['status'] ?? 'AVAILABLE'),
        minLevel: drift.Value(questData['min_level'] ?? 1),
        requiredQuestId: drift.Value(questData['required_quest_id']),
        createdAt: drift.Value(questData['created_at'] ?? DateTime.now().toIso8601String()),
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
    questChangeNotifier.value++;
  }

  Future<List<Map<String, dynamic>>> getQuests({String? sourceType, String? status}) async {
    if (_driftDb == null) return [];
    final query = _driftDb!.select(_driftDb!.localQuests);
    if (sourceType != null) query.where((t) => t.sourceType.equals(sourceType));
    if (status != null) query.where((t) => t.status.equals(status));
    query.orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]);
    final results = await query.get();
    return results
        .map((q) => {
              'id': q.id,
              'title': q.title,
              'description': q.description,
              'source_type': q.sourceType,
              'reward_vinks': q.rewardVinks,
              'xp_reward': q.xpReward,
              'status': q.status,
              'min_level': q.minLevel,
              'required_quest_id': q.requiredQuestId,
              'created_at': q.createdAt,
            })
        .toList();
  }

  Future<void> updateQuestStatus(String questId, String newStatus) async {
    if (_driftDb == null) return;

    await (_driftDb!.update(_driftDb!.localQuests)..where((t) => t.id.equals(questId)))
        .write(LocalQuestsCompanion(status: drift.Value(newStatus)));

    if (newStatus == 'COMPLETED') {
      final dependentQuery = _driftDb!.select(_driftDb!.localQuests)
        ..where((t) => t.requiredQuestId.equals(questId) & t.status.equals('LOCKED'));

      final lockedQuests = await dependentQuery.get();
      for (var chained in lockedQuests) {
        await (_driftDb!.update(_driftDb!.localQuests)..where((t) => t.id.equals(chained.id)))
            .write(const LocalQuestsCompanion(status: drift.Value('AVAILABLE')));
      }
    }

    questChangeNotifier.value++;
  }

  Future<void> addAvatarRewards(int vinksEarned, int xpEarned) async {
    final avatar = await getAvatarSheet("LOCAL_USER");
    final int currentXp = (avatar?['experience_points'] as int?) ?? 0;
    final stats = Map<String, dynamic>.from(avatar?['stats'] as Map<String, dynamic>? ?? {});
    final int currentVinks = (stats['vinks'] as int?) ?? 150;

    stats['vinks'] = (currentVinks + vinksEarned).clamp(0, 999999);
    await saveAvatarSheet("LOCAL_USER", {
      'character_class': avatar?['character_class'] ?? 'INICIADO',
      'level': 1 + ((currentXp + xpEarned) ~/ 500),
      'experience_points': currentXp + xpEarned,
      'reputation_score': avatar?['reputation_score'] ?? 1.0,
      'stats': stats,
      'active_buffs': avatar?['active_buffs'] ?? [],
      'active_debuffs': avatar?['active_debuffs'] ?? [],
    });
  }

  Future<Map<String, dynamic>?> getAvatarSheet(String userId) async {
    if (_driftDb == null) return null;
    final query = _driftDb!.select(_driftDb!.avatarSheets)..where((t) => t.id.equals(userId));
    final result = await query.getSingleOrNull();
    if (result == null) return null;
    return {
      'id': result.id,
      'character_class': result.characterClass,
      'level': result.level,
      'experience_points': result.experiencePoints,
      'reputation_score': result.reputationScore,
      'stats': result.stats != null ? jsonDecode(result.stats!) : {},
    };
  }

  Future<void> saveAvatarSheet(String userId, Map<String, dynamic> avatarData) async {
    if (_driftDb == null) return;
    await _driftDb!.into(_driftDb!.avatarSheets).insert(
      AvatarSheetsCompanion.insert(
        id: userId,
        characterClass: drift.Value(avatarData['character_class']),
        level: drift.Value(avatarData['level']),
        experiencePoints: drift.Value(avatarData['experience_points']),
        reputationScore: drift.Value((avatarData['reputation_score'] as num?)?.toDouble()),
        stats: drift.Value(jsonEncode(avatarData['stats'])),
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
    avatarChangeNotifier.value++;
  }

  Future<void> saveUserVector(String vector) async {
    if (_driftDb == null) return;
    await _driftDb!.into(_driftDb!.sysConfig).insert(
      SysConfigCompanion.insert(key: 'enneagram_vector', value: drift.Value(vector)),
      mode: drift.InsertMode.insertOrReplace,
    );
  }

  Future<String?> getUserVector() async {
    if (_driftDb == null) return null;
    final query = _driftDb!.select(_driftDb!.sysConfig)..where((t) => t.key.equals('enneagram_vector'));
    final result = await query.getSingleOrNull();
    return result?.value;
  }

  Future<void> saveSoulSheet(String userId, Map<String, dynamic> soulSheetData) async {
    if (_driftDb == null) throw VaultSecurityException("La base de datos está bloqueada.");
    await _driftDb!.into(_driftDb!.soulSheets).insert(
      SoulSheetsCompanion.insert(uuid: userId, aliasSanitizado: const drift.Value('[USER_TARGET]')),
      mode: drift.InsertMode.insertOrReplace,
    );
  }

  Future<Map<String, dynamic>?> getSoulSheet(String userId) async {
    if (_driftDb == null) throw VaultSecurityException("La base de datos está bloqueada.");
    final query = _driftDb!.select(_driftDb!.soulSheets)..where((t) => t.uuid.equals(userId));
    final result = await query.getSingleOrNull();
    if (result == null) return null;
    return {'id': result.uuid};
  }

  Future<void> updateAvatarData(Map<String, dynamic> newData) async {
    final currentData = await getAvatarSheet("LOCAL_USER");
    if (currentData != null) {
      final stats = currentData['stats'] as Map<String, dynamic>? ?? {};
      newData.forEach((key, value) {
        stats[key] = value;
      });
      currentData['stats'] = stats;
      await saveAvatarSheet("LOCAL_USER", currentData);
    } else {
      final defaultData = {
        'character_class': 'INICIADO',
        'level': 1,
        'experience_points': 0,
        'reputation_score': 0,
        'stats': newData,
        'active_buffs': [],
        'active_debuffs': [],
      };
      await saveAvatarSheet("LOCAL_USER", defaultData);
    }
  }

  // =========================================================================
  // SECCIÓN 5: BITÁCORA DEL BÚNKER, GREMIOS, ENERGÍA Y RESPALDOS
  // =========================================================================

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'vinkiar_vault_v4.db');
  }

  Future<List<Map<String, dynamic>>> getActivityFeed() async {
    if (_driftDb == null) return [];
    try {
      final query = _driftDb!.select(_driftDb!.sysConfig)..where((t) => t.key.equals('activity_feed_events'));
      final result = await query.getSingleOrNull();
      if (result != null && result.value != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(result.value!));
      }
    } catch (_) {}
    return [];
  }

  Future<void> logActivityEvent({required String title, required String description, required String type}) async {
    final feed = await getActivityFeed();
    feed.insert(0, {
      "id": "ACT_${DateTime.now().millisecondsSinceEpoch}",
      "title": title,
      "description": description,
      "type": type,
      "timestamp": DateTime.now().toIso8601String(),
    });
    if (feed.length > 50) feed.removeLast();
    if (_driftDb != null) {
      await _driftDb!.into(_driftDb!.sysConfig).insert(
        SysConfigCompanion.insert(key: 'activity_feed_events', value: drift.Value(jsonEncode(feed))),
        mode: drift.InsertMode.insertOrReplace,
      );
    }
  }

  Future<void> saveGuild(Map<String, dynamic> guildData) async {
    final guilds = await getGuilds();
    final String guildId = guildData['guild_id'];
    guilds.removeWhere((g) => g['guild_id'] == guildId);
    guilds.insert(0, guildData);
    if (_driftDb != null) {
      await _driftDb!.into(_driftDb!.sysConfig).insert(
        SysConfigCompanion.insert(key: 'user_guilds_list', value: drift.Value(jsonEncode(guilds))),
        mode: drift.InsertMode.insertOrReplace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getGuilds() async {
    if (_driftDb == null) return [];
    final query = _driftDb!.select(_driftDb!.sysConfig)..where((t) => t.key.equals('user_guilds_list'));
    final result = await query.getSingleOrNull();
    if (result != null && result.value != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(result.value!));
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getGuildMembers(String guildId) async {
    if (_driftDb == null) return [];
    try {
      final query = _driftDb!.select(_driftDb!.sysConfig)..where((t) => t.key.equals('guild_members_$guildId'));
      final result = await query.getSingleOrNull();
      if (result != null && result.value != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(result.value!));
      }
    } catch (_) {}
    return [
      {"id": "USR_MEMBER_01", "alias": "Vektor_Faraday", "archetype": "EL CENTINELA DE FARADAY", "status": "ACTIVE", "joined_at": "2026-10-15"},
      {"id": "USR_MEMBER_02", "alias": "Kaelen_Void", "archetype": "ILUSIONISTA HÁPTICO", "status": "ACTIVE", "joined_at": "2026-10-17"},
    ];
  }

  Future<void> updateGuildMemberStatus({required String guildId, required String memberId, required String newStatus}) async {
    final members = await getGuildMembers(guildId);
    for (var m in members) {
      if (m['id'] == memberId) m['status'] = newStatus;
    }
    if (_driftDb != null) {
      await _driftDb!.into(_driftDb!.sysConfig).insert(
        SysConfigCompanion.insert(key: 'guild_members_$guildId', value: drift.Value(jsonEncode(members))),
        mode: drift.InsertMode.insertOrReplace,
      );
    }
  }

  Future<String> getConformityLevel(String entityId) async {
    if (_driftDb == null) return 'GREEN';
    final query = _driftDb!.select(_driftDb!.sysConfig)..where((t) => t.key.equals('ssc_level_$entityId'));
    final result = await query.getSingleOrNull();
    return result?.value ?? 'GREEN';
  }

  Future<void> setConformityLevel(String entityId, String color) async {
    if (_driftDb == null) return;
    await _driftDb!.into(_driftDb!.sysConfig).insert(
      SysConfigCompanion.insert(key: 'ssc_level_$entityId', value: drift.Value(color.toUpperCase())),
      mode: drift.InsertMode.insertOrReplace,
    );
  }

  Future<int> getEnergyLevel() async {
    if (_driftDb == null) return 100;
    final query = _driftDb!.select(_driftDb!.sysConfig)..where((t) => t.key.equals('energy_level'));
    final result = await query.getSingleOrNull();
    return int.tryParse(result?.value ?? '100') ?? 100;
  }

  Future<void> setEnergyLevel(int energy) async {
    if (_driftDb == null) return;
    await _driftDb!.into(_driftDb!.sysConfig).insert(
      SysConfigCompanion.insert(key: 'energy_level', value: drift.Value(energy.clamp(0, 100).toString())),
      mode: drift.InsertMode.insertOrReplace,
    );
  }

  Future<bool> consumeEnergy(int amount) async {
    final currentEnergy = await getEnergyLevel();
    if (currentEnergy < amount || currentEnergy <= 0) return false;
    await setEnergyLevel(currentEnergy - amount);
    return true;
  }

  Future<void> markAvatarRegistered() async {
    try {
      final dir = await path_provider.getApplicationDocumentsDirectory();
      final marker = File(join(dir.path, 'vinkiar_avatar_registered.lock'));
      await marker.writeAsString('1');
    } catch (_) {}
  }

  Future<bool> hasRegisteredAvatar() async {
    try {
      final dir = await path_provider.getApplicationDocumentsDirectory();
      final marker = File(join(dir.path, 'vinkiar_avatar_registered.lock'));
      if (await marker.exists()) return true;
      final dbPath = await getDatabasesPath();
      final dbFile = File(join(dbPath, 'vinkiar_vault_v4.db'));
      return await dbFile.exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> replaceDatabase(String newDbPath) async {
    if (_driftDb != null) {
      await _driftDb!.close();
      _driftDb = null;
    }
    final targetPath = await getDatabasePath();
    final newFile = File(newDbPath);
    if (await newFile.exists()) {
      await newFile.copy(targetPath);
      await markAvatarRegistered();
      avatarChangeNotifier.value++;
      print(">>> [ZKA VAULT]: Copia de Bóveda restaurada con éxito desde $newDbPath");
    } else {
      throw VaultSecurityException("El archivo de backup especificado no existe.");
    }
  }

  Future<void> purgeCorruptedVault() async {
    if (_driftDb != null) {
      await _driftDb!.close();
      _driftDb = null;
    }
    final path = await getDatabasePath();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<List<Map<String, dynamic>>> getDiaryEntries() async {
    final rawMessages = await getLocalMessages('VAULT_DIARY');
    final List<Map<String, dynamic>> entries = [];
    for (var m in rawMessages.reversed) {
      try {
        final data = jsonDecode(m['decrypted_content'] ?? '{}');
        entries.add({
          'id': m['id'],
          'title': data['title'] ?? 'Sin título',
          'content': data['content'] ?? '',
          'deltas': data['deltas'] ?? {},
          'timestamp': m['timestamp'],
        });
      } catch (_) {}
    }
    return entries;
  }

  Future<Map<String, dynamic>> saveDiaryEntry({required String title, required String content}) async {
    final deltas = analyzeDiaryText("$title $content");
    final entryPayload = jsonEncode({'title': title, 'content': content, 'deltas': deltas});
    await saveLocalMessage(
      guildId: 'VAULT_DIARY',
      senderId: 'LOCAL_USER',
      decryptedContent: entryPayload,
      timestamp: DateTime.now().toIso8601String(),
    );
    await applyDeltaUpdate(deltas);
    avatarChangeNotifier.value++;
    return deltas;
  }

  Future<void> deleteDiaryEntry(String entryId) async {
    await deleteLocalMessage(entryId);
  }

  // =========================================================================
  // SECCIÓN 6: CRIPTOGRAFÍA ZKA, SANITIZACIÓN Y MOTOR DE DELTAS
  // =========================================================================

  Map<String, dynamic> analyzeDiaryText(String rawText) {
    final text = rawText.toLowerCase();
    int deltaEmpathy = 0;
    int deltaWillpower = 0;
    int deltaErotism = 0;
    int deltaSovereignty = 0;
    final Map<String, double> egoDeltas = {};
    final Map<String, double> erosDeltas = {};
    final Map<String, double> philiaDeltas = {};

    if (RegExp(r'(perfección|error|culpa|debo|regla|control|juicio|divo|diva|corregir)').hasMatch(text)) {
      deltaWillpower += 8;
      deltaSovereignty += 6;
      egoDeltas['divo'] = 18.0;
    }
    if (RegExp(r'(ayudar|rescatar|salvar|necesita|cuidar|sacrificio|complacer)').hasMatch(text)) {
      deltaEmpathy += 12;
      egoDeltas['rescatador'] = 20.0;
    }
    if (RegExp(r'(líder|mando|fuerza|poder|dominio|autoridad|firme|exijo)').hasMatch(text)) {
      deltaWillpower += 12;
      deltaSovereignty += 10;
      egoDeltas['lider'] = 20.0;
    }
    if (RegExp(r'(aislamiento|estudio|pensar|mente|análisis|distancia|silencio|intelectual)').hasMatch(text)) {
      deltaSovereignty += 10;
      egoDeltas['intelectual'] = 18.0;
    }
    if (RegExp(r'(piel|tacto|caricia|masaje|lento|sensual|aroma|textura|cuerpo)').hasMatch(text)) {
      deltaErotism += 12;
      erosDeltas['sensual'] = 22.0;
      erosDeltas['sosIndex'] = 1.2;
    }
    if (RegExp(r'(kinky|atadura|cuerda|venda|tabú|sumisión|dominación|shibari|juego de poder)').hasMatch(text)) {
      deltaErotism += 15;
      erosDeltas['kinky'] = 25.0;
      erosDeltas['sosIndex'] = 1.5;
    }
    if (RegExp(r'(miedo a perder|soledad|abandono|inseguridad|angustia|celos|aferrar)').hasMatch(text)) {
      deltaEmpathy += 8;
      philiaDeltas['ocnofilo'] = 20.0;
      philiaDeltas['iAR'] = -0.05;
    }
    if (RegExp(r'(confianza|seguridad|diálogo|asertividad|acuerdo|paz|calma|diferenciación)').hasMatch(text)) {
      deltaEmpathy += 10;
      deltaSovereignty += 10;
      philiaDeltas['seguro'] = 20.0;
      philiaDeltas['iAR'] = 0.08;
    }
    if (deltaEmpathy == 0 && deltaWillpower == 0 && deltaErotism == 0 && deltaSovereignty == 0) {
      deltaSovereignty = 1;
      deltaWillpower = 1;
      egoDeltas['intelectual'] = 2.0;
    }

    return {
      'empathy': deltaEmpathy,
      'willpower': deltaWillpower,
      'erotism': deltaErotism,
      'sovereignty': deltaSovereignty,
      'ego_deltas': egoDeltas,
      'eros_deltas': erosDeltas,
      'philia_deltas': philiaDeltas,
    };
  }

  String encryptZKAPayload(String plaintext, String secretKey) {
    List<int> plainBytes = utf8.encode(plaintext);
    List<int> keyBytes = utf8.encode(secretKey.isEmpty ? "VINKIAR_ZKA_DEFAULT_KEY" : secretKey);
    List<int> encrypted = [];
    for (int i = 0; i < plainBytes.length; i++) {
      encrypted.add(plainBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return base64.encode(encrypted);
  }

  String decryptZKAPayload(String ciphertextBase64, String secretKey) {
    try {
      List<int> encrypted = base64.decode(ciphertextBase64);
      List<int> keyBytes = utf8.encode(secretKey.isEmpty ? "VINKIAR_ZKA_DEFAULT_KEY" : secretKey);
      List<int> decrypted = [];
      for (int i = 0; i < encrypted.length; i++) {
        decrypted.add(encrypted[i] ^ keyBytes[i % keyBytes.length]);
      }
      return utf8.decode(decrypted);
    } catch (e) {
      return "[Error de Descifrado ZKA: Blob opaco inaccesible]";
    }
  }

  Map<String, dynamic> sanitizeLocalInput(String rawText, Map<String, String> localEntityMap) {
    String sanitizedText = rawText;
    localEntityMap.forEach((key, placeholder) {
      sanitizedText = sanitizedText.replaceAll(key, placeholder);
    });
    bool containsAggressiveLanguage = _detectToxicityPatterns(rawText);
    return {
      "sanitized_text": sanitizedText,
      "metadata": {
        "toxicity_flag": containsAggressiveLanguage,
        "length": rawText.length,
        "words_count": rawText.split(" ").length,
      }
    };
  }

  bool _detectToxicityPatterns(String text) {
    final RegExp aggressionRegex =
        RegExp(r'(odio|te desprecio|maldito|eres el peor|siempre lo mismo|nunca haces)', caseSensitive: false);
    return aggressionRegex.hasMatch(text);
  }

  Future<void> applyDeltaUpdate(Map<String, dynamic> deltas) async {
    final avatar = await getAvatarSheet("LOCAL_USER");
    final Map<String, dynamic> baseAvatar = avatar ??
        {
          'character_class': 'INICIADO',
          'level': 1,
          'experience_points': 0,
          'reputation_score': 1.0,
          'stats': {},
          'active_buffs': [],
          'active_debuffs': [],
        };
    final stats = Map<String, dynamic>.from(baseAvatar['stats'] as Map<String, dynamic>? ?? {});

    if (deltas.containsKey('empathy')) {
      stats['empathy'] = ((stats['empathy'] ?? 0) + (deltas['empathy'] as num).toInt()).clamp(0, 100);
    }
    if (deltas.containsKey('willpower')) {
      stats['willpower'] = ((stats['willpower'] ?? 0) + (deltas['willpower'] as num).toInt()).clamp(0, 100);
    }
    if (deltas.containsKey('erotism')) {
      stats['erotism'] = ((stats['erotism'] ?? 0) + (deltas['erotism'] as num).toInt()).clamp(0, 100);
    }
    if (deltas.containsKey('sovereignty')) {
      stats['sovereignty'] = ((stats['sovereignty'] ?? 0) + (deltas['sovereignty'] as num).toInt()).clamp(0, 100);
    }

    if (deltas.containsKey('ego_deltas')) {
      final currentEgo = Map<String, dynamic>.from(stats['ego_vector'] as Map<String, dynamic>? ?? {});
      final egoChanges = Map<String, dynamic>.from(deltas['ego_deltas'] as Map<String, dynamic>);
      egoChanges.forEach((k, v) {
        final double prev = (currentEgo[k] as num?)?.toDouble() ?? 15.0;
        currentEgo[k] = VinkiarPsychometricsEngine.applyInertialDelta(
          currentPct: prev,
          deltaPct: (v as num).toDouble(),
          lambda: VinkiarPsychometricsEngine.lambdaEgo,
        );
      });
      stats['ego_vector'] = currentEgo;
    }
    if (deltas.containsKey('eros_deltas')) {
      final currentEros = Map<String, dynamic>.from(stats['eros_vector'] as Map<String, dynamic>? ?? {});
      final erosChanges = Map<String, dynamic>.from(deltas['eros_deltas'] as Map<String, dynamic>);
      erosChanges.forEach((k, v) {
        if (k == 'sosIndex' || k == 'erotofiliaIndex') {
          currentEros[k] = ((currentEros[k] ?? 0.0) + (v as num).toDouble()).clamp(-10.0, 10.0);
        } else {
          final double prev = (currentEros[k] as num?)?.toDouble() ?? 15.0;
          currentEros[k] = VinkiarPsychometricsEngine.applyInertialDelta(
            currentPct: prev,
            deltaPct: (v as num).toDouble(),
            lambda: VinkiarPsychometricsEngine.lambdaErosPhilia,
          );
        }
      });
      stats['eros_vector'] = currentEros;
    }
    if (deltas.containsKey('philia_deltas')) {
      final currentPhilia = Map<String, dynamic>.from(stats['philia_vector'] as Map<String, dynamic>? ?? {});
      final philiaChanges = Map<String, dynamic>.from(deltas['philia_deltas'] as Map<String, dynamic>);
      philiaChanges.forEach((k, v) {
        if (k == 'iAR' || k == 'diferenciacionSelf') {
          currentPhilia[k] = ((currentPhilia[k] ?? 0.0) + (v as num).toDouble()).clamp(0.00, 1.00);
        } else {
          final double prev = (currentPhilia[k] as num?)?.toDouble() ?? 15.0;
          currentPhilia[k] = VinkiarPsychometricsEngine.applyInertialDelta(
            currentPct: prev,
            deltaPct: (v as num).toDouble(),
            lambda: VinkiarPsychometricsEngine.lambdaErosPhilia,
          );
        }
      });
      stats['philia_vector'] = currentPhilia;
    }

    // Recalcular IFS e ICA dinámicos tras actualizar las ruedas
    final egoMap = Map<String, dynamic>.from(stats['ego_vector'] as Map<String, dynamic>? ?? {});
    final erosMap = Map<String, dynamic>.from(stats['eros_vector'] as Map<String, dynamic>? ?? {});
    final philiaMap = Map<String, dynamic>.from(stats['philia_vector'] as Map<String, dynamic>? ?? {});

    final List<double> egoRadii = [
      (egoMap['divo'] as num?)?.toDouble() ?? 0.0,
      (egoMap['rescatador'] as num?)?.toDouble() ?? 0.0,
      (egoMap['vividor'] as num?)?.toDouble() ?? 0.0,
      (egoMap['artista'] as num?)?.toDouble() ?? 0.0,
      (egoMap['intelectual'] as num?)?.toDouble() ?? 0.0,
      (egoMap['afrodita'] ?? egoMap['cautivador'] as num?)?.toDouble() ?? 0.0,
      (egoMap['cautivador'] ?? egoMap['entusiasta'] as num?)?.toDouble() ?? 0.0,
      (egoMap['lider'] as num?)?.toDouble() ?? 0.0,
      (egoMap['encantador'] as num?)?.toDouble() ?? 0.0,
    ];
    final List<double> erosRadii = [
      (erosMap['energetico'] as num?)?.toDouble() ?? 0.0,
      (erosMap['sensual'] as num?)?.toDouble() ?? 0.0,
      (erosMap['sexual'] as num?)?.toDouble() ?? 0.0,
      (erosMap['kinky'] as num?)?.toDouble() ?? 0.0,
      (erosMap['cambiaformas'] as num?)?.toDouble() ?? 0.0,
    ];
    final List<double> philiaRadii = [
      (philiaMap['seguro'] as num?)?.toDouble() ?? 0.0,
      (philiaMap['ocnofilo'] as num?)?.toDouble() ?? 0.0,
      (philiaMap['filobata'] as num?)?.toDouble() ?? 0.0,
      (philiaMap['desorganizado'] as num?)?.toDouble() ?? 0.0,
    ];

    stats['ifs_index'] = VinkiarPsychometricsEngine.computeSomaticStrengthIndex(
      egoRadiiPct: egoRadii,
      erosRadiiPct: erosRadii,
      philiaRadiiPct: philiaRadii,
    );
    stats['ica_index'] = VinkiarPsychometricsEngine.computeSoulCoherenceIndex(
      egoRadiiPct: egoRadii,
      erosRadiiPct: erosRadii,
      philiaRadiiPct: philiaRadii,
    );

    await saveAvatarSheet("LOCAL_USER", {...baseAvatar, "stats": stats});
  }

  Future<void> logRadarPing(Map<String, dynamic> pingData) async {
    if (_driftDb == null) return;
    await _driftDb!.into(_driftDb!.radarPings).insert(
      RadarPingsCompanion.insert(
        id: "PING_${DateTime.now().millisecondsSinceEpoch}",
        nodeId: pingData['node_id'] ?? 'UNKNOWN',
        alias: pingData['alias'] ?? 'Avatar Anónimo',
        interactionType: drift.Value(pingData['interaction_type'] ?? 'PING'),
        distanceMeters: drift.Value(pingData['distance_meters'] as double?),
        timestamp: drift.Value(DateTime.now().toIso8601String()),
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
  }

  // =========================================================================
  // SECCIÓN 7: CONTRATOS ESCROW Y DOBLE FIRMA 2-DE-2
  // =========================================================================

  Future<void> lockEscrow(int amount) async {
    final avatar = await getAvatarSheet("LOCAL_USER");
    final stats = Map<String, dynamic>.from(avatar?['stats'] as Map<String, dynamic>? ?? {});
    final int currentVinks = (stats['vinks'] as int?) ?? 150;
    final int currentEscrow = (stats['escrow'] as int?) ?? 0;

    if (currentVinks >= amount) {
      stats['vinks'] = currentVinks - amount;
      stats['escrow'] = currentEscrow + amount;

      await saveAvatarSheet("LOCAL_USER", {
        'character_class': avatar?['character_class'] ?? 'INICIADO',
        'level': avatar?['level'] ?? 1,
        'experience_points': avatar?['experience_points'] ?? 0,
        'reputation_score': avatar?['reputation_score'] ?? 1.0,
        'stats': stats,
        'active_buffs': avatar?['active_buffs'] ?? [],
        'active_debuffs': avatar?['active_debuffs'] ?? [],
      });
    } else {
      throw VaultSecurityException("Saldo insuficiente para retención Escrow.");
    }
  }

  Future<void> releaseEscrowTo(int amount, bool refundToSelf) async {
    final avatar = await getAvatarSheet("LOCAL_USER");
    final stats = Map<String, dynamic>.from(avatar?['stats'] as Map<String, dynamic>? ?? {});
    final int currentVinks = (stats['vinks'] as int?) ?? 0;
    final int currentEscrow = (stats['escrow'] as int?) ?? 0;

    if (currentEscrow >= amount) {
      stats['escrow'] = currentEscrow - amount;
      if (refundToSelf) {
        stats['vinks'] = currentVinks + amount;
      }

      await saveAvatarSheet("LOCAL_USER", {
        'character_class': avatar?['character_class'] ?? 'INICIADO',
        'level': avatar?['level'] ?? 1,
        'experience_points': avatar?['experience_points'] ?? 0,
        'reputation_score': avatar?['reputation_score'] ?? 1.0,
        'stats': stats,
        'active_buffs': avatar?['active_buffs'] ?? [],
        'active_debuffs': avatar?['active_debuffs'] ?? [],
      });
    }
  }

  Future<void> saveQuestMetadata(String questId, Map<String, dynamic> metaData) async {
    if (_driftDb == null) return;

    final existing = await getQuestMetadata(questId);
    final merged = {...existing, ...metaData};

    await _driftDb!.into(_driftDb!.sysConfig).insert(
      SysConfigCompanion.insert(
        key: 'quest_meta_$questId',
        value: drift.Value(jsonEncode(merged)),
      ),
      mode: drift.InsertMode.insertOrReplace,
    );
    questChangeNotifier.value++;
  }

  Future<Map<String, dynamic>> getQuestMetadata(String questId) async {
    if (_driftDb == null) return {};
    try {
      final query = _driftDb!.select(_driftDb!.sysConfig)..where((t) => t.key.equals('quest_meta_$questId'));
      final result = await query.getSingleOrNull();
      if (result != null && result.value != null) {
        return jsonDecode(result.value!);
      }
    } catch (_) {}
    return {};
  }

  Future<bool> verifyDoubleSignature(String questId) async {
    final meta = await getQuestMetadata(questId);
    final String? sigCreator = meta['signature_creator'];
    final String? sigExecutor = meta['signature_executor'];

    if (sigCreator != null && sigCreator.isNotEmpty && sigExecutor != null && sigExecutor.isNotEmpty) {
      final int escrowAmount = meta['escrow_amount'] ?? 0;
      final String creatorId = meta['creator_id'] ?? 'LOCAL_AVATAR';

      if (creatorId == 'LOCAL_USER' || creatorId == 'LOCAL_AVATAR') {
        await releaseEscrowTo(escrowAmount, false);
      } else {
        await addAvatarRewards(escrowAmount, 0);
      }

      await updateQuestStatus(questId, 'COMPLETED');
      return true;
    }

    return false;
  }
}
