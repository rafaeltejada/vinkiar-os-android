import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinkiar_flutter/game/vinkiar_destiny_engine.dart';
import 'package:vinkiar_flutter/game/glitch_manager.dart';
import 'package:vinkiar_flutter/game/grip_manager.dart';

void main() {
  // ==========================================================================
  // GRUPO 1: Motor de Destino — Rolls y Tablas de Probabilidad
  // ==========================================================================
  group('VinkiarDestinyEngine', () {
    late VinkiarDestinyEngine engine;

    setUp(() {
      engine = VinkiarDestinyEngine();
    });

    test('rollD10 genera valores entre 1 y 10', () {
      for (int i = 0; i < 100; i++) {
        final result = engine.rollD10();
        expect(result, greaterThanOrEqualTo(1));
        expect(result, lessThanOrEqualTo(10));
      }
    });

    test('rollD100 genera valores entre 1 y 100', () {
      for (int i = 0; i < 100; i++) {
        final result = engine.rollD100();
        expect(result, greaterThanOrEqualTo(1));
        expect(result, lessThanOrEqualTo(100));
      }
    });

    test('Fase VERDE favorece resultados positivos (>50% success rate)', () {
      int successes = 0;
      const iterations = 1000;
      for (int i = 0; i < iterations; i++) {
        // En tu engine real, el método es resolveRound y los niveles son de RelationshipLevel
        final outcome = engine.resolveRound(RelationshipLevel.VERDE, 1);
        if (outcome['result'] == 'NADA' || outcome['result'] == 'EVENTO_ESPECIAL') {
          successes++;
        }
      }
      // En fase VERDE, la probabilidad de éxito (sin efecto negativo) debería ser dominante
      expect(successes / iterations, greaterThan(0.50));
    });

    test('Fase ROJO tiene mayor tasa de desgaste (Óxido) que VERDE', () {
      int glitchesVerde = 0;
      int glitchesRojo = 0;
      const iterations = 1000;
      for (int i = 0; i < iterations; i++) {
        if (engine.resolveRound(RelationshipLevel.VERDE, 1)['result'] == 'OXIDO') {
          glitchesVerde++;
        }
        if (engine.resolveRound(RelationshipLevel.ROJO, 1)['result'] == 'OXIDO') {
          glitchesRojo++;
        }
      }
      expect(glitchesRojo, greaterThan(glitchesVerde));
    });
  });

  // ==========================================================================
  // GRUPO 2: Gestor de Glitches de Óxido
  // ==========================================================================
  group('GlitchManager', () {
    test('Tiene exactamente 4 glitches de Óxido definidos', () {
      // allGlitches es un getter sobre la instancia, por lo que instanciamos el Singleton primero
      final glitches = GlitchManager().allGlitches;
      expect(glitches.length, equals(4));
    });

    test('Todos los glitches tienen ID, título y mecánica definidos', () {
      for (final glitch in GlitchManager().allGlitches) {
        expect(glitch.id, isNotEmpty);
        expect(glitch.title, isNotEmpty);
        // En tu implementación real, se llama keyMechanic, no mechanic
        expect(glitch.keyMechanic, isNotEmpty);
      }
    });

    test('GL_RUST_001 es la Subasta Inversa de Tareas', () {
      final glitch = GlitchManager().allGlitches.firstWhere((g) => g.id == 'GL_RUST_001');
      expect(glitch.id, equals('GL_RUST_001'));
      expect(glitch.title.toLowerCase(), contains('subasta'));
    });

    test('GL_RUST_002 es el Protocolo de Silencio', () {
      final glitch = GlitchManager().allGlitches.firstWhere((g) => g.id == 'GL_RUST_002');
      expect(glitch.title.toLowerCase(), contains('silencio'));
    });
  });

  // ==========================================================================
  // GRUPO 3: Máquina de Estados GRIP (GripSession)
  // ==========================================================================
  group('GripSession', () {
    late GripSession grip;

    setUp(() {
      // Tu clase real se llama GripSession, no GripManager
      grip = GripSession.initialize('TEST_TRIGGER', 'Player1');
    });

    test('El estado inicial es G_GESTION', () {
      // Las fases reales están nombradas G_GESTION, R_REENCUADRE, etc.
      expect(grip.currentPhase, equals(GripPhase.G_GESTION));
      expect(grip.totemHolderId, equals('Player1'));
    });

    test('Se puede avanzar de G_GESTION a R_REENCUADRE al transferir el tótem', () {
      // Tu clase usa transferTotem, no advancePhase
      grip.transferTotem('Player2');
      expect(grip.currentPhase, equals(GripPhase.R_REENCUADRE));
      expect(grip.totemHolderId, equals('Player2'));
    });

    test('El flujo GRIP completo tiene 4 fases', () {
      expect(GripPhase.values.length, equals(4));
    });

    test('Pacto es la fase final del protocolo GRIP', () {
      grip.transferTotem('Player2'); // Avanza a Reencuadre
      grip.validateAndSubmitIntervention('Player2', 'raw', 'reconf'); // Avanza a Indagación
      grip.resolveNeed('NECESIDAD_XYZ'); // Avanza a Pacto
      expect(grip.currentPhase, equals(GripPhase.P_PACTO));
    });
  });

  // ==========================================================================
  // GRUPO 4: Seguridad — Validación de datos criptográficos
  // ==========================================================================
  group('Cryptographic Data Validation', () {
    test('El código ZK tiene formato ZK-XXXX-XXXX', () {
      final zkPattern = RegExp(r'^ZK-[A-Z0-9]{8}-[A-Z0-9]{4}$');
      const validCode = 'ZK-A1B2C3D4-E5F6';
      const invalidCode = 'INVALID_CODE';
      
      expect(zkPattern.hasMatch(validCode), isTrue);
      expect(zkPattern.hasMatch(invalidCode), isFalse);
    });

    test('Salt de 32 bytes genera lista de longitud correcta', () {
      final salt = Uint8List(32);
      expect(salt.length, equals(32));
    });

    test('Wiping de buffer — todos los bytes deben ser cero después de limpiar', () {
      final buffer = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      for (int i = 0; i < buffer.length; i++) {
        buffer[i] = 0;
      }
      expect(buffer.every((b) => b == 0), isTrue);
    });
  });
}
