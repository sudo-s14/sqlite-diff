import 'package:sqlite3/sqlite3.dart';

/// Creates an in-memory SQLite database with the given DDL and DML statements.
Database createTestDb([
  List<String> ddl = const [],
  List<String> dml = const [],
]) {
  final db = sqlite3.openInMemory();
  for (final sql in ddl) {
    db.execute(sql);
  }
  for (final sql in dml) {
    db.execute(sql);
  }
  return db;
}
