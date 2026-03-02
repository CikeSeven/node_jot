// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_cursor_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSyncCursorEntityCollection on Isar {
  IsarCollection<SyncCursorEntity> get syncCursorEntitys => this.collection();
}

const SyncCursorEntitySchema = CollectionSchema(
  name: r'SyncCursorEntity',
  id: -74307207056311713,
  properties: {
    r'lastLamportSeen': PropertySchema(
      id: 0,
      name: r'lastLamportSeen',
      type: IsarType.long,
    ),
    r'lastSyncAt': PropertySchema(
      id: 1,
      name: r'lastSyncAt',
      type: IsarType.dateTime,
    ),
    r'peerDeviceId': PropertySchema(
      id: 2,
      name: r'peerDeviceId',
      type: IsarType.string,
    )
  },
  estimateSize: _syncCursorEntityEstimateSize,
  serialize: _syncCursorEntitySerialize,
  deserialize: _syncCursorEntityDeserialize,
  deserializeProp: _syncCursorEntityDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'peerDeviceId': IndexSchema(
      id: -6226856260251651803,
      name: r'peerDeviceId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'peerDeviceId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _syncCursorEntityGetId,
  getLinks: _syncCursorEntityGetLinks,
  attach: _syncCursorEntityAttach,
  version: '3.1.0+1',
);

int _syncCursorEntityEstimateSize(
  SyncCursorEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.peerDeviceId.length * 3;
  return bytesCount;
}

void _syncCursorEntitySerialize(
  SyncCursorEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.lastLamportSeen);
  writer.writeDateTime(offsets[1], object.lastSyncAt);
  writer.writeString(offsets[2], object.peerDeviceId);
}

SyncCursorEntity _syncCursorEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SyncCursorEntity();
  object.isarId = id;
  object.lastLamportSeen = reader.readLong(offsets[0]);
  object.lastSyncAt = reader.readDateTimeOrNull(offsets[1]);
  object.peerDeviceId = reader.readString(offsets[2]);
  return object;
}

P _syncCursorEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _syncCursorEntityGetId(SyncCursorEntity object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _syncCursorEntityGetLinks(SyncCursorEntity object) {
  return [];
}

void _syncCursorEntityAttach(
    IsarCollection<dynamic> col, Id id, SyncCursorEntity object) {
  object.isarId = id;
}

extension SyncCursorEntityByIndex on IsarCollection<SyncCursorEntity> {
  Future<SyncCursorEntity?> getByPeerDeviceId(String peerDeviceId) {
    return getByIndex(r'peerDeviceId', [peerDeviceId]);
  }

  SyncCursorEntity? getByPeerDeviceIdSync(String peerDeviceId) {
    return getByIndexSync(r'peerDeviceId', [peerDeviceId]);
  }

  Future<bool> deleteByPeerDeviceId(String peerDeviceId) {
    return deleteByIndex(r'peerDeviceId', [peerDeviceId]);
  }

  bool deleteByPeerDeviceIdSync(String peerDeviceId) {
    return deleteByIndexSync(r'peerDeviceId', [peerDeviceId]);
  }

  Future<List<SyncCursorEntity?>> getAllByPeerDeviceId(
      List<String> peerDeviceIdValues) {
    final values = peerDeviceIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'peerDeviceId', values);
  }

  List<SyncCursorEntity?> getAllByPeerDeviceIdSync(
      List<String> peerDeviceIdValues) {
    final values = peerDeviceIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'peerDeviceId', values);
  }

  Future<int> deleteAllByPeerDeviceId(List<String> peerDeviceIdValues) {
    final values = peerDeviceIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'peerDeviceId', values);
  }

  int deleteAllByPeerDeviceIdSync(List<String> peerDeviceIdValues) {
    final values = peerDeviceIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'peerDeviceId', values);
  }

  Future<Id> putByPeerDeviceId(SyncCursorEntity object) {
    return putByIndex(r'peerDeviceId', object);
  }

  Id putByPeerDeviceIdSync(SyncCursorEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'peerDeviceId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByPeerDeviceId(List<SyncCursorEntity> objects) {
    return putAllByIndex(r'peerDeviceId', objects);
  }

  List<Id> putAllByPeerDeviceIdSync(List<SyncCursorEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'peerDeviceId', objects, saveLinks: saveLinks);
  }
}

extension SyncCursorEntityQueryWhereSort
    on QueryBuilder<SyncCursorEntity, SyncCursorEntity, QWhere> {
  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SyncCursorEntityQueryWhere
    on QueryBuilder<SyncCursorEntity, SyncCursorEntity, QWhereClause> {
  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterWhereClause>
      isarIdEqualTo(Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: isarId,
        upper: isarId,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterWhereClause>
      isarIdNotEqualTo(Id isarId) {
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

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterWhereClause>
      isarIdGreaterThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterWhereClause>
      isarIdLessThan(Id isarId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterWhereClause>
      isarIdBetween(
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

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterWhereClause>
      peerDeviceIdEqualTo(String peerDeviceId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'peerDeviceId',
        value: [peerDeviceId],
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterWhereClause>
      peerDeviceIdNotEqualTo(String peerDeviceId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'peerDeviceId',
              lower: [],
              upper: [peerDeviceId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'peerDeviceId',
              lower: [peerDeviceId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'peerDeviceId',
              lower: [peerDeviceId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'peerDeviceId',
              lower: [],
              upper: [peerDeviceId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension SyncCursorEntityQueryFilter
    on QueryBuilder<SyncCursorEntity, SyncCursorEntity, QFilterCondition> {
  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      isarIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
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

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
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

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      isarIdBetween(
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

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      lastLamportSeenEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastLamportSeen',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      lastLamportSeenGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastLamportSeen',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      lastLamportSeenLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastLamportSeen',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      lastLamportSeenBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastLamportSeen',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      lastSyncAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastSyncAt',
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      lastSyncAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastSyncAt',
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      lastSyncAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastSyncAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      lastSyncAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastSyncAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      lastSyncAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastSyncAt',
        value: value,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      lastSyncAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastSyncAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      peerDeviceIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'peerDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      peerDeviceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'peerDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      peerDeviceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'peerDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      peerDeviceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'peerDeviceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      peerDeviceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'peerDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      peerDeviceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'peerDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      peerDeviceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'peerDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      peerDeviceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'peerDeviceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      peerDeviceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'peerDeviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterFilterCondition>
      peerDeviceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'peerDeviceId',
        value: '',
      ));
    });
  }
}

extension SyncCursorEntityQueryObject
    on QueryBuilder<SyncCursorEntity, SyncCursorEntity, QFilterCondition> {}

extension SyncCursorEntityQueryLinks
    on QueryBuilder<SyncCursorEntity, SyncCursorEntity, QFilterCondition> {}

extension SyncCursorEntityQuerySortBy
    on QueryBuilder<SyncCursorEntity, SyncCursorEntity, QSortBy> {
  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterSortBy>
      sortByLastLamportSeen() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLamportSeen', Sort.asc);
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterSortBy>
      sortByLastLamportSeenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLamportSeen', Sort.desc);
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterSortBy>
      sortByLastSyncAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.asc);
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterSortBy>
      sortByLastSyncAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.desc);
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterSortBy>
      sortByPeerDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerDeviceId', Sort.asc);
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterSortBy>
      sortByPeerDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerDeviceId', Sort.desc);
    });
  }
}

extension SyncCursorEntityQuerySortThenBy
    on QueryBuilder<SyncCursorEntity, SyncCursorEntity, QSortThenBy> {
  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterSortBy>
      thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterSortBy>
      thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterSortBy>
      thenByLastLamportSeen() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLamportSeen', Sort.asc);
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterSortBy>
      thenByLastLamportSeenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLamportSeen', Sort.desc);
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterSortBy>
      thenByLastSyncAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.asc);
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterSortBy>
      thenByLastSyncAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncAt', Sort.desc);
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterSortBy>
      thenByPeerDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerDeviceId', Sort.asc);
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QAfterSortBy>
      thenByPeerDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'peerDeviceId', Sort.desc);
    });
  }
}

extension SyncCursorEntityQueryWhereDistinct
    on QueryBuilder<SyncCursorEntity, SyncCursorEntity, QDistinct> {
  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QDistinct>
      distinctByLastLamportSeen() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastLamportSeen');
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QDistinct>
      distinctByLastSyncAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSyncAt');
    });
  }

  QueryBuilder<SyncCursorEntity, SyncCursorEntity, QDistinct>
      distinctByPeerDeviceId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'peerDeviceId', caseSensitive: caseSensitive);
    });
  }
}

extension SyncCursorEntityQueryProperty
    on QueryBuilder<SyncCursorEntity, SyncCursorEntity, QQueryProperty> {
  QueryBuilder<SyncCursorEntity, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<SyncCursorEntity, int, QQueryOperations>
      lastLamportSeenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastLamportSeen');
    });
  }

  QueryBuilder<SyncCursorEntity, DateTime?, QQueryOperations>
      lastSyncAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSyncAt');
    });
  }

  QueryBuilder<SyncCursorEntity, String, QQueryOperations>
      peerDeviceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'peerDeviceId');
    });
  }
}
