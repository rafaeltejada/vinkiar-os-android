import 'package:drift/drift.dart';

// 1. EL CORE: Hoja de Alma
class SoulSheets extends Table {
  TextColumn get uuid => text()(); 
  TextColumn get aliasSanitizado => text().withDefault(const Constant('[USER_TARGET]'))();
  IntColumn get vinksAcumulados => integer().withDefault(const Constant(0))();
  IntColumn get rangoForja => integer().withDefault(const Constant(1))();
  DateTimeColumn get ultimaRecalibracion => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {uuid};
}

// 2. RUEDA I: El Ego (Máscara Estratégica)
class EgoWheels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get soulSheetUuid => text().references(SoulSheets, #uuid)();
  
  IntColumn get eneatipoDaniels => integer().nullable()(); // 1 al 9[cite: 8]
  TextColumn get arquetipoSeduccion => text().nullable()(); // Ej: "El Cautivador"[cite: 8]
  TextColumn get vectorHorney => text().nullable()(); // "Hacia", "Contra", "Lejos"[cite: 8]
  TextColumn get mecanismoDefensa => text().nullable()(); // Ej: "Aislamiento Cognitivo"
}

// 3. RUEDA II: Eros (Hardware Somatosensorial)
class ErosWheels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get soulSheetUuid => text().references(SoulSheets, #uuid)();
  
  TextColumn get blueprintPrimario => text().nullable()(); // Energético, Sensual, Sexual, Kinky, Cambiaformas[cite: 8]
  RealColumn get escalaErotofiliaSos => real().nullable()(); // Puntuación continua SOS[cite: 8]
  TextColumn get semaforoLimitesJson => text().nullable()(); // JSON mapeando arrays de Verdes, Amarillos, Rojos[cite: 8]
}

// 4. RUEDA III: Philia (Núcleo del Vínculo)
class PhiliaWheels extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get soulSheetUuid => text().references(SoulSheets, #uuid)();
  
  TextColumn get estiloApego => text().nullable()(); // Seguro, Ansioso, Evitativo, Desorganizado[cite: 8]
  RealColumn get modeloYo => real().nullable()(); // Autoestima continua[cite: 1]
  RealColumn get modeloOtro => real().nullable()(); // Confianza continua[cite: 1]
  RealColumn get indiceDiferenciacionIar => real().nullable()(); // Cálculo matemático de Autonomía Relacional[cite: 8]
}

// 5. INGESTA: Registro del Onboarding Clandestino (VINKIAR-SOUL-HARVEST)
class HarvestLogs extends Table {
  TextColumn get id => text()(); // UUID de transacción
  TextColumn get soulSheetUuid => text().references(SoulSheets, #uuid)();
  
  TextColumn get dilemaId => text()(); // Ej: "dilema_lazo_autonomia"[cite: 8]
  TextColumn get opcionSeleccionada => text()(); // Opción elegida en la simulación
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// --- TABLAS LEGACY MIGRADAS A DRIFT ---

class SysConfig extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}

class AvatarSheets extends Table {
  TextColumn get id => text()();
  TextColumn get characterClass => text().nullable()();
  IntColumn get level => integer().nullable()();
  IntColumn get experiencePoints => integer().nullable()();
  RealColumn get reputationScore => real().nullable()();
  TextColumn get stats => text().nullable()(); // JSON
  TextColumn get activeBuffs => text().nullable()(); // JSON
  TextColumn get activeDebuffs => text().nullable()(); // JSON

  @override
  Set<Column> get primaryKey => {id};
}

class LocalMessages extends Table {
  TextColumn get id => text()();
  TextColumn get guildId => text().nullable()();
  TextColumn get senderId => text().nullable()();
  TextColumn get encryptedBlob => text().nullable()();
  TextColumn get decryptedContent => text().nullable()();
  TextColumn get timestamp => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalQuests extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get sourceType => text().nullable()();
  IntColumn get rewardVinks => integer().nullable()();
  IntColumn get xpReward => integer().nullable()();
  TextColumn get status => text().nullable()();
  IntColumn get minLevel => integer().withDefault(const Constant(1))();
  TextColumn get requiredQuestId => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalContacts extends Table {
  TextColumn get id => text()();
  TextColumn get alias => text()();
  TextColumn get characterClass => text().nullable()();
  TextColumn get relationshipType => text().withDefault(const Constant('FRIEND'))();
  TextColumn get sscLevel => text().withDefault(const Constant('GREEN'))();
  IntColumn get isActive => integer().withDefault(const Constant(1))();
  RealColumn get reputationScore => real().withDefault(const Constant(1.0))();
  TextColumn get lastInteraction => text().nullable()();
  TextColumn get createdAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class RadarPings extends Table {
  TextColumn get id => text()();
  TextColumn get nodeId => text()();
  TextColumn get alias => text()();
  TextColumn get interactionType => text().withDefault(const Constant('PING'))();
  RealColumn get distanceMeters => real().nullable()();
  TextColumn get timestamp => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}