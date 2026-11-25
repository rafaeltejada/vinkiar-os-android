// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SoulSheetsTable extends SoulSheets
    with TableInfo<$SoulSheetsTable, SoulSheet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SoulSheetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
      'uuid', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aliasSanitizadoMeta =
      const VerificationMeta('aliasSanitizado');
  @override
  late final GeneratedColumn<String> aliasSanitizado = GeneratedColumn<String>(
      'alias_sanitizado', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[USER_TARGET]'));
  static const VerificationMeta _vinksAcumuladosMeta =
      const VerificationMeta('vinksAcumulados');
  @override
  late final GeneratedColumn<int> vinksAcumulados = GeneratedColumn<int>(
      'vinks_acumulados', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _rangoForjaMeta =
      const VerificationMeta('rangoForja');
  @override
  late final GeneratedColumn<int> rangoForja = GeneratedColumn<int>(
      'rango_forja', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _ultimaRecalibracionMeta =
      const VerificationMeta('ultimaRecalibracion');
  @override
  late final GeneratedColumn<DateTime> ultimaRecalibracion =
      GeneratedColumn<DateTime>('ultima_recalibracion', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [uuid, aliasSanitizado, vinksAcumulados, rangoForja, ultimaRecalibracion];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'soul_sheets';
  @override
  VerificationContext validateIntegrity(Insertable<SoulSheet> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
          _uuidMeta, uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta));
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('alias_sanitizado')) {
      context.handle(
          _aliasSanitizadoMeta,
          aliasSanitizado.isAcceptableOrUnknown(
              data['alias_sanitizado']!, _aliasSanitizadoMeta));
    }
    if (data.containsKey('vinks_acumulados')) {
      context.handle(
          _vinksAcumuladosMeta,
          vinksAcumulados.isAcceptableOrUnknown(
              data['vinks_acumulados']!, _vinksAcumuladosMeta));
    }
    if (data.containsKey('rango_forja')) {
      context.handle(
          _rangoForjaMeta,
          rangoForja.isAcceptableOrUnknown(
              data['rango_forja']!, _rangoForjaMeta));
    }
    if (data.containsKey('ultima_recalibracion')) {
      context.handle(
          _ultimaRecalibracionMeta,
          ultimaRecalibracion.isAcceptableOrUnknown(
              data['ultima_recalibracion']!, _ultimaRecalibracionMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  SoulSheet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SoulSheet(
      uuid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uuid'])!,
      aliasSanitizado: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}alias_sanitizado'])!,
      vinksAcumulados: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}vinks_acumulados'])!,
      rangoForja: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rango_forja'])!,
      ultimaRecalibracion: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}ultima_recalibracion']),
    );
  }

  @override
  $SoulSheetsTable createAlias(String alias) {
    return $SoulSheetsTable(attachedDatabase, alias);
  }
}

class SoulSheet extends DataClass implements Insertable<SoulSheet> {
  final String uuid;
  final String aliasSanitizado;
  final int vinksAcumulados;
  final int rangoForja;
  final DateTime? ultimaRecalibracion;
  const SoulSheet(
      {required this.uuid,
      required this.aliasSanitizado,
      required this.vinksAcumulados,
      required this.rangoForja,
      this.ultimaRecalibracion});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['alias_sanitizado'] = Variable<String>(aliasSanitizado);
    map['vinks_acumulados'] = Variable<int>(vinksAcumulados);
    map['rango_forja'] = Variable<int>(rangoForja);
    if (!nullToAbsent || ultimaRecalibracion != null) {
      map['ultima_recalibracion'] = Variable<DateTime>(ultimaRecalibracion);
    }
    return map;
  }

  SoulSheetsCompanion toCompanion(bool nullToAbsent) {
    return SoulSheetsCompanion(
      uuid: Value(uuid),
      aliasSanitizado: Value(aliasSanitizado),
      vinksAcumulados: Value(vinksAcumulados),
      rangoForja: Value(rangoForja),
      ultimaRecalibracion: ultimaRecalibracion == null && nullToAbsent
          ? const Value.absent()
          : Value(ultimaRecalibracion),
    );
  }

  factory SoulSheet.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SoulSheet(
      uuid: serializer.fromJson<String>(json['uuid']),
      aliasSanitizado: serializer.fromJson<String>(json['aliasSanitizado']),
      vinksAcumulados: serializer.fromJson<int>(json['vinksAcumulados']),
      rangoForja: serializer.fromJson<int>(json['rangoForja']),
      ultimaRecalibracion:
          serializer.fromJson<DateTime?>(json['ultimaRecalibracion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'aliasSanitizado': serializer.toJson<String>(aliasSanitizado),
      'vinksAcumulados': serializer.toJson<int>(vinksAcumulados),
      'rangoForja': serializer.toJson<int>(rangoForja),
      'ultimaRecalibracion': serializer.toJson<DateTime?>(ultimaRecalibracion),
    };
  }

  SoulSheet copyWith(
          {String? uuid,
          String? aliasSanitizado,
          int? vinksAcumulados,
          int? rangoForja,
          Value<DateTime?> ultimaRecalibracion = const Value.absent()}) =>
      SoulSheet(
        uuid: uuid ?? this.uuid,
        aliasSanitizado: aliasSanitizado ?? this.aliasSanitizado,
        vinksAcumulados: vinksAcumulados ?? this.vinksAcumulados,
        rangoForja: rangoForja ?? this.rangoForja,
        ultimaRecalibracion: ultimaRecalibracion.present
            ? ultimaRecalibracion.value
            : this.ultimaRecalibracion,
      );
  SoulSheet copyWithCompanion(SoulSheetsCompanion data) {
    return SoulSheet(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      aliasSanitizado: data.aliasSanitizado.present
          ? data.aliasSanitizado.value
          : this.aliasSanitizado,
      vinksAcumulados: data.vinksAcumulados.present
          ? data.vinksAcumulados.value
          : this.vinksAcumulados,
      rangoForja:
          data.rangoForja.present ? data.rangoForja.value : this.rangoForja,
      ultimaRecalibracion: data.ultimaRecalibracion.present
          ? data.ultimaRecalibracion.value
          : this.ultimaRecalibracion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SoulSheet(')
          ..write('uuid: $uuid, ')
          ..write('aliasSanitizado: $aliasSanitizado, ')
          ..write('vinksAcumulados: $vinksAcumulados, ')
          ..write('rangoForja: $rangoForja, ')
          ..write('ultimaRecalibracion: $ultimaRecalibracion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      uuid, aliasSanitizado, vinksAcumulados, rangoForja, ultimaRecalibracion);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SoulSheet &&
          other.uuid == this.uuid &&
          other.aliasSanitizado == this.aliasSanitizado &&
          other.vinksAcumulados == this.vinksAcumulados &&
          other.rangoForja == this.rangoForja &&
          other.ultimaRecalibracion == this.ultimaRecalibracion);
}

class SoulSheetsCompanion extends UpdateCompanion<SoulSheet> {
  final Value<String> uuid;
  final Value<String> aliasSanitizado;
  final Value<int> vinksAcumulados;
  final Value<int> rangoForja;
  final Value<DateTime?> ultimaRecalibracion;
  final Value<int> rowid;
  const SoulSheetsCompanion({
    this.uuid = const Value.absent(),
    this.aliasSanitizado = const Value.absent(),
    this.vinksAcumulados = const Value.absent(),
    this.rangoForja = const Value.absent(),
    this.ultimaRecalibracion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SoulSheetsCompanion.insert({
    required String uuid,
    this.aliasSanitizado = const Value.absent(),
    this.vinksAcumulados = const Value.absent(),
    this.rangoForja = const Value.absent(),
    this.ultimaRecalibracion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid);
  static Insertable<SoulSheet> custom({
    Expression<String>? uuid,
    Expression<String>? aliasSanitizado,
    Expression<int>? vinksAcumulados,
    Expression<int>? rangoForja,
    Expression<DateTime>? ultimaRecalibracion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (aliasSanitizado != null) 'alias_sanitizado': aliasSanitizado,
      if (vinksAcumulados != null) 'vinks_acumulados': vinksAcumulados,
      if (rangoForja != null) 'rango_forja': rangoForja,
      if (ultimaRecalibracion != null)
        'ultima_recalibracion': ultimaRecalibracion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SoulSheetsCompanion copyWith(
      {Value<String>? uuid,
      Value<String>? aliasSanitizado,
      Value<int>? vinksAcumulados,
      Value<int>? rangoForja,
      Value<DateTime?>? ultimaRecalibracion,
      Value<int>? rowid}) {
    return SoulSheetsCompanion(
      uuid: uuid ?? this.uuid,
      aliasSanitizado: aliasSanitizado ?? this.aliasSanitizado,
      vinksAcumulados: vinksAcumulados ?? this.vinksAcumulados,
      rangoForja: rangoForja ?? this.rangoForja,
      ultimaRecalibracion: ultimaRecalibracion ?? this.ultimaRecalibracion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (aliasSanitizado.present) {
      map['alias_sanitizado'] = Variable<String>(aliasSanitizado.value);
    }
    if (vinksAcumulados.present) {
      map['vinks_acumulados'] = Variable<int>(vinksAcumulados.value);
    }
    if (rangoForja.present) {
      map['rango_forja'] = Variable<int>(rangoForja.value);
    }
    if (ultimaRecalibracion.present) {
      map['ultima_recalibracion'] =
          Variable<DateTime>(ultimaRecalibracion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SoulSheetsCompanion(')
          ..write('uuid: $uuid, ')
          ..write('aliasSanitizado: $aliasSanitizado, ')
          ..write('vinksAcumulados: $vinksAcumulados, ')
          ..write('rangoForja: $rangoForja, ')
          ..write('ultimaRecalibracion: $ultimaRecalibracion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EgoWheelsTable extends EgoWheels
    with TableInfo<$EgoWheelsTable, EgoWheel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EgoWheelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _soulSheetUuidMeta =
      const VerificationMeta('soulSheetUuid');
  @override
  late final GeneratedColumn<String> soulSheetUuid = GeneratedColumn<String>(
      'soul_sheet_uuid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES soul_sheets (uuid)'));
  static const VerificationMeta _eneatipoDanielsMeta =
      const VerificationMeta('eneatipoDaniels');
  @override
  late final GeneratedColumn<int> eneatipoDaniels = GeneratedColumn<int>(
      'eneatipo_daniels', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _arquetipoSeduccionMeta =
      const VerificationMeta('arquetipoSeduccion');
  @override
  late final GeneratedColumn<String> arquetipoSeduccion =
      GeneratedColumn<String>('arquetipo_seduccion', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _vectorHorneyMeta =
      const VerificationMeta('vectorHorney');
  @override
  late final GeneratedColumn<String> vectorHorney = GeneratedColumn<String>(
      'vector_horney', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _mecanismoDefensaMeta =
      const VerificationMeta('mecanismoDefensa');
  @override
  late final GeneratedColumn<String> mecanismoDefensa = GeneratedColumn<String>(
      'mecanismo_defensa', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        soulSheetUuid,
        eneatipoDaniels,
        arquetipoSeduccion,
        vectorHorney,
        mecanismoDefensa
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ego_wheels';
  @override
  VerificationContext validateIntegrity(Insertable<EgoWheel> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('soul_sheet_uuid')) {
      context.handle(
          _soulSheetUuidMeta,
          soulSheetUuid.isAcceptableOrUnknown(
              data['soul_sheet_uuid']!, _soulSheetUuidMeta));
    } else if (isInserting) {
      context.missing(_soulSheetUuidMeta);
    }
    if (data.containsKey('eneatipo_daniels')) {
      context.handle(
          _eneatipoDanielsMeta,
          eneatipoDaniels.isAcceptableOrUnknown(
              data['eneatipo_daniels']!, _eneatipoDanielsMeta));
    }
    if (data.containsKey('arquetipo_seduccion')) {
      context.handle(
          _arquetipoSeduccionMeta,
          arquetipoSeduccion.isAcceptableOrUnknown(
              data['arquetipo_seduccion']!, _arquetipoSeduccionMeta));
    }
    if (data.containsKey('vector_horney')) {
      context.handle(
          _vectorHorneyMeta,
          vectorHorney.isAcceptableOrUnknown(
              data['vector_horney']!, _vectorHorneyMeta));
    }
    if (data.containsKey('mecanismo_defensa')) {
      context.handle(
          _mecanismoDefensaMeta,
          mecanismoDefensa.isAcceptableOrUnknown(
              data['mecanismo_defensa']!, _mecanismoDefensaMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EgoWheel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EgoWheel(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      soulSheetUuid: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}soul_sheet_uuid'])!,
      eneatipoDaniels: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}eneatipo_daniels']),
      arquetipoSeduccion: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}arquetipo_seduccion']),
      vectorHorney: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}vector_horney']),
      mecanismoDefensa: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}mecanismo_defensa']),
    );
  }

  @override
  $EgoWheelsTable createAlias(String alias) {
    return $EgoWheelsTable(attachedDatabase, alias);
  }
}

class EgoWheel extends DataClass implements Insertable<EgoWheel> {
  final int id;
  final String soulSheetUuid;
  final int? eneatipoDaniels;
  final String? arquetipoSeduccion;
  final String? vectorHorney;
  final String? mecanismoDefensa;
  const EgoWheel(
      {required this.id,
      required this.soulSheetUuid,
      this.eneatipoDaniels,
      this.arquetipoSeduccion,
      this.vectorHorney,
      this.mecanismoDefensa});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['soul_sheet_uuid'] = Variable<String>(soulSheetUuid);
    if (!nullToAbsent || eneatipoDaniels != null) {
      map['eneatipo_daniels'] = Variable<int>(eneatipoDaniels);
    }
    if (!nullToAbsent || arquetipoSeduccion != null) {
      map['arquetipo_seduccion'] = Variable<String>(arquetipoSeduccion);
    }
    if (!nullToAbsent || vectorHorney != null) {
      map['vector_horney'] = Variable<String>(vectorHorney);
    }
    if (!nullToAbsent || mecanismoDefensa != null) {
      map['mecanismo_defensa'] = Variable<String>(mecanismoDefensa);
    }
    return map;
  }

  EgoWheelsCompanion toCompanion(bool nullToAbsent) {
    return EgoWheelsCompanion(
      id: Value(id),
      soulSheetUuid: Value(soulSheetUuid),
      eneatipoDaniels: eneatipoDaniels == null && nullToAbsent
          ? const Value.absent()
          : Value(eneatipoDaniels),
      arquetipoSeduccion: arquetipoSeduccion == null && nullToAbsent
          ? const Value.absent()
          : Value(arquetipoSeduccion),
      vectorHorney: vectorHorney == null && nullToAbsent
          ? const Value.absent()
          : Value(vectorHorney),
      mecanismoDefensa: mecanismoDefensa == null && nullToAbsent
          ? const Value.absent()
          : Value(mecanismoDefensa),
    );
  }

  factory EgoWheel.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EgoWheel(
      id: serializer.fromJson<int>(json['id']),
      soulSheetUuid: serializer.fromJson<String>(json['soulSheetUuid']),
      eneatipoDaniels: serializer.fromJson<int?>(json['eneatipoDaniels']),
      arquetipoSeduccion:
          serializer.fromJson<String?>(json['arquetipoSeduccion']),
      vectorHorney: serializer.fromJson<String?>(json['vectorHorney']),
      mecanismoDefensa: serializer.fromJson<String?>(json['mecanismoDefensa']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'soulSheetUuid': serializer.toJson<String>(soulSheetUuid),
      'eneatipoDaniels': serializer.toJson<int?>(eneatipoDaniels),
      'arquetipoSeduccion': serializer.toJson<String?>(arquetipoSeduccion),
      'vectorHorney': serializer.toJson<String?>(vectorHorney),
      'mecanismoDefensa': serializer.toJson<String?>(mecanismoDefensa),
    };
  }

  EgoWheel copyWith(
          {int? id,
          String? soulSheetUuid,
          Value<int?> eneatipoDaniels = const Value.absent(),
          Value<String?> arquetipoSeduccion = const Value.absent(),
          Value<String?> vectorHorney = const Value.absent(),
          Value<String?> mecanismoDefensa = const Value.absent()}) =>
      EgoWheel(
        id: id ?? this.id,
        soulSheetUuid: soulSheetUuid ?? this.soulSheetUuid,
        eneatipoDaniels: eneatipoDaniels.present
            ? eneatipoDaniels.value
            : this.eneatipoDaniels,
        arquetipoSeduccion: arquetipoSeduccion.present
            ? arquetipoSeduccion.value
            : this.arquetipoSeduccion,
        vectorHorney:
            vectorHorney.present ? vectorHorney.value : this.vectorHorney,
        mecanismoDefensa: mecanismoDefensa.present
            ? mecanismoDefensa.value
            : this.mecanismoDefensa,
      );
  EgoWheel copyWithCompanion(EgoWheelsCompanion data) {
    return EgoWheel(
      id: data.id.present ? data.id.value : this.id,
      soulSheetUuid: data.soulSheetUuid.present
          ? data.soulSheetUuid.value
          : this.soulSheetUuid,
      eneatipoDaniels: data.eneatipoDaniels.present
          ? data.eneatipoDaniels.value
          : this.eneatipoDaniels,
      arquetipoSeduccion: data.arquetipoSeduccion.present
          ? data.arquetipoSeduccion.value
          : this.arquetipoSeduccion,
      vectorHorney: data.vectorHorney.present
          ? data.vectorHorney.value
          : this.vectorHorney,
      mecanismoDefensa: data.mecanismoDefensa.present
          ? data.mecanismoDefensa.value
          : this.mecanismoDefensa,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EgoWheel(')
          ..write('id: $id, ')
          ..write('soulSheetUuid: $soulSheetUuid, ')
          ..write('eneatipoDaniels: $eneatipoDaniels, ')
          ..write('arquetipoSeduccion: $arquetipoSeduccion, ')
          ..write('vectorHorney: $vectorHorney, ')
          ..write('mecanismoDefensa: $mecanismoDefensa')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, soulSheetUuid, eneatipoDaniels,
      arquetipoSeduccion, vectorHorney, mecanismoDefensa);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EgoWheel &&
          other.id == this.id &&
          other.soulSheetUuid == this.soulSheetUuid &&
          other.eneatipoDaniels == this.eneatipoDaniels &&
          other.arquetipoSeduccion == this.arquetipoSeduccion &&
          other.vectorHorney == this.vectorHorney &&
          other.mecanismoDefensa == this.mecanismoDefensa);
}

class EgoWheelsCompanion extends UpdateCompanion<EgoWheel> {
  final Value<int> id;
  final Value<String> soulSheetUuid;
  final Value<int?> eneatipoDaniels;
  final Value<String?> arquetipoSeduccion;
  final Value<String?> vectorHorney;
  final Value<String?> mecanismoDefensa;
  const EgoWheelsCompanion({
    this.id = const Value.absent(),
    this.soulSheetUuid = const Value.absent(),
    this.eneatipoDaniels = const Value.absent(),
    this.arquetipoSeduccion = const Value.absent(),
    this.vectorHorney = const Value.absent(),
    this.mecanismoDefensa = const Value.absent(),
  });
  EgoWheelsCompanion.insert({
    this.id = const Value.absent(),
    required String soulSheetUuid,
    this.eneatipoDaniels = const Value.absent(),
    this.arquetipoSeduccion = const Value.absent(),
    this.vectorHorney = const Value.absent(),
    this.mecanismoDefensa = const Value.absent(),
  }) : soulSheetUuid = Value(soulSheetUuid);
  static Insertable<EgoWheel> custom({
    Expression<int>? id,
    Expression<String>? soulSheetUuid,
    Expression<int>? eneatipoDaniels,
    Expression<String>? arquetipoSeduccion,
    Expression<String>? vectorHorney,
    Expression<String>? mecanismoDefensa,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (soulSheetUuid != null) 'soul_sheet_uuid': soulSheetUuid,
      if (eneatipoDaniels != null) 'eneatipo_daniels': eneatipoDaniels,
      if (arquetipoSeduccion != null) 'arquetipo_seduccion': arquetipoSeduccion,
      if (vectorHorney != null) 'vector_horney': vectorHorney,
      if (mecanismoDefensa != null) 'mecanismo_defensa': mecanismoDefensa,
    });
  }

  EgoWheelsCompanion copyWith(
      {Value<int>? id,
      Value<String>? soulSheetUuid,
      Value<int?>? eneatipoDaniels,
      Value<String?>? arquetipoSeduccion,
      Value<String?>? vectorHorney,
      Value<String?>? mecanismoDefensa}) {
    return EgoWheelsCompanion(
      id: id ?? this.id,
      soulSheetUuid: soulSheetUuid ?? this.soulSheetUuid,
      eneatipoDaniels: eneatipoDaniels ?? this.eneatipoDaniels,
      arquetipoSeduccion: arquetipoSeduccion ?? this.arquetipoSeduccion,
      vectorHorney: vectorHorney ?? this.vectorHorney,
      mecanismoDefensa: mecanismoDefensa ?? this.mecanismoDefensa,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (soulSheetUuid.present) {
      map['soul_sheet_uuid'] = Variable<String>(soulSheetUuid.value);
    }
    if (eneatipoDaniels.present) {
      map['eneatipo_daniels'] = Variable<int>(eneatipoDaniels.value);
    }
    if (arquetipoSeduccion.present) {
      map['arquetipo_seduccion'] = Variable<String>(arquetipoSeduccion.value);
    }
    if (vectorHorney.present) {
      map['vector_horney'] = Variable<String>(vectorHorney.value);
    }
    if (mecanismoDefensa.present) {
      map['mecanismo_defensa'] = Variable<String>(mecanismoDefensa.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EgoWheelsCompanion(')
          ..write('id: $id, ')
          ..write('soulSheetUuid: $soulSheetUuid, ')
          ..write('eneatipoDaniels: $eneatipoDaniels, ')
          ..write('arquetipoSeduccion: $arquetipoSeduccion, ')
          ..write('vectorHorney: $vectorHorney, ')
          ..write('mecanismoDefensa: $mecanismoDefensa')
          ..write(')'))
        .toString();
  }
}

class $ErosWheelsTable extends ErosWheels
    with TableInfo<$ErosWheelsTable, ErosWheel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ErosWheelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _soulSheetUuidMeta =
      const VerificationMeta('soulSheetUuid');
  @override
  late final GeneratedColumn<String> soulSheetUuid = GeneratedColumn<String>(
      'soul_sheet_uuid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES soul_sheets (uuid)'));
  static const VerificationMeta _blueprintPrimarioMeta =
      const VerificationMeta('blueprintPrimario');
  @override
  late final GeneratedColumn<String> blueprintPrimario =
      GeneratedColumn<String>('blueprint_primario', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _escalaErotofiliaSosMeta =
      const VerificationMeta('escalaErotofiliaSos');
  @override
  late final GeneratedColumn<double> escalaErotofiliaSos =
      GeneratedColumn<double>('escala_erotofilia_sos', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _semaforoLimitesJsonMeta =
      const VerificationMeta('semaforoLimitesJson');
  @override
  late final GeneratedColumn<String> semaforoLimitesJson =
      GeneratedColumn<String>('semaforo_limites_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        soulSheetUuid,
        blueprintPrimario,
        escalaErotofiliaSos,
        semaforoLimitesJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'eros_wheels';
  @override
  VerificationContext validateIntegrity(Insertable<ErosWheel> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('soul_sheet_uuid')) {
      context.handle(
          _soulSheetUuidMeta,
          soulSheetUuid.isAcceptableOrUnknown(
              data['soul_sheet_uuid']!, _soulSheetUuidMeta));
    } else if (isInserting) {
      context.missing(_soulSheetUuidMeta);
    }
    if (data.containsKey('blueprint_primario')) {
      context.handle(
          _blueprintPrimarioMeta,
          blueprintPrimario.isAcceptableOrUnknown(
              data['blueprint_primario']!, _blueprintPrimarioMeta));
    }
    if (data.containsKey('escala_erotofilia_sos')) {
      context.handle(
          _escalaErotofiliaSosMeta,
          escalaErotofiliaSos.isAcceptableOrUnknown(
              data['escala_erotofilia_sos']!, _escalaErotofiliaSosMeta));
    }
    if (data.containsKey('semaforo_limites_json')) {
      context.handle(
          _semaforoLimitesJsonMeta,
          semaforoLimitesJson.isAcceptableOrUnknown(
              data['semaforo_limites_json']!, _semaforoLimitesJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ErosWheel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ErosWheel(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      soulSheetUuid: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}soul_sheet_uuid'])!,
      blueprintPrimario: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}blueprint_primario']),
      escalaErotofiliaSos: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}escala_erotofilia_sos']),
      semaforoLimitesJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}semaforo_limites_json']),
    );
  }

  @override
  $ErosWheelsTable createAlias(String alias) {
    return $ErosWheelsTable(attachedDatabase, alias);
  }
}

class ErosWheel extends DataClass implements Insertable<ErosWheel> {
  final int id;
  final String soulSheetUuid;
  final String? blueprintPrimario;
  final double? escalaErotofiliaSos;
  final String? semaforoLimitesJson;
  const ErosWheel(
      {required this.id,
      required this.soulSheetUuid,
      this.blueprintPrimario,
      this.escalaErotofiliaSos,
      this.semaforoLimitesJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['soul_sheet_uuid'] = Variable<String>(soulSheetUuid);
    if (!nullToAbsent || blueprintPrimario != null) {
      map['blueprint_primario'] = Variable<String>(blueprintPrimario);
    }
    if (!nullToAbsent || escalaErotofiliaSos != null) {
      map['escala_erotofilia_sos'] = Variable<double>(escalaErotofiliaSos);
    }
    if (!nullToAbsent || semaforoLimitesJson != null) {
      map['semaforo_limites_json'] = Variable<String>(semaforoLimitesJson);
    }
    return map;
  }

  ErosWheelsCompanion toCompanion(bool nullToAbsent) {
    return ErosWheelsCompanion(
      id: Value(id),
      soulSheetUuid: Value(soulSheetUuid),
      blueprintPrimario: blueprintPrimario == null && nullToAbsent
          ? const Value.absent()
          : Value(blueprintPrimario),
      escalaErotofiliaSos: escalaErotofiliaSos == null && nullToAbsent
          ? const Value.absent()
          : Value(escalaErotofiliaSos),
      semaforoLimitesJson: semaforoLimitesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(semaforoLimitesJson),
    );
  }

  factory ErosWheel.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ErosWheel(
      id: serializer.fromJson<int>(json['id']),
      soulSheetUuid: serializer.fromJson<String>(json['soulSheetUuid']),
      blueprintPrimario:
          serializer.fromJson<String?>(json['blueprintPrimario']),
      escalaErotofiliaSos:
          serializer.fromJson<double?>(json['escalaErotofiliaSos']),
      semaforoLimitesJson:
          serializer.fromJson<String?>(json['semaforoLimitesJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'soulSheetUuid': serializer.toJson<String>(soulSheetUuid),
      'blueprintPrimario': serializer.toJson<String?>(blueprintPrimario),
      'escalaErotofiliaSos': serializer.toJson<double?>(escalaErotofiliaSos),
      'semaforoLimitesJson': serializer.toJson<String?>(semaforoLimitesJson),
    };
  }

  ErosWheel copyWith(
          {int? id,
          String? soulSheetUuid,
          Value<String?> blueprintPrimario = const Value.absent(),
          Value<double?> escalaErotofiliaSos = const Value.absent(),
          Value<String?> semaforoLimitesJson = const Value.absent()}) =>
      ErosWheel(
        id: id ?? this.id,
        soulSheetUuid: soulSheetUuid ?? this.soulSheetUuid,
        blueprintPrimario: blueprintPrimario.present
            ? blueprintPrimario.value
            : this.blueprintPrimario,
        escalaErotofiliaSos: escalaErotofiliaSos.present
            ? escalaErotofiliaSos.value
            : this.escalaErotofiliaSos,
        semaforoLimitesJson: semaforoLimitesJson.present
            ? semaforoLimitesJson.value
            : this.semaforoLimitesJson,
      );
  ErosWheel copyWithCompanion(ErosWheelsCompanion data) {
    return ErosWheel(
      id: data.id.present ? data.id.value : this.id,
      soulSheetUuid: data.soulSheetUuid.present
          ? data.soulSheetUuid.value
          : this.soulSheetUuid,
      blueprintPrimario: data.blueprintPrimario.present
          ? data.blueprintPrimario.value
          : this.blueprintPrimario,
      escalaErotofiliaSos: data.escalaErotofiliaSos.present
          ? data.escalaErotofiliaSos.value
          : this.escalaErotofiliaSos,
      semaforoLimitesJson: data.semaforoLimitesJson.present
          ? data.semaforoLimitesJson.value
          : this.semaforoLimitesJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ErosWheel(')
          ..write('id: $id, ')
          ..write('soulSheetUuid: $soulSheetUuid, ')
          ..write('blueprintPrimario: $blueprintPrimario, ')
          ..write('escalaErotofiliaSos: $escalaErotofiliaSos, ')
          ..write('semaforoLimitesJson: $semaforoLimitesJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, soulSheetUuid, blueprintPrimario,
      escalaErotofiliaSos, semaforoLimitesJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ErosWheel &&
          other.id == this.id &&
          other.soulSheetUuid == this.soulSheetUuid &&
          other.blueprintPrimario == this.blueprintPrimario &&
          other.escalaErotofiliaSos == this.escalaErotofiliaSos &&
          other.semaforoLimitesJson == this.semaforoLimitesJson);
}

class ErosWheelsCompanion extends UpdateCompanion<ErosWheel> {
  final Value<int> id;
  final Value<String> soulSheetUuid;
  final Value<String?> blueprintPrimario;
  final Value<double?> escalaErotofiliaSos;
  final Value<String?> semaforoLimitesJson;
  const ErosWheelsCompanion({
    this.id = const Value.absent(),
    this.soulSheetUuid = const Value.absent(),
    this.blueprintPrimario = const Value.absent(),
    this.escalaErotofiliaSos = const Value.absent(),
    this.semaforoLimitesJson = const Value.absent(),
  });
  ErosWheelsCompanion.insert({
    this.id = const Value.absent(),
    required String soulSheetUuid,
    this.blueprintPrimario = const Value.absent(),
    this.escalaErotofiliaSos = const Value.absent(),
    this.semaforoLimitesJson = const Value.absent(),
  }) : soulSheetUuid = Value(soulSheetUuid);
  static Insertable<ErosWheel> custom({
    Expression<int>? id,
    Expression<String>? soulSheetUuid,
    Expression<String>? blueprintPrimario,
    Expression<double>? escalaErotofiliaSos,
    Expression<String>? semaforoLimitesJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (soulSheetUuid != null) 'soul_sheet_uuid': soulSheetUuid,
      if (blueprintPrimario != null) 'blueprint_primario': blueprintPrimario,
      if (escalaErotofiliaSos != null)
        'escala_erotofilia_sos': escalaErotofiliaSos,
      if (semaforoLimitesJson != null)
        'semaforo_limites_json': semaforoLimitesJson,
    });
  }

  ErosWheelsCompanion copyWith(
      {Value<int>? id,
      Value<String>? soulSheetUuid,
      Value<String?>? blueprintPrimario,
      Value<double?>? escalaErotofiliaSos,
      Value<String?>? semaforoLimitesJson}) {
    return ErosWheelsCompanion(
      id: id ?? this.id,
      soulSheetUuid: soulSheetUuid ?? this.soulSheetUuid,
      blueprintPrimario: blueprintPrimario ?? this.blueprintPrimario,
      escalaErotofiliaSos: escalaErotofiliaSos ?? this.escalaErotofiliaSos,
      semaforoLimitesJson: semaforoLimitesJson ?? this.semaforoLimitesJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (soulSheetUuid.present) {
      map['soul_sheet_uuid'] = Variable<String>(soulSheetUuid.value);
    }
    if (blueprintPrimario.present) {
      map['blueprint_primario'] = Variable<String>(blueprintPrimario.value);
    }
    if (escalaErotofiliaSos.present) {
      map['escala_erotofilia_sos'] =
          Variable<double>(escalaErotofiliaSos.value);
    }
    if (semaforoLimitesJson.present) {
      map['semaforo_limites_json'] =
          Variable<String>(semaforoLimitesJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ErosWheelsCompanion(')
          ..write('id: $id, ')
          ..write('soulSheetUuid: $soulSheetUuid, ')
          ..write('blueprintPrimario: $blueprintPrimario, ')
          ..write('escalaErotofiliaSos: $escalaErotofiliaSos, ')
          ..write('semaforoLimitesJson: $semaforoLimitesJson')
          ..write(')'))
        .toString();
  }
}

class $PhiliaWheelsTable extends PhiliaWheels
    with TableInfo<$PhiliaWheelsTable, PhiliaWheel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhiliaWheelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _soulSheetUuidMeta =
      const VerificationMeta('soulSheetUuid');
  @override
  late final GeneratedColumn<String> soulSheetUuid = GeneratedColumn<String>(
      'soul_sheet_uuid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES soul_sheets (uuid)'));
  static const VerificationMeta _estiloApegoMeta =
      const VerificationMeta('estiloApego');
  @override
  late final GeneratedColumn<String> estiloApego = GeneratedColumn<String>(
      'estilo_apego', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _modeloYoMeta =
      const VerificationMeta('modeloYo');
  @override
  late final GeneratedColumn<double> modeloYo = GeneratedColumn<double>(
      'modelo_yo', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _modeloOtroMeta =
      const VerificationMeta('modeloOtro');
  @override
  late final GeneratedColumn<double> modeloOtro = GeneratedColumn<double>(
      'modelo_otro', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _indiceDiferenciacionIarMeta =
      const VerificationMeta('indiceDiferenciacionIar');
  @override
  late final GeneratedColumn<double> indiceDiferenciacionIar =
      GeneratedColumn<double>('indice_diferenciacion_iar', aliasedName, true,
          type: DriftSqlType.double, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        soulSheetUuid,
        estiloApego,
        modeloYo,
        modeloOtro,
        indiceDiferenciacionIar
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'philia_wheels';
  @override
  VerificationContext validateIntegrity(Insertable<PhiliaWheel> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('soul_sheet_uuid')) {
      context.handle(
          _soulSheetUuidMeta,
          soulSheetUuid.isAcceptableOrUnknown(
              data['soul_sheet_uuid']!, _soulSheetUuidMeta));
    } else if (isInserting) {
      context.missing(_soulSheetUuidMeta);
    }
    if (data.containsKey('estilo_apego')) {
      context.handle(
          _estiloApegoMeta,
          estiloApego.isAcceptableOrUnknown(
              data['estilo_apego']!, _estiloApegoMeta));
    }
    if (data.containsKey('modelo_yo')) {
      context.handle(_modeloYoMeta,
          modeloYo.isAcceptableOrUnknown(data['modelo_yo']!, _modeloYoMeta));
    }
    if (data.containsKey('modelo_otro')) {
      context.handle(
          _modeloOtroMeta,
          modeloOtro.isAcceptableOrUnknown(
              data['modelo_otro']!, _modeloOtroMeta));
    }
    if (data.containsKey('indice_diferenciacion_iar')) {
      context.handle(
          _indiceDiferenciacionIarMeta,
          indiceDiferenciacionIar.isAcceptableOrUnknown(
              data['indice_diferenciacion_iar']!,
              _indiceDiferenciacionIarMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhiliaWheel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhiliaWheel(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      soulSheetUuid: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}soul_sheet_uuid'])!,
      estiloApego: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}estilo_apego']),
      modeloYo: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}modelo_yo']),
      modeloOtro: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}modelo_otro']),
      indiceDiferenciacionIar: attachedDatabase.typeMapping.read(
          DriftSqlType.double,
          data['${effectivePrefix}indice_diferenciacion_iar']),
    );
  }

  @override
  $PhiliaWheelsTable createAlias(String alias) {
    return $PhiliaWheelsTable(attachedDatabase, alias);
  }
}

class PhiliaWheel extends DataClass implements Insertable<PhiliaWheel> {
  final int id;
  final String soulSheetUuid;
  final String? estiloApego;
  final double? modeloYo;
  final double? modeloOtro;
  final double? indiceDiferenciacionIar;
  const PhiliaWheel(
      {required this.id,
      required this.soulSheetUuid,
      this.estiloApego,
      this.modeloYo,
      this.modeloOtro,
      this.indiceDiferenciacionIar});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['soul_sheet_uuid'] = Variable<String>(soulSheetUuid);
    if (!nullToAbsent || estiloApego != null) {
      map['estilo_apego'] = Variable<String>(estiloApego);
    }
    if (!nullToAbsent || modeloYo != null) {
      map['modelo_yo'] = Variable<double>(modeloYo);
    }
    if (!nullToAbsent || modeloOtro != null) {
      map['modelo_otro'] = Variable<double>(modeloOtro);
    }
    if (!nullToAbsent || indiceDiferenciacionIar != null) {
      map['indice_diferenciacion_iar'] =
          Variable<double>(indiceDiferenciacionIar);
    }
    return map;
  }

  PhiliaWheelsCompanion toCompanion(bool nullToAbsent) {
    return PhiliaWheelsCompanion(
      id: Value(id),
      soulSheetUuid: Value(soulSheetUuid),
      estiloApego: estiloApego == null && nullToAbsent
          ? const Value.absent()
          : Value(estiloApego),
      modeloYo: modeloYo == null && nullToAbsent
          ? const Value.absent()
          : Value(modeloYo),
      modeloOtro: modeloOtro == null && nullToAbsent
          ? const Value.absent()
          : Value(modeloOtro),
      indiceDiferenciacionIar: indiceDiferenciacionIar == null && nullToAbsent
          ? const Value.absent()
          : Value(indiceDiferenciacionIar),
    );
  }

  factory PhiliaWheel.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhiliaWheel(
      id: serializer.fromJson<int>(json['id']),
      soulSheetUuid: serializer.fromJson<String>(json['soulSheetUuid']),
      estiloApego: serializer.fromJson<String?>(json['estiloApego']),
      modeloYo: serializer.fromJson<double?>(json['modeloYo']),
      modeloOtro: serializer.fromJson<double?>(json['modeloOtro']),
      indiceDiferenciacionIar:
          serializer.fromJson<double?>(json['indiceDiferenciacionIar']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'soulSheetUuid': serializer.toJson<String>(soulSheetUuid),
      'estiloApego': serializer.toJson<String?>(estiloApego),
      'modeloYo': serializer.toJson<double?>(modeloYo),
      'modeloOtro': serializer.toJson<double?>(modeloOtro),
      'indiceDiferenciacionIar':
          serializer.toJson<double?>(indiceDiferenciacionIar),
    };
  }

  PhiliaWheel copyWith(
          {int? id,
          String? soulSheetUuid,
          Value<String?> estiloApego = const Value.absent(),
          Value<double?> modeloYo = const Value.absent(),
          Value<double?> modeloOtro = const Value.absent(),
          Value<double?> indiceDiferenciacionIar = const Value.absent()}) =>
      PhiliaWheel(
        id: id ?? this.id,
        soulSheetUuid: soulSheetUuid ?? this.soulSheetUuid,
        estiloApego: estiloApego.present ? estiloApego.value : this.estiloApego,
        modeloYo: modeloYo.present ? modeloYo.value : this.modeloYo,
        modeloOtro: modeloOtro.present ? modeloOtro.value : this.modeloOtro,
        indiceDiferenciacionIar: indiceDiferenciacionIar.present
            ? indiceDiferenciacionIar.value
            : this.indiceDiferenciacionIar,
      );
  PhiliaWheel copyWithCompanion(PhiliaWheelsCompanion data) {
    return PhiliaWheel(
      id: data.id.present ? data.id.value : this.id,
      soulSheetUuid: data.soulSheetUuid.present
          ? data.soulSheetUuid.value
          : this.soulSheetUuid,
      estiloApego:
          data.estiloApego.present ? data.estiloApego.value : this.estiloApego,
      modeloYo: data.modeloYo.present ? data.modeloYo.value : this.modeloYo,
      modeloOtro:
          data.modeloOtro.present ? data.modeloOtro.value : this.modeloOtro,
      indiceDiferenciacionIar: data.indiceDiferenciacionIar.present
          ? data.indiceDiferenciacionIar.value
          : this.indiceDiferenciacionIar,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhiliaWheel(')
          ..write('id: $id, ')
          ..write('soulSheetUuid: $soulSheetUuid, ')
          ..write('estiloApego: $estiloApego, ')
          ..write('modeloYo: $modeloYo, ')
          ..write('modeloOtro: $modeloOtro, ')
          ..write('indiceDiferenciacionIar: $indiceDiferenciacionIar')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, soulSheetUuid, estiloApego, modeloYo,
      modeloOtro, indiceDiferenciacionIar);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhiliaWheel &&
          other.id == this.id &&
          other.soulSheetUuid == this.soulSheetUuid &&
          other.estiloApego == this.estiloApego &&
          other.modeloYo == this.modeloYo &&
          other.modeloOtro == this.modeloOtro &&
          other.indiceDiferenciacionIar == this.indiceDiferenciacionIar);
}

class PhiliaWheelsCompanion extends UpdateCompanion<PhiliaWheel> {
  final Value<int> id;
  final Value<String> soulSheetUuid;
  final Value<String?> estiloApego;
  final Value<double?> modeloYo;
  final Value<double?> modeloOtro;
  final Value<double?> indiceDiferenciacionIar;
  const PhiliaWheelsCompanion({
    this.id = const Value.absent(),
    this.soulSheetUuid = const Value.absent(),
    this.estiloApego = const Value.absent(),
    this.modeloYo = const Value.absent(),
    this.modeloOtro = const Value.absent(),
    this.indiceDiferenciacionIar = const Value.absent(),
  });
  PhiliaWheelsCompanion.insert({
    this.id = const Value.absent(),
    required String soulSheetUuid,
    this.estiloApego = const Value.absent(),
    this.modeloYo = const Value.absent(),
    this.modeloOtro = const Value.absent(),
    this.indiceDiferenciacionIar = const Value.absent(),
  }) : soulSheetUuid = Value(soulSheetUuid);
  static Insertable<PhiliaWheel> custom({
    Expression<int>? id,
    Expression<String>? soulSheetUuid,
    Expression<String>? estiloApego,
    Expression<double>? modeloYo,
    Expression<double>? modeloOtro,
    Expression<double>? indiceDiferenciacionIar,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (soulSheetUuid != null) 'soul_sheet_uuid': soulSheetUuid,
      if (estiloApego != null) 'estilo_apego': estiloApego,
      if (modeloYo != null) 'modelo_yo': modeloYo,
      if (modeloOtro != null) 'modelo_otro': modeloOtro,
      if (indiceDiferenciacionIar != null)
        'indice_diferenciacion_iar': indiceDiferenciacionIar,
    });
  }

  PhiliaWheelsCompanion copyWith(
      {Value<int>? id,
      Value<String>? soulSheetUuid,
      Value<String?>? estiloApego,
      Value<double?>? modeloYo,
      Value<double?>? modeloOtro,
      Value<double?>? indiceDiferenciacionIar}) {
    return PhiliaWheelsCompanion(
      id: id ?? this.id,
      soulSheetUuid: soulSheetUuid ?? this.soulSheetUuid,
      estiloApego: estiloApego ?? this.estiloApego,
      modeloYo: modeloYo ?? this.modeloYo,
      modeloOtro: modeloOtro ?? this.modeloOtro,
      indiceDiferenciacionIar:
          indiceDiferenciacionIar ?? this.indiceDiferenciacionIar,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (soulSheetUuid.present) {
      map['soul_sheet_uuid'] = Variable<String>(soulSheetUuid.value);
    }
    if (estiloApego.present) {
      map['estilo_apego'] = Variable<String>(estiloApego.value);
    }
    if (modeloYo.present) {
      map['modelo_yo'] = Variable<double>(modeloYo.value);
    }
    if (modeloOtro.present) {
      map['modelo_otro'] = Variable<double>(modeloOtro.value);
    }
    if (indiceDiferenciacionIar.present) {
      map['indice_diferenciacion_iar'] =
          Variable<double>(indiceDiferenciacionIar.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhiliaWheelsCompanion(')
          ..write('id: $id, ')
          ..write('soulSheetUuid: $soulSheetUuid, ')
          ..write('estiloApego: $estiloApego, ')
          ..write('modeloYo: $modeloYo, ')
          ..write('modeloOtro: $modeloOtro, ')
          ..write('indiceDiferenciacionIar: $indiceDiferenciacionIar')
          ..write(')'))
        .toString();
  }
}

class $HarvestLogsTable extends HarvestLogs
    with TableInfo<$HarvestLogsTable, HarvestLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HarvestLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _soulSheetUuidMeta =
      const VerificationMeta('soulSheetUuid');
  @override
  late final GeneratedColumn<String> soulSheetUuid = GeneratedColumn<String>(
      'soul_sheet_uuid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES soul_sheets (uuid)'));
  static const VerificationMeta _dilemaIdMeta =
      const VerificationMeta('dilemaId');
  @override
  late final GeneratedColumn<String> dilemaId = GeneratedColumn<String>(
      'dilema_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _opcionSeleccionadaMeta =
      const VerificationMeta('opcionSeleccionada');
  @override
  late final GeneratedColumn<String> opcionSeleccionada =
      GeneratedColumn<String>('opcion_seleccionada', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, soulSheetUuid, dilemaId, opcionSeleccionada, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'harvest_logs';
  @override
  VerificationContext validateIntegrity(Insertable<HarvestLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('soul_sheet_uuid')) {
      context.handle(
          _soulSheetUuidMeta,
          soulSheetUuid.isAcceptableOrUnknown(
              data['soul_sheet_uuid']!, _soulSheetUuidMeta));
    } else if (isInserting) {
      context.missing(_soulSheetUuidMeta);
    }
    if (data.containsKey('dilema_id')) {
      context.handle(_dilemaIdMeta,
          dilemaId.isAcceptableOrUnknown(data['dilema_id']!, _dilemaIdMeta));
    } else if (isInserting) {
      context.missing(_dilemaIdMeta);
    }
    if (data.containsKey('opcion_seleccionada')) {
      context.handle(
          _opcionSeleccionadaMeta,
          opcionSeleccionada.isAcceptableOrUnknown(
              data['opcion_seleccionada']!, _opcionSeleccionadaMeta));
    } else if (isInserting) {
      context.missing(_opcionSeleccionadaMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HarvestLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HarvestLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      soulSheetUuid: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}soul_sheet_uuid'])!,
      dilemaId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dilema_id'])!,
      opcionSeleccionada: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}opcion_seleccionada'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $HarvestLogsTable createAlias(String alias) {
    return $HarvestLogsTable(attachedDatabase, alias);
  }
}

class HarvestLog extends DataClass implements Insertable<HarvestLog> {
  final String id;
  final String soulSheetUuid;
  final String dilemaId;
  final String opcionSeleccionada;
  final DateTime timestamp;
  const HarvestLog(
      {required this.id,
      required this.soulSheetUuid,
      required this.dilemaId,
      required this.opcionSeleccionada,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['soul_sheet_uuid'] = Variable<String>(soulSheetUuid);
    map['dilema_id'] = Variable<String>(dilemaId);
    map['opcion_seleccionada'] = Variable<String>(opcionSeleccionada);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  HarvestLogsCompanion toCompanion(bool nullToAbsent) {
    return HarvestLogsCompanion(
      id: Value(id),
      soulSheetUuid: Value(soulSheetUuid),
      dilemaId: Value(dilemaId),
      opcionSeleccionada: Value(opcionSeleccionada),
      timestamp: Value(timestamp),
    );
  }

  factory HarvestLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HarvestLog(
      id: serializer.fromJson<String>(json['id']),
      soulSheetUuid: serializer.fromJson<String>(json['soulSheetUuid']),
      dilemaId: serializer.fromJson<String>(json['dilemaId']),
      opcionSeleccionada:
          serializer.fromJson<String>(json['opcionSeleccionada']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'soulSheetUuid': serializer.toJson<String>(soulSheetUuid),
      'dilemaId': serializer.toJson<String>(dilemaId),
      'opcionSeleccionada': serializer.toJson<String>(opcionSeleccionada),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  HarvestLog copyWith(
          {String? id,
          String? soulSheetUuid,
          String? dilemaId,
          String? opcionSeleccionada,
          DateTime? timestamp}) =>
      HarvestLog(
        id: id ?? this.id,
        soulSheetUuid: soulSheetUuid ?? this.soulSheetUuid,
        dilemaId: dilemaId ?? this.dilemaId,
        opcionSeleccionada: opcionSeleccionada ?? this.opcionSeleccionada,
        timestamp: timestamp ?? this.timestamp,
      );
  HarvestLog copyWithCompanion(HarvestLogsCompanion data) {
    return HarvestLog(
      id: data.id.present ? data.id.value : this.id,
      soulSheetUuid: data.soulSheetUuid.present
          ? data.soulSheetUuid.value
          : this.soulSheetUuid,
      dilemaId: data.dilemaId.present ? data.dilemaId.value : this.dilemaId,
      opcionSeleccionada: data.opcionSeleccionada.present
          ? data.opcionSeleccionada.value
          : this.opcionSeleccionada,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HarvestLog(')
          ..write('id: $id, ')
          ..write('soulSheetUuid: $soulSheetUuid, ')
          ..write('dilemaId: $dilemaId, ')
          ..write('opcionSeleccionada: $opcionSeleccionada, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, soulSheetUuid, dilemaId, opcionSeleccionada, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HarvestLog &&
          other.id == this.id &&
          other.soulSheetUuid == this.soulSheetUuid &&
          other.dilemaId == this.dilemaId &&
          other.opcionSeleccionada == this.opcionSeleccionada &&
          other.timestamp == this.timestamp);
}

class HarvestLogsCompanion extends UpdateCompanion<HarvestLog> {
  final Value<String> id;
  final Value<String> soulSheetUuid;
  final Value<String> dilemaId;
  final Value<String> opcionSeleccionada;
  final Value<DateTime> timestamp;
  final Value<int> rowid;
  const HarvestLogsCompanion({
    this.id = const Value.absent(),
    this.soulSheetUuid = const Value.absent(),
    this.dilemaId = const Value.absent(),
    this.opcionSeleccionada = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HarvestLogsCompanion.insert({
    required String id,
    required String soulSheetUuid,
    required String dilemaId,
    required String opcionSeleccionada,
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        soulSheetUuid = Value(soulSheetUuid),
        dilemaId = Value(dilemaId),
        opcionSeleccionada = Value(opcionSeleccionada);
  static Insertable<HarvestLog> custom({
    Expression<String>? id,
    Expression<String>? soulSheetUuid,
    Expression<String>? dilemaId,
    Expression<String>? opcionSeleccionada,
    Expression<DateTime>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (soulSheetUuid != null) 'soul_sheet_uuid': soulSheetUuid,
      if (dilemaId != null) 'dilema_id': dilemaId,
      if (opcionSeleccionada != null) 'opcion_seleccionada': opcionSeleccionada,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HarvestLogsCompanion copyWith(
      {Value<String>? id,
      Value<String>? soulSheetUuid,
      Value<String>? dilemaId,
      Value<String>? opcionSeleccionada,
      Value<DateTime>? timestamp,
      Value<int>? rowid}) {
    return HarvestLogsCompanion(
      id: id ?? this.id,
      soulSheetUuid: soulSheetUuid ?? this.soulSheetUuid,
      dilemaId: dilemaId ?? this.dilemaId,
      opcionSeleccionada: opcionSeleccionada ?? this.opcionSeleccionada,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (soulSheetUuid.present) {
      map['soul_sheet_uuid'] = Variable<String>(soulSheetUuid.value);
    }
    if (dilemaId.present) {
      map['dilema_id'] = Variable<String>(dilemaId.value);
    }
    if (opcionSeleccionada.present) {
      map['opcion_seleccionada'] = Variable<String>(opcionSeleccionada.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HarvestLogsCompanion(')
          ..write('id: $id, ')
          ..write('soulSheetUuid: $soulSheetUuid, ')
          ..write('dilemaId: $dilemaId, ')
          ..write('opcionSeleccionada: $opcionSeleccionada, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SysConfigTable extends SysConfig
    with TableInfo<$SysConfigTable, SysConfigData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SysConfigTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sys_config';
  @override
  VerificationContext validateIntegrity(Insertable<SysConfigData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SysConfigData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SysConfigData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value']),
    );
  }

  @override
  $SysConfigTable createAlias(String alias) {
    return $SysConfigTable(attachedDatabase, alias);
  }
}

class SysConfigData extends DataClass implements Insertable<SysConfigData> {
  final String key;
  final String? value;
  const SysConfigData({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  SysConfigCompanion toCompanion(bool nullToAbsent) {
    return SysConfigCompanion(
      key: Value(key),
      value:
          value == null && nullToAbsent ? const Value.absent() : Value(value),
    );
  }

  factory SysConfigData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SysConfigData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  SysConfigData copyWith(
          {String? key, Value<String?> value = const Value.absent()}) =>
      SysConfigData(
        key: key ?? this.key,
        value: value.present ? value.value : this.value,
      );
  SysConfigData copyWithCompanion(SysConfigCompanion data) {
    return SysConfigData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SysConfigData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SysConfigData &&
          other.key == this.key &&
          other.value == this.value);
}

class SysConfigCompanion extends UpdateCompanion<SysConfigData> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const SysConfigCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SysConfigCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<SysConfigData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SysConfigCompanion copyWith(
      {Value<String>? key, Value<String?>? value, Value<int>? rowid}) {
    return SysConfigCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SysConfigCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AvatarSheetsTable extends AvatarSheets
    with TableInfo<$AvatarSheetsTable, AvatarSheet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AvatarSheetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _characterClassMeta =
      const VerificationMeta('characterClass');
  @override
  late final GeneratedColumn<String> characterClass = GeneratedColumn<String>(
      'character_class', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
      'level', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _experiencePointsMeta =
      const VerificationMeta('experiencePoints');
  @override
  late final GeneratedColumn<int> experiencePoints = GeneratedColumn<int>(
      'experience_points', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _reputationScoreMeta =
      const VerificationMeta('reputationScore');
  @override
  late final GeneratedColumn<double> reputationScore = GeneratedColumn<double>(
      'reputation_score', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _statsMeta = const VerificationMeta('stats');
  @override
  late final GeneratedColumn<String> stats = GeneratedColumn<String>(
      'stats', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _activeBuffsMeta =
      const VerificationMeta('activeBuffs');
  @override
  late final GeneratedColumn<String> activeBuffs = GeneratedColumn<String>(
      'active_buffs', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _activeDebuffsMeta =
      const VerificationMeta('activeDebuffs');
  @override
  late final GeneratedColumn<String> activeDebuffs = GeneratedColumn<String>(
      'active_debuffs', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        characterClass,
        level,
        experiencePoints,
        reputationScore,
        stats,
        activeBuffs,
        activeDebuffs
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'avatar_sheets';
  @override
  VerificationContext validateIntegrity(Insertable<AvatarSheet> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('character_class')) {
      context.handle(
          _characterClassMeta,
          characterClass.isAcceptableOrUnknown(
              data['character_class']!, _characterClassMeta));
    }
    if (data.containsKey('level')) {
      context.handle(
          _levelMeta, level.isAcceptableOrUnknown(data['level']!, _levelMeta));
    }
    if (data.containsKey('experience_points')) {
      context.handle(
          _experiencePointsMeta,
          experiencePoints.isAcceptableOrUnknown(
              data['experience_points']!, _experiencePointsMeta));
    }
    if (data.containsKey('reputation_score')) {
      context.handle(
          _reputationScoreMeta,
          reputationScore.isAcceptableOrUnknown(
              data['reputation_score']!, _reputationScoreMeta));
    }
    if (data.containsKey('stats')) {
      context.handle(
          _statsMeta, stats.isAcceptableOrUnknown(data['stats']!, _statsMeta));
    }
    if (data.containsKey('active_buffs')) {
      context.handle(
          _activeBuffsMeta,
          activeBuffs.isAcceptableOrUnknown(
              data['active_buffs']!, _activeBuffsMeta));
    }
    if (data.containsKey('active_debuffs')) {
      context.handle(
          _activeDebuffsMeta,
          activeDebuffs.isAcceptableOrUnknown(
              data['active_debuffs']!, _activeDebuffsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AvatarSheet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AvatarSheet(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      characterClass: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}character_class']),
      level: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}level']),
      experiencePoints: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}experience_points']),
      reputationScore: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}reputation_score']),
      stats: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stats']),
      activeBuffs: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}active_buffs']),
      activeDebuffs: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}active_debuffs']),
    );
  }

  @override
  $AvatarSheetsTable createAlias(String alias) {
    return $AvatarSheetsTable(attachedDatabase, alias);
  }
}

class AvatarSheet extends DataClass implements Insertable<AvatarSheet> {
  final String id;
  final String? characterClass;
  final int? level;
  final int? experiencePoints;
  final double? reputationScore;
  final String? stats;
  final String? activeBuffs;
  final String? activeDebuffs;
  const AvatarSheet(
      {required this.id,
      this.characterClass,
      this.level,
      this.experiencePoints,
      this.reputationScore,
      this.stats,
      this.activeBuffs,
      this.activeDebuffs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || characterClass != null) {
      map['character_class'] = Variable<String>(characterClass);
    }
    if (!nullToAbsent || level != null) {
      map['level'] = Variable<int>(level);
    }
    if (!nullToAbsent || experiencePoints != null) {
      map['experience_points'] = Variable<int>(experiencePoints);
    }
    if (!nullToAbsent || reputationScore != null) {
      map['reputation_score'] = Variable<double>(reputationScore);
    }
    if (!nullToAbsent || stats != null) {
      map['stats'] = Variable<String>(stats);
    }
    if (!nullToAbsent || activeBuffs != null) {
      map['active_buffs'] = Variable<String>(activeBuffs);
    }
    if (!nullToAbsent || activeDebuffs != null) {
      map['active_debuffs'] = Variable<String>(activeDebuffs);
    }
    return map;
  }

  AvatarSheetsCompanion toCompanion(bool nullToAbsent) {
    return AvatarSheetsCompanion(
      id: Value(id),
      characterClass: characterClass == null && nullToAbsent
          ? const Value.absent()
          : Value(characterClass),
      level:
          level == null && nullToAbsent ? const Value.absent() : Value(level),
      experiencePoints: experiencePoints == null && nullToAbsent
          ? const Value.absent()
          : Value(experiencePoints),
      reputationScore: reputationScore == null && nullToAbsent
          ? const Value.absent()
          : Value(reputationScore),
      stats:
          stats == null && nullToAbsent ? const Value.absent() : Value(stats),
      activeBuffs: activeBuffs == null && nullToAbsent
          ? const Value.absent()
          : Value(activeBuffs),
      activeDebuffs: activeDebuffs == null && nullToAbsent
          ? const Value.absent()
          : Value(activeDebuffs),
    );
  }

  factory AvatarSheet.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AvatarSheet(
      id: serializer.fromJson<String>(json['id']),
      characterClass: serializer.fromJson<String?>(json['characterClass']),
      level: serializer.fromJson<int?>(json['level']),
      experiencePoints: serializer.fromJson<int?>(json['experiencePoints']),
      reputationScore: serializer.fromJson<double?>(json['reputationScore']),
      stats: serializer.fromJson<String?>(json['stats']),
      activeBuffs: serializer.fromJson<String?>(json['activeBuffs']),
      activeDebuffs: serializer.fromJson<String?>(json['activeDebuffs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'characterClass': serializer.toJson<String?>(characterClass),
      'level': serializer.toJson<int?>(level),
      'experiencePoints': serializer.toJson<int?>(experiencePoints),
      'reputationScore': serializer.toJson<double?>(reputationScore),
      'stats': serializer.toJson<String?>(stats),
      'activeBuffs': serializer.toJson<String?>(activeBuffs),
      'activeDebuffs': serializer.toJson<String?>(activeDebuffs),
    };
  }

  AvatarSheet copyWith(
          {String? id,
          Value<String?> characterClass = const Value.absent(),
          Value<int?> level = const Value.absent(),
          Value<int?> experiencePoints = const Value.absent(),
          Value<double?> reputationScore = const Value.absent(),
          Value<String?> stats = const Value.absent(),
          Value<String?> activeBuffs = const Value.absent(),
          Value<String?> activeDebuffs = const Value.absent()}) =>
      AvatarSheet(
        id: id ?? this.id,
        characterClass:
            characterClass.present ? characterClass.value : this.characterClass,
        level: level.present ? level.value : this.level,
        experiencePoints: experiencePoints.present
            ? experiencePoints.value
            : this.experiencePoints,
        reputationScore: reputationScore.present
            ? reputationScore.value
            : this.reputationScore,
        stats: stats.present ? stats.value : this.stats,
        activeBuffs: activeBuffs.present ? activeBuffs.value : this.activeBuffs,
        activeDebuffs:
            activeDebuffs.present ? activeDebuffs.value : this.activeDebuffs,
      );
  AvatarSheet copyWithCompanion(AvatarSheetsCompanion data) {
    return AvatarSheet(
      id: data.id.present ? data.id.value : this.id,
      characterClass: data.characterClass.present
          ? data.characterClass.value
          : this.characterClass,
      level: data.level.present ? data.level.value : this.level,
      experiencePoints: data.experiencePoints.present
          ? data.experiencePoints.value
          : this.experiencePoints,
      reputationScore: data.reputationScore.present
          ? data.reputationScore.value
          : this.reputationScore,
      stats: data.stats.present ? data.stats.value : this.stats,
      activeBuffs:
          data.activeBuffs.present ? data.activeBuffs.value : this.activeBuffs,
      activeDebuffs: data.activeDebuffs.present
          ? data.activeDebuffs.value
          : this.activeDebuffs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AvatarSheet(')
          ..write('id: $id, ')
          ..write('characterClass: $characterClass, ')
          ..write('level: $level, ')
          ..write('experiencePoints: $experiencePoints, ')
          ..write('reputationScore: $reputationScore, ')
          ..write('stats: $stats, ')
          ..write('activeBuffs: $activeBuffs, ')
          ..write('activeDebuffs: $activeDebuffs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, characterClass, level, experiencePoints,
      reputationScore, stats, activeBuffs, activeDebuffs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AvatarSheet &&
          other.id == this.id &&
          other.characterClass == this.characterClass &&
          other.level == this.level &&
          other.experiencePoints == this.experiencePoints &&
          other.reputationScore == this.reputationScore &&
          other.stats == this.stats &&
          other.activeBuffs == this.activeBuffs &&
          other.activeDebuffs == this.activeDebuffs);
}

class AvatarSheetsCompanion extends UpdateCompanion<AvatarSheet> {
  final Value<String> id;
  final Value<String?> characterClass;
  final Value<int?> level;
  final Value<int?> experiencePoints;
  final Value<double?> reputationScore;
  final Value<String?> stats;
  final Value<String?> activeBuffs;
  final Value<String?> activeDebuffs;
  final Value<int> rowid;
  const AvatarSheetsCompanion({
    this.id = const Value.absent(),
    this.characterClass = const Value.absent(),
    this.level = const Value.absent(),
    this.experiencePoints = const Value.absent(),
    this.reputationScore = const Value.absent(),
    this.stats = const Value.absent(),
    this.activeBuffs = const Value.absent(),
    this.activeDebuffs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AvatarSheetsCompanion.insert({
    required String id,
    this.characterClass = const Value.absent(),
    this.level = const Value.absent(),
    this.experiencePoints = const Value.absent(),
    this.reputationScore = const Value.absent(),
    this.stats = const Value.absent(),
    this.activeBuffs = const Value.absent(),
    this.activeDebuffs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<AvatarSheet> custom({
    Expression<String>? id,
    Expression<String>? characterClass,
    Expression<int>? level,
    Expression<int>? experiencePoints,
    Expression<double>? reputationScore,
    Expression<String>? stats,
    Expression<String>? activeBuffs,
    Expression<String>? activeDebuffs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (characterClass != null) 'character_class': characterClass,
      if (level != null) 'level': level,
      if (experiencePoints != null) 'experience_points': experiencePoints,
      if (reputationScore != null) 'reputation_score': reputationScore,
      if (stats != null) 'stats': stats,
      if (activeBuffs != null) 'active_buffs': activeBuffs,
      if (activeDebuffs != null) 'active_debuffs': activeDebuffs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AvatarSheetsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? characterClass,
      Value<int?>? level,
      Value<int?>? experiencePoints,
      Value<double?>? reputationScore,
      Value<String?>? stats,
      Value<String?>? activeBuffs,
      Value<String?>? activeDebuffs,
      Value<int>? rowid}) {
    return AvatarSheetsCompanion(
      id: id ?? this.id,
      characterClass: characterClass ?? this.characterClass,
      level: level ?? this.level,
      experiencePoints: experiencePoints ?? this.experiencePoints,
      reputationScore: reputationScore ?? this.reputationScore,
      stats: stats ?? this.stats,
      activeBuffs: activeBuffs ?? this.activeBuffs,
      activeDebuffs: activeDebuffs ?? this.activeDebuffs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (characterClass.present) {
      map['character_class'] = Variable<String>(characterClass.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (experiencePoints.present) {
      map['experience_points'] = Variable<int>(experiencePoints.value);
    }
    if (reputationScore.present) {
      map['reputation_score'] = Variable<double>(reputationScore.value);
    }
    if (stats.present) {
      map['stats'] = Variable<String>(stats.value);
    }
    if (activeBuffs.present) {
      map['active_buffs'] = Variable<String>(activeBuffs.value);
    }
    if (activeDebuffs.present) {
      map['active_debuffs'] = Variable<String>(activeDebuffs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AvatarSheetsCompanion(')
          ..write('id: $id, ')
          ..write('characterClass: $characterClass, ')
          ..write('level: $level, ')
          ..write('experiencePoints: $experiencePoints, ')
          ..write('reputationScore: $reputationScore, ')
          ..write('stats: $stats, ')
          ..write('activeBuffs: $activeBuffs, ')
          ..write('activeDebuffs: $activeDebuffs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalMessagesTable extends LocalMessages
    with TableInfo<$LocalMessagesTable, LocalMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _guildIdMeta =
      const VerificationMeta('guildId');
  @override
  late final GeneratedColumn<String> guildId = GeneratedColumn<String>(
      'guild_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _senderIdMeta =
      const VerificationMeta('senderId');
  @override
  late final GeneratedColumn<String> senderId = GeneratedColumn<String>(
      'sender_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _encryptedBlobMeta =
      const VerificationMeta('encryptedBlob');
  @override
  late final GeneratedColumn<String> encryptedBlob = GeneratedColumn<String>(
      'encrypted_blob', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _decryptedContentMeta =
      const VerificationMeta('decryptedContent');
  @override
  late final GeneratedColumn<String> decryptedContent = GeneratedColumn<String>(
      'decrypted_content', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<String> timestamp = GeneratedColumn<String>(
      'timestamp', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, guildId, senderId, encryptedBlob, decryptedContent, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_messages';
  @override
  VerificationContext validateIntegrity(Insertable<LocalMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('guild_id')) {
      context.handle(_guildIdMeta,
          guildId.isAcceptableOrUnknown(data['guild_id']!, _guildIdMeta));
    }
    if (data.containsKey('sender_id')) {
      context.handle(_senderIdMeta,
          senderId.isAcceptableOrUnknown(data['sender_id']!, _senderIdMeta));
    }
    if (data.containsKey('encrypted_blob')) {
      context.handle(
          _encryptedBlobMeta,
          encryptedBlob.isAcceptableOrUnknown(
              data['encrypted_blob']!, _encryptedBlobMeta));
    }
    if (data.containsKey('decrypted_content')) {
      context.handle(
          _decryptedContentMeta,
          decryptedContent.isAcceptableOrUnknown(
              data['decrypted_content']!, _decryptedContentMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMessage(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      guildId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}guild_id']),
      senderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sender_id']),
      encryptedBlob: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}encrypted_blob']),
      decryptedContent: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}decrypted_content']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}timestamp']),
    );
  }

  @override
  $LocalMessagesTable createAlias(String alias) {
    return $LocalMessagesTable(attachedDatabase, alias);
  }
}

class LocalMessage extends DataClass implements Insertable<LocalMessage> {
  final String id;
  final String? guildId;
  final String? senderId;
  final String? encryptedBlob;
  final String? decryptedContent;
  final String? timestamp;
  const LocalMessage(
      {required this.id,
      this.guildId,
      this.senderId,
      this.encryptedBlob,
      this.decryptedContent,
      this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || guildId != null) {
      map['guild_id'] = Variable<String>(guildId);
    }
    if (!nullToAbsent || senderId != null) {
      map['sender_id'] = Variable<String>(senderId);
    }
    if (!nullToAbsent || encryptedBlob != null) {
      map['encrypted_blob'] = Variable<String>(encryptedBlob);
    }
    if (!nullToAbsent || decryptedContent != null) {
      map['decrypted_content'] = Variable<String>(decryptedContent);
    }
    if (!nullToAbsent || timestamp != null) {
      map['timestamp'] = Variable<String>(timestamp);
    }
    return map;
  }

  LocalMessagesCompanion toCompanion(bool nullToAbsent) {
    return LocalMessagesCompanion(
      id: Value(id),
      guildId: guildId == null && nullToAbsent
          ? const Value.absent()
          : Value(guildId),
      senderId: senderId == null && nullToAbsent
          ? const Value.absent()
          : Value(senderId),
      encryptedBlob: encryptedBlob == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedBlob),
      decryptedContent: decryptedContent == null && nullToAbsent
          ? const Value.absent()
          : Value(decryptedContent),
      timestamp: timestamp == null && nullToAbsent
          ? const Value.absent()
          : Value(timestamp),
    );
  }

  factory LocalMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMessage(
      id: serializer.fromJson<String>(json['id']),
      guildId: serializer.fromJson<String?>(json['guildId']),
      senderId: serializer.fromJson<String?>(json['senderId']),
      encryptedBlob: serializer.fromJson<String?>(json['encryptedBlob']),
      decryptedContent: serializer.fromJson<String?>(json['decryptedContent']),
      timestamp: serializer.fromJson<String?>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'guildId': serializer.toJson<String?>(guildId),
      'senderId': serializer.toJson<String?>(senderId),
      'encryptedBlob': serializer.toJson<String?>(encryptedBlob),
      'decryptedContent': serializer.toJson<String?>(decryptedContent),
      'timestamp': serializer.toJson<String?>(timestamp),
    };
  }

  LocalMessage copyWith(
          {String? id,
          Value<String?> guildId = const Value.absent(),
          Value<String?> senderId = const Value.absent(),
          Value<String?> encryptedBlob = const Value.absent(),
          Value<String?> decryptedContent = const Value.absent(),
          Value<String?> timestamp = const Value.absent()}) =>
      LocalMessage(
        id: id ?? this.id,
        guildId: guildId.present ? guildId.value : this.guildId,
        senderId: senderId.present ? senderId.value : this.senderId,
        encryptedBlob:
            encryptedBlob.present ? encryptedBlob.value : this.encryptedBlob,
        decryptedContent: decryptedContent.present
            ? decryptedContent.value
            : this.decryptedContent,
        timestamp: timestamp.present ? timestamp.value : this.timestamp,
      );
  LocalMessage copyWithCompanion(LocalMessagesCompanion data) {
    return LocalMessage(
      id: data.id.present ? data.id.value : this.id,
      guildId: data.guildId.present ? data.guildId.value : this.guildId,
      senderId: data.senderId.present ? data.senderId.value : this.senderId,
      encryptedBlob: data.encryptedBlob.present
          ? data.encryptedBlob.value
          : this.encryptedBlob,
      decryptedContent: data.decryptedContent.present
          ? data.decryptedContent.value
          : this.decryptedContent,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessage(')
          ..write('id: $id, ')
          ..write('guildId: $guildId, ')
          ..write('senderId: $senderId, ')
          ..write('encryptedBlob: $encryptedBlob, ')
          ..write('decryptedContent: $decryptedContent, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, guildId, senderId, encryptedBlob, decryptedContent, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMessage &&
          other.id == this.id &&
          other.guildId == this.guildId &&
          other.senderId == this.senderId &&
          other.encryptedBlob == this.encryptedBlob &&
          other.decryptedContent == this.decryptedContent &&
          other.timestamp == this.timestamp);
}

class LocalMessagesCompanion extends UpdateCompanion<LocalMessage> {
  final Value<String> id;
  final Value<String?> guildId;
  final Value<String?> senderId;
  final Value<String?> encryptedBlob;
  final Value<String?> decryptedContent;
  final Value<String?> timestamp;
  final Value<int> rowid;
  const LocalMessagesCompanion({
    this.id = const Value.absent(),
    this.guildId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.encryptedBlob = const Value.absent(),
    this.decryptedContent = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMessagesCompanion.insert({
    required String id,
    this.guildId = const Value.absent(),
    this.senderId = const Value.absent(),
    this.encryptedBlob = const Value.absent(),
    this.decryptedContent = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<LocalMessage> custom({
    Expression<String>? id,
    Expression<String>? guildId,
    Expression<String>? senderId,
    Expression<String>? encryptedBlob,
    Expression<String>? decryptedContent,
    Expression<String>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (guildId != null) 'guild_id': guildId,
      if (senderId != null) 'sender_id': senderId,
      if (encryptedBlob != null) 'encrypted_blob': encryptedBlob,
      if (decryptedContent != null) 'decrypted_content': decryptedContent,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMessagesCompanion copyWith(
      {Value<String>? id,
      Value<String?>? guildId,
      Value<String?>? senderId,
      Value<String?>? encryptedBlob,
      Value<String?>? decryptedContent,
      Value<String?>? timestamp,
      Value<int>? rowid}) {
    return LocalMessagesCompanion(
      id: id ?? this.id,
      guildId: guildId ?? this.guildId,
      senderId: senderId ?? this.senderId,
      encryptedBlob: encryptedBlob ?? this.encryptedBlob,
      decryptedContent: decryptedContent ?? this.decryptedContent,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (guildId.present) {
      map['guild_id'] = Variable<String>(guildId.value);
    }
    if (senderId.present) {
      map['sender_id'] = Variable<String>(senderId.value);
    }
    if (encryptedBlob.present) {
      map['encrypted_blob'] = Variable<String>(encryptedBlob.value);
    }
    if (decryptedContent.present) {
      map['decrypted_content'] = Variable<String>(decryptedContent.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<String>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessagesCompanion(')
          ..write('id: $id, ')
          ..write('guildId: $guildId, ')
          ..write('senderId: $senderId, ')
          ..write('encryptedBlob: $encryptedBlob, ')
          ..write('decryptedContent: $decryptedContent, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalQuestsTable extends LocalQuests
    with TableInfo<$LocalQuestsTable, LocalQuest> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalQuestsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceTypeMeta =
      const VerificationMeta('sourceType');
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
      'source_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rewardVinksMeta =
      const VerificationMeta('rewardVinks');
  @override
  late final GeneratedColumn<int> rewardVinks = GeneratedColumn<int>(
      'reward_vinks', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _xpRewardMeta =
      const VerificationMeta('xpReward');
  @override
  late final GeneratedColumn<int> xpReward = GeneratedColumn<int>(
      'xp_reward', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _minLevelMeta =
      const VerificationMeta('minLevel');
  @override
  late final GeneratedColumn<int> minLevel = GeneratedColumn<int>(
      'min_level', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _requiredQuestIdMeta =
      const VerificationMeta('requiredQuestId');
  @override
  late final GeneratedColumn<String> requiredQuestId = GeneratedColumn<String>(
      'required_quest_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        description,
        sourceType,
        rewardVinks,
        xpReward,
        status,
        minLevel,
        requiredQuestId,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_quests';
  @override
  VerificationContext validateIntegrity(Insertable<LocalQuest> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('source_type')) {
      context.handle(
          _sourceTypeMeta,
          sourceType.isAcceptableOrUnknown(
              data['source_type']!, _sourceTypeMeta));
    }
    if (data.containsKey('reward_vinks')) {
      context.handle(
          _rewardVinksMeta,
          rewardVinks.isAcceptableOrUnknown(
              data['reward_vinks']!, _rewardVinksMeta));
    }
    if (data.containsKey('xp_reward')) {
      context.handle(_xpRewardMeta,
          xpReward.isAcceptableOrUnknown(data['xp_reward']!, _xpRewardMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('min_level')) {
      context.handle(_minLevelMeta,
          minLevel.isAcceptableOrUnknown(data['min_level']!, _minLevelMeta));
    }
    if (data.containsKey('required_quest_id')) {
      context.handle(
          _requiredQuestIdMeta,
          requiredQuestId.isAcceptableOrUnknown(
              data['required_quest_id']!, _requiredQuestIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalQuest map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalQuest(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title']),
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      sourceType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_type']),
      rewardVinks: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reward_vinks']),
      xpReward: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}xp_reward']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status']),
      minLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}min_level'])!,
      requiredQuestId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}required_quest_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at']),
    );
  }

  @override
  $LocalQuestsTable createAlias(String alias) {
    return $LocalQuestsTable(attachedDatabase, alias);
  }
}

class LocalQuest extends DataClass implements Insertable<LocalQuest> {
  final String id;
  final String? title;
  final String? description;
  final String? sourceType;
  final int? rewardVinks;
  final int? xpReward;
  final String? status;
  final int minLevel;
  final String? requiredQuestId;
  final String? createdAt;
  const LocalQuest(
      {required this.id,
      this.title,
      this.description,
      this.sourceType,
      this.rewardVinks,
      this.xpReward,
      this.status,
      required this.minLevel,
      this.requiredQuestId,
      this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || sourceType != null) {
      map['source_type'] = Variable<String>(sourceType);
    }
    if (!nullToAbsent || rewardVinks != null) {
      map['reward_vinks'] = Variable<int>(rewardVinks);
    }
    if (!nullToAbsent || xpReward != null) {
      map['xp_reward'] = Variable<int>(xpReward);
    }
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    map['min_level'] = Variable<int>(minLevel);
    if (!nullToAbsent || requiredQuestId != null) {
      map['required_quest_id'] = Variable<String>(requiredQuestId);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    return map;
  }

  LocalQuestsCompanion toCompanion(bool nullToAbsent) {
    return LocalQuestsCompanion(
      id: Value(id),
      title:
          title == null && nullToAbsent ? const Value.absent() : Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      sourceType: sourceType == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceType),
      rewardVinks: rewardVinks == null && nullToAbsent
          ? const Value.absent()
          : Value(rewardVinks),
      xpReward: xpReward == null && nullToAbsent
          ? const Value.absent()
          : Value(xpReward),
      status:
          status == null && nullToAbsent ? const Value.absent() : Value(status),
      minLevel: Value(minLevel),
      requiredQuestId: requiredQuestId == null && nullToAbsent
          ? const Value.absent()
          : Value(requiredQuestId),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory LocalQuest.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalQuest(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String?>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      sourceType: serializer.fromJson<String?>(json['sourceType']),
      rewardVinks: serializer.fromJson<int?>(json['rewardVinks']),
      xpReward: serializer.fromJson<int?>(json['xpReward']),
      status: serializer.fromJson<String?>(json['status']),
      minLevel: serializer.fromJson<int>(json['minLevel']),
      requiredQuestId: serializer.fromJson<String?>(json['requiredQuestId']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String?>(title),
      'description': serializer.toJson<String?>(description),
      'sourceType': serializer.toJson<String?>(sourceType),
      'rewardVinks': serializer.toJson<int?>(rewardVinks),
      'xpReward': serializer.toJson<int?>(xpReward),
      'status': serializer.toJson<String?>(status),
      'minLevel': serializer.toJson<int>(minLevel),
      'requiredQuestId': serializer.toJson<String?>(requiredQuestId),
      'createdAt': serializer.toJson<String?>(createdAt),
    };
  }

  LocalQuest copyWith(
          {String? id,
          Value<String?> title = const Value.absent(),
          Value<String?> description = const Value.absent(),
          Value<String?> sourceType = const Value.absent(),
          Value<int?> rewardVinks = const Value.absent(),
          Value<int?> xpReward = const Value.absent(),
          Value<String?> status = const Value.absent(),
          int? minLevel,
          Value<String?> requiredQuestId = const Value.absent(),
          Value<String?> createdAt = const Value.absent()}) =>
      LocalQuest(
        id: id ?? this.id,
        title: title.present ? title.value : this.title,
        description: description.present ? description.value : this.description,
        sourceType: sourceType.present ? sourceType.value : this.sourceType,
        rewardVinks: rewardVinks.present ? rewardVinks.value : this.rewardVinks,
        xpReward: xpReward.present ? xpReward.value : this.xpReward,
        status: status.present ? status.value : this.status,
        minLevel: minLevel ?? this.minLevel,
        requiredQuestId: requiredQuestId.present
            ? requiredQuestId.value
            : this.requiredQuestId,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
      );
  LocalQuest copyWithCompanion(LocalQuestsCompanion data) {
    return LocalQuest(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description:
          data.description.present ? data.description.value : this.description,
      sourceType:
          data.sourceType.present ? data.sourceType.value : this.sourceType,
      rewardVinks:
          data.rewardVinks.present ? data.rewardVinks.value : this.rewardVinks,
      xpReward: data.xpReward.present ? data.xpReward.value : this.xpReward,
      status: data.status.present ? data.status.value : this.status,
      minLevel: data.minLevel.present ? data.minLevel.value : this.minLevel,
      requiredQuestId: data.requiredQuestId.present
          ? data.requiredQuestId.value
          : this.requiredQuestId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalQuest(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('sourceType: $sourceType, ')
          ..write('rewardVinks: $rewardVinks, ')
          ..write('xpReward: $xpReward, ')
          ..write('status: $status, ')
          ..write('minLevel: $minLevel, ')
          ..write('requiredQuestId: $requiredQuestId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, description, sourceType,
      rewardVinks, xpReward, status, minLevel, requiredQuestId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalQuest &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.sourceType == this.sourceType &&
          other.rewardVinks == this.rewardVinks &&
          other.xpReward == this.xpReward &&
          other.status == this.status &&
          other.minLevel == this.minLevel &&
          other.requiredQuestId == this.requiredQuestId &&
          other.createdAt == this.createdAt);
}

class LocalQuestsCompanion extends UpdateCompanion<LocalQuest> {
  final Value<String> id;
  final Value<String?> title;
  final Value<String?> description;
  final Value<String?> sourceType;
  final Value<int?> rewardVinks;
  final Value<int?> xpReward;
  final Value<String?> status;
  final Value<int> minLevel;
  final Value<String?> requiredQuestId;
  final Value<String?> createdAt;
  final Value<int> rowid;
  const LocalQuestsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.rewardVinks = const Value.absent(),
    this.xpReward = const Value.absent(),
    this.status = const Value.absent(),
    this.minLevel = const Value.absent(),
    this.requiredQuestId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalQuestsCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.rewardVinks = const Value.absent(),
    this.xpReward = const Value.absent(),
    this.status = const Value.absent(),
    this.minLevel = const Value.absent(),
    this.requiredQuestId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<LocalQuest> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? sourceType,
    Expression<int>? rewardVinks,
    Expression<int>? xpReward,
    Expression<String>? status,
    Expression<int>? minLevel,
    Expression<String>? requiredQuestId,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (sourceType != null) 'source_type': sourceType,
      if (rewardVinks != null) 'reward_vinks': rewardVinks,
      if (xpReward != null) 'xp_reward': xpReward,
      if (status != null) 'status': status,
      if (minLevel != null) 'min_level': minLevel,
      if (requiredQuestId != null) 'required_quest_id': requiredQuestId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalQuestsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? title,
      Value<String?>? description,
      Value<String?>? sourceType,
      Value<int?>? rewardVinks,
      Value<int?>? xpReward,
      Value<String?>? status,
      Value<int>? minLevel,
      Value<String?>? requiredQuestId,
      Value<String?>? createdAt,
      Value<int>? rowid}) {
    return LocalQuestsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      sourceType: sourceType ?? this.sourceType,
      rewardVinks: rewardVinks ?? this.rewardVinks,
      xpReward: xpReward ?? this.xpReward,
      status: status ?? this.status,
      minLevel: minLevel ?? this.minLevel,
      requiredQuestId: requiredQuestId ?? this.requiredQuestId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (rewardVinks.present) {
      map['reward_vinks'] = Variable<int>(rewardVinks.value);
    }
    if (xpReward.present) {
      map['xp_reward'] = Variable<int>(xpReward.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (minLevel.present) {
      map['min_level'] = Variable<int>(minLevel.value);
    }
    if (requiredQuestId.present) {
      map['required_quest_id'] = Variable<String>(requiredQuestId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalQuestsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('sourceType: $sourceType, ')
          ..write('rewardVinks: $rewardVinks, ')
          ..write('xpReward: $xpReward, ')
          ..write('status: $status, ')
          ..write('minLevel: $minLevel, ')
          ..write('requiredQuestId: $requiredQuestId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalContactsTable extends LocalContacts
    with TableInfo<$LocalContactsTable, LocalContact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
      'alias', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _characterClassMeta =
      const VerificationMeta('characterClass');
  @override
  late final GeneratedColumn<String> characterClass = GeneratedColumn<String>(
      'character_class', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _relationshipTypeMeta =
      const VerificationMeta('relationshipType');
  @override
  late final GeneratedColumn<String> relationshipType = GeneratedColumn<String>(
      'relationship_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('FRIEND'));
  static const VerificationMeta _sscLevelMeta =
      const VerificationMeta('sscLevel');
  @override
  late final GeneratedColumn<String> sscLevel = GeneratedColumn<String>(
      'ssc_level', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('GREEN'));
  static const VerificationMeta _isActiveMeta =
      const VerificationMeta('isActive');
  @override
  late final GeneratedColumn<int> isActive = GeneratedColumn<int>(
      'is_active', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _reputationScoreMeta =
      const VerificationMeta('reputationScore');
  @override
  late final GeneratedColumn<double> reputationScore = GeneratedColumn<double>(
      'reputation_score', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1.0));
  static const VerificationMeta _lastInteractionMeta =
      const VerificationMeta('lastInteraction');
  @override
  late final GeneratedColumn<String> lastInteraction = GeneratedColumn<String>(
      'last_interaction', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        alias,
        characterClass,
        relationshipType,
        sscLevel,
        isActive,
        reputationScore,
        lastInteraction,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_contacts';
  @override
  VerificationContext validateIntegrity(Insertable<LocalContact> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('alias')) {
      context.handle(
          _aliasMeta, alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta));
    } else if (isInserting) {
      context.missing(_aliasMeta);
    }
    if (data.containsKey('character_class')) {
      context.handle(
          _characterClassMeta,
          characterClass.isAcceptableOrUnknown(
              data['character_class']!, _characterClassMeta));
    }
    if (data.containsKey('relationship_type')) {
      context.handle(
          _relationshipTypeMeta,
          relationshipType.isAcceptableOrUnknown(
              data['relationship_type']!, _relationshipTypeMeta));
    }
    if (data.containsKey('ssc_level')) {
      context.handle(_sscLevelMeta,
          sscLevel.isAcceptableOrUnknown(data['ssc_level']!, _sscLevelMeta));
    }
    if (data.containsKey('is_active')) {
      context.handle(_isActiveMeta,
          isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta));
    }
    if (data.containsKey('reputation_score')) {
      context.handle(
          _reputationScoreMeta,
          reputationScore.isAcceptableOrUnknown(
              data['reputation_score']!, _reputationScoreMeta));
    }
    if (data.containsKey('last_interaction')) {
      context.handle(
          _lastInteractionMeta,
          lastInteraction.isAcceptableOrUnknown(
              data['last_interaction']!, _lastInteractionMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalContact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalContact(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      alias: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}alias'])!,
      characterClass: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}character_class']),
      relationshipType: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}relationship_type'])!,
      sscLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ssc_level'])!,
      isActive: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}is_active'])!,
      reputationScore: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}reputation_score'])!,
      lastInteraction: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}last_interaction']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at']),
    );
  }

  @override
  $LocalContactsTable createAlias(String alias) {
    return $LocalContactsTable(attachedDatabase, alias);
  }
}

class LocalContact extends DataClass implements Insertable<LocalContact> {
  final String id;
  final String alias;
  final String? characterClass;
  final String relationshipType;
  final String sscLevel;
  final int isActive;
  final double reputationScore;
  final String? lastInteraction;
  final String? createdAt;
  const LocalContact(
      {required this.id,
      required this.alias,
      this.characterClass,
      required this.relationshipType,
      required this.sscLevel,
      required this.isActive,
      required this.reputationScore,
      this.lastInteraction,
      this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['alias'] = Variable<String>(alias);
    if (!nullToAbsent || characterClass != null) {
      map['character_class'] = Variable<String>(characterClass);
    }
    map['relationship_type'] = Variable<String>(relationshipType);
    map['ssc_level'] = Variable<String>(sscLevel);
    map['is_active'] = Variable<int>(isActive);
    map['reputation_score'] = Variable<double>(reputationScore);
    if (!nullToAbsent || lastInteraction != null) {
      map['last_interaction'] = Variable<String>(lastInteraction);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    return map;
  }

  LocalContactsCompanion toCompanion(bool nullToAbsent) {
    return LocalContactsCompanion(
      id: Value(id),
      alias: Value(alias),
      characterClass: characterClass == null && nullToAbsent
          ? const Value.absent()
          : Value(characterClass),
      relationshipType: Value(relationshipType),
      sscLevel: Value(sscLevel),
      isActive: Value(isActive),
      reputationScore: Value(reputationScore),
      lastInteraction: lastInteraction == null && nullToAbsent
          ? const Value.absent()
          : Value(lastInteraction),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory LocalContact.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalContact(
      id: serializer.fromJson<String>(json['id']),
      alias: serializer.fromJson<String>(json['alias']),
      characterClass: serializer.fromJson<String?>(json['characterClass']),
      relationshipType: serializer.fromJson<String>(json['relationshipType']),
      sscLevel: serializer.fromJson<String>(json['sscLevel']),
      isActive: serializer.fromJson<int>(json['isActive']),
      reputationScore: serializer.fromJson<double>(json['reputationScore']),
      lastInteraction: serializer.fromJson<String?>(json['lastInteraction']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'alias': serializer.toJson<String>(alias),
      'characterClass': serializer.toJson<String?>(characterClass),
      'relationshipType': serializer.toJson<String>(relationshipType),
      'sscLevel': serializer.toJson<String>(sscLevel),
      'isActive': serializer.toJson<int>(isActive),
      'reputationScore': serializer.toJson<double>(reputationScore),
      'lastInteraction': serializer.toJson<String?>(lastInteraction),
      'createdAt': serializer.toJson<String?>(createdAt),
    };
  }

  LocalContact copyWith(
          {String? id,
          String? alias,
          Value<String?> characterClass = const Value.absent(),
          String? relationshipType,
          String? sscLevel,
          int? isActive,
          double? reputationScore,
          Value<String?> lastInteraction = const Value.absent(),
          Value<String?> createdAt = const Value.absent()}) =>
      LocalContact(
        id: id ?? this.id,
        alias: alias ?? this.alias,
        characterClass:
            characterClass.present ? characterClass.value : this.characterClass,
        relationshipType: relationshipType ?? this.relationshipType,
        sscLevel: sscLevel ?? this.sscLevel,
        isActive: isActive ?? this.isActive,
        reputationScore: reputationScore ?? this.reputationScore,
        lastInteraction: lastInteraction.present
            ? lastInteraction.value
            : this.lastInteraction,
        createdAt: createdAt.present ? createdAt.value : this.createdAt,
      );
  LocalContact copyWithCompanion(LocalContactsCompanion data) {
    return LocalContact(
      id: data.id.present ? data.id.value : this.id,
      alias: data.alias.present ? data.alias.value : this.alias,
      characterClass: data.characterClass.present
          ? data.characterClass.value
          : this.characterClass,
      relationshipType: data.relationshipType.present
          ? data.relationshipType.value
          : this.relationshipType,
      sscLevel: data.sscLevel.present ? data.sscLevel.value : this.sscLevel,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      reputationScore: data.reputationScore.present
          ? data.reputationScore.value
          : this.reputationScore,
      lastInteraction: data.lastInteraction.present
          ? data.lastInteraction.value
          : this.lastInteraction,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalContact(')
          ..write('id: $id, ')
          ..write('alias: $alias, ')
          ..write('characterClass: $characterClass, ')
          ..write('relationshipType: $relationshipType, ')
          ..write('sscLevel: $sscLevel, ')
          ..write('isActive: $isActive, ')
          ..write('reputationScore: $reputationScore, ')
          ..write('lastInteraction: $lastInteraction, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, alias, characterClass, relationshipType,
      sscLevel, isActive, reputationScore, lastInteraction, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalContact &&
          other.id == this.id &&
          other.alias == this.alias &&
          other.characterClass == this.characterClass &&
          other.relationshipType == this.relationshipType &&
          other.sscLevel == this.sscLevel &&
          other.isActive == this.isActive &&
          other.reputationScore == this.reputationScore &&
          other.lastInteraction == this.lastInteraction &&
          other.createdAt == this.createdAt);
}

class LocalContactsCompanion extends UpdateCompanion<LocalContact> {
  final Value<String> id;
  final Value<String> alias;
  final Value<String?> characterClass;
  final Value<String> relationshipType;
  final Value<String> sscLevel;
  final Value<int> isActive;
  final Value<double> reputationScore;
  final Value<String?> lastInteraction;
  final Value<String?> createdAt;
  final Value<int> rowid;
  const LocalContactsCompanion({
    this.id = const Value.absent(),
    this.alias = const Value.absent(),
    this.characterClass = const Value.absent(),
    this.relationshipType = const Value.absent(),
    this.sscLevel = const Value.absent(),
    this.isActive = const Value.absent(),
    this.reputationScore = const Value.absent(),
    this.lastInteraction = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalContactsCompanion.insert({
    required String id,
    required String alias,
    this.characterClass = const Value.absent(),
    this.relationshipType = const Value.absent(),
    this.sscLevel = const Value.absent(),
    this.isActive = const Value.absent(),
    this.reputationScore = const Value.absent(),
    this.lastInteraction = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        alias = Value(alias);
  static Insertable<LocalContact> custom({
    Expression<String>? id,
    Expression<String>? alias,
    Expression<String>? characterClass,
    Expression<String>? relationshipType,
    Expression<String>? sscLevel,
    Expression<int>? isActive,
    Expression<double>? reputationScore,
    Expression<String>? lastInteraction,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (alias != null) 'alias': alias,
      if (characterClass != null) 'character_class': characterClass,
      if (relationshipType != null) 'relationship_type': relationshipType,
      if (sscLevel != null) 'ssc_level': sscLevel,
      if (isActive != null) 'is_active': isActive,
      if (reputationScore != null) 'reputation_score': reputationScore,
      if (lastInteraction != null) 'last_interaction': lastInteraction,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalContactsCompanion copyWith(
      {Value<String>? id,
      Value<String>? alias,
      Value<String?>? characterClass,
      Value<String>? relationshipType,
      Value<String>? sscLevel,
      Value<int>? isActive,
      Value<double>? reputationScore,
      Value<String?>? lastInteraction,
      Value<String?>? createdAt,
      Value<int>? rowid}) {
    return LocalContactsCompanion(
      id: id ?? this.id,
      alias: alias ?? this.alias,
      characterClass: characterClass ?? this.characterClass,
      relationshipType: relationshipType ?? this.relationshipType,
      sscLevel: sscLevel ?? this.sscLevel,
      isActive: isActive ?? this.isActive,
      reputationScore: reputationScore ?? this.reputationScore,
      lastInteraction: lastInteraction ?? this.lastInteraction,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (characterClass.present) {
      map['character_class'] = Variable<String>(characterClass.value);
    }
    if (relationshipType.present) {
      map['relationship_type'] = Variable<String>(relationshipType.value);
    }
    if (sscLevel.present) {
      map['ssc_level'] = Variable<String>(sscLevel.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<int>(isActive.value);
    }
    if (reputationScore.present) {
      map['reputation_score'] = Variable<double>(reputationScore.value);
    }
    if (lastInteraction.present) {
      map['last_interaction'] = Variable<String>(lastInteraction.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalContactsCompanion(')
          ..write('id: $id, ')
          ..write('alias: $alias, ')
          ..write('characterClass: $characterClass, ')
          ..write('relationshipType: $relationshipType, ')
          ..write('sscLevel: $sscLevel, ')
          ..write('isActive: $isActive, ')
          ..write('reputationScore: $reputationScore, ')
          ..write('lastInteraction: $lastInteraction, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RadarPingsTable extends RadarPings
    with TableInfo<$RadarPingsTable, RadarPing> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RadarPingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
      'node_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
      'alias', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _interactionTypeMeta =
      const VerificationMeta('interactionType');
  @override
  late final GeneratedColumn<String> interactionType = GeneratedColumn<String>(
      'interaction_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('PING'));
  static const VerificationMeta _distanceMetersMeta =
      const VerificationMeta('distanceMeters');
  @override
  late final GeneratedColumn<double> distanceMeters = GeneratedColumn<double>(
      'distance_meters', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<String> timestamp = GeneratedColumn<String>(
      'timestamp', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, nodeId, alias, interactionType, distanceMeters, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'radar_pings';
  @override
  VerificationContext validateIntegrity(Insertable<RadarPing> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('node_id')) {
      context.handle(_nodeIdMeta,
          nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta));
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('alias')) {
      context.handle(
          _aliasMeta, alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta));
    } else if (isInserting) {
      context.missing(_aliasMeta);
    }
    if (data.containsKey('interaction_type')) {
      context.handle(
          _interactionTypeMeta,
          interactionType.isAcceptableOrUnknown(
              data['interaction_type']!, _interactionTypeMeta));
    }
    if (data.containsKey('distance_meters')) {
      context.handle(
          _distanceMetersMeta,
          distanceMeters.isAcceptableOrUnknown(
              data['distance_meters']!, _distanceMetersMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RadarPing map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RadarPing(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      nodeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}node_id'])!,
      alias: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}alias'])!,
      interactionType: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}interaction_type'])!,
      distanceMeters: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}distance_meters']),
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}timestamp']),
    );
  }

  @override
  $RadarPingsTable createAlias(String alias) {
    return $RadarPingsTable(attachedDatabase, alias);
  }
}

class RadarPing extends DataClass implements Insertable<RadarPing> {
  final String id;
  final String nodeId;
  final String alias;
  final String interactionType;
  final double? distanceMeters;
  final String? timestamp;
  const RadarPing(
      {required this.id,
      required this.nodeId,
      required this.alias,
      required this.interactionType,
      this.distanceMeters,
      this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['node_id'] = Variable<String>(nodeId);
    map['alias'] = Variable<String>(alias);
    map['interaction_type'] = Variable<String>(interactionType);
    if (!nullToAbsent || distanceMeters != null) {
      map['distance_meters'] = Variable<double>(distanceMeters);
    }
    if (!nullToAbsent || timestamp != null) {
      map['timestamp'] = Variable<String>(timestamp);
    }
    return map;
  }

  RadarPingsCompanion toCompanion(bool nullToAbsent) {
    return RadarPingsCompanion(
      id: Value(id),
      nodeId: Value(nodeId),
      alias: Value(alias),
      interactionType: Value(interactionType),
      distanceMeters: distanceMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceMeters),
      timestamp: timestamp == null && nullToAbsent
          ? const Value.absent()
          : Value(timestamp),
    );
  }

  factory RadarPing.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RadarPing(
      id: serializer.fromJson<String>(json['id']),
      nodeId: serializer.fromJson<String>(json['nodeId']),
      alias: serializer.fromJson<String>(json['alias']),
      interactionType: serializer.fromJson<String>(json['interactionType']),
      distanceMeters: serializer.fromJson<double?>(json['distanceMeters']),
      timestamp: serializer.fromJson<String?>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nodeId': serializer.toJson<String>(nodeId),
      'alias': serializer.toJson<String>(alias),
      'interactionType': serializer.toJson<String>(interactionType),
      'distanceMeters': serializer.toJson<double?>(distanceMeters),
      'timestamp': serializer.toJson<String?>(timestamp),
    };
  }

  RadarPing copyWith(
          {String? id,
          String? nodeId,
          String? alias,
          String? interactionType,
          Value<double?> distanceMeters = const Value.absent(),
          Value<String?> timestamp = const Value.absent()}) =>
      RadarPing(
        id: id ?? this.id,
        nodeId: nodeId ?? this.nodeId,
        alias: alias ?? this.alias,
        interactionType: interactionType ?? this.interactionType,
        distanceMeters:
            distanceMeters.present ? distanceMeters.value : this.distanceMeters,
        timestamp: timestamp.present ? timestamp.value : this.timestamp,
      );
  RadarPing copyWithCompanion(RadarPingsCompanion data) {
    return RadarPing(
      id: data.id.present ? data.id.value : this.id,
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      alias: data.alias.present ? data.alias.value : this.alias,
      interactionType: data.interactionType.present
          ? data.interactionType.value
          : this.interactionType,
      distanceMeters: data.distanceMeters.present
          ? data.distanceMeters.value
          : this.distanceMeters,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RadarPing(')
          ..write('id: $id, ')
          ..write('nodeId: $nodeId, ')
          ..write('alias: $alias, ')
          ..write('interactionType: $interactionType, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, nodeId, alias, interactionType, distanceMeters, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RadarPing &&
          other.id == this.id &&
          other.nodeId == this.nodeId &&
          other.alias == this.alias &&
          other.interactionType == this.interactionType &&
          other.distanceMeters == this.distanceMeters &&
          other.timestamp == this.timestamp);
}

class RadarPingsCompanion extends UpdateCompanion<RadarPing> {
  final Value<String> id;
  final Value<String> nodeId;
  final Value<String> alias;
  final Value<String> interactionType;
  final Value<double?> distanceMeters;
  final Value<String?> timestamp;
  final Value<int> rowid;
  const RadarPingsCompanion({
    this.id = const Value.absent(),
    this.nodeId = const Value.absent(),
    this.alias = const Value.absent(),
    this.interactionType = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RadarPingsCompanion.insert({
    required String id,
    required String nodeId,
    required String alias,
    this.interactionType = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        nodeId = Value(nodeId),
        alias = Value(alias);
  static Insertable<RadarPing> custom({
    Expression<String>? id,
    Expression<String>? nodeId,
    Expression<String>? alias,
    Expression<String>? interactionType,
    Expression<double>? distanceMeters,
    Expression<String>? timestamp,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nodeId != null) 'node_id': nodeId,
      if (alias != null) 'alias': alias,
      if (interactionType != null) 'interaction_type': interactionType,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (timestamp != null) 'timestamp': timestamp,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RadarPingsCompanion copyWith(
      {Value<String>? id,
      Value<String>? nodeId,
      Value<String>? alias,
      Value<String>? interactionType,
      Value<double?>? distanceMeters,
      Value<String?>? timestamp,
      Value<int>? rowid}) {
    return RadarPingsCompanion(
      id: id ?? this.id,
      nodeId: nodeId ?? this.nodeId,
      alias: alias ?? this.alias,
      interactionType: interactionType ?? this.interactionType,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      timestamp: timestamp ?? this.timestamp,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (interactionType.present) {
      map['interaction_type'] = Variable<String>(interactionType.value);
    }
    if (distanceMeters.present) {
      map['distance_meters'] = Variable<double>(distanceMeters.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<String>(timestamp.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RadarPingsCompanion(')
          ..write('id: $id, ')
          ..write('nodeId: $nodeId, ')
          ..write('alias: $alias, ')
          ..write('interactionType: $interactionType, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('timestamp: $timestamp, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SoulSheetsTable soulSheets = $SoulSheetsTable(this);
  late final $EgoWheelsTable egoWheels = $EgoWheelsTable(this);
  late final $ErosWheelsTable erosWheels = $ErosWheelsTable(this);
  late final $PhiliaWheelsTable philiaWheels = $PhiliaWheelsTable(this);
  late final $HarvestLogsTable harvestLogs = $HarvestLogsTable(this);
  late final $SysConfigTable sysConfig = $SysConfigTable(this);
  late final $AvatarSheetsTable avatarSheets = $AvatarSheetsTable(this);
  late final $LocalMessagesTable localMessages = $LocalMessagesTable(this);
  late final $LocalQuestsTable localQuests = $LocalQuestsTable(this);
  late final $LocalContactsTable localContacts = $LocalContactsTable(this);
  late final $RadarPingsTable radarPings = $RadarPingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        soulSheets,
        egoWheels,
        erosWheels,
        philiaWheels,
        harvestLogs,
        sysConfig,
        avatarSheets,
        localMessages,
        localQuests,
        localContacts,
        radarPings
      ];
}

typedef $$SoulSheetsTableCreateCompanionBuilder = SoulSheetsCompanion Function({
  required String uuid,
  Value<String> aliasSanitizado,
  Value<int> vinksAcumulados,
  Value<int> rangoForja,
  Value<DateTime?> ultimaRecalibracion,
  Value<int> rowid,
});
typedef $$SoulSheetsTableUpdateCompanionBuilder = SoulSheetsCompanion Function({
  Value<String> uuid,
  Value<String> aliasSanitizado,
  Value<int> vinksAcumulados,
  Value<int> rangoForja,
  Value<DateTime?> ultimaRecalibracion,
  Value<int> rowid,
});

final class $$SoulSheetsTableReferences
    extends BaseReferences<_$AppDatabase, $SoulSheetsTable, SoulSheet> {
  $$SoulSheetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EgoWheelsTable, List<EgoWheel>>
      _egoWheelsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.egoWheels,
              aliasName: $_aliasNameGenerator(
                  db.soulSheets.uuid, db.egoWheels.soulSheetUuid));

  $$EgoWheelsTableProcessedTableManager get egoWheelsRefs {
    final manager = $$EgoWheelsTableTableManager($_db, $_db.egoWheels).filter(
        (f) => f.soulSheetUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!));

    final cache = $_typedResult.readTableOrNull(_egoWheelsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$ErosWheelsTable, List<ErosWheel>>
      _erosWheelsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.erosWheels,
              aliasName: $_aliasNameGenerator(
                  db.soulSheets.uuid, db.erosWheels.soulSheetUuid));

  $$ErosWheelsTableProcessedTableManager get erosWheelsRefs {
    final manager = $$ErosWheelsTableTableManager($_db, $_db.erosWheels).filter(
        (f) => f.soulSheetUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!));

    final cache = $_typedResult.readTableOrNull(_erosWheelsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$PhiliaWheelsTable, List<PhiliaWheel>>
      _philiaWheelsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.philiaWheels,
              aliasName: $_aliasNameGenerator(
                  db.soulSheets.uuid, db.philiaWheels.soulSheetUuid));

  $$PhiliaWheelsTableProcessedTableManager get philiaWheelsRefs {
    final manager = $$PhiliaWheelsTableTableManager($_db, $_db.philiaWheels)
        .filter((f) =>
            f.soulSheetUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!));

    final cache = $_typedResult.readTableOrNull(_philiaWheelsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$HarvestLogsTable, List<HarvestLog>>
      _harvestLogsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.harvestLogs,
              aliasName: $_aliasNameGenerator(
                  db.soulSheets.uuid, db.harvestLogs.soulSheetUuid));

  $$HarvestLogsTableProcessedTableManager get harvestLogsRefs {
    final manager = $$HarvestLogsTableTableManager($_db, $_db.harvestLogs)
        .filter((f) =>
            f.soulSheetUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!));

    final cache = $_typedResult.readTableOrNull(_harvestLogsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SoulSheetsTableFilterComposer
    extends Composer<_$AppDatabase, $SoulSheetsTable> {
  $$SoulSheetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get aliasSanitizado => $composableBuilder(
      column: $table.aliasSanitizado,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get vinksAcumulados => $composableBuilder(
      column: $table.vinksAcumulados,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rangoForja => $composableBuilder(
      column: $table.rangoForja, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get ultimaRecalibracion => $composableBuilder(
      column: $table.ultimaRecalibracion,
      builder: (column) => ColumnFilters(column));

  Expression<bool> egoWheelsRefs(
      Expression<bool> Function($$EgoWheelsTableFilterComposer f) f) {
    final $$EgoWheelsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.uuid,
        referencedTable: $db.egoWheels,
        getReferencedColumn: (t) => t.soulSheetUuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EgoWheelsTableFilterComposer(
              $db: $db,
              $table: $db.egoWheels,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> erosWheelsRefs(
      Expression<bool> Function($$ErosWheelsTableFilterComposer f) f) {
    final $$ErosWheelsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.uuid,
        referencedTable: $db.erosWheels,
        getReferencedColumn: (t) => t.soulSheetUuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ErosWheelsTableFilterComposer(
              $db: $db,
              $table: $db.erosWheels,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> philiaWheelsRefs(
      Expression<bool> Function($$PhiliaWheelsTableFilterComposer f) f) {
    final $$PhiliaWheelsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.uuid,
        referencedTable: $db.philiaWheels,
        getReferencedColumn: (t) => t.soulSheetUuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PhiliaWheelsTableFilterComposer(
              $db: $db,
              $table: $db.philiaWheels,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> harvestLogsRefs(
      Expression<bool> Function($$HarvestLogsTableFilterComposer f) f) {
    final $$HarvestLogsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.uuid,
        referencedTable: $db.harvestLogs,
        getReferencedColumn: (t) => t.soulSheetUuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HarvestLogsTableFilterComposer(
              $db: $db,
              $table: $db.harvestLogs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SoulSheetsTableOrderingComposer
    extends Composer<_$AppDatabase, $SoulSheetsTable> {
  $$SoulSheetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
      column: $table.uuid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get aliasSanitizado => $composableBuilder(
      column: $table.aliasSanitizado,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get vinksAcumulados => $composableBuilder(
      column: $table.vinksAcumulados,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rangoForja => $composableBuilder(
      column: $table.rangoForja, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get ultimaRecalibracion => $composableBuilder(
      column: $table.ultimaRecalibracion,
      builder: (column) => ColumnOrderings(column));
}

class $$SoulSheetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SoulSheetsTable> {
  $$SoulSheetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get aliasSanitizado => $composableBuilder(
      column: $table.aliasSanitizado, builder: (column) => column);

  GeneratedColumn<int> get vinksAcumulados => $composableBuilder(
      column: $table.vinksAcumulados, builder: (column) => column);

  GeneratedColumn<int> get rangoForja => $composableBuilder(
      column: $table.rangoForja, builder: (column) => column);

  GeneratedColumn<DateTime> get ultimaRecalibracion => $composableBuilder(
      column: $table.ultimaRecalibracion, builder: (column) => column);

  Expression<T> egoWheelsRefs<T extends Object>(
      Expression<T> Function($$EgoWheelsTableAnnotationComposer a) f) {
    final $$EgoWheelsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.uuid,
        referencedTable: $db.egoWheels,
        getReferencedColumn: (t) => t.soulSheetUuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$EgoWheelsTableAnnotationComposer(
              $db: $db,
              $table: $db.egoWheels,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> erosWheelsRefs<T extends Object>(
      Expression<T> Function($$ErosWheelsTableAnnotationComposer a) f) {
    final $$ErosWheelsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.uuid,
        referencedTable: $db.erosWheels,
        getReferencedColumn: (t) => t.soulSheetUuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ErosWheelsTableAnnotationComposer(
              $db: $db,
              $table: $db.erosWheels,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> philiaWheelsRefs<T extends Object>(
      Expression<T> Function($$PhiliaWheelsTableAnnotationComposer a) f) {
    final $$PhiliaWheelsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.uuid,
        referencedTable: $db.philiaWheels,
        getReferencedColumn: (t) => t.soulSheetUuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$PhiliaWheelsTableAnnotationComposer(
              $db: $db,
              $table: $db.philiaWheels,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> harvestLogsRefs<T extends Object>(
      Expression<T> Function($$HarvestLogsTableAnnotationComposer a) f) {
    final $$HarvestLogsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.uuid,
        referencedTable: $db.harvestLogs,
        getReferencedColumn: (t) => t.soulSheetUuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HarvestLogsTableAnnotationComposer(
              $db: $db,
              $table: $db.harvestLogs,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SoulSheetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SoulSheetsTable,
    SoulSheet,
    $$SoulSheetsTableFilterComposer,
    $$SoulSheetsTableOrderingComposer,
    $$SoulSheetsTableAnnotationComposer,
    $$SoulSheetsTableCreateCompanionBuilder,
    $$SoulSheetsTableUpdateCompanionBuilder,
    (SoulSheet, $$SoulSheetsTableReferences),
    SoulSheet,
    PrefetchHooks Function(
        {bool egoWheelsRefs,
        bool erosWheelsRefs,
        bool philiaWheelsRefs,
        bool harvestLogsRefs})> {
  $$SoulSheetsTableTableManager(_$AppDatabase db, $SoulSheetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SoulSheetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SoulSheetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SoulSheetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> uuid = const Value.absent(),
            Value<String> aliasSanitizado = const Value.absent(),
            Value<int> vinksAcumulados = const Value.absent(),
            Value<int> rangoForja = const Value.absent(),
            Value<DateTime?> ultimaRecalibracion = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SoulSheetsCompanion(
            uuid: uuid,
            aliasSanitizado: aliasSanitizado,
            vinksAcumulados: vinksAcumulados,
            rangoForja: rangoForja,
            ultimaRecalibracion: ultimaRecalibracion,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String uuid,
            Value<String> aliasSanitizado = const Value.absent(),
            Value<int> vinksAcumulados = const Value.absent(),
            Value<int> rangoForja = const Value.absent(),
            Value<DateTime?> ultimaRecalibracion = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SoulSheetsCompanion.insert(
            uuid: uuid,
            aliasSanitizado: aliasSanitizado,
            vinksAcumulados: vinksAcumulados,
            rangoForja: rangoForja,
            ultimaRecalibracion: ultimaRecalibracion,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SoulSheetsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {egoWheelsRefs = false,
              erosWheelsRefs = false,
              philiaWheelsRefs = false,
              harvestLogsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (egoWheelsRefs) db.egoWheels,
                if (erosWheelsRefs) db.erosWheels,
                if (philiaWheelsRefs) db.philiaWheels,
                if (harvestLogsRefs) db.harvestLogs
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (egoWheelsRefs)
                    await $_getPrefetchedData<SoulSheet, $SoulSheetsTable,
                            EgoWheel>(
                        currentTable: table,
                        referencedTable:
                            $$SoulSheetsTableReferences._egoWheelsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SoulSheetsTableReferences(db, table, p0)
                                .egoWheelsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.soulSheetUuid == item.uuid),
                        typedResults: items),
                  if (erosWheelsRefs)
                    await $_getPrefetchedData<SoulSheet, $SoulSheetsTable,
                            ErosWheel>(
                        currentTable: table,
                        referencedTable: $$SoulSheetsTableReferences
                            ._erosWheelsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SoulSheetsTableReferences(db, table, p0)
                                .erosWheelsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.soulSheetUuid == item.uuid),
                        typedResults: items),
                  if (philiaWheelsRefs)
                    await $_getPrefetchedData<SoulSheet, $SoulSheetsTable,
                            PhiliaWheel>(
                        currentTable: table,
                        referencedTable: $$SoulSheetsTableReferences
                            ._philiaWheelsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SoulSheetsTableReferences(db, table, p0)
                                .philiaWheelsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.soulSheetUuid == item.uuid),
                        typedResults: items),
                  if (harvestLogsRefs)
                    await $_getPrefetchedData<SoulSheet, $SoulSheetsTable,
                            HarvestLog>(
                        currentTable: table,
                        referencedTable: $$SoulSheetsTableReferences
                            ._harvestLogsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SoulSheetsTableReferences(db, table, p0)
                                .harvestLogsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.soulSheetUuid == item.uuid),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SoulSheetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SoulSheetsTable,
    SoulSheet,
    $$SoulSheetsTableFilterComposer,
    $$SoulSheetsTableOrderingComposer,
    $$SoulSheetsTableAnnotationComposer,
    $$SoulSheetsTableCreateCompanionBuilder,
    $$SoulSheetsTableUpdateCompanionBuilder,
    (SoulSheet, $$SoulSheetsTableReferences),
    SoulSheet,
    PrefetchHooks Function(
        {bool egoWheelsRefs,
        bool erosWheelsRefs,
        bool philiaWheelsRefs,
        bool harvestLogsRefs})>;
typedef $$EgoWheelsTableCreateCompanionBuilder = EgoWheelsCompanion Function({
  Value<int> id,
  required String soulSheetUuid,
  Value<int?> eneatipoDaniels,
  Value<String?> arquetipoSeduccion,
  Value<String?> vectorHorney,
  Value<String?> mecanismoDefensa,
});
typedef $$EgoWheelsTableUpdateCompanionBuilder = EgoWheelsCompanion Function({
  Value<int> id,
  Value<String> soulSheetUuid,
  Value<int?> eneatipoDaniels,
  Value<String?> arquetipoSeduccion,
  Value<String?> vectorHorney,
  Value<String?> mecanismoDefensa,
});

final class $$EgoWheelsTableReferences
    extends BaseReferences<_$AppDatabase, $EgoWheelsTable, EgoWheel> {
  $$EgoWheelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SoulSheetsTable _soulSheetUuidTable(_$AppDatabase db) =>
      db.soulSheets.createAlias(
          $_aliasNameGenerator(db.egoWheels.soulSheetUuid, db.soulSheets.uuid));

  $$SoulSheetsTableProcessedTableManager get soulSheetUuid {
    final $_column = $_itemColumn<String>('soul_sheet_uuid')!;

    final manager = $$SoulSheetsTableTableManager($_db, $_db.soulSheets)
        .filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_soulSheetUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$EgoWheelsTableFilterComposer
    extends Composer<_$AppDatabase, $EgoWheelsTable> {
  $$EgoWheelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get eneatipoDaniels => $composableBuilder(
      column: $table.eneatipoDaniels,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get arquetipoSeduccion => $composableBuilder(
      column: $table.arquetipoSeduccion,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get vectorHorney => $composableBuilder(
      column: $table.vectorHorney, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mecanismoDefensa => $composableBuilder(
      column: $table.mecanismoDefensa,
      builder: (column) => ColumnFilters(column));

  $$SoulSheetsTableFilterComposer get soulSheetUuid {
    final $$SoulSheetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.soulSheetUuid,
        referencedTable: $db.soulSheets,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SoulSheetsTableFilterComposer(
              $db: $db,
              $table: $db.soulSheets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$EgoWheelsTableOrderingComposer
    extends Composer<_$AppDatabase, $EgoWheelsTable> {
  $$EgoWheelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get eneatipoDaniels => $composableBuilder(
      column: $table.eneatipoDaniels,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get arquetipoSeduccion => $composableBuilder(
      column: $table.arquetipoSeduccion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get vectorHorney => $composableBuilder(
      column: $table.vectorHorney,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mecanismoDefensa => $composableBuilder(
      column: $table.mecanismoDefensa,
      builder: (column) => ColumnOrderings(column));

  $$SoulSheetsTableOrderingComposer get soulSheetUuid {
    final $$SoulSheetsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.soulSheetUuid,
        referencedTable: $db.soulSheets,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SoulSheetsTableOrderingComposer(
              $db: $db,
              $table: $db.soulSheets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$EgoWheelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EgoWheelsTable> {
  $$EgoWheelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get eneatipoDaniels => $composableBuilder(
      column: $table.eneatipoDaniels, builder: (column) => column);

  GeneratedColumn<String> get arquetipoSeduccion => $composableBuilder(
      column: $table.arquetipoSeduccion, builder: (column) => column);

  GeneratedColumn<String> get vectorHorney => $composableBuilder(
      column: $table.vectorHorney, builder: (column) => column);

  GeneratedColumn<String> get mecanismoDefensa => $composableBuilder(
      column: $table.mecanismoDefensa, builder: (column) => column);

  $$SoulSheetsTableAnnotationComposer get soulSheetUuid {
    final $$SoulSheetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.soulSheetUuid,
        referencedTable: $db.soulSheets,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SoulSheetsTableAnnotationComposer(
              $db: $db,
              $table: $db.soulSheets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$EgoWheelsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $EgoWheelsTable,
    EgoWheel,
    $$EgoWheelsTableFilterComposer,
    $$EgoWheelsTableOrderingComposer,
    $$EgoWheelsTableAnnotationComposer,
    $$EgoWheelsTableCreateCompanionBuilder,
    $$EgoWheelsTableUpdateCompanionBuilder,
    (EgoWheel, $$EgoWheelsTableReferences),
    EgoWheel,
    PrefetchHooks Function({bool soulSheetUuid})> {
  $$EgoWheelsTableTableManager(_$AppDatabase db, $EgoWheelsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EgoWheelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EgoWheelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EgoWheelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> soulSheetUuid = const Value.absent(),
            Value<int?> eneatipoDaniels = const Value.absent(),
            Value<String?> arquetipoSeduccion = const Value.absent(),
            Value<String?> vectorHorney = const Value.absent(),
            Value<String?> mecanismoDefensa = const Value.absent(),
          }) =>
              EgoWheelsCompanion(
            id: id,
            soulSheetUuid: soulSheetUuid,
            eneatipoDaniels: eneatipoDaniels,
            arquetipoSeduccion: arquetipoSeduccion,
            vectorHorney: vectorHorney,
            mecanismoDefensa: mecanismoDefensa,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String soulSheetUuid,
            Value<int?> eneatipoDaniels = const Value.absent(),
            Value<String?> arquetipoSeduccion = const Value.absent(),
            Value<String?> vectorHorney = const Value.absent(),
            Value<String?> mecanismoDefensa = const Value.absent(),
          }) =>
              EgoWheelsCompanion.insert(
            id: id,
            soulSheetUuid: soulSheetUuid,
            eneatipoDaniels: eneatipoDaniels,
            arquetipoSeduccion: arquetipoSeduccion,
            vectorHorney: vectorHorney,
            mecanismoDefensa: mecanismoDefensa,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$EgoWheelsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({soulSheetUuid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (soulSheetUuid) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.soulSheetUuid,
                    referencedTable:
                        $$EgoWheelsTableReferences._soulSheetUuidTable(db),
                    referencedColumn:
                        $$EgoWheelsTableReferences._soulSheetUuidTable(db).uuid,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$EgoWheelsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $EgoWheelsTable,
    EgoWheel,
    $$EgoWheelsTableFilterComposer,
    $$EgoWheelsTableOrderingComposer,
    $$EgoWheelsTableAnnotationComposer,
    $$EgoWheelsTableCreateCompanionBuilder,
    $$EgoWheelsTableUpdateCompanionBuilder,
    (EgoWheel, $$EgoWheelsTableReferences),
    EgoWheel,
    PrefetchHooks Function({bool soulSheetUuid})>;
typedef $$ErosWheelsTableCreateCompanionBuilder = ErosWheelsCompanion Function({
  Value<int> id,
  required String soulSheetUuid,
  Value<String?> blueprintPrimario,
  Value<double?> escalaErotofiliaSos,
  Value<String?> semaforoLimitesJson,
});
typedef $$ErosWheelsTableUpdateCompanionBuilder = ErosWheelsCompanion Function({
  Value<int> id,
  Value<String> soulSheetUuid,
  Value<String?> blueprintPrimario,
  Value<double?> escalaErotofiliaSos,
  Value<String?> semaforoLimitesJson,
});

final class $$ErosWheelsTableReferences
    extends BaseReferences<_$AppDatabase, $ErosWheelsTable, ErosWheel> {
  $$ErosWheelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SoulSheetsTable _soulSheetUuidTable(_$AppDatabase db) =>
      db.soulSheets.createAlias($_aliasNameGenerator(
          db.erosWheels.soulSheetUuid, db.soulSheets.uuid));

  $$SoulSheetsTableProcessedTableManager get soulSheetUuid {
    final $_column = $_itemColumn<String>('soul_sheet_uuid')!;

    final manager = $$SoulSheetsTableTableManager($_db, $_db.soulSheets)
        .filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_soulSheetUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$ErosWheelsTableFilterComposer
    extends Composer<_$AppDatabase, $ErosWheelsTable> {
  $$ErosWheelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get blueprintPrimario => $composableBuilder(
      column: $table.blueprintPrimario,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get escalaErotofiliaSos => $composableBuilder(
      column: $table.escalaErotofiliaSos,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get semaforoLimitesJson => $composableBuilder(
      column: $table.semaforoLimitesJson,
      builder: (column) => ColumnFilters(column));

  $$SoulSheetsTableFilterComposer get soulSheetUuid {
    final $$SoulSheetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.soulSheetUuid,
        referencedTable: $db.soulSheets,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SoulSheetsTableFilterComposer(
              $db: $db,
              $table: $db.soulSheets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ErosWheelsTableOrderingComposer
    extends Composer<_$AppDatabase, $ErosWheelsTable> {
  $$ErosWheelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get blueprintPrimario => $composableBuilder(
      column: $table.blueprintPrimario,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get escalaErotofiliaSos => $composableBuilder(
      column: $table.escalaErotofiliaSos,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get semaforoLimitesJson => $composableBuilder(
      column: $table.semaforoLimitesJson,
      builder: (column) => ColumnOrderings(column));

  $$SoulSheetsTableOrderingComposer get soulSheetUuid {
    final $$SoulSheetsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.soulSheetUuid,
        referencedTable: $db.soulSheets,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SoulSheetsTableOrderingComposer(
              $db: $db,
              $table: $db.soulSheets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ErosWheelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ErosWheelsTable> {
  $$ErosWheelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get blueprintPrimario => $composableBuilder(
      column: $table.blueprintPrimario, builder: (column) => column);

  GeneratedColumn<double> get escalaErotofiliaSos => $composableBuilder(
      column: $table.escalaErotofiliaSos, builder: (column) => column);

  GeneratedColumn<String> get semaforoLimitesJson => $composableBuilder(
      column: $table.semaforoLimitesJson, builder: (column) => column);

  $$SoulSheetsTableAnnotationComposer get soulSheetUuid {
    final $$SoulSheetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.soulSheetUuid,
        referencedTable: $db.soulSheets,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SoulSheetsTableAnnotationComposer(
              $db: $db,
              $table: $db.soulSheets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ErosWheelsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ErosWheelsTable,
    ErosWheel,
    $$ErosWheelsTableFilterComposer,
    $$ErosWheelsTableOrderingComposer,
    $$ErosWheelsTableAnnotationComposer,
    $$ErosWheelsTableCreateCompanionBuilder,
    $$ErosWheelsTableUpdateCompanionBuilder,
    (ErosWheel, $$ErosWheelsTableReferences),
    ErosWheel,
    PrefetchHooks Function({bool soulSheetUuid})> {
  $$ErosWheelsTableTableManager(_$AppDatabase db, $ErosWheelsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ErosWheelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ErosWheelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ErosWheelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> soulSheetUuid = const Value.absent(),
            Value<String?> blueprintPrimario = const Value.absent(),
            Value<double?> escalaErotofiliaSos = const Value.absent(),
            Value<String?> semaforoLimitesJson = const Value.absent(),
          }) =>
              ErosWheelsCompanion(
            id: id,
            soulSheetUuid: soulSheetUuid,
            blueprintPrimario: blueprintPrimario,
            escalaErotofiliaSos: escalaErotofiliaSos,
            semaforoLimitesJson: semaforoLimitesJson,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String soulSheetUuid,
            Value<String?> blueprintPrimario = const Value.absent(),
            Value<double?> escalaErotofiliaSos = const Value.absent(),
            Value<String?> semaforoLimitesJson = const Value.absent(),
          }) =>
              ErosWheelsCompanion.insert(
            id: id,
            soulSheetUuid: soulSheetUuid,
            blueprintPrimario: blueprintPrimario,
            escalaErotofiliaSos: escalaErotofiliaSos,
            semaforoLimitesJson: semaforoLimitesJson,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ErosWheelsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({soulSheetUuid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (soulSheetUuid) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.soulSheetUuid,
                    referencedTable:
                        $$ErosWheelsTableReferences._soulSheetUuidTable(db),
                    referencedColumn: $$ErosWheelsTableReferences
                        ._soulSheetUuidTable(db)
                        .uuid,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$ErosWheelsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ErosWheelsTable,
    ErosWheel,
    $$ErosWheelsTableFilterComposer,
    $$ErosWheelsTableOrderingComposer,
    $$ErosWheelsTableAnnotationComposer,
    $$ErosWheelsTableCreateCompanionBuilder,
    $$ErosWheelsTableUpdateCompanionBuilder,
    (ErosWheel, $$ErosWheelsTableReferences),
    ErosWheel,
    PrefetchHooks Function({bool soulSheetUuid})>;
typedef $$PhiliaWheelsTableCreateCompanionBuilder = PhiliaWheelsCompanion
    Function({
  Value<int> id,
  required String soulSheetUuid,
  Value<String?> estiloApego,
  Value<double?> modeloYo,
  Value<double?> modeloOtro,
  Value<double?> indiceDiferenciacionIar,
});
typedef $$PhiliaWheelsTableUpdateCompanionBuilder = PhiliaWheelsCompanion
    Function({
  Value<int> id,
  Value<String> soulSheetUuid,
  Value<String?> estiloApego,
  Value<double?> modeloYo,
  Value<double?> modeloOtro,
  Value<double?> indiceDiferenciacionIar,
});

final class $$PhiliaWheelsTableReferences
    extends BaseReferences<_$AppDatabase, $PhiliaWheelsTable, PhiliaWheel> {
  $$PhiliaWheelsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SoulSheetsTable _soulSheetUuidTable(_$AppDatabase db) =>
      db.soulSheets.createAlias($_aliasNameGenerator(
          db.philiaWheels.soulSheetUuid, db.soulSheets.uuid));

  $$SoulSheetsTableProcessedTableManager get soulSheetUuid {
    final $_column = $_itemColumn<String>('soul_sheet_uuid')!;

    final manager = $$SoulSheetsTableTableManager($_db, $_db.soulSheets)
        .filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_soulSheetUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$PhiliaWheelsTableFilterComposer
    extends Composer<_$AppDatabase, $PhiliaWheelsTable> {
  $$PhiliaWheelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get estiloApego => $composableBuilder(
      column: $table.estiloApego, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get modeloYo => $composableBuilder(
      column: $table.modeloYo, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get modeloOtro => $composableBuilder(
      column: $table.modeloOtro, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get indiceDiferenciacionIar => $composableBuilder(
      column: $table.indiceDiferenciacionIar,
      builder: (column) => ColumnFilters(column));

  $$SoulSheetsTableFilterComposer get soulSheetUuid {
    final $$SoulSheetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.soulSheetUuid,
        referencedTable: $db.soulSheets,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SoulSheetsTableFilterComposer(
              $db: $db,
              $table: $db.soulSheets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PhiliaWheelsTableOrderingComposer
    extends Composer<_$AppDatabase, $PhiliaWheelsTable> {
  $$PhiliaWheelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get estiloApego => $composableBuilder(
      column: $table.estiloApego, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get modeloYo => $composableBuilder(
      column: $table.modeloYo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get modeloOtro => $composableBuilder(
      column: $table.modeloOtro, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get indiceDiferenciacionIar => $composableBuilder(
      column: $table.indiceDiferenciacionIar,
      builder: (column) => ColumnOrderings(column));

  $$SoulSheetsTableOrderingComposer get soulSheetUuid {
    final $$SoulSheetsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.soulSheetUuid,
        referencedTable: $db.soulSheets,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SoulSheetsTableOrderingComposer(
              $db: $db,
              $table: $db.soulSheets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PhiliaWheelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhiliaWheelsTable> {
  $$PhiliaWheelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get estiloApego => $composableBuilder(
      column: $table.estiloApego, builder: (column) => column);

  GeneratedColumn<double> get modeloYo =>
      $composableBuilder(column: $table.modeloYo, builder: (column) => column);

  GeneratedColumn<double> get modeloOtro => $composableBuilder(
      column: $table.modeloOtro, builder: (column) => column);

  GeneratedColumn<double> get indiceDiferenciacionIar => $composableBuilder(
      column: $table.indiceDiferenciacionIar, builder: (column) => column);

  $$SoulSheetsTableAnnotationComposer get soulSheetUuid {
    final $$SoulSheetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.soulSheetUuid,
        referencedTable: $db.soulSheets,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SoulSheetsTableAnnotationComposer(
              $db: $db,
              $table: $db.soulSheets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$PhiliaWheelsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PhiliaWheelsTable,
    PhiliaWheel,
    $$PhiliaWheelsTableFilterComposer,
    $$PhiliaWheelsTableOrderingComposer,
    $$PhiliaWheelsTableAnnotationComposer,
    $$PhiliaWheelsTableCreateCompanionBuilder,
    $$PhiliaWheelsTableUpdateCompanionBuilder,
    (PhiliaWheel, $$PhiliaWheelsTableReferences),
    PhiliaWheel,
    PrefetchHooks Function({bool soulSheetUuid})> {
  $$PhiliaWheelsTableTableManager(_$AppDatabase db, $PhiliaWheelsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhiliaWheelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhiliaWheelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhiliaWheelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> soulSheetUuid = const Value.absent(),
            Value<String?> estiloApego = const Value.absent(),
            Value<double?> modeloYo = const Value.absent(),
            Value<double?> modeloOtro = const Value.absent(),
            Value<double?> indiceDiferenciacionIar = const Value.absent(),
          }) =>
              PhiliaWheelsCompanion(
            id: id,
            soulSheetUuid: soulSheetUuid,
            estiloApego: estiloApego,
            modeloYo: modeloYo,
            modeloOtro: modeloOtro,
            indiceDiferenciacionIar: indiceDiferenciacionIar,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String soulSheetUuid,
            Value<String?> estiloApego = const Value.absent(),
            Value<double?> modeloYo = const Value.absent(),
            Value<double?> modeloOtro = const Value.absent(),
            Value<double?> indiceDiferenciacionIar = const Value.absent(),
          }) =>
              PhiliaWheelsCompanion.insert(
            id: id,
            soulSheetUuid: soulSheetUuid,
            estiloApego: estiloApego,
            modeloYo: modeloYo,
            modeloOtro: modeloOtro,
            indiceDiferenciacionIar: indiceDiferenciacionIar,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$PhiliaWheelsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({soulSheetUuid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (soulSheetUuid) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.soulSheetUuid,
                    referencedTable:
                        $$PhiliaWheelsTableReferences._soulSheetUuidTable(db),
                    referencedColumn: $$PhiliaWheelsTableReferences
                        ._soulSheetUuidTable(db)
                        .uuid,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$PhiliaWheelsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PhiliaWheelsTable,
    PhiliaWheel,
    $$PhiliaWheelsTableFilterComposer,
    $$PhiliaWheelsTableOrderingComposer,
    $$PhiliaWheelsTableAnnotationComposer,
    $$PhiliaWheelsTableCreateCompanionBuilder,
    $$PhiliaWheelsTableUpdateCompanionBuilder,
    (PhiliaWheel, $$PhiliaWheelsTableReferences),
    PhiliaWheel,
    PrefetchHooks Function({bool soulSheetUuid})>;
typedef $$HarvestLogsTableCreateCompanionBuilder = HarvestLogsCompanion
    Function({
  required String id,
  required String soulSheetUuid,
  required String dilemaId,
  required String opcionSeleccionada,
  Value<DateTime> timestamp,
  Value<int> rowid,
});
typedef $$HarvestLogsTableUpdateCompanionBuilder = HarvestLogsCompanion
    Function({
  Value<String> id,
  Value<String> soulSheetUuid,
  Value<String> dilemaId,
  Value<String> opcionSeleccionada,
  Value<DateTime> timestamp,
  Value<int> rowid,
});

final class $$HarvestLogsTableReferences
    extends BaseReferences<_$AppDatabase, $HarvestLogsTable, HarvestLog> {
  $$HarvestLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SoulSheetsTable _soulSheetUuidTable(_$AppDatabase db) =>
      db.soulSheets.createAlias($_aliasNameGenerator(
          db.harvestLogs.soulSheetUuid, db.soulSheets.uuid));

  $$SoulSheetsTableProcessedTableManager get soulSheetUuid {
    final $_column = $_itemColumn<String>('soul_sheet_uuid')!;

    final manager = $$SoulSheetsTableTableManager($_db, $_db.soulSheets)
        .filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_soulSheetUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$HarvestLogsTableFilterComposer
    extends Composer<_$AppDatabase, $HarvestLogsTable> {
  $$HarvestLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dilemaId => $composableBuilder(
      column: $table.dilemaId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get opcionSeleccionada => $composableBuilder(
      column: $table.opcionSeleccionada,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  $$SoulSheetsTableFilterComposer get soulSheetUuid {
    final $$SoulSheetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.soulSheetUuid,
        referencedTable: $db.soulSheets,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SoulSheetsTableFilterComposer(
              $db: $db,
              $table: $db.soulSheets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HarvestLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $HarvestLogsTable> {
  $$HarvestLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dilemaId => $composableBuilder(
      column: $table.dilemaId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get opcionSeleccionada => $composableBuilder(
      column: $table.opcionSeleccionada,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  $$SoulSheetsTableOrderingComposer get soulSheetUuid {
    final $$SoulSheetsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.soulSheetUuid,
        referencedTable: $db.soulSheets,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SoulSheetsTableOrderingComposer(
              $db: $db,
              $table: $db.soulSheets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HarvestLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HarvestLogsTable> {
  $$HarvestLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dilemaId =>
      $composableBuilder(column: $table.dilemaId, builder: (column) => column);

  GeneratedColumn<String> get opcionSeleccionada => $composableBuilder(
      column: $table.opcionSeleccionada, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  $$SoulSheetsTableAnnotationComposer get soulSheetUuid {
    final $$SoulSheetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.soulSheetUuid,
        referencedTable: $db.soulSheets,
        getReferencedColumn: (t) => t.uuid,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SoulSheetsTableAnnotationComposer(
              $db: $db,
              $table: $db.soulSheets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HarvestLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HarvestLogsTable,
    HarvestLog,
    $$HarvestLogsTableFilterComposer,
    $$HarvestLogsTableOrderingComposer,
    $$HarvestLogsTableAnnotationComposer,
    $$HarvestLogsTableCreateCompanionBuilder,
    $$HarvestLogsTableUpdateCompanionBuilder,
    (HarvestLog, $$HarvestLogsTableReferences),
    HarvestLog,
    PrefetchHooks Function({bool soulSheetUuid})> {
  $$HarvestLogsTableTableManager(_$AppDatabase db, $HarvestLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HarvestLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HarvestLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HarvestLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> soulSheetUuid = const Value.absent(),
            Value<String> dilemaId = const Value.absent(),
            Value<String> opcionSeleccionada = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HarvestLogsCompanion(
            id: id,
            soulSheetUuid: soulSheetUuid,
            dilemaId: dilemaId,
            opcionSeleccionada: opcionSeleccionada,
            timestamp: timestamp,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String soulSheetUuid,
            required String dilemaId,
            required String opcionSeleccionada,
            Value<DateTime> timestamp = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HarvestLogsCompanion.insert(
            id: id,
            soulSheetUuid: soulSheetUuid,
            dilemaId: dilemaId,
            opcionSeleccionada: opcionSeleccionada,
            timestamp: timestamp,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$HarvestLogsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({soulSheetUuid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (soulSheetUuid) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.soulSheetUuid,
                    referencedTable:
                        $$HarvestLogsTableReferences._soulSheetUuidTable(db),
                    referencedColumn: $$HarvestLogsTableReferences
                        ._soulSheetUuidTable(db)
                        .uuid,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$HarvestLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HarvestLogsTable,
    HarvestLog,
    $$HarvestLogsTableFilterComposer,
    $$HarvestLogsTableOrderingComposer,
    $$HarvestLogsTableAnnotationComposer,
    $$HarvestLogsTableCreateCompanionBuilder,
    $$HarvestLogsTableUpdateCompanionBuilder,
    (HarvestLog, $$HarvestLogsTableReferences),
    HarvestLog,
    PrefetchHooks Function({bool soulSheetUuid})>;
typedef $$SysConfigTableCreateCompanionBuilder = SysConfigCompanion Function({
  required String key,
  Value<String?> value,
  Value<int> rowid,
});
typedef $$SysConfigTableUpdateCompanionBuilder = SysConfigCompanion Function({
  Value<String> key,
  Value<String?> value,
  Value<int> rowid,
});

class $$SysConfigTableFilterComposer
    extends Composer<_$AppDatabase, $SysConfigTable> {
  $$SysConfigTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SysConfigTableOrderingComposer
    extends Composer<_$AppDatabase, $SysConfigTable> {
  $$SysConfigTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SysConfigTableAnnotationComposer
    extends Composer<_$AppDatabase, $SysConfigTable> {
  $$SysConfigTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SysConfigTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SysConfigTable,
    SysConfigData,
    $$SysConfigTableFilterComposer,
    $$SysConfigTableOrderingComposer,
    $$SysConfigTableAnnotationComposer,
    $$SysConfigTableCreateCompanionBuilder,
    $$SysConfigTableUpdateCompanionBuilder,
    (
      SysConfigData,
      BaseReferences<_$AppDatabase, $SysConfigTable, SysConfigData>
    ),
    SysConfigData,
    PrefetchHooks Function()> {
  $$SysConfigTableTableManager(_$AppDatabase db, $SysConfigTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SysConfigTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SysConfigTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SysConfigTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String?> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SysConfigCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            Value<String?> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SysConfigCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SysConfigTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SysConfigTable,
    SysConfigData,
    $$SysConfigTableFilterComposer,
    $$SysConfigTableOrderingComposer,
    $$SysConfigTableAnnotationComposer,
    $$SysConfigTableCreateCompanionBuilder,
    $$SysConfigTableUpdateCompanionBuilder,
    (
      SysConfigData,
      BaseReferences<_$AppDatabase, $SysConfigTable, SysConfigData>
    ),
    SysConfigData,
    PrefetchHooks Function()>;
typedef $$AvatarSheetsTableCreateCompanionBuilder = AvatarSheetsCompanion
    Function({
  required String id,
  Value<String?> characterClass,
  Value<int?> level,
  Value<int?> experiencePoints,
  Value<double?> reputationScore,
  Value<String?> stats,
  Value<String?> activeBuffs,
  Value<String?> activeDebuffs,
  Value<int> rowid,
});
typedef $$AvatarSheetsTableUpdateCompanionBuilder = AvatarSheetsCompanion
    Function({
  Value<String> id,
  Value<String?> characterClass,
  Value<int?> level,
  Value<int?> experiencePoints,
  Value<double?> reputationScore,
  Value<String?> stats,
  Value<String?> activeBuffs,
  Value<String?> activeDebuffs,
  Value<int> rowid,
});

class $$AvatarSheetsTableFilterComposer
    extends Composer<_$AppDatabase, $AvatarSheetsTable> {
  $$AvatarSheetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get characterClass => $composableBuilder(
      column: $table.characterClass,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get experiencePoints => $composableBuilder(
      column: $table.experiencePoints,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get reputationScore => $composableBuilder(
      column: $table.reputationScore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get stats => $composableBuilder(
      column: $table.stats, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get activeBuffs => $composableBuilder(
      column: $table.activeBuffs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get activeDebuffs => $composableBuilder(
      column: $table.activeDebuffs, builder: (column) => ColumnFilters(column));
}

class $$AvatarSheetsTableOrderingComposer
    extends Composer<_$AppDatabase, $AvatarSheetsTable> {
  $$AvatarSheetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get characterClass => $composableBuilder(
      column: $table.characterClass,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get level => $composableBuilder(
      column: $table.level, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get experiencePoints => $composableBuilder(
      column: $table.experiencePoints,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get reputationScore => $composableBuilder(
      column: $table.reputationScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get stats => $composableBuilder(
      column: $table.stats, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get activeBuffs => $composableBuilder(
      column: $table.activeBuffs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get activeDebuffs => $composableBuilder(
      column: $table.activeDebuffs,
      builder: (column) => ColumnOrderings(column));
}

class $$AvatarSheetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AvatarSheetsTable> {
  $$AvatarSheetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get characterClass => $composableBuilder(
      column: $table.characterClass, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get experiencePoints => $composableBuilder(
      column: $table.experiencePoints, builder: (column) => column);

  GeneratedColumn<double> get reputationScore => $composableBuilder(
      column: $table.reputationScore, builder: (column) => column);

  GeneratedColumn<String> get stats =>
      $composableBuilder(column: $table.stats, builder: (column) => column);

  GeneratedColumn<String> get activeBuffs => $composableBuilder(
      column: $table.activeBuffs, builder: (column) => column);

  GeneratedColumn<String> get activeDebuffs => $composableBuilder(
      column: $table.activeDebuffs, builder: (column) => column);
}

class $$AvatarSheetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AvatarSheetsTable,
    AvatarSheet,
    $$AvatarSheetsTableFilterComposer,
    $$AvatarSheetsTableOrderingComposer,
    $$AvatarSheetsTableAnnotationComposer,
    $$AvatarSheetsTableCreateCompanionBuilder,
    $$AvatarSheetsTableUpdateCompanionBuilder,
    (
      AvatarSheet,
      BaseReferences<_$AppDatabase, $AvatarSheetsTable, AvatarSheet>
    ),
    AvatarSheet,
    PrefetchHooks Function()> {
  $$AvatarSheetsTableTableManager(_$AppDatabase db, $AvatarSheetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AvatarSheetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AvatarSheetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AvatarSheetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> characterClass = const Value.absent(),
            Value<int?> level = const Value.absent(),
            Value<int?> experiencePoints = const Value.absent(),
            Value<double?> reputationScore = const Value.absent(),
            Value<String?> stats = const Value.absent(),
            Value<String?> activeBuffs = const Value.absent(),
            Value<String?> activeDebuffs = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AvatarSheetsCompanion(
            id: id,
            characterClass: characterClass,
            level: level,
            experiencePoints: experiencePoints,
            reputationScore: reputationScore,
            stats: stats,
            activeBuffs: activeBuffs,
            activeDebuffs: activeDebuffs,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> characterClass = const Value.absent(),
            Value<int?> level = const Value.absent(),
            Value<int?> experiencePoints = const Value.absent(),
            Value<double?> reputationScore = const Value.absent(),
            Value<String?> stats = const Value.absent(),
            Value<String?> activeBuffs = const Value.absent(),
            Value<String?> activeDebuffs = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AvatarSheetsCompanion.insert(
            id: id,
            characterClass: characterClass,
            level: level,
            experiencePoints: experiencePoints,
            reputationScore: reputationScore,
            stats: stats,
            activeBuffs: activeBuffs,
            activeDebuffs: activeDebuffs,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AvatarSheetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AvatarSheetsTable,
    AvatarSheet,
    $$AvatarSheetsTableFilterComposer,
    $$AvatarSheetsTableOrderingComposer,
    $$AvatarSheetsTableAnnotationComposer,
    $$AvatarSheetsTableCreateCompanionBuilder,
    $$AvatarSheetsTableUpdateCompanionBuilder,
    (
      AvatarSheet,
      BaseReferences<_$AppDatabase, $AvatarSheetsTable, AvatarSheet>
    ),
    AvatarSheet,
    PrefetchHooks Function()>;
typedef $$LocalMessagesTableCreateCompanionBuilder = LocalMessagesCompanion
    Function({
  required String id,
  Value<String?> guildId,
  Value<String?> senderId,
  Value<String?> encryptedBlob,
  Value<String?> decryptedContent,
  Value<String?> timestamp,
  Value<int> rowid,
});
typedef $$LocalMessagesTableUpdateCompanionBuilder = LocalMessagesCompanion
    Function({
  Value<String> id,
  Value<String?> guildId,
  Value<String?> senderId,
  Value<String?> encryptedBlob,
  Value<String?> decryptedContent,
  Value<String?> timestamp,
  Value<int> rowid,
});

class $$LocalMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get guildId => $composableBuilder(
      column: $table.guildId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get encryptedBlob => $composableBuilder(
      column: $table.encryptedBlob, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get decryptedContent => $composableBuilder(
      column: $table.decryptedContent,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$LocalMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get guildId => $composableBuilder(
      column: $table.guildId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get senderId => $composableBuilder(
      column: $table.senderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get encryptedBlob => $composableBuilder(
      column: $table.encryptedBlob,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get decryptedContent => $composableBuilder(
      column: $table.decryptedContent,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$LocalMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get guildId =>
      $composableBuilder(column: $table.guildId, builder: (column) => column);

  GeneratedColumn<String> get senderId =>
      $composableBuilder(column: $table.senderId, builder: (column) => column);

  GeneratedColumn<String> get encryptedBlob => $composableBuilder(
      column: $table.encryptedBlob, builder: (column) => column);

  GeneratedColumn<String> get decryptedContent => $composableBuilder(
      column: $table.decryptedContent, builder: (column) => column);

  GeneratedColumn<String> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$LocalMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalMessagesTable,
    LocalMessage,
    $$LocalMessagesTableFilterComposer,
    $$LocalMessagesTableOrderingComposer,
    $$LocalMessagesTableAnnotationComposer,
    $$LocalMessagesTableCreateCompanionBuilder,
    $$LocalMessagesTableUpdateCompanionBuilder,
    (
      LocalMessage,
      BaseReferences<_$AppDatabase, $LocalMessagesTable, LocalMessage>
    ),
    LocalMessage,
    PrefetchHooks Function()> {
  $$LocalMessagesTableTableManager(_$AppDatabase db, $LocalMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> guildId = const Value.absent(),
            Value<String?> senderId = const Value.absent(),
            Value<String?> encryptedBlob = const Value.absent(),
            Value<String?> decryptedContent = const Value.absent(),
            Value<String?> timestamp = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalMessagesCompanion(
            id: id,
            guildId: guildId,
            senderId: senderId,
            encryptedBlob: encryptedBlob,
            decryptedContent: decryptedContent,
            timestamp: timestamp,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> guildId = const Value.absent(),
            Value<String?> senderId = const Value.absent(),
            Value<String?> encryptedBlob = const Value.absent(),
            Value<String?> decryptedContent = const Value.absent(),
            Value<String?> timestamp = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalMessagesCompanion.insert(
            id: id,
            guildId: guildId,
            senderId: senderId,
            encryptedBlob: encryptedBlob,
            decryptedContent: decryptedContent,
            timestamp: timestamp,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalMessagesTable,
    LocalMessage,
    $$LocalMessagesTableFilterComposer,
    $$LocalMessagesTableOrderingComposer,
    $$LocalMessagesTableAnnotationComposer,
    $$LocalMessagesTableCreateCompanionBuilder,
    $$LocalMessagesTableUpdateCompanionBuilder,
    (
      LocalMessage,
      BaseReferences<_$AppDatabase, $LocalMessagesTable, LocalMessage>
    ),
    LocalMessage,
    PrefetchHooks Function()>;
typedef $$LocalQuestsTableCreateCompanionBuilder = LocalQuestsCompanion
    Function({
  required String id,
  Value<String?> title,
  Value<String?> description,
  Value<String?> sourceType,
  Value<int?> rewardVinks,
  Value<int?> xpReward,
  Value<String?> status,
  Value<int> minLevel,
  Value<String?> requiredQuestId,
  Value<String?> createdAt,
  Value<int> rowid,
});
typedef $$LocalQuestsTableUpdateCompanionBuilder = LocalQuestsCompanion
    Function({
  Value<String> id,
  Value<String?> title,
  Value<String?> description,
  Value<String?> sourceType,
  Value<int?> rewardVinks,
  Value<int?> xpReward,
  Value<String?> status,
  Value<int> minLevel,
  Value<String?> requiredQuestId,
  Value<String?> createdAt,
  Value<int> rowid,
});

class $$LocalQuestsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalQuestsTable> {
  $$LocalQuestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceType => $composableBuilder(
      column: $table.sourceType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rewardVinks => $composableBuilder(
      column: $table.rewardVinks, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get xpReward => $composableBuilder(
      column: $table.xpReward, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get minLevel => $composableBuilder(
      column: $table.minLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get requiredQuestId => $composableBuilder(
      column: $table.requiredQuestId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LocalQuestsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalQuestsTable> {
  $$LocalQuestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceType => $composableBuilder(
      column: $table.sourceType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rewardVinks => $composableBuilder(
      column: $table.rewardVinks, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get xpReward => $composableBuilder(
      column: $table.xpReward, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get minLevel => $composableBuilder(
      column: $table.minLevel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get requiredQuestId => $composableBuilder(
      column: $table.requiredQuestId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalQuestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalQuestsTable> {
  $$LocalQuestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get sourceType => $composableBuilder(
      column: $table.sourceType, builder: (column) => column);

  GeneratedColumn<int> get rewardVinks => $composableBuilder(
      column: $table.rewardVinks, builder: (column) => column);

  GeneratedColumn<int> get xpReward =>
      $composableBuilder(column: $table.xpReward, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get minLevel =>
      $composableBuilder(column: $table.minLevel, builder: (column) => column);

  GeneratedColumn<String> get requiredQuestId => $composableBuilder(
      column: $table.requiredQuestId, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalQuestsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalQuestsTable,
    LocalQuest,
    $$LocalQuestsTableFilterComposer,
    $$LocalQuestsTableOrderingComposer,
    $$LocalQuestsTableAnnotationComposer,
    $$LocalQuestsTableCreateCompanionBuilder,
    $$LocalQuestsTableUpdateCompanionBuilder,
    (LocalQuest, BaseReferences<_$AppDatabase, $LocalQuestsTable, LocalQuest>),
    LocalQuest,
    PrefetchHooks Function()> {
  $$LocalQuestsTableTableManager(_$AppDatabase db, $LocalQuestsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalQuestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalQuestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalQuestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> sourceType = const Value.absent(),
            Value<int?> rewardVinks = const Value.absent(),
            Value<int?> xpReward = const Value.absent(),
            Value<String?> status = const Value.absent(),
            Value<int> minLevel = const Value.absent(),
            Value<String?> requiredQuestId = const Value.absent(),
            Value<String?> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalQuestsCompanion(
            id: id,
            title: title,
            description: description,
            sourceType: sourceType,
            rewardVinks: rewardVinks,
            xpReward: xpReward,
            status: status,
            minLevel: minLevel,
            requiredQuestId: requiredQuestId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> title = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> sourceType = const Value.absent(),
            Value<int?> rewardVinks = const Value.absent(),
            Value<int?> xpReward = const Value.absent(),
            Value<String?> status = const Value.absent(),
            Value<int> minLevel = const Value.absent(),
            Value<String?> requiredQuestId = const Value.absent(),
            Value<String?> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalQuestsCompanion.insert(
            id: id,
            title: title,
            description: description,
            sourceType: sourceType,
            rewardVinks: rewardVinks,
            xpReward: xpReward,
            status: status,
            minLevel: minLevel,
            requiredQuestId: requiredQuestId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalQuestsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalQuestsTable,
    LocalQuest,
    $$LocalQuestsTableFilterComposer,
    $$LocalQuestsTableOrderingComposer,
    $$LocalQuestsTableAnnotationComposer,
    $$LocalQuestsTableCreateCompanionBuilder,
    $$LocalQuestsTableUpdateCompanionBuilder,
    (LocalQuest, BaseReferences<_$AppDatabase, $LocalQuestsTable, LocalQuest>),
    LocalQuest,
    PrefetchHooks Function()>;
typedef $$LocalContactsTableCreateCompanionBuilder = LocalContactsCompanion
    Function({
  required String id,
  required String alias,
  Value<String?> characterClass,
  Value<String> relationshipType,
  Value<String> sscLevel,
  Value<int> isActive,
  Value<double> reputationScore,
  Value<String?> lastInteraction,
  Value<String?> createdAt,
  Value<int> rowid,
});
typedef $$LocalContactsTableUpdateCompanionBuilder = LocalContactsCompanion
    Function({
  Value<String> id,
  Value<String> alias,
  Value<String?> characterClass,
  Value<String> relationshipType,
  Value<String> sscLevel,
  Value<int> isActive,
  Value<double> reputationScore,
  Value<String?> lastInteraction,
  Value<String?> createdAt,
  Value<int> rowid,
});

class $$LocalContactsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalContactsTable> {
  $$LocalContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get alias => $composableBuilder(
      column: $table.alias, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get characterClass => $composableBuilder(
      column: $table.characterClass,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get relationshipType => $composableBuilder(
      column: $table.relationshipType,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sscLevel => $composableBuilder(
      column: $table.sscLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get reputationScore => $composableBuilder(
      column: $table.reputationScore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastInteraction => $composableBuilder(
      column: $table.lastInteraction,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LocalContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalContactsTable> {
  $$LocalContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get alias => $composableBuilder(
      column: $table.alias, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get characterClass => $composableBuilder(
      column: $table.characterClass,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get relationshipType => $composableBuilder(
      column: $table.relationshipType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sscLevel => $composableBuilder(
      column: $table.sscLevel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get isActive => $composableBuilder(
      column: $table.isActive, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get reputationScore => $composableBuilder(
      column: $table.reputationScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastInteraction => $composableBuilder(
      column: $table.lastInteraction,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalContactsTable> {
  $$LocalContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<String> get characterClass => $composableBuilder(
      column: $table.characterClass, builder: (column) => column);

  GeneratedColumn<String> get relationshipType => $composableBuilder(
      column: $table.relationshipType, builder: (column) => column);

  GeneratedColumn<String> get sscLevel =>
      $composableBuilder(column: $table.sscLevel, builder: (column) => column);

  GeneratedColumn<int> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<double> get reputationScore => $composableBuilder(
      column: $table.reputationScore, builder: (column) => column);

  GeneratedColumn<String> get lastInteraction => $composableBuilder(
      column: $table.lastInteraction, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalContactsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalContactsTable,
    LocalContact,
    $$LocalContactsTableFilterComposer,
    $$LocalContactsTableOrderingComposer,
    $$LocalContactsTableAnnotationComposer,
    $$LocalContactsTableCreateCompanionBuilder,
    $$LocalContactsTableUpdateCompanionBuilder,
    (
      LocalContact,
      BaseReferences<_$AppDatabase, $LocalContactsTable, LocalContact>
    ),
    LocalContact,
    PrefetchHooks Function()> {
  $$LocalContactsTableTableManager(_$AppDatabase db, $LocalContactsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> alias = const Value.absent(),
            Value<String?> characterClass = const Value.absent(),
            Value<String> relationshipType = const Value.absent(),
            Value<String> sscLevel = const Value.absent(),
            Value<int> isActive = const Value.absent(),
            Value<double> reputationScore = const Value.absent(),
            Value<String?> lastInteraction = const Value.absent(),
            Value<String?> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalContactsCompanion(
            id: id,
            alias: alias,
            characterClass: characterClass,
            relationshipType: relationshipType,
            sscLevel: sscLevel,
            isActive: isActive,
            reputationScore: reputationScore,
            lastInteraction: lastInteraction,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String alias,
            Value<String?> characterClass = const Value.absent(),
            Value<String> relationshipType = const Value.absent(),
            Value<String> sscLevel = const Value.absent(),
            Value<int> isActive = const Value.absent(),
            Value<double> reputationScore = const Value.absent(),
            Value<String?> lastInteraction = const Value.absent(),
            Value<String?> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalContactsCompanion.insert(
            id: id,
            alias: alias,
            characterClass: characterClass,
            relationshipType: relationshipType,
            sscLevel: sscLevel,
            isActive: isActive,
            reputationScore: reputationScore,
            lastInteraction: lastInteraction,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalContactsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalContactsTable,
    LocalContact,
    $$LocalContactsTableFilterComposer,
    $$LocalContactsTableOrderingComposer,
    $$LocalContactsTableAnnotationComposer,
    $$LocalContactsTableCreateCompanionBuilder,
    $$LocalContactsTableUpdateCompanionBuilder,
    (
      LocalContact,
      BaseReferences<_$AppDatabase, $LocalContactsTable, LocalContact>
    ),
    LocalContact,
    PrefetchHooks Function()>;
typedef $$RadarPingsTableCreateCompanionBuilder = RadarPingsCompanion Function({
  required String id,
  required String nodeId,
  required String alias,
  Value<String> interactionType,
  Value<double?> distanceMeters,
  Value<String?> timestamp,
  Value<int> rowid,
});
typedef $$RadarPingsTableUpdateCompanionBuilder = RadarPingsCompanion Function({
  Value<String> id,
  Value<String> nodeId,
  Value<String> alias,
  Value<String> interactionType,
  Value<double?> distanceMeters,
  Value<String?> timestamp,
  Value<int> rowid,
});

class $$RadarPingsTableFilterComposer
    extends Composer<_$AppDatabase, $RadarPingsTable> {
  $$RadarPingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nodeId => $composableBuilder(
      column: $table.nodeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get alias => $composableBuilder(
      column: $table.alias, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get interactionType => $composableBuilder(
      column: $table.interactionType,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get distanceMeters => $composableBuilder(
      column: $table.distanceMeters,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$RadarPingsTableOrderingComposer
    extends Composer<_$AppDatabase, $RadarPingsTable> {
  $$RadarPingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nodeId => $composableBuilder(
      column: $table.nodeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get alias => $composableBuilder(
      column: $table.alias, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get interactionType => $composableBuilder(
      column: $table.interactionType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get distanceMeters => $composableBuilder(
      column: $table.distanceMeters,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$RadarPingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RadarPingsTable> {
  $$RadarPingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<String> get interactionType => $composableBuilder(
      column: $table.interactionType, builder: (column) => column);

  GeneratedColumn<double> get distanceMeters => $composableBuilder(
      column: $table.distanceMeters, builder: (column) => column);

  GeneratedColumn<String> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$RadarPingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RadarPingsTable,
    RadarPing,
    $$RadarPingsTableFilterComposer,
    $$RadarPingsTableOrderingComposer,
    $$RadarPingsTableAnnotationComposer,
    $$RadarPingsTableCreateCompanionBuilder,
    $$RadarPingsTableUpdateCompanionBuilder,
    (RadarPing, BaseReferences<_$AppDatabase, $RadarPingsTable, RadarPing>),
    RadarPing,
    PrefetchHooks Function()> {
  $$RadarPingsTableTableManager(_$AppDatabase db, $RadarPingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RadarPingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RadarPingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RadarPingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> nodeId = const Value.absent(),
            Value<String> alias = const Value.absent(),
            Value<String> interactionType = const Value.absent(),
            Value<double?> distanceMeters = const Value.absent(),
            Value<String?> timestamp = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RadarPingsCompanion(
            id: id,
            nodeId: nodeId,
            alias: alias,
            interactionType: interactionType,
            distanceMeters: distanceMeters,
            timestamp: timestamp,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String nodeId,
            required String alias,
            Value<String> interactionType = const Value.absent(),
            Value<double?> distanceMeters = const Value.absent(),
            Value<String?> timestamp = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RadarPingsCompanion.insert(
            id: id,
            nodeId: nodeId,
            alias: alias,
            interactionType: interactionType,
            distanceMeters: distanceMeters,
            timestamp: timestamp,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RadarPingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RadarPingsTable,
    RadarPing,
    $$RadarPingsTableFilterComposer,
    $$RadarPingsTableOrderingComposer,
    $$RadarPingsTableAnnotationComposer,
    $$RadarPingsTableCreateCompanionBuilder,
    $$RadarPingsTableUpdateCompanionBuilder,
    (RadarPing, BaseReferences<_$AppDatabase, $RadarPingsTable, RadarPing>),
    RadarPing,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SoulSheetsTableTableManager get soulSheets =>
      $$SoulSheetsTableTableManager(_db, _db.soulSheets);
  $$EgoWheelsTableTableManager get egoWheels =>
      $$EgoWheelsTableTableManager(_db, _db.egoWheels);
  $$ErosWheelsTableTableManager get erosWheels =>
      $$ErosWheelsTableTableManager(_db, _db.erosWheels);
  $$PhiliaWheelsTableTableManager get philiaWheels =>
      $$PhiliaWheelsTableTableManager(_db, _db.philiaWheels);
  $$HarvestLogsTableTableManager get harvestLogs =>
      $$HarvestLogsTableTableManager(_db, _db.harvestLogs);
  $$SysConfigTableTableManager get sysConfig =>
      $$SysConfigTableTableManager(_db, _db.sysConfig);
  $$AvatarSheetsTableTableManager get avatarSheets =>
      $$AvatarSheetsTableTableManager(_db, _db.avatarSheets);
  $$LocalMessagesTableTableManager get localMessages =>
      $$LocalMessagesTableTableManager(_db, _db.localMessages);
  $$LocalQuestsTableTableManager get localQuests =>
      $$LocalQuestsTableTableManager(_db, _db.localQuests);
  $$LocalContactsTableTableManager get localContacts =>
      $$LocalContactsTableTableManager(_db, _db.localContacts);
  $$RadarPingsTableTableManager get radarPings =>
      $$RadarPingsTableTableManager(_db, _db.radarPings);
}
