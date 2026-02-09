import 'package:collection/collection.dart';
import 'package:sqlite3/common.dart';

import '../models/diff_options.dart';
import '../models/row_diff.dart';
import '../models/table_data_diff.dart';
import '../models/table_schema.dart';

/// Compares data in a single table across two databases.
class DataDiffer {
  /// Compare data for a single table.
  TableDataDiff diff({
    required CommonDatabase oldDb,
    required CommonDatabase newDb,
    required String tableName,
    required TableSchema oldSchema,
    required TableSchema newSchema,
    required DiffOptions options,
  }) {
    final keyColumns =
        _resolveKeyColumns(tableName, oldSchema, options);
    final comparedColumns =
        _resolveComparedColumns(tableName, oldSchema, newSchema, options);

    // Build the full SELECT column list (keys + compared, deduplicated)
    final selectColumns = <String>[...keyColumns];
    for (final col in comparedColumns) {
      if (!selectColumns.contains(col)) {
        selectColumns.add(col);
      }
    }

    final oldRows = _readRows(oldDb, tableName, selectColumns, keyColumns);
    final newRows = _readRows(newDb, tableName, selectColumns, keyColumns);

    final oldKeys = oldRows.keys.toSet();
    final newKeys = newRows.keys.toSet();

    // Deleted rows: keys only in old
    final deletedRows = <RowDiff>[];
    for (final key in oldKeys.difference(newKeys)) {
      deletedRows.add(RowDiff(
        kind: RowChangeKind.deleted,
        keyValues: _keyToMap(keyColumns, key),
        rowValues: oldRows[key]!,
      ));
    }

    // Inserted rows: keys only in new
    final insertedRows = <RowDiff>[];
    for (final key in newKeys.difference(oldKeys)) {
      insertedRows.add(RowDiff(
        kind: RowChangeKind.inserted,
        keyValues: _keyToMap(keyColumns, key),
        rowValues: newRows[key]!,
      ));
    }

    // Modified rows: keys in both, values differ
    final modifiedRows = <RowDiff>[];
    for (final key in oldKeys.intersection(newKeys)) {
      final oldRow = oldRows[key]!;
      final newRow = newRows[key]!;

      final cellChanges = <CellChange>[];
      for (final col in comparedColumns) {
        final oldVal = oldRow[col];
        final newVal = newRow[col];
        if (!_valuesEqual(oldVal, newVal)) {
          cellChanges.add(CellChange(
            columnName: col,
            oldValue: oldVal,
            newValue: newVal,
          ));
        }
      }

      if (cellChanges.isNotEmpty) {
        modifiedRows.add(RowDiff(
          kind: RowChangeKind.modified,
          keyValues: _keyToMap(keyColumns, key),
          rowValues: newRow,
          oldRowValues: oldRow,
          cellChanges: cellChanges,
        ));
      }
    }

    return TableDataDiff(
      tableName: tableName,
      keyColumns: keyColumns,
      comparedColumns: comparedColumns,
      insertedRows: insertedRows,
      deletedRows: deletedRows,
      modifiedRows: modifiedRows,
    );
  }

  List<String> _resolveKeyColumns(
    String tableName,
    TableSchema oldSchema,
    DiffOptions options,
  ) {
    // Custom key columns take precedence
    final custom = options.customKeyColumns;
    if (custom != null && custom.containsKey(tableName)) {
      return custom[tableName]!;
    }

    // Primary key if available
    if (oldSchema.primaryKeyColumns.isNotEmpty) {
      return oldSchema.primaryKeyColumns;
    }

    // Fallback to rowid
    return const ['rowid'];
  }

  List<String> _resolveComparedColumns(
    String tableName,
    TableSchema oldSchema,
    TableSchema newSchema,
    DiffOptions options,
  ) {
    final oldNames = oldSchema.columnNames.toSet();
    final newNames = newSchema.columnNames.toSet();
    var shared = oldNames.intersection(newNames).toList()..sort();

    final filter = options.columnFilters;
    if (filter != null && filter.containsKey(tableName)) {
      final allowed = filter[tableName]!;
      shared = shared.where((c) => allowed.contains(c)).toList();
    }

    return shared;
  }

  Map<_CompositeKey, Map<String, Object?>> _readRows(
    CommonDatabase db,
    String tableName,
    List<String> selectColumns,
    List<String> keyColumns,
  ) {
    final quotedCols = selectColumns.map((c) => '"$c"').join(', ');
    final sql = 'SELECT $quotedCols FROM "$tableName"';
    final result = db.select(sql);

    final rows = <_CompositeKey, Map<String, Object?>>{};
    for (final row in result) {
      final keyValues = keyColumns.map((k) => row[k]).toList();
      final key = _CompositeKey(keyValues);
      final rowMap = <String, Object?>{};
      for (final col in selectColumns) {
        rowMap[col] = row[col];
      }
      rows[key] = rowMap;
    }
    return rows;
  }

  Map<String, Object?> _keyToMap(
      List<String> keyColumns, _CompositeKey key) {
    return {
      for (var i = 0; i < keyColumns.length; i++)
        keyColumns[i]: key.values[i],
    };
  }

  bool _valuesEqual(Object? a, Object? b) {
    if (a is List<int> && b is List<int>) {
      return const ListEquality<int>().equals(a, b);
    }
    return a == b;
  }
}

/// A composite key with proper equality/hashCode for use as a Map key.
class _CompositeKey {
  final List<Object?> values;

  _CompositeKey(this.values);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _CompositeKey) return false;
    if (values.length != other.values.length) return false;
    for (var i = 0; i < values.length; i++) {
      final a = values[i];
      final b = other.values[i];
      if (a is List<int> && b is List<int>) {
        if (!const ListEquality<int>().equals(a, b)) return false;
      } else if (a != b) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    var hash = 0;
    for (final v in values) {
      if (v is List<int>) {
        hash = Object.hash(hash, Object.hashAll(v));
      } else {
        hash = Object.hash(hash, v);
      }
    }
    return hash;
  }
}
