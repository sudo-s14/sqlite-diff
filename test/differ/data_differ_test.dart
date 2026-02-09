import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'package:sqlite_diff/sqlite_diff.dart';
import 'package:sqlite_diff/src/differ/data_differ.dart';
import 'package:sqlite_diff/src/differ/schema_reader.dart';

import '../helpers/test_db.dart';

void main() {
  late Database oldDb;
  late Database newDb;

  tearDown(() {
    oldDb.dispose();
    newDb.dispose();
  });

  TableDataDiff runDiff({
    required String tableName,
    DiffOptions options = DiffOptions.defaults,
  }) {
    final oldSchema = SchemaReader(oldDb).readTableSchema(tableName);
    final newSchema = SchemaReader(newDb).readTableSchema(tableName);
    return DataDiffer().diff(
      oldDb: oldDb,
      newDb: newDb,
      tableName: tableName,
      oldSchema: oldSchema,
      newSchema: newSchema,
      options: options,
    );
  }

  test('identical data produces empty diff', () {
    oldDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
    ], [
      "INSERT INTO users VALUES (1, 'Alice')",
      "INSERT INTO users VALUES (2, 'Bob')",
    ]);
    newDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
    ], [
      "INSERT INTO users VALUES (1, 'Alice')",
      "INSERT INTO users VALUES (2, 'Bob')",
    ]);

    final diff = runDiff(tableName: 'users');

    expect(diff.isEmpty, isTrue);
  });

  test('detects inserted rows', () {
    oldDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
    ], [
      "INSERT INTO users VALUES (1, 'Alice')",
    ]);
    newDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
    ], [
      "INSERT INTO users VALUES (1, 'Alice')",
      "INSERT INTO users VALUES (2, 'Bob')",
    ]);

    final diff = runDiff(tableName: 'users');

    expect(diff.insertedRows, hasLength(1));
    expect(diff.insertedRows.first.keyValues, {'id': 2});
    expect(diff.insertedRows.first.rowValues['name'], 'Bob');
  });

  test('detects deleted rows', () {
    oldDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
    ], [
      "INSERT INTO users VALUES (1, 'Alice')",
      "INSERT INTO users VALUES (2, 'Bob')",
    ]);
    newDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
    ], [
      "INSERT INTO users VALUES (1, 'Alice')",
    ]);

    final diff = runDiff(tableName: 'users');

    expect(diff.deletedRows, hasLength(1));
    expect(diff.deletedRows.first.keyValues, {'id': 2});
    expect(diff.deletedRows.first.rowValues['name'], 'Bob');
  });

  test('detects modified rows with cell changes', () {
    oldDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)',
    ], [
      "INSERT INTO users VALUES (1, 'Alice', 'alice@old.com')",
    ]);
    newDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)',
    ], [
      "INSERT INTO users VALUES (1, 'Alice', 'alice@new.com')",
    ]);

    final diff = runDiff(tableName: 'users');

    expect(diff.modifiedRows, hasLength(1));
    final row = diff.modifiedRows.first;
    expect(row.keyValues, {'id': 1});
    expect(row.cellChanges, hasLength(1));
    expect(row.cellChanges!.first.columnName, 'email');
    expect(row.cellChanges!.first.oldValue, 'alice@old.com');
    expect(row.cellChanges!.first.newValue, 'alice@new.com');
  });

  test('detects multiple cell changes in a row', () {
    oldDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)',
    ], [
      "INSERT INTO users VALUES (1, 'Bob', 'bob@old.com')",
    ]);
    newDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)',
    ], [
      "INSERT INTO users VALUES (1, 'Robert', 'bob@new.com')",
    ]);

    final diff = runDiff(tableName: 'users');

    expect(diff.modifiedRows, hasLength(1));
    expect(diff.modifiedRows.first.cellChanges, hasLength(2));
  });

  test('uses custom key columns when specified', () {
    oldDb = createTestDb([
      'CREATE TABLE events (ts INTEGER, kind TEXT, data TEXT)',
    ], [
      "INSERT INTO events VALUES (100, 'click', 'old-data')",
    ]);
    newDb = createTestDb([
      'CREATE TABLE events (ts INTEGER, kind TEXT, data TEXT)',
    ], [
      "INSERT INTO events VALUES (100, 'click', 'new-data')",
    ]);

    final diff = runDiff(
      tableName: 'events',
      options: DiffOptions(
        customKeyColumns: {
          'events': ['ts', 'kind'],
        },
      ),
    );

    expect(diff.keyColumns, ['ts', 'kind']);
    expect(diff.modifiedRows, hasLength(1));
    expect(diff.modifiedRows.first.keyValues, {'ts': 100, 'kind': 'click'});
  });

  test('falls back to rowid when no primary key', () {
    oldDb = createTestDb([
      'CREATE TABLE logs (message TEXT)',
    ], [
      "INSERT INTO logs VALUES ('hello')",
    ]);
    newDb = createTestDb([
      'CREATE TABLE logs (message TEXT)',
    ], [
      "INSERT INTO logs VALUES ('hello')",
      "INSERT INTO logs VALUES ('world')",
    ]);

    final diff = runDiff(tableName: 'logs');

    expect(diff.keyColumns, ['rowid']);
    expect(diff.insertedRows, hasLength(1));
  });

  test('handles NULL values correctly', () {
    oldDb = createTestDb([
      'CREATE TABLE items (id INTEGER PRIMARY KEY, value TEXT)',
    ], [
      'INSERT INTO items VALUES (1, NULL)',
    ]);
    newDb = createTestDb([
      'CREATE TABLE items (id INTEGER PRIMARY KEY, value TEXT)',
    ], [
      "INSERT INTO items VALUES (1, 'something')",
    ]);

    final diff = runDiff(tableName: 'items');

    expect(diff.modifiedRows, hasLength(1));
    expect(diff.modifiedRows.first.cellChanges!.first.oldValue, isNull);
    expect(diff.modifiedRows.first.cellChanges!.first.newValue, 'something');
  });

  test('NULL to NULL is not a change', () {
    oldDb = createTestDb([
      'CREATE TABLE items (id INTEGER PRIMARY KEY, value TEXT)',
    ], [
      'INSERT INTO items VALUES (1, NULL)',
    ]);
    newDb = createTestDb([
      'CREATE TABLE items (id INTEGER PRIMARY KEY, value TEXT)',
    ], [
      'INSERT INTO items VALUES (1, NULL)',
    ]);

    final diff = runDiff(tableName: 'items');

    expect(diff.isEmpty, isTrue);
  });

  test('column filter restricts compared columns', () {
    oldDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)',
    ], [
      "INSERT INTO users VALUES (1, 'Alice', 'alice@old.com')",
    ]);
    newDb = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT)',
    ], [
      "INSERT INTO users VALUES (1, 'Alice', 'alice@new.com')",
    ]);

    // Only compare 'name' column — email change should be invisible
    final diff = runDiff(
      tableName: 'users',
      options: DiffOptions(
        columnFilters: {
          'users': {'name'},
        },
      ),
    );

    expect(diff.isEmpty, isTrue);
  });

  test('empty tables produce empty diff', () {
    oldDb = createTestDb([
      'CREATE TABLE empty (id INTEGER PRIMARY KEY)',
    ]);
    newDb = createTestDb([
      'CREATE TABLE empty (id INTEGER PRIMARY KEY)',
    ]);

    final diff = runDiff(tableName: 'empty');

    expect(diff.isEmpty, isTrue);
  });

  test('composite primary key matching', () {
    oldDb = createTestDb([
      'CREATE TABLE order_items ('
          'order_id INTEGER, item_id INTEGER, qty INTEGER, '
          'PRIMARY KEY (order_id, item_id))',
    ], [
      'INSERT INTO order_items VALUES (1, 10, 2)',
      'INSERT INTO order_items VALUES (1, 20, 1)',
    ]);
    newDb = createTestDb([
      'CREATE TABLE order_items ('
          'order_id INTEGER, item_id INTEGER, qty INTEGER, '
          'PRIMARY KEY (order_id, item_id))',
    ], [
      'INSERT INTO order_items VALUES (1, 10, 5)',
      'INSERT INTO order_items VALUES (1, 20, 1)',
    ]);

    final diff = runDiff(tableName: 'order_items');

    expect(diff.modifiedRows, hasLength(1));
    expect(
        diff.modifiedRows.first.keyValues, {'order_id': 1, 'item_id': 10});
    expect(diff.modifiedRows.first.cellChanges!.first.oldValue, 2);
    expect(diff.modifiedRows.first.cellChanges!.first.newValue, 5);
  });
}
