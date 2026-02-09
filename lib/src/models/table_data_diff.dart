import 'package:meta/meta.dart';

import 'row_diff.dart';

/// Data differences for a single table.
@immutable
final class TableDataDiff {
  final String tableName;

  /// The columns used as the matching key.
  final List<String> keyColumns;

  /// All column names compared.
  final List<String> comparedColumns;

  final List<RowDiff> insertedRows;
  final List<RowDiff> deletedRows;
  final List<RowDiff> modifiedRows;

  const TableDataDiff({
    required this.tableName,
    required this.keyColumns,
    required this.comparedColumns,
    required this.insertedRows,
    required this.deletedRows,
    required this.modifiedRows,
  });

  int get totalChanges =>
      insertedRows.length + deletedRows.length + modifiedRows.length;

  bool get isEmpty => totalChanges == 0;
}
