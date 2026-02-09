import 'package:test/test.dart';

import 'package:sqlite_diff/src/differ/schema_differ.dart';
import 'package:sqlite_diff/src/differ/schema_reader.dart';
import 'package:sqlite_diff/sqlite_diff.dart';

import '../helpers/test_db.dart';

void main() {
  test('identical schemas produce empty diff', () {
    final oldDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
    ]);
    final newDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
    ]);

    final oldSchemas = SchemaReader(oldDb).readAllSchemas();
    final newSchemas = SchemaReader(newDb).readAllSchemas();
    final diff = SchemaDiffer().diff(oldSchemas, newSchemas);

    expect(diff.isEmpty, isTrue);
    expect(diff.unchangedTables, ['users']);

    oldDb.dispose();
    newDb.dispose();
  });

  test('detects added table', () {
    final oldDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY)',
    ]);
    final newDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY)',
      'CREATE TABLE orders (id INTEGER PRIMARY KEY)',
    ]);

    final diff = SchemaDiffer().diff(
      SchemaReader(oldDb).readAllSchemas(),
      SchemaReader(newDb).readAllSchemas(),
    );

    expect(diff.addedTables, hasLength(1));
    expect(diff.addedTables.first.name, 'orders');

    oldDb.dispose();
    newDb.dispose();
  });

  test('detects removed table', () {
    final oldDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY)',
      'CREATE TABLE logs (id INTEGER PRIMARY KEY)',
    ]);
    final newDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY)',
    ]);

    final diff = SchemaDiffer().diff(
      SchemaReader(oldDb).readAllSchemas(),
      SchemaReader(newDb).readAllSchemas(),
    );

    expect(diff.removedTables, hasLength(1));
    expect(diff.removedTables.first.name, 'logs');

    oldDb.dispose();
    newDb.dispose();
  });

  test('detects added column', () {
    final oldDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
    ]);
    final newDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)',
    ]);

    final diff = SchemaDiffer().diff(
      SchemaReader(oldDb).readAllSchemas(),
      SchemaReader(newDb).readAllSchemas(),
    );

    expect(diff.modifiedTables, hasLength(1));
    final tableDiff = diff.modifiedTables.first;
    expect(tableDiff.tableName, 'users');

    final addedCol = tableDiff.columnDiffs
        .where((c) => c.changes.contains(ColumnChangeKind.added));
    expect(addedCol, hasLength(1));
    expect(addedCol.first.columnName, 'email');
    expect(addedCol.first.newColumn!.type, 'TEXT');

    oldDb.dispose();
    newDb.dispose();
  });

  test('detects removed column', () {
    final oldDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)',
    ]);
    final newDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
    ]);

    final diff = SchemaDiffer().diff(
      SchemaReader(oldDb).readAllSchemas(),
      SchemaReader(newDb).readAllSchemas(),
    );

    expect(diff.modifiedTables, hasLength(1));
    final removed = diff.modifiedTables.first.columnDiffs
        .where((c) => c.changes.contains(ColumnChangeKind.removed));
    expect(removed, hasLength(1));
    expect(removed.first.columnName, 'age');

    oldDb.dispose();
    newDb.dispose();
  });

  test('detects column type change', () {
    final oldDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, score INTEGER)',
    ]);
    final newDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, score REAL)',
    ]);

    final diff = SchemaDiffer().diff(
      SchemaReader(oldDb).readAllSchemas(),
      SchemaReader(newDb).readAllSchemas(),
    );

    expect(diff.modifiedTables, hasLength(1));
    final colDiff = diff.modifiedTables.first.columnDiffs.first;
    expect(colDiff.columnName, 'score');
    expect(colDiff.changes, contains(ColumnChangeKind.typeChanged));
    expect(colDiff.oldColumn!.type, 'INTEGER');
    expect(colDiff.newColumn!.type, 'REAL');

    oldDb.dispose();
    newDb.dispose();
  });

  test('detects nullability change', () {
    final oldDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
    ]);
    final newDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)',
    ]);

    final diff = SchemaDiffer().diff(
      SchemaReader(oldDb).readAllSchemas(),
      SchemaReader(newDb).readAllSchemas(),
    );

    expect(diff.modifiedTables, hasLength(1));
    final colDiff = diff.modifiedTables.first.columnDiffs.first;
    expect(colDiff.changes, contains(ColumnChangeKind.nullabilityChanged));

    oldDb.dispose();
    newDb.dispose();
  });
}
