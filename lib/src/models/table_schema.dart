import 'package:meta/meta.dart';

import 'column_info.dart';

/// Represents the schema of a single SQLite table.
@immutable
final class TableSchema {
  /// The table name.
  final String name;

  /// The full CREATE TABLE SQL statement.
  final String createSql;

  /// Ordered list of columns in this table.
  final List<ColumnInfo> columns;

  /// Names of columns that form the primary key, in order.
  final List<String> primaryKeyColumns;

  /// Whether this table uses WITHOUT ROWID.
  final bool withoutRowId;

  const TableSchema({
    required this.name,
    required this.createSql,
    required this.columns,
    required this.primaryKeyColumns,
    this.withoutRowId = false,
  });

  /// Returns a column by name, or null if not found.
  ColumnInfo? column(String name) {
    for (final col in columns) {
      if (col.name == name) return col;
    }
    return null;
  }

  /// All column names.
  List<String> get columnNames => columns.map((c) => c.name).toList();
}
