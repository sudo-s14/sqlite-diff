import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

import 'models/database_diff.dart';
import 'models/diff_options.dart';
import 'differ/database_differ.dart';
import 'formatter/text_formatter.dart';

/// Main entry point for comparing two SQLite databases.
///
/// ```dart
/// final diff = SqliteDiff.compareFiles('old.db', 'new.db');
/// if (!diff.isEmpty) {
///   print(SqliteDiff.formatAsText(diff));
/// }
/// ```
class SqliteDiff {
  SqliteDiff._();

  /// Compare two SQLite databases given their file paths.
  ///
  /// Both databases are opened in read-only mode, compared, and then closed.
  static DatabaseDiff compareFiles(
    String oldPath,
    String newPath, {
    DiffOptions options = DiffOptions.defaults,
  }) {
    final effectiveOptions =
        (options.oldLabel == null && options.newLabel == null)
            ? options.withLabels(oldLabel: oldPath, newLabel: newPath)
            : options;

    final oldDb = s3.sqlite3.open(oldPath, mode: s3.OpenMode.readOnly);
    final newDb = s3.sqlite3.open(newPath, mode: s3.OpenMode.readOnly);
    try {
      return compareDatabases(oldDb, newDb, options: effectiveOptions);
    } finally {
      oldDb.dispose();
      newDb.dispose();
    }
  }

  /// Compare two already-open SQLite database connections.
  ///
  /// The caller is responsible for managing the lifecycle of both databases.
  static DatabaseDiff compareDatabases(
    CommonDatabase oldDb,
    CommonDatabase newDb, {
    DiffOptions options = DiffOptions.defaults,
  }) {
    return DatabaseDiffer(oldDb, newDb, options).diff();
  }

  /// Format a [DatabaseDiff] as human-readable text.
  static String formatAsText(
    DatabaseDiff diff, {
    bool colorize = false,
    bool showUnchanged = false,
  }) {
    return DiffTextFormatter(
      colorize: colorize,
      showUnchanged: showUnchanged,
    ).format(diff);
  }
}
