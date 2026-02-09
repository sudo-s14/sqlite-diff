import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart' as s3;

import 'models/database_diff.dart';
import 'models/diff_options.dart';
import 'differ/database_differ.dart';
import 'formatter/text_formatter.dart';

/// Exception thrown when a database comparison fails.
class DiffException implements Exception {
  final String message;
  DiffException(this.message);

  @override
  String toString() => message;
}

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
  /// Both databases are opened in read-write mode (for WAL compatibility) with
  /// query_only=ON to prevent modifications, compared, and then closed.
  /// Optional [oldPassword] and [newPassword] unlock SQLCipher-encrypted databases.
  static DatabaseDiff compareFiles(
    String oldPath,
    String newPath, {
    DiffOptions options = DiffOptions.defaults,
    String? oldPassword,
    String? newPassword,
  }) {
    final effectiveOptions =
        (options.oldLabel == null && options.newLabel == null)
            ? options.withLabels(oldLabel: oldPath, newLabel: newPath)
            : options;

    final oldDb = _openDatabase(oldPath, oldPassword, 'Old database');
    try {
      final newDb = _openDatabase(newPath, newPassword, 'New database');
      try {
        return compareDatabases(oldDb, newDb, options: effectiveOptions);
      } finally {
        newDb.dispose();
      }
    } finally {
      oldDb.dispose();
    }
  }

  /// Open a database file with optional encryption key and verify it's readable.
  static CommonDatabase _openDatabase(
      String path, String? password, String label) {
    final CommonDatabase db;
    try {
      db = s3.sqlite3.open(path, mode: s3.OpenMode.readWrite);
    } on SqliteException catch (e) {
      throw DiffException(
          '$label: Failed to open "$path" — ${e.message}');
    } catch (e) {
      throw DiffException(
          '$label: Failed to open "$path" — $e');
    }

    try {
      if (password != null && password.isNotEmpty) {
        final escaped = password.replaceAll("'", "''");
        db.execute("PRAGMA key = '$escaped';");
      }
      // Prevent accidental writes — we only read for diffing
      db.execute('PRAGMA query_only = ON;');
      // Verify the database is readable (catches wrong password or corrupt file)
      db.select('SELECT count(*) FROM sqlite_master;');
    } on SqliteException catch (e) {
      db.dispose();
      final reason = _describeOpenError(e, password);
      throw DiffException('$label: $reason');
    } catch (e) {
      db.dispose();
      throw DiffException('$label: Failed to read "$path" — $e');
    }

    return db;
  }

  /// Produce a human-readable error reason from a SqliteException.
  static String _describeOpenError(SqliteException e, String? password) {
    final msg = e.message.toLowerCase();
    if (msg.contains('not a database') || msg.contains('file is encrypted')) {
      if (password != null && password.isNotEmpty) {
        return 'Wrong password or file is not a valid SQLite/SQLCipher database.';
      }
      return 'File is encrypted (password required) or not a valid SQLite database.';
    }
    if (msg.contains('no such file') || msg.contains('unable to open')) {
      return 'File not found or cannot be accessed.';
    }
    if (msg.contains('disk i/o error')) {
      return 'Disk I/O error — file may be locked or on an inaccessible volume.';
    }
    if (msg.contains('read-only')) {
      return 'File cannot be opened — permission denied.';
    }
    return e.message;
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
