import 'package:sqflite_sqlcipher/sqflite.dart';

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
/// final diff = await SqliteDiff.compareFiles('old.db', 'new.db');
/// if (!diff.isEmpty) {
///   print(SqliteDiff.formatAsText(diff));
/// }
/// ```
class SqliteDiff {
  SqliteDiff._();

  /// Compare two SQLite databases given their file paths.
  ///
  /// Both databases are opened read-only for comparison.
  /// Optional [oldPassword] and [newPassword] unlock SQLCipher-encrypted databases.
  static Future<DatabaseDiff> compareFiles(
    String oldPath,
    String newPath, {
    DiffOptions options = DiffOptions.defaults,
    String? oldPassword,
    String? newPassword,
  }) async {
    final effectiveOptions =
        (options.oldLabel == null && options.newLabel == null)
            ? options.withLabels(oldLabel: oldPath, newLabel: newPath)
            : options;

    final oldDb = await _openDatabase(oldPath, oldPassword, 'Old database');
    try {
      final newDb = await _openDatabase(newPath, newPassword, 'New database');
      try {
        return await compareDatabases(oldDb, newDb, options: effectiveOptions);
      } finally {
        await newDb.close();
      }
    } finally {
      await oldDb.close();
    }
  }

  /// Open a database file with optional encryption key and verify it's readable.
  static Future<Database> _openDatabase(
      String path, String? password, String label) async {
    try {
      final db = await openDatabase(
        path,
        password: (password != null && password.isNotEmpty) ? password : null,
        readOnly: true,
      );

      // Verify the database is readable (catches wrong password or corrupt file)
      await db.rawQuery('SELECT count(*) FROM sqlite_master;');

      return db;
    } on DatabaseException catch (e) {
      final reason = _describeOpenError(e, password);
      throw DiffException('$label: $reason');
    } catch (e) {
      throw DiffException('$label: Failed to open "$path" — $e');
    }
  }

  /// Produce a human-readable error reason from a DatabaseException.
  static String _describeOpenError(DatabaseException e, String? password) {
    final msg = e.toString().toLowerCase();
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
    return e.toString();
  }

  /// Compare two already-open SQLite database connections.
  ///
  /// The caller is responsible for managing the lifecycle of both databases.
  static Future<DatabaseDiff> compareDatabases(
    Database oldDb,
    Database newDb, {
    DiffOptions options = DiffOptions.defaults,
  }) async {
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
