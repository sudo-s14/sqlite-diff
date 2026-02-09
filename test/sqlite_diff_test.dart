import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'package:sqlite_diff/sqlite_diff.dart';

import 'helpers/test_db.dart';

void main() {
  group('SqliteDiff.compareDatabases', () {
    late Database oldDb;
    late Database newDb;

    tearDown(() {
      oldDb.dispose();
      newDb.dispose();
    });

    test('end-to-end with schema and data changes', () {
      oldDb = createTestDb([
        'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)',
      ], [
        "INSERT INTO users VALUES (1, 'Alice', 30)",
        "INSERT INTO users VALUES (2, 'Bob', 25)",
      ]);
      newDb = createTestDb([
        'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)',
      ], [
        "INSERT INTO users VALUES (1, 'Alice', 'alice@test.com')",
        "INSERT INTO users VALUES (3, 'Charlie', 'charlie@test.com')",
      ]);

      final diff = SqliteDiff.compareDatabases(oldDb, newDb);

      // Schema: age removed, email added
      expect(diff.schemaDiff.modifiedTables, hasLength(1));
      final tableSchemaDiff = diff.schemaDiff.modifiedTables.first;
      expect(
        tableSchemaDiff.columnDiffs
            .where((c) => c.changes.contains(ColumnChangeKind.removed))
            .map((c) => c.columnName),
        contains('age'),
      );
      expect(
        tableSchemaDiff.columnDiffs
            .where((c) => c.changes.contains(ColumnChangeKind.added))
            .map((c) => c.columnName),
        contains('email'),
      );

      // Data: row 2 deleted, row 3 inserted
      // (only shared columns — id, name — are compared)
      final dataDiff = diff.dataDiffs.first;
      expect(dataDiff.insertedRows, hasLength(1));
      expect(dataDiff.insertedRows.first.keyValues, {'id': 3});
      expect(dataDiff.deletedRows, hasLength(1));
      expect(dataDiff.deletedRows.first.keyValues, {'id': 2});
    });

    test('identical databases produce empty diff', () {
      oldDb = createTestDb([
        'CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)',
      ], [
        "INSERT INTO t VALUES (1, 'x')",
      ]);
      newDb = createTestDb([
        'CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT)',
      ], [
        "INSERT INTO t VALUES (1, 'x')",
      ]);

      final diff = SqliteDiff.compareDatabases(oldDb, newDb);

      expect(diff.isEmpty, isTrue);
    });

    test('table filter restricts comparison', () {
      oldDb = createTestDb([
        'CREATE TABLE a (id INTEGER PRIMARY KEY, v TEXT)',
        'CREATE TABLE b (id INTEGER PRIMARY KEY, v TEXT)',
      ], [
        "INSERT INTO a VALUES (1, 'old')",
        "INSERT INTO b VALUES (1, 'old')",
      ]);
      newDb = createTestDb([
        'CREATE TABLE a (id INTEGER PRIMARY KEY, v TEXT)',
        'CREATE TABLE b (id INTEGER PRIMARY KEY, v TEXT)',
      ], [
        "INSERT INTO a VALUES (1, 'new')",
        "INSERT INTO b VALUES (1, 'new')",
      ]);

      final diff = SqliteDiff.compareDatabases(
        oldDb,
        newDb,
        options: DiffOptions(tables: {'a'}),
      );

      // Only table 'a' should be in data diffs
      expect(diff.dataDiffs, hasLength(1));
      expect(diff.dataDiffs.first.tableName, 'a');
    });

    test('includeSchema false skips schema diff', () {
      oldDb = createTestDb([
        'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
      ]);
      newDb = createTestDb([
        'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)',
      ]);

      final diff = SqliteDiff.compareDatabases(
        oldDb,
        newDb,
        options: DiffOptions(includeSchema: false),
      );

      expect(diff.schemaDiff.isEmpty, isTrue);
    });

    test('includeData false skips data diff', () {
      oldDb = createTestDb([
        'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
      ], [
        "INSERT INTO users VALUES (1, 'Alice')",
      ]);
      newDb = createTestDb([
        'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
      ], [
        "INSERT INTO users VALUES (1, 'Bob')",
      ]);

      final diff = SqliteDiff.compareDatabases(
        oldDb,
        newDb,
        options: DiffOptions(includeData: false),
      );

      expect(diff.dataDiffs, isEmpty);
    });
  });

  group('SqliteDiff.compareFiles', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('sqlite_diff_test_');
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('compares two database files', () {
      final oldPath = '${tmpDir.path}/old.db';
      final newPath = '${tmpDir.path}/new.db';

      // Create old database
      final oldDb = sqlite3.open(oldPath);
      oldDb.execute(
          'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT)');
      oldDb.execute("INSERT INTO items VALUES (1, 'Widget')");
      oldDb.dispose();

      // Create new database
      final newDb = sqlite3.open(newPath);
      newDb.execute(
          'CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT)');
      newDb.execute("INSERT INTO items VALUES (1, 'Gadget')");
      newDb.execute("INSERT INTO items VALUES (2, 'Doohickey')");
      newDb.dispose();

      final diff = SqliteDiff.compareFiles(oldPath, newPath);

      expect(diff.oldLabel, oldPath);
      expect(diff.newLabel, newPath);
      expect(diff.isEmpty, isFalse);

      final dataDiff = diff.dataDiffs.first;
      expect(dataDiff.insertedRows, hasLength(1));
      expect(dataDiff.modifiedRows, hasLength(1));
    });
  });

  group('SqliteDiff.formatAsText', () {
    test('produces readable output for a non-trivial diff', () {
      final oldDb = createTestDb([
        'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
      ], [
        "INSERT INTO users VALUES (1, 'Alice')",
        "INSERT INTO users VALUES (2, 'Bob')",
      ]);
      final newDb = createTestDb([
        'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
      ], [
        "INSERT INTO users VALUES (1, 'Alicia')",
        "INSERT INTO users VALUES (3, 'Charlie')",
      ]);

      final diff = SqliteDiff.compareDatabases(
        oldDb,
        newDb,
        options: DiffOptions(oldLabel: 'old.db', newLabel: 'new.db'),
      );
      final text = SqliteDiff.formatAsText(diff);

      expect(text, contains('--- old.db'));
      expect(text, contains('+++ new.db'));
      expect(text, contains('Table: users'));
      expect(text, contains('INSERT'));
      expect(text, contains('DELETE'));
      expect(text, contains('MODIFY'));

      oldDb.dispose();
      newDb.dispose();
    });
  });
}
