import 'package:meta/meta.dart';

/// The kind of change for a single row.
enum RowChangeKind {
  inserted,
  deleted,
  modified,
}

/// Describes a change for a specific cell within a modified row.
@immutable
final class CellChange {
  final String columnName;
  final Object? oldValue;
  final Object? newValue;

  const CellChange({
    required this.columnName,
    required this.oldValue,
    required this.newValue,
  });
}

/// A single row-level change.
@immutable
final class RowDiff {
  /// What kind of change this represents.
  final RowChangeKind kind;

  /// The key values used to match this row.
  final Map<String, Object?> keyValues;

  /// For inserted: the full row from the new database.
  /// For deleted: the full row from the old database.
  /// For modified: the row from the new database.
  final Map<String, Object?> rowValues;

  /// Only populated for modified rows — the old row values.
  final Map<String, Object?>? oldRowValues;

  /// Only populated for modified rows — specific cell-level changes.
  final List<CellChange>? cellChanges;

  const RowDiff({
    required this.kind,
    required this.keyValues,
    required this.rowValues,
    this.oldRowValues,
    this.cellChanges,
  });
}
