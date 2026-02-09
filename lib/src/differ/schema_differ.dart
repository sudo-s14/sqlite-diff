import '../models/schema_diff.dart';
import '../models/table_schema.dart';

/// Compares two sets of table schemas and produces a [SchemaDiff].
class SchemaDiffer {
  SchemaDiff diff(
    Map<String, TableSchema> oldSchemas,
    Map<String, TableSchema> newSchemas,
  ) {
    final oldNames = oldSchemas.keys.toSet();
    final newNames = newSchemas.keys.toSet();

    final removedNames = oldNames.difference(newNames);
    final addedNames = newNames.difference(oldNames);
    final sharedNames = oldNames.intersection(newNames);

    final removedTables =
        removedNames.map((n) => oldSchemas[n]!).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final addedTables =
        addedNames.map((n) => newSchemas[n]!).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    final modifiedTables = <TableSchemaDiff>[];
    final unchangedTables = <String>[];

    for (final name in sharedNames.toList()..sort()) {
      final tableDiff = _diffTable(oldSchemas[name]!, newSchemas[name]!);
      if (tableDiff.hasDifferences) {
        modifiedTables.add(tableDiff);
      } else {
        unchangedTables.add(name);
      }
    }

    return SchemaDiff(
      removedTables: removedTables,
      addedTables: addedTables,
      modifiedTables: modifiedTables,
      unchangedTables: unchangedTables,
    );
  }

  TableSchemaDiff _diffTable(TableSchema oldSchema, TableSchema newSchema) {
    final oldCols = {for (final c in oldSchema.columns) c.name: c};
    final newCols = {for (final c in newSchema.columns) c.name: c};

    final oldColNames = oldCols.keys.toSet();
    final newColNames = newCols.keys.toSet();

    final columnDiffs = <ColumnDiff>[];

    // Removed columns
    for (final name in (oldColNames.difference(newColNames).toList()..sort())) {
      columnDiffs.add(ColumnDiff(
        columnName: name,
        changes: [ColumnChangeKind.removed],
        oldColumn: oldCols[name],
      ));
    }

    // Added columns
    for (final name in (newColNames.difference(oldColNames).toList()..sort())) {
      columnDiffs.add(ColumnDiff(
        columnName: name,
        changes: [ColumnChangeKind.added],
        newColumn: newCols[name],
      ));
    }

    // Modified columns
    for (final name
        in (oldColNames.intersection(newColNames).toList()..sort())) {
      final oldCol = oldCols[name]!;
      final newCol = newCols[name]!;

      if (oldCol != newCol) {
        final changes = <ColumnChangeKind>[];
        if (oldCol.type != newCol.type) {
          changes.add(ColumnChangeKind.typeChanged);
        }
        if (oldCol.nullable != newCol.nullable) {
          changes.add(ColumnChangeKind.nullabilityChanged);
        }
        if (oldCol.defaultValue != newCol.defaultValue) {
          changes.add(ColumnChangeKind.defaultValueChanged);
        }
        if (changes.length > 1) {
          changes.insert(0, ColumnChangeKind.modified);
        }

        columnDiffs.add(ColumnDiff(
          columnName: name,
          changes: changes,
          oldColumn: oldCol,
          newColumn: newCol,
        ));
      }
    }

    return TableSchemaDiff(
      tableName: oldSchema.name,
      columnDiffs: columnDiffs,
      createSqlChanged: oldSchema.createSql != newSchema.createSql,
      oldCreateSql: oldSchema.createSql,
      newCreateSql: newSchema.createSql,
    );
  }
}
