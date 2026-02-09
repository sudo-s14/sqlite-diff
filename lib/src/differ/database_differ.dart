import 'package:sqlite3/common.dart';

import '../models/database_diff.dart';
import '../models/diff_options.dart';
import '../models/row_diff.dart';
import '../models/schema_diff.dart';
import '../models/table_data_diff.dart';
import '../models/table_schema.dart';
import 'data_differ.dart';
import 'schema_differ.dart';
import 'schema_reader.dart';

/// Orchestrates the full database diff operation.
class DatabaseDiffer {
  final CommonDatabase _oldDb;
  final CommonDatabase _newDb;
  final DiffOptions _options;

  DatabaseDiffer(this._oldDb, this._newDb, this._options);

  DatabaseDiff diff() {
    final oldReader = SchemaReader(_oldDb);
    final newReader = SchemaReader(_newDb);

    var oldSchemas = oldReader.readAllSchemas();
    var newSchemas = newReader.readAllSchemas();

    // Apply table filter
    if (_options.tables != null) {
      final allowed = _options.tables!;
      oldSchemas = {
        for (final e in oldSchemas.entries)
          if (allowed.contains(e.key)) e.key: e.value,
      };
      newSchemas = {
        for (final e in newSchemas.entries)
          if (allowed.contains(e.key)) e.key: e.value,
      };
    }

    // Schema diff
    final schemaDiff = _options.includeSchema
        ? SchemaDiffer().diff(oldSchemas, newSchemas)
        : const SchemaDiff(
            removedTables: [],
            addedTables: [],
            modifiedTables: [],
            unchangedTables: [],
          );

    // Data diff
    final dataDiffs = <TableDataDiff>[];

    if (_options.includeData) {
      final oldNames = oldSchemas.keys.toSet();
      final newNames = newSchemas.keys.toSet();
      final sharedTables = oldNames.intersection(newNames);

      final dataDiffer = DataDiffer();

      for (final tableName in sharedTables.toList()..sort()) {
        dataDiffs.add(dataDiffer.diff(
          oldDb: _oldDb,
          newDb: _newDb,
          tableName: tableName,
          oldSchema: oldSchemas[tableName]!,
          newSchema: newSchemas[tableName]!,
          options: _options,
        ));
      }

      // Optionally include data for tables in only one database
      if (_options.includeDataForExclusiveTables) {
        for (final tableName
            in (oldNames.difference(newNames).toList()..sort())) {
          dataDiffs.add(_allRowsAs(
            _oldDb,
            tableName,
            oldSchemas[tableName]!,
            RowChangeKind.deleted,
          ));
        }
        for (final tableName
            in (newNames.difference(oldNames).toList()..sort())) {
          dataDiffs.add(_allRowsAs(
            _newDb,
            tableName,
            newSchemas[tableName]!,
            RowChangeKind.inserted,
          ));
        }
      }
    }

    return DatabaseDiff(
      schemaDiff: schemaDiff,
      dataDiffs: dataDiffs,
      oldLabel: _options.oldLabel,
      newLabel: _options.newLabel,
    );
  }

  TableDataDiff _allRowsAs(
    CommonDatabase db,
    String tableName,
    TableSchema schema,
    RowChangeKind kind,
  ) {
    final keyColumns = schema.primaryKeyColumns.isNotEmpty
        ? schema.primaryKeyColumns
        : ['rowid'];
    final allColumns = schema.columnNames;

    final selectColumns = <String>[...keyColumns];
    for (final col in allColumns) {
      if (!selectColumns.contains(col)) {
        selectColumns.add(col);
      }
    }

    final quotedCols = selectColumns.map((c) => '"$c"').join(', ');
    final result = db.select('SELECT $quotedCols FROM "$tableName"');

    final rows = <RowDiff>[];
    for (final row in result) {
      final keyValues = <String, Object?>{};
      for (final k in keyColumns) {
        keyValues[k] = row[k];
      }
      final rowValues = <String, Object?>{};
      for (final col in selectColumns) {
        rowValues[col] = row[col];
      }
      rows.add(RowDiff(
        kind: kind,
        keyValues: keyValues,
        rowValues: rowValues,
      ));
    }

    return TableDataDiff(
      tableName: tableName,
      keyColumns: keyColumns,
      comparedColumns: allColumns,
      insertedRows: kind == RowChangeKind.inserted ? rows : [],
      deletedRows: kind == RowChangeKind.deleted ? rows : [],
      modifiedRows: [],
    );
  }
}
