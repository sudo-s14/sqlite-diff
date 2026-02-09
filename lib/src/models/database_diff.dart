import 'package:meta/meta.dart';

import 'schema_diff.dart';
import 'table_data_diff.dart';

/// The complete result of diffing two SQLite databases.
@immutable
final class DatabaseDiff {
  final SchemaDiff schemaDiff;
  final List<TableDataDiff> dataDiffs;

  /// Label for the old database (e.g. file path).
  final String? oldLabel;

  /// Label for the new database (e.g. file path).
  final String? newLabel;

  const DatabaseDiff({
    required this.schemaDiff,
    required this.dataDiffs,
    this.oldLabel,
    this.newLabel,
  });

  /// True if the databases are identical.
  bool get isEmpty => schemaDiff.isEmpty && dataDiffs.every((d) => d.isEmpty);

  /// Tables with data changes only.
  List<TableDataDiff> get tablesWithDataChanges =>
      dataDiffs.where((d) => !d.isEmpty).toList();

  int get totalInsertedRows =>
      dataDiffs.fold(0, (sum, d) => sum + d.insertedRows.length);

  int get totalDeletedRows =>
      dataDiffs.fold(0, (sum, d) => sum + d.deletedRows.length);

  int get totalModifiedRows =>
      dataDiffs.fold(0, (sum, d) => sum + d.modifiedRows.length);
}
