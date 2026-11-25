import 'package:flutter/material.dart';
import '../ui/theme.dart';

class RelationalTagDef {
  final String key;
  final String fullLabel;
  final String shortLabel;
  final String emoji;
  final Color color;

  const RelationalTagDef({
    required this.key,
    required this.fullLabel,
    required this.shortLabel,
    required this.emoji,
    required this.color,
  });
}

class VinkiarRelationalTags {
  static const List<RelationalTagDef> all = [
    RelationalTagDef(
      key: 'PARTNER',
      fullLabel: '❤️ Pareja / Vínculo Primario',
      shortLabel: '❤️ Pareja',
      emoji: '❤️',
      color: Colors.pinkAccent,
    ),
    RelationalTagDef(
      key: 'FREE_BOND',
      fullLabel: '⚡ Vínculo Libre (Afinidad A³)',
      shortLabel: '⚡ Vínculo Libre',
      emoji: '⚡',
      color: VinkiarColors.vertigoGold,
    ),
    RelationalTagDef(
      key: 'COMPLICE',
      fullLabel: '🤝 Cómplice Íntimo / Manada',
      shortLabel: '🤝 Cómplice Íntimo',
      emoji: '🤝',
      color: VinkiarColors.aegisCyan,
    ),
    RelationalTagDef(
      key: 'EXPLORATION',
      fullLabel: '🌱 Semilla en Exploración / Kink',
      shortLabel: '🌱 Semilla',
      emoji: '🌱',
      color: VinkiarColors.hackingGreen,
    ),
    RelationalTagDef(
      key: 'ALLIANCE',
      fullLabel: '🛡️ Alianza de Célula ZKA',
      shortLabel: '🛡️ Alianza ZKA',
      emoji: '🛡️',
      color: Colors.indigoAccent,
    ),
    RelationalTagDef(
      key: 'SATELLITE',
      fullLabel: '🪐 Órbita / Satélite Afectivo',
      shortLabel: '🪐 Satélite',
      emoji: '🪐',
      color: Colors.purpleAccent,
    ),
  ];

  static RelationalTagDef find(String? raw) {
    if (raw == null || raw.isEmpty) return all[3]; // Por defecto: Semilla en Exploración
    final clean = raw.trim().toUpperCase();

    for (var def in all) {
      if (def.key == clean) return def;
      if (clean.contains("PAREJA") || clean.contains("PRIMARIO")) return all[0];
      if (clean.contains("LIBRE") || clean.contains("A³") || clean.contains("A3")) return all[1];
      if (clean.contains("CÓMPLICE") || clean.contains("COMPLICE") || clean.contains("MANADA")) return all[2];
      if (clean.contains("SEMILLA") || clean.contains("EXPLORACIÓN") || clean.contains("KINK")) return all[3];
      if (clean.contains("ALIANZA") || clean.contains("CONTACTO")) return all[4];
      if (clean.contains("ÓRBITA") || clean.contains("ORBITA") || clean.contains("SATÉLITE")) return all[5];
    }
    return all[3];
  }

  static String formatTabernaBadge(String? relationshipType, String? relationalTag) {
    final def = find(relationalTag ?? relationshipType);
    return def.shortLabel;
  }
}