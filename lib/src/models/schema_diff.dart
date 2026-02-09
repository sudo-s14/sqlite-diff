import 'package:meta/meta.dart';

import 'column_info.dart';
import 'table_schema.dart';

/// Describes how a single column changed between two database versions.
enum ColumnChangeKind {
  added,
  removed,
  typeChanged,
  nullabilityChanged,
  defaultValueChanged,
  modified,
}

/// A single column-level change.
@immutable
final class ColumnDiff {
  /// The column name.
  final String columnName;

  /// The kind(s) of change detected.
  final List<ColumnChangeKind> changes;

  /// Column definition in the old database, or null if added.
  final ColumnInfo? oldColumn;

  /// Column definition in the new database, or null if removed.
  final ColumnInfo? newColumn;

  const ColumnDiff({
    required this.columnName,
    required this.changes,
    this.oldColumn,
    this.newColumn,
  });
}

/// Schema differences for a single table that exists in both databases.
@immutable
final class TableSchemaDiff {
  /// The table name.
  final String tableName;

  /// Columns that were added, removed, or changed.
  final List<ColumnDiff> columnDiffs;

  /// Whether the CREATE TABLE statement itself changed.
  final bool createSqlChanged;

  /// Old CREATE TABLE SQL.
  final String oldCreateSql;

  /// New CREATE TABLE SQL.
  final String newCreateSql;

  const TableSchemaDiff({
    required this.tableName,
    required this.columnDiffs,
    required this.createSqlChanged,
    required this.oldCreateSql,
    required this.newCreateSql,
  });

  /// True if there are any schema differences for this table.
  bool get hasDifferences => columnDiffs.isNotEmpty || createSqlChanged;
}

/// All schema-level differences between two databases.
@immutable
final class SchemaDiff {
  /// Tables that exist only in the old database.
  final List<TableSchema> removedTables;

  /// Tables that exist only in the new database.
  final List<TableSchema> addedTables;

  /// Tables that exist in both but have schema changes.
  final List<TableSchemaDiff> modifiedTables;

  /// Tables that exist in both with identical schemas.
  final List<String> unchangedTables;

  const SchemaDiff({
    required this.removedTables,
    required this.addedTables,
    required this.modifiedTables,
    required this.unchangedTables,
  });

  /// True if the schemas are identical.
  bool get isEmpty =>
      removedTables.isEmpty &&
      addedTables.isEmpty &&
      modifiedTables.isEmpty;
}
