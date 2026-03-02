// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDeviceEntityCollection on Isar {
  IsarCollection<DeviceEntity> get deviceEntitys => this.collection();
}

const DeviceEntitySchema = CollectionSchema(
  name: r'DeviceEntity',
  id: 6626679775157521336,
  properties: {
    r'deviceId': PropertySchema(
      id: 0,
      name: r'deviceId',
      type: IsarType.string,
    ),
    r'displayName': PropertySchema(
      id: 1,
      name: r'displayName',
      type: IsarType.string,
    ),
    r'host': PropertySchema(
      id: 2,
      name: r'host',
      type: IsarType.string,
    ),
    r'lastSeenAt': PropertySchema(
      id: 3,
      name: r'lastSeenAt',
      type: IsarType.dateTime,
    ),
    r'pairedAt': PropertySchema(
      id: 4,
      name: r'pairedAt',
      type: IsarType.dateTime,
    ),
    r'port': PropertySchema(
      id: 5,
      name: r'port',
      type: IsarType.long,
    ),
    r'publicKey': PropertySchema(
      id: 6,
      name: r'publicKey',
      type: IsarType.string,
    ),
    r'sharedKey': PropertySchema(
      id: 7,
      name: r'sharedKey',
      type: IsarType.string,
    ),
    r'trusted': PropertySchema(
      id: 8,
      name: r'trusted',
      type: IsarType.bool,
    )
  },
  estimateSize: _deviceEntityEstimateSize,
  serialize: _deviceEntitySerialize,
  deserialize: _deviceEntityDeserialize,
  deserializeProp: _deviceEntityDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'deviceId': IndexSchema(
      id: 4442814072367132509,
      name: r'deviceId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'deviceId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _deviceEntityGetId,
  getLinks: _deviceEntityGetLinks,
  attach: _deviceEntityAttach,
  version: '3.1.0+1',
);

int _deviceEntityEstimateSize(
  DeviceEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.deviceId.length * 3;
  bytesCount += 3 + object.displayName.length * 3;
  bytesCount += 3 + object.host.length * 3;
  bytesCount += 3 + object.publicKey.length * 3;
  {
    final value = object.sharedKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _deviceEntitySerialize(
  DeviceEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.deviceId);
  writer.writeString(offsets[1], object.displayName);
  writer.writeString(offsets[2], object.host);
  writer.writeDateTime(offsets[3], object.lastSeenAt);
  writer.writeDateTime(offsets[4], object.pairedAt);
  writer.writeLong(offsets[5], object.port);
  writer.writeString(offsets[6], object.publicKey);
  writer.writeString(offsets[7], object.sharedKey);
  writer.writeBool(offsets[8], object.trusted);
}

DeviceEntity _deviceEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DeviceEntity();
  object.deviceId = reader.readString(offsets[0]);
  object.displayName = reader.readString(offsets[1]);
  object.host = reader.readString(offsets[2]);
  object.isarId = id;
  object.lastSeenAt = reader.readDateTimeOrNull(offsets[3]);
  object.pairedAt = reader.readDateTimeOrNull(offsets[4]);
  object.port = reader.readLong(offsets[5]);
  object.publicKey = reader.readString(offsets[6]);
  object.sharedKey = reader.readStringOrNull(offsets[7]);
  object.trusted = reader.readBool(offsets[8]);
  return object;
}

P _deviceEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 4:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readBool(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _deviceEntityGetId(DeviceEntity object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _deviceEntityGetLinks(DeviceEntity object) {
  return [];
}

void _deviceEntityAttach(
    IsarCollection<dynamic> col, Id id, DeviceEntity object) {
  object.isarId = id;
}

extension DeviceEntityByIndex on IsarCollection<DeviceEntity> {
  Future<DeviceEntity?> getByDeviceId(String deviceId) {
    return getByIndex(r'deviceId', [deviceId]);
  }

  DeviceEntity? getByDeviceIdSync(String deviceId) {
    return getByIndexSync(r'deviceId', [deviceId]);
  }

  Future<bool> deleteByDeviceId(String deviceId) {
    return deleteByIndex(r'deviceId', [deviceId]);
  }

  bool deleteByDeviceIdSync(String deviceId) {
    return deleteByIndexSync(r'deviceId', [deviceId]);
  }

  Future<List<DeviceEntity?>> getAllByDeviceId(List<String> deviceIdValues) {
    final values = deviceIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'deviceId', values);
  }

  List<DeviceEntity?> getAllByDeviceIdSync(List<String> deviceIdValues) {
    final values = deviceIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'deviceId', values);
  }

  Future<int> deleteAllByDeviceId(List<String> deviceIdValues) {
    final values = deviceIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'deviceId', values);
  }

  int deleteAllByDeviceIdSync(List<String> deviceIdValues) {
    final values = deviceIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'deviceId', values);
  }

  Future<Id> putByDeviceId(DeviceEntity object) {
    return putByIndex(r'deviceId', object);
  }

  Id putByDeviceIdSync(DeviceEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'deviceId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByDeviceId(List<DeviceEntity> objects) {
    return putAllByIndex(r'deviceId', objects);
  }

  List<Id> putAllByDeviceIdSync(List<DeviceEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'deviceId', objects, saveLinks: saveLinks);
  }
}

extension DeviceEntityQueryWhereSort
    on QueryBuilder<DeviceEntity, DeviceEntity, QWhere> {
  QueryBuilder<DeviceEntity, DeviceEntity, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension DeviceEntityQueryWhere
    on QueryBuilder<DeviceEntity, DeviceEntity, QWhereClause> {
  QueryBuilder<DeviceEntity, DeviceEntity, QAfterWhereClause> isarIdEqualTo(
      Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: isarId,
        upper: isarId,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterWhereClause> isarIdNotEqualTo(
      Id isarId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: isarId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: isarId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterWhereClause> isarIdGreaterThan(
      Id isarId,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterWhereClause> isarIdLessThan(
      Id isarId,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterWhereClause> isarIdBetween(
    Id lowerIsarId,
    Id upperIsarId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerIsarId,
        includeLower: includeLower,
        upper: upperIsarId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterWhereClause> deviceIdEqualTo(
      String deviceId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'deviceId',
        value: [deviceId],
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterWhereClause>
      deviceIdNotEqualTo(String deviceId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'deviceId',
              lower: [],
              upper: [deviceId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'deviceId',
              lower: [deviceId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'deviceId',
              lower: [deviceId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'deviceId',
              lower: [],
              upper: [deviceId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension DeviceEntityQueryFilter
    on QueryBuilder<DeviceEntity, DeviceEntity, QFilterCondition> {
  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      deviceIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      deviceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      deviceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      deviceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deviceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      deviceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      deviceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      deviceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'deviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      deviceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'deviceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      deviceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      deviceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'deviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      displayNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      displayNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      displayNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      displayNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'displayName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      displayNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      displayNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      displayNameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'displayName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      displayNameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'displayName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      displayNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'displayName',
        value: '',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      displayNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'displayName',
        value: '',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition> hostEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'host',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      hostGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'host',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition> hostLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'host',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition> hostBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'host',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      hostStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'host',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition> hostEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'host',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition> hostContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'host',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition> hostMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'host',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      hostIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'host',
        value: '',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      hostIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'host',
        value: '',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition> isarIdEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      isarIdGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      isarIdLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition> isarIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'isarId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      lastSeenAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastSeenAt',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      lastSeenAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastSeenAt',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      lastSeenAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastSeenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      lastSeenAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastSeenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      lastSeenAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastSeenAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      lastSeenAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastSeenAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      pairedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'pairedAt',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      pairedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'pairedAt',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      pairedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pairedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      pairedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pairedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      pairedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pairedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      pairedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pairedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition> portEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'port',
        value: value,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      portGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'port',
        value: value,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition> portLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'port',
        value: value,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition> portBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'port',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      publicKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      publicKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'publicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      publicKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'publicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      publicKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'publicKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      publicKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'publicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      publicKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'publicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      publicKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'publicKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      publicKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'publicKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      publicKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publicKey',
        value: '',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      publicKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'publicKey',
        value: '',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      sharedKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'sharedKey',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      sharedKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'sharedKey',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      sharedKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sharedKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      sharedKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sharedKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      sharedKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sharedKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      sharedKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sharedKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      sharedKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sharedKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      sharedKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sharedKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      sharedKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sharedKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      sharedKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sharedKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      sharedKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sharedKey',
        value: '',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      sharedKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sharedKey',
        value: '',
      ));
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterFilterCondition>
      trustedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'trusted',
        value: value,
      ));
    });
  }
}

extension DeviceEntityQueryObject
    on QueryBuilder<DeviceEntity, DeviceEntity, QFilterCondition> {}

extension DeviceEntityQueryLinks
    on QueryBuilder<DeviceEntity, DeviceEntity, QFilterCondition> {}

extension DeviceEntityQuerySortBy
    on QueryBuilder<DeviceEntity, DeviceEntity, QSortBy> {
  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy>
      sortByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortByHost() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'host', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortByHostDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'host', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy>
      sortByLastSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortByPairedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pairedAt', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortByPairedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pairedAt', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortByPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'port', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortByPortDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'port', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortByPublicKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publicKey', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortByPublicKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publicKey', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortBySharedKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sharedKey', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortBySharedKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sharedKey', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortByTrusted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trusted', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> sortByTrustedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trusted', Sort.desc);
    });
  }
}

extension DeviceEntityQuerySortThenBy
    on QueryBuilder<DeviceEntity, DeviceEntity, QSortThenBy> {
  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deviceId', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByDisplayName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy>
      thenByDisplayNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'displayName', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByHost() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'host', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByHostDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'host', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy>
      thenByLastSeenAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSeenAt', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByPairedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pairedAt', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByPairedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pairedAt', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'port', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByPortDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'port', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByPublicKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publicKey', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByPublicKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publicKey', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenBySharedKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sharedKey', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenBySharedKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sharedKey', Sort.desc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByTrusted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trusted', Sort.asc);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QAfterSortBy> thenByTrustedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trusted', Sort.desc);
    });
  }
}

extension DeviceEntityQueryWhereDistinct
    on QueryBuilder<DeviceEntity, DeviceEntity, QDistinct> {
  QueryBuilder<DeviceEntity, DeviceEntity, QDistinct> distinctByDeviceId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deviceId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QDistinct> distinctByDisplayName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'displayName', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QDistinct> distinctByHost(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'host', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QDistinct> distinctByLastSeenAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSeenAt');
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QDistinct> distinctByPairedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pairedAt');
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QDistinct> distinctByPort() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'port');
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QDistinct> distinctByPublicKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'publicKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QDistinct> distinctBySharedKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sharedKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DeviceEntity, DeviceEntity, QDistinct> distinctByTrusted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'trusted');
    });
  }
}

extension DeviceEntityQueryProperty
    on QueryBuilder<DeviceEntity, DeviceEntity, QQueryProperty> {
  QueryBuilder<DeviceEntity, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<DeviceEntity, String, QQueryOperations> deviceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deviceId');
    });
  }

  QueryBuilder<DeviceEntity, String, QQueryOperations> displayNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'displayName');
    });
  }

  QueryBuilder<DeviceEntity, String, QQueryOperations> hostProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'host');
    });
  }

  QueryBuilder<DeviceEntity, DateTime?, QQueryOperations> lastSeenAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSeenAt');
    });
  }

  QueryBuilder<DeviceEntity, DateTime?, QQueryOperations> pairedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pairedAt');
    });
  }

  QueryBuilder<DeviceEntity, int, QQueryOperations> portProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'port');
    });
  }

  QueryBuilder<DeviceEntity, String, QQueryOperations> publicKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'publicKey');
    });
  }

  QueryBuilder<DeviceEntity, String?, QQueryOperations> sharedKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sharedKey');
    });
  }

  QueryBuilder<DeviceEntity, bool, QQueryOperations> trustedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'trusted');
    });
  }
}
