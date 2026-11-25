import 'dart:convert';
import 'vinkiar_secure_database.dart';

// =========================================================================
// SECCIÓN 1: ENUMERACIONES DEL PROTOCOLO SSC (PERMISOS, OPERATIVO Y NIVELES)
// =========================================================================

/// Permisos operativos evaluados en tiempo real dentro de salas y chats
enum SSCPermission {
  canChat,
  canSendPermanentMedia,
  canSendEphemeralMedia,
  canParticipateInQuests,
  isExiled,
}

/// Estado operativo en tiempo real del vínculo (disponibilidad y pausa de seguridad)
enum SscOperationalState {
  green,  // Flujo abierto / Sintonía activa
  yellow, // Calibración / Cautela
  red,    // Pausa de chat / Espacio seguro inmediato
}

/// Categoría del límite o deseo dentro del catálogo SSC de revelación gradual
enum SscLimitTier {
  green,  // Deseos / Prácticas afines (Nivel 0)
  yellow, // Negociables / Requieren contexto previo (Nivel 1)
  red,    // Límites duros / Protocolos de cuidado (Nivel 2)
}

// =========================================================================
// SECCIÓN 2: MODELOS DE DATOS DIÁDICOS (ÍTEMS, COLISIONES Y PERFIL)
// =========================================================================

/// Elemento individual del catálogo SSC con control granular Visible / Oculto
class SscLimitItem {
  final String id;
  final String label;
  final SscLimitTier tier;
  final bool isVisible;      // Checkbox: true = Visible para el contacto, false = Oculto en bóveda
  final bool manualOverride; // true si el usuario ajustó manualmente la casilla

  const SscLimitItem({
    required this.id,
    required this.label,
    required this.tier,
    this.isVisible = false,
    this.manualOverride = false,
  });

  SscLimitItem copyWith({
    String? id,
    String? label,
    SscLimitTier? tier,
    bool? isVisible,
    bool? manualOverride,
  }) {
    return SscLimitItem(
      id: id ?? this.id,
      label: label ?? this.label,
      tier: tier ?? this.tier,
      isVisible: isVisible ?? this.isVisible,
      manualOverride: manualOverride ?? this.manualOverride,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'tier': tier.name.toUpperCase(),
        'is_visible': isVisible,
        'manual_override': manualOverride,
      };

  factory SscLimitItem.fromJson(Map<String, dynamic> json) {
    final tierStr = (json['tier'] ?? 'GREEN').toString().toUpperCase();
    final tier = SscLimitTier.values.firstWhere(
      (e) => e.name.toUpperCase() == tierStr,
      orElse: () => SscLimitTier.green,
    );
    return SscLimitItem(
      id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      label: json['label']?.toString() ?? '',
      tier: tier,
      isVisible: json['is_visible'] == true,
      manualOverride: json['manual_override'] == true,
    );
  }
}

/// Alerta generada cuando un deseo o práctica choca con un límite rojo de la contraparte
class SscCollisionAlert {
  final String myLabel;
  final SscLimitTier myTier;
  final String peerLabel;
  final SscLimitTier peerTier;
  final String severity; // 'CRITICAL' | 'WARNING'

  const SscCollisionAlert({
    required this.myLabel,
    required this.myTier,
    required this.peerLabel,
    required this.peerTier,
    required this.severity,
  });
}

/// Estado completo del Doble Semáforo SSC para un contacto específico
class DyadicSscProfile {
  final String contactId;
  final SscOperationalState operationalState;
  final int synergyLevel; // 0 = Inicial (Verdes), 1 = Sintonía (+Ámbar), 2 = Cristalizada (+Rojos)
  final int sharedQuestsCount;
  final int phygitalEncountersCount;
  final List<SscLimitItem> myLimits;
  final List<SscLimitItem> incomingLimits;
  final DateTime updatedAt;

  const DyadicSscProfile({
    required this.contactId,
    this.operationalState = SscOperationalState.green,
    this.synergyLevel = 0,
    this.sharedQuestsCount = 0,
    this.phygitalEncountersCount = 0,
    this.myLimits = const [],
    this.incomingLimits = const [],
    required this.updatedAt,
  });

  DyadicSscProfile copyWith({
    SscOperationalState? operationalState,
    int? synergyLevel,
    int? sharedQuestsCount,
    int? phygitalEncountersCount,
    List<SscLimitItem>? myLimits,
    List<SscLimitItem>? incomingLimits,
    DateTime? updatedAt,
  }) {
    return DyadicSscProfile(
      contactId: contactId,
      operationalState: operationalState ?? this.operationalState,
      synergyLevel: synergyLevel ?? this.synergyLevel,
      sharedQuestsCount: sharedQuestsCount ?? this.sharedQuestsCount,
      phygitalEncountersCount: phygitalEncountersCount ?? this.phygitalEncountersCount,
      myLimits: myLimits ?? this.myLimits,
      incomingLimits: incomingLimits ?? this.incomingLimits,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'contact_id': contactId,
        'operational_state': operationalState.name.toUpperCase(),
        'synergy_level': synergyLevel,
        'shared_quests_count': sharedQuestsCount,
        'phygital_encounters_count': phygitalEncountersCount,
        'my_limits': myLimits.map((e) => e.toJson()).toList(),
        'incoming_limits': incomingLimits.map((e) => e.toJson()).toList(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory DyadicSscProfile.fromJson(String contactId, Map<String, dynamic> json) {
    final opStr = (json['operational_state'] ?? json['ssc_level'] ?? 'GREEN').toString().toUpperCase();
    SscOperationalState opState = SscOperationalState.green;
    if (opStr == 'YELLOW') {
      opState = SscOperationalState.yellow;
    } else if (opStr == 'RED' || opStr == 'BARBECHO' || opStr == 'REVOKED') {
      opState = SscOperationalState.red;
    }

    final rawMy = (json['my_limits'] as List<dynamic>? ?? []);
    final rawIn = (json['incoming_limits'] as List<dynamic>? ?? []);

    return DyadicSscProfile(
      contactId: contactId,
      operationalState: opState,
      synergyLevel: (json['synergy_level'] as num?)?.toInt() ?? 0,
      sharedQuestsCount: (json['shared_quests_count'] as num?)?.toInt() ??
          (json['completed_quests'] as num?)?.toInt() ??
          0,
      phygitalEncountersCount: (json['phygital_encounters_count'] as num?)?.toInt() ?? 0,
      myLimits: rawMy.map((e) => SscLimitItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      incomingLimits: rawIn.map((e) => SscLimitItem.fromJson(Map<String, dynamic>.from(e))).toList(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

// =========================================================================
// SECCIÓN 3: GESTOR CENTRAL Y REGLAS DE REVELACIÓN GRADUAL (VinkiarSSCManager)
// =========================================================================

typedef VinkiarSscManager = VinkiarSSCManager;

class VinkiarSSCManager {
  static final VinkiarSSCManager _instance = VinkiarSSCManager._internal();
  factory VinkiarSSCManager() => _instance;
  VinkiarSSCManager._internal();

  /// Comprueba permisos operativos conservando compatibilidad total con chat_qa_screen
  Future<bool> checkPermission(String contactId, SSCPermission permission) async {
    final db = VinkiarSecureDatabase();
    final contacts = await db.getContacts();
    final contact = contacts.firstWhere(
      (c) => c['id'] == contactId,
      orElse: () => {},
    );

    final bondSettings = await db.getContactBondSettings(contactId);
    final String sscLevel = (bondSettings['operational_state'] ??
            bondSettings['ssc_level'] ??
            contact['ssc_level'] ??
            'GREEN')
        .toString()
        .toUpperCase();

    switch (permission) {
      case SSCPermission.canChat:
        return sscLevel == 'GREEN' || sscLevel == 'YELLOW';
      case SSCPermission.canSendEphemeralMedia:
        return sscLevel == 'GREEN' || sscLevel == 'YELLOW';
      case SSCPermission.canSendPermanentMedia:
        return sscLevel == 'GREEN';
      case SSCPermission.canParticipateInQuests:
        return sscLevel == 'GREEN' || sscLevel == 'YELLOW';
      case SSCPermission.isExiled:
        return sscLevel == 'REVOKED';
    }
  }

  /// Calcula el nivel de sintonía (0, 1 o 2) según misiones compartidas y encuentros Phygital
  static int computeSynergyLevel({
    required int sharedQuestsCount,
    required int phygitalEncountersCount,
  }) {
    final totalMilestones = sharedQuestsCount + phygitalEncountersCount;
    if (totalMilestones >= 3 || (sharedQuestsCount >= 2 && phygitalEncountersCount >= 1)) {
      return 2; // Célula Cristalizada -> Verdes + Amarillos + Rojos
    }
    if (totalMilestones >= 1) {
      return 1; // Sintonía Validada -> Verdes + Amarillos
    }
    return 0;   // Enlace Inicial -> Solo Verdes
  }

  /// Determina si una categoría está desbloqueada automáticamente para el nivel de sintonía dado
  static bool isTierUnlockedForLevel(SscLimitTier tier, int synergyLevel) {
    switch (tier) {
      case SscLimitTier.green:
        return true;
      case SscLimitTier.yellow:
        return synergyLevel >= 1;
      case SscLimitTier.red:
        return synergyLevel >= 2;
    }
  }

  /// Aplica explícitamente un nivel de revelación (0, 1 o 2) actualizando las casillas por categoría
  static DyadicSscProfile applySynergyLevelPreset(DyadicSscProfile profile, int targetLevel) {
    final clampedLevel = targetLevel.clamp(0, 2);
    final updatedLimits = profile.myLimits.map((item) {
      final shouldBeVisible = isTierUnlockedForLevel(item.tier, clampedLevel);
      return item.copyWith(
        isVisible: shouldBeVisible,
        manualOverride: false,
      );
    }).toList();

    return profile.copyWith(
      synergyLevel: clampedLevel,
      myLimits: updatedLimits,
      updatedAt: DateTime.now(),
    );
  }

  /// Aplica las reglas automáticas al alcanzar nuevos hitos respetando ajustes manuales
  static DyadicSscProfile applyProgressiveDisclosure(DyadicSscProfile profile) {
    final calculatedLevel = computeSynergyLevel(
      sharedQuestsCount: profile.sharedQuestsCount,
      phygitalEncountersCount: profile.phygitalEncountersCount,
    );
    final effectiveLevel = calculatedLevel > profile.synergyLevel
        ? calculatedLevel
        : profile.synergyLevel;

    final updatedLimits = profile.myLimits.map((item) {
      if (item.manualOverride) return item;
      final shouldBeVisible = isTierUnlockedForLevel(item.tier, effectiveLevel);
      return item.copyWith(isVisible: shouldBeVisible);
    }).toList();

    return profile.copyWith(
      synergyLevel: effectiveLevel,
      myLimits: updatedLimits,
      updatedAt: DateTime.now(),
    );
  }

  /// Conmuta manualmente la casilla Visible / Oculto de un elemento concreto
  static DyadicSscProfile toggleItemVisibility(
    DyadicSscProfile profile,
    String itemId,
    bool newVisibility,
  ) {
    final updated = profile.myLimits.map((item) {
      if (item.id != itemId) return item;
      return item.copyWith(
        isVisible: newVisibility,
        manualOverride: true,
      );
    }).toList();

    return profile.copyWith(myLimits: updated, updatedAt: DateTime.now());
  }

  /// Detecta colisiones entre límites propios y los revelados por el contacto
  static List<SscCollisionAlert> detectCollisions(DyadicSscProfile profile) {
    final alerts = <SscCollisionAlert>[];
    for (final mine in profile.myLimits) {
      final myNorm = mine.label.toLowerCase().trim();
      if (myNorm.isEmpty) continue;

      for (final peer in profile.incomingLimits) {
        final peerNorm = peer.label.toLowerCase().trim();
        if (peerNorm.isEmpty) continue;

        final sameTopic = myNorm == peerNorm ||
            (myNorm.length >= 4 && peerNorm.contains(myNorm)) ||
            (peerNorm.length >= 4 && myNorm.contains(peerNorm));

        if (!sameTopic) continue;

        if ((mine.tier == SscLimitTier.green && peer.tier == SscLimitTier.red) ||
            (mine.tier == SscLimitTier.red && peer.tier == SscLimitTier.green)) {
          alerts.add(SscCollisionAlert(
            myLabel: mine.label,
            myTier: mine.tier,
            peerLabel: peer.label,
            peerTier: peer.tier,
            severity: 'CRITICAL',
          ));
        } else if ((mine.tier == SscLimitTier.yellow && peer.tier == SscLimitTier.red) ||
            (mine.tier == SscLimitTier.red && peer.tier == SscLimitTier.yellow)) {
          alerts.add(SscCollisionAlert(
            myLabel: mine.label,
            myTier: mine.tier,
            peerLabel: peer.label,
            peerTier: peer.tier,
            severity: 'WARNING',
          ));
        }
      }
    }
    return alerts;
  }

  /// Construye el paquete ZKA filtrado: JAMÁS incluye ítems con isVisible == false
  static String buildZkaShareablePayload({
    required String senderHandle,
    required DyadicSscProfile profile,
  }) {
    final visibleOnly = profile.myLimits
        .where((item) => item.isVisible)
        .map((item) => {
              'id': item.id,
              'label': item.label,
              'tier': item.tier.name.toUpperCase(),
            })
        .toList();

    return jsonEncode({
      'type': 'SSC_DISCLOSURE_SYNC',
      'sender_handle': senderHandle,
      'operational_state': profile.operationalState.name.toUpperCase(),
      'synergy_level': profile.synergyLevel,
      'disclosed_limits': visibleOnly,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Perfil inicial por defecto para un vínculo recién creado (Nivel 0: solo Verdes visibles)
  static DyadicSscProfile createDefaultProfile(String contactId) {
    return DyadicSscProfile(
      contactId: contactId,
      operationalState: SscOperationalState.green,
      synergyLevel: 0,
      updatedAt: DateTime.now(),
      myLimits: const [
        SscLimitItem(
          id: 'ssc_g_1',
          label: 'Encuentros presenciales en Santuarios acreditados',
          tier: SscLimitTier.green,
          isVisible: true,
        ),
        SscLimitItem(
          id: 'ssc_g_2',
          label: 'Conversación profunda sin móviles sobre la mesa',
          tier: SscLimitTier.green,
          isVisible: true,
        ),
        SscLimitItem(
          id: 'ssc_y_1',
          label: 'Contacto físico / afectivo tras validar sintonía',
          tier: SscLimitTier.yellow,
          isVisible: false,
        ),
        SscLimitItem(
          id: 'ssc_y_2',
          label: 'Compartir red social o teléfono fuera de Vinkiar',
          tier: SscLimitTier.yellow,
          isVisible: false,
        ),
        SscLimitItem(
          id: 'ssc_r_1',
          label: 'Cero fotografías ni grabaciones sin consentimiento explícito',
          tier: SscLimitTier.red,
          isVisible: false,
        ),
        SscLimitItem(
          id: 'ssc_r_2',
          label: 'Pausa inmediata sin explicaciones ante saturación sensorial',
          tier: SscLimitTier.red,
          isVisible: false,
        ),
      ],
    );
  }
}
