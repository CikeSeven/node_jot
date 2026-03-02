// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'note_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetNoteEntityCollection on Isar {
  IsarCollection<NoteEntity> get noteEntitys => this.collection();
}

const NoteEntitySchema = CollectionSchema(
  name: r'NoteEntity',
  id: -8531409808967742627,
  properties: {
    r'archivedAt': PropertySchema(
      id: 0,
      name: r'archivedAt',
      type: IsarType.dateTime,
    ),
    r'baseRevision': PropertySchema(
      id: 1,
      name: r'baseRevision',
      type: IsarType.long,
    ),
    r'contentMd': PropertySchema(
      id: 2,
      name: r'contentMd',
      type: IsarType.string,
    ),
    r'deletedAt': PropertySchema(
      id: 3,
      name: r'deletedAt',
      type: IsarType.dateTime,
    ),
    r'headRevision': PropertySchema(
      id: 4,
      name: r'headRevision',
      type: IsarType.long,
    ),
    r'isConflictCopy': PropertySchema(
      id: 5,
      name: r'isConflictCopy',
      type: IsarType.bool,
    ),
    r'lastEditorDeviceId': PropertySchema(
      id: 6,
      name: r'lastEditorDeviceId',
      type: IsarType.string,
    ),
    r'noteId': PropertySchema(
      id: 7,
      name: r'noteId',
      type: IsarType.string,
    ),
    r'originNoteId': PropertySchema(
      id: 8,
      name: r'originNoteId',
      type: IsarType.string,
    ),
    r'title': PropertySchema(
      id: 9,
      name: r'title',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 10,
      name: r'updatedAt',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _noteEntityEstimateSize,
  serialize: _noteEntitySerialize,
  deserialize: _noteEntityDeserialize,
  deserializeProp: _noteEntityDeserializeProp,
  idName: r'isarId',
  indexes: {
    r'noteId': IndexSchema(
      id: -9014133502494436840,
      name: r'noteId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'noteId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _noteEntityGetId,
  getLinks: _noteEntityGetLinks,
  attach: _noteEntityAttach,
  version: '3.1.0+1',
);

int _noteEntityEstimateSize(
  NoteEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.contentMd.length * 3;
  bytesCount += 3 + object.lastEditorDeviceId.length * 3;
  bytesCount += 3 + object.noteId.length * 3;
  {
    final value = object.originNoteId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _noteEntitySerialize(
  NoteEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.archivedAt);
  writer.writeLong(offsets[1], object.baseRevision);
  writer.writeString(offsets[2], object.contentMd);
  writer.writeDateTime(offsets[3], object.deletedAt);
  writer.writeLong(offsets[4], object.headRevision);
  writer.writeBool(offsets[5], object.isConflictCopy);
  writer.writeString(offsets[6], object.lastEditorDeviceId);
  writer.writeString(offsets[7], object.noteId);
  writer.writeString(offsets[8], object.originNoteId);
  writer.writeString(offsets[9], object.title);
  writer.writeDateTime(offsets[10], object.updatedAt);
}

NoteEntity _noteEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = NoteEntity();
  object.archivedAt = reader.readDateTimeOrNull(offsets[0]);
  object.baseRevision = reader.readLong(offsets[1]);
  object.contentMd = reader.readString(offsets[2]);
  object.deletedAt = reader.readDateTimeOrNull(offsets[3]);
  object.headRevision = reader.readLong(offsets[4]);
  object.isConflictCopy = reader.readBool(offsets[5]);
  object.isarId = id;
  object.lastEditorDeviceId = reader.readString(offsets[6]);
  object.noteId = reader.readString(offsets[7]);
  object.originNoteId = reader.readStringOrNull(offsets[8]);
  object.title = reader.readString(offsets[9]);
  object.updatedAt = reader.readDateTime(offsets[10]);
  return object;
}

P _noteEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _noteEntityGetId(NoteEntity object) {
  return object.isarId;
}

List<IsarLinkBase<dynamic>> _noteEntityGetLinks(NoteEntity object) {
  return [];
}

void _noteEntityAttach(IsarCollection<dynamic> col, Id id, NoteEntity object) {
  object.isarId = id;
}

extension NoteEntityByIndex on IsarCollection<NoteEntity> {
  Future<NoteEntity?> getByNoteId(String noteId) {
    return getByIndex(r'noteId', [noteId]);
  }

  NoteEntity? getByNoteIdSync(String noteId) {
    return getByIndexSync(r'noteId', [noteId]);
  }

  Future<bool> deleteByNoteId(String noteId) {
    return deleteByIndex(r'noteId', [noteId]);
  }

  bool deleteByNoteIdSync(String noteId) {
    return deleteByIndexSync(r'noteId', [noteId]);
  }

  Future<List<NoteEntity?>> getAllByNoteId(List<String> noteIdValues) {
    final values = noteIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'noteId', values);
  }

  List<NoteEntity?> getAllByNoteIdSync(List<String> noteIdValues) {
    final values = noteIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'noteId', values);
  }

  Future<int> deleteAllByNoteId(List<String> noteIdValues) {
    final values = noteIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'noteId', values);
  }

  int deleteAllByNoteIdSync(List<String> noteIdValues) {
    final values = noteIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'noteId', values);
  }

  Future<Id> putByNoteId(NoteEntity object) {
    return putByIndex(r'noteId', object);
  }

  Id putByNoteIdSync(NoteEntity object, {bool saveLinks = true}) {
    return putByIndexSync(r'noteId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByNoteId(List<NoteEntity> objects) {
    return putAllByIndex(r'noteId', objects);
  }

  List<Id> putAllByNoteIdSync(List<NoteEntity> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'noteId', objects, saveLinks: saveLinks);
  }
}

extension NoteEntityQueryWhereSort
    on QueryBuilder<NoteEntity, NoteEntity, QWhere> {
  QueryBuilder<NoteEntity, NoteEntity, QAfterWhere> anyIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension NoteEntityQueryWhere
    on QueryBuilder<NoteEntity, NoteEntity, QWhereClause> {
  QueryBuilder<NoteEntity, NoteEntity, QAfterWhereClause> isarIdEqualTo(
      Id isarId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: isarId,
        upper: isarId,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterWhereClause> isarIdNotEqualTo(
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

  QueryBuilder<NoteEntity, NoteEntity, QAfterWhereClause> isarIdGreaterThan(
      Id isarId,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: isarId, includeLower: include),
      );
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterWhereClause> isarIdLessThan(
      Id isarId,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: isarId, includeUpper: include),
      );
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterWhereClause> isarIdBetween(
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

  QueryBuilder<NoteEntity, NoteEntity, QAfterWhereClause> noteIdEqualTo(
      String noteId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'noteId',
        value: [noteId],
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterWhereClause> noteIdNotEqualTo(
      String noteId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'noteId',
              lower: [],
              upper: [noteId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'noteId',
              lower: [noteId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'noteId',
              lower: [noteId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'noteId',
              lower: [],
              upper: [noteId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension NoteEntityQueryFilter
    on QueryBuilder<NoteEntity, NoteEntity, QFilterCondition> {
  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      archivedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'archivedAt',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      archivedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'archivedAt',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> archivedAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'archivedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      archivedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'archivedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      archivedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'archivedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> archivedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'archivedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      baseRevisionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'baseRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      baseRevisionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'baseRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      baseRevisionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'baseRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      baseRevisionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'baseRevision',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> contentMdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contentMd',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      contentMdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'contentMd',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> contentMdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'contentMd',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> contentMdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'contentMd',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      contentMdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'contentMd',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> contentMdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'contentMd',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> contentMdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'contentMd',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> contentMdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'contentMd',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      contentMdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contentMd',
        value: '',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      contentMdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'contentMd',
        value: '',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      deletedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      deletedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'deletedAt',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> deletedAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      deletedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> deletedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'deletedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> deletedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'deletedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      headRevisionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'headRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      headRevisionGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'headRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      headRevisionLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'headRevision',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      headRevisionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'headRevision',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      isConflictCopyEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isConflictCopy',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> isarIdEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isarId',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> isarIdGreaterThan(
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

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> isarIdLessThan(
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

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> isarIdBetween(
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

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      lastEditorDeviceIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastEditorDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      lastEditorDeviceIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastEditorDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      lastEditorDeviceIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastEditorDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      lastEditorDeviceIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastEditorDeviceId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      lastEditorDeviceIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lastEditorDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      lastEditorDeviceIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lastEditorDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      lastEditorDeviceIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lastEditorDeviceId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      lastEditorDeviceIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lastEditorDeviceId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      lastEditorDeviceIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastEditorDeviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      lastEditorDeviceIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lastEditorDeviceId',
        value: '',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> noteIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'noteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> noteIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'noteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> noteIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'noteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> noteIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'noteId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> noteIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'noteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> noteIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'noteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> noteIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'noteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> noteIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'noteId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> noteIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'noteId',
        value: '',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      noteIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'noteId',
        value: '',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      originNoteIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'originNoteId',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      originNoteIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'originNoteId',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      originNoteIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originNoteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      originNoteIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'originNoteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      originNoteIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'originNoteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      originNoteIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'originNoteId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      originNoteIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'originNoteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      originNoteIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'originNoteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      originNoteIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'originNoteId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      originNoteIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'originNoteId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      originNoteIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originNoteId',
        value: '',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      originNoteIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'originNoteId',
        value: '',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> titleContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> titleMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> updatedAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterFilterCondition> updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension NoteEntityQueryObject
    on QueryBuilder<NoteEntity, NoteEntity, QFilterCondition> {}

extension NoteEntityQueryLinks
    on QueryBuilder<NoteEntity, NoteEntity, QFilterCondition> {}

extension NoteEntityQuerySortBy
    on QueryBuilder<NoteEntity, NoteEntity, QSortBy> {
  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByArchivedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'archivedAt', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByArchivedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'archivedAt', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByBaseRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseRevision', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByBaseRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseRevision', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByContentMd() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentMd', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByContentMdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentMd', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByHeadRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'headRevision', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByHeadRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'headRevision', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByIsConflictCopy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isConflictCopy', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy>
      sortByIsConflictCopyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isConflictCopy', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy>
      sortByLastEditorDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEditorDeviceId', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy>
      sortByLastEditorDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEditorDeviceId', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByNoteId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteId', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByNoteIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteId', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByOriginNoteId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originNoteId', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByOriginNoteIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originNoteId', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension NoteEntityQuerySortThenBy
    on QueryBuilder<NoteEntity, NoteEntity, QSortThenBy> {
  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByArchivedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'archivedAt', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByArchivedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'archivedAt', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByBaseRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseRevision', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByBaseRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'baseRevision', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByContentMd() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentMd', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByContentMdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contentMd', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByDeletedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'deletedAt', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByHeadRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'headRevision', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByHeadRevisionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'headRevision', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByIsConflictCopy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isConflictCopy', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy>
      thenByIsConflictCopyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isConflictCopy', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isarId', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy>
      thenByLastEditorDeviceId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEditorDeviceId', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy>
      thenByLastEditorDeviceIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastEditorDeviceId', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByNoteId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteId', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByNoteIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteId', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByOriginNoteId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originNoteId', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByOriginNoteIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'originNoteId', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension NoteEntityQueryWhereDistinct
    on QueryBuilder<NoteEntity, NoteEntity, QDistinct> {
  QueryBuilder<NoteEntity, NoteEntity, QDistinct> distinctByArchivedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'archivedAt');
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QDistinct> distinctByBaseRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'baseRevision');
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QDistinct> distinctByContentMd(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'contentMd', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QDistinct> distinctByDeletedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'deletedAt');
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QDistinct> distinctByHeadRevision() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'headRevision');
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QDistinct> distinctByIsConflictCopy() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isConflictCopy');
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QDistinct> distinctByLastEditorDeviceId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastEditorDeviceId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QDistinct> distinctByNoteId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'noteId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QDistinct> distinctByOriginNoteId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'originNoteId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<NoteEntity, NoteEntity, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension NoteEntityQueryProperty
    on QueryBuilder<NoteEntity, NoteEntity, QQueryProperty> {
  QueryBuilder<NoteEntity, int, QQueryOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isarId');
    });
  }

  QueryBuilder<NoteEntity, DateTime?, QQueryOperations> archivedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'archivedAt');
    });
  }

  QueryBuilder<NoteEntity, int, QQueryOperations> baseRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'baseRevision');
    });
  }

  QueryBuilder<NoteEntity, String, QQueryOperations> contentMdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'contentMd');
    });
  }

  QueryBuilder<NoteEntity, DateTime?, QQueryOperations> deletedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'deletedAt');
    });
  }

  QueryBuilder<NoteEntity, int, QQueryOperations> headRevisionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'headRevision');
    });
  }

  QueryBuilder<NoteEntity, bool, QQueryOperations> isConflictCopyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isConflictCopy');
    });
  }

  QueryBuilder<NoteEntity, String, QQueryOperations>
      lastEditorDeviceIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastEditorDeviceId');
    });
  }

  QueryBuilder<NoteEntity, String, QQueryOperations> noteIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'noteId');
    });
  }

  QueryBuilder<NoteEntity, String?, QQueryOperations> originNoteIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'originNoteId');
    });
  }

  QueryBuilder<NoteEntity, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<NoteEntity, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }
}
