import 'package:drift/drift.dart';
import 'schema.dart'; // Importamos las tablas que creaste

// Esta línea es OBLIGATORIA para que Drift sepa dónde escribir el código autogenerado
part 'app_database.g.dart'; 

@DriftDatabase(tables: [
  // Tridimensionalidad del Alma
  SoulSheets, EgoWheels, ErosWheels, PhiliaWheels, HarvestLogs,
  // Ecosistema Vinkiar
  SysConfig, AvatarSheets, LocalMessages, LocalQuests, LocalContacts, RadarPings
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  // Construcción instantánea del Vector Tridimensional
  Stream<TripleEnneagramView?> watchSoulSheetFull(String targetUuid) {
    final query = select(soulSheets).join([
      leftOuterJoin(egoWheels, egoWheels.soulSheetUuid.equalsExp(soulSheets.uuid)),
      leftOuterJoin(erosWheels, erosWheels.soulSheetUuid.equalsExp(soulSheets.uuid)),
      leftOuterJoin(philiaWheels, philiaWheels.soulSheetUuid.equalsExp(soulSheets.uuid)),
    ])..where(soulSheets.uuid.equals(targetUuid));

    return query.watchSingleOrNull().map((row) {
      if (row == null) return null;
      return TripleEnneagramView(
        soul: row.readTable(soulSheets),
        ego: row.readTableOrNull(egoWheels),
        eros: row.readTableOrNull(erosWheels),
        philia: row.readTableOrNull(philiaWheels),
      );
    });
  }
}

// DTO para la serialización a JSON
class TripleEnneagramView {
  final SoulSheet soul;
  final EgoWheel? ego;
  final ErosWheel? eros;
  final PhiliaWheel? philia;

  TripleEnneagramView({required this.soul, this.ego, this.eros, this.philia});

  Map<String, dynamic> toJson() => {
    'soul_sheet_id': soul.uuid,
    'avatar_alias': soul.aliasSanitizado,
    'wheels': {
      'rueda_i_ego': ego?.toJson(),
      'rueda_ii_eros': eros?.toJson(),
      'rueda_iii_philia': philia?.toJson(),
    }
  };
}