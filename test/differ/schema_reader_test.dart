import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'package:sqlite_diff/src/differ/schema_reader.dart';

import '../helpers/test_db.dart';

void main() {
  late Database db;

  tearDown(() => db.dispose());

  test('reads table names excluding sqlite_ internal tables', () {
    db = createTestDb([
      'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)',
      'CREATE TABLE orders (id INTEGER PRIMARY KEY, amount REAL)',
    ]);

    final reader = SchemaReader(db);
    final names = reader.readTableNames();

    expect(names, ['orders', 'users']);
  });

  test('reads column info with types, nullable, defaults', () {
    db = createTestDb([
      'CREATE TABLE items ('
          'id INTEGER PRIMARY KEY, '
          'name TEXT NOT NULL, '
          'price REAL DEFAULT 0.0, '
          'description TEXT'
          ')',
    ]);

    final reader = SchemaReader(db);
    final schema = reader.readTableSchema('items');

    expect(schema.name, 'items');
    expect(schema.columns, hasLength(4));

    final idCol = schema.column('id')!;
    expect(idCol.type, 'INTEGER');
    expect(idCol.isPrimaryKey, isTrue);

    final nameCol = schema.column('name')!;
    expect(nameCol.type, 'TEXT');
    expect(nameCol.nullable, isFalse);

    final priceCol = schema.column('price')!;
    expect(priceCol.type, 'REAL');
    expect(priceCol.defaultValue, '0.0');
    expect(priceCol.nullable, isTrue);

    final descCol = schema.column('description')!;
    expect(descCol.type, 'TEXT');
    expect(descCol.nullable, isTrue);
    expect(descCol.defaultValue, isNull);
  });

  test('reads composite primary key', () {
    db = createTestDb([
      'CREATE TABLE order_items ('
          'order_id INTEGER, '
          'item_id INTEGER, '
          'quantity INTEGER, '
          'PRIMARY KEY (order_id, item_id)'
          ')',
    ]);

    final reader = SchemaReader(db);
    final schema = reader.readTableSchema('order_items');

    expect(schema.primaryKeyColumns, ['order_id', 'item_id']);
    expect(schema.column('order_id')!.isPrimaryKey, isTrue);
    expect(schema.column('item_id')!.isPrimaryKey, isTrue);
    expect(schema.column('quantity')!.isPrimaryKey, isFalse);
  });

  test('reads table with no explicit primary key', () {
    db = createTestDb([
      'CREATE TABLE logs (message TEXT, ts INTEGER)',
    ]);

    final reader = SchemaReader(db);
    final schema = reader.readTableSchema('logs');

    expect(schema.primaryKeyColumns, isEmpty);
  });

  test('readAllSchemas returns all tables', () {
    db = createTestDb([
      'CREATE TABLE a (id INTEGER PRIMARY KEY)',
      'CREATE TABLE b (id INTEGER PRIMARY KEY)',
      'CREATE TABLE c (id INTEGER PRIMARY KEY)',
    ]);

    final reader = SchemaReader(db);
    final schemas = reader.readAllSchemas();

    expect(schemas.keys, containsAll(['a', 'b', 'c']));
    expect(schemas, hasLength(3));
  });
}
