import 'dart:convert';

enum GripPhase {
  G_GESTION,     // Gestión de la Atención: Turno físico del Tótem
  R_REENCUADRE,  // Reencuadre del Sentimiento: NLP local de traducción asertiva
  I_INDAGACION,  // Indagación de Necesidades: Selección de token por el receptor
  P_PACTO        // Pacto de Sincronía: Consolidación de compromisos y recompensas
}

class GripSession {
  final String sessionId;
  final String triggerSource;
  GripPhase currentPhase;
  String totemHolderId;
  final Map<String, dynamic> stateData;

  GripSession({
    required this.sessionId,
    required this.triggerSource,
    required this.currentPhase,
    required this.totemHolderId,
    required this.stateData,
  });

  factory GripSession.initialize(String trigger, String initialPlayerId) {
    return GripSession(
      sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
      triggerSource: trigger,
      currentPhase: GripPhase.G_GESTION,
      totemHolderId: initialPlayerId,
      stateData: {
        'interventions': [],
        'identified_needs': [],
        'pact_commitments': []
      },
    );
  }

  void transferTotem(String nextPlayerId) {
    if (currentPhase == GripPhase.G_GESTION) {
      totemHolderId = nextPlayerId;
      currentPhase = GripPhase.R_REENCUADRE;
    }
  }

  bool validateAndSubmitIntervention(String playerId, String rawText, String reconfiguredText) {
    if (playerId != totemHolderId) return false;

    final interventions = stateData['interventions'] as List;
    interventions.add({
      'player_id': playerId,
      'raw_input': rawText,
      'reconfigured_input': reconfiguredText,
      'is_approved': true
    });

    currentPhase = GripPhase.I_INDAGACION;
    return true;
  }

  void resolveNeed(String needToken) {
    final needs = stateData['identified_needs'] as List;
    needs.add(needToken);
    currentPhase = GripPhase.P_PACTO;
  }

  Map<String, dynamic> sealPact(String executorId, String actionToken) {
    final commitments = stateData['pact_commitments'] as List;
    commitments.add({
      'executor_id': executorId,
      'action_token': actionToken,
      'cooldown_days': 2
    });

    return {
      'status': 'RESOLVED',
      'xp_reward': 100,
      'vinks_reward': 20,
      'payload': toJson()
    };
  }

  String toJson() {
    return jsonEncode({
      'session_id': sessionId,
      'trigger_source': triggerSource,
      'current_phase': currentPhase.toString().split('.').last,
      'totem_holder': totemHolderId,
      'state_data': stateData,
    });
  }

  factory GripSession.fromJson(Map<String, dynamic> json) {
    final String phaseStr = json['current_phase'];
    final GripPhase phase = GripPhase.values.firstWhere(
      (e) => e.toString().split('.').last == phaseStr,
      orElse: () => GripPhase.G_GESTION,
    );

    return GripSession(
      sessionId: json['session_id'],
      triggerSource: json['trigger_source'],
      currentPhase: phase,
      totemHolderId: json['totem_holder'],
      stateData: Map<String, dynamic>.from(json['state_data']),
    );
  }
}
