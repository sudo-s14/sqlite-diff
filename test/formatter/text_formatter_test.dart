import 'package:test/test.dart';

import 'package:sqlite_diff/sqlite_diff.dart';

void main() {
  test('empty diff says databases are identical', () {
    const diff = DatabaseDiff(
      schemaDiff: SchemaDiff(
        removedTables: [],
        addedTables: [],
        modifiedTables: [],
        unchangedTables: ['users'],
      ),
      dataDiffs: [],
    );

    final text = const DiffTextFormatter().format(diff);

    expect(text, contains('Databases are identical'));
  });

  test('shows added table', () {
    final diff = DatabaseDiff(
      schemaDiff: SchemaDiff(
        removedTables: [],
        addedTables: [
          TableSchema(
            name: 'orders',
            createSql: 'CREATE TABLE orders (id INTEGER PRIMARY KEY)',
            columns: [
              ColumnInfo(
                name: 'id',
                type: 'INTEGER',
                nullable: false,
                defaultValue: null,
                isPrimaryKey: true,
              ),
            ],
            primaryKeyColumns: ['id'],
          ),
        ],
        modifiedTables: [],
        unchangedTables: [],
      ),
      dataDiffs: [],
    );

    final text = const DiffTextFormatter().format(diff);

    expect(text, contains('Added Tables'));
    expect(text, contains('+ orders'));
  });

  test('shows removed table', () {
    final diff = DatabaseDiff(
      schemaDiff: SchemaDiff(
        removedTables: [
          TableSchema(
            name: 'logs',
            createSql: 'CREATE TABLE logs (id INTEGER PRIMARY KEY)',
            columns: [
              ColumnInfo(
                name: 'id',
                type: 'INTEGER',
                nullable: false,
                defaultValue: null,
                isPrimaryKey: true,
              ),
            ],
            primaryKeyColumns: ['id'],
          ),
        ],
        addedTables: [],
        modifiedTables: [],
        unchangedTables: [],
      ),
      dataDiffs: [],
    );

    final text = const DiffTextFormatter().format(diff);

    expect(text, contains('Removed Tables'));
    expect(text, contains('- logs'));
  });

  test('shows data changes', () {
    const diff = DatabaseDiff(
      schemaDiff: SchemaDiff(
        removedTables: [],
        addedTables: [],
        modifiedTables: [],
        unchangedTables: ['users'],
      ),
      dataDiffs: [
        TableDataDiff(
          tableName: 'users',
          keyColumns: ['id'],
          comparedColumns: ['id', 'name', 'email'],
          insertedRows: [
            RowDiff(
              kind: RowChangeKind.inserted,
              keyValues: {'id': 3},
              rowValues: {'id': 3, 'name': 'Charlie', 'email': 'c@test.com'},
            ),
          ],
          deletedRows: [
            RowDiff(
              kind: RowChangeKind.deleted,
              keyValues: {'id': 5},
              rowValues: {'id': 5, 'name': 'Eve', 'email': 'eve@test.com'},
            ),
          ],
          modifiedRows: [
            RowDiff(
              kind: RowChangeKind.modified,
              keyValues: {'id': 1},
              rowValues: {'id': 1, 'name': 'Alice', 'email': 'alice@new.com'},
              oldRowValues: {
                'id': 1,
                'name': 'Alice',
                'email': 'alice@old.com'
              },
              cellChanges: [
                CellChange(
                  columnName: 'email',
                  oldValue: 'alice@old.com',
                  newValue: 'alice@new.com',
                ),
              ],
            ),
          ],
        ),
      ],
    );

    final text = const DiffTextFormatter().format(diff);

    expect(text, contains('Table: users'));
    expect(text, contains('+ INSERT'));
    expect(text, contains('Charlie'));
    expect(text, contains('- DELETE'));
    expect(text, contains('Eve'));
    expect(text, contains('~ MODIFY'));
    expect(text, contains('alice@old.com'));
    expect(text, contains('alice@new.com'));
  });

  test('colorize adds ANSI codes', () {
    const diff = DatabaseDiff(
      schemaDiff: SchemaDiff(
        removedTables: [],
        addedTables: [],
        modifiedTables: [],
        unchangedTables: [],
      ),
      dataDiffs: [
        TableDataDiff(
          tableName: 'items',
          keyColumns: ['id'],
          comparedColumns: ['id', 'name'],
          insertedRows: [
            RowDiff(
              kind: RowChangeKind.inserted,
              keyValues: {'id': 1},
              rowValues: {'id': 1, 'name': 'Test'},
            ),
          ],
          deletedRows: [],
          modifiedRows: [],
        ),
      ],
    );

    final text =
        const DiffTextFormatter(colorize: true).format(diff);

    expect(text, contains('\x1B[32m')); // green
    expect(text, contains('\x1B[0m')); // reset
  });

  test('summary counts are correct', () {
    const diff = DatabaseDiff(
      schemaDiff: SchemaDiff(
        removedTables: [],
        addedTables: [],
        modifiedTables: [],
        unchangedTables: [],
      ),
      dataDiffs: [
        TableDataDiff(
          tableName: 'users',
          keyColumns: ['id'],
          comparedColumns: ['id', 'name'],
          insertedRows: [
            RowDiff(
              kind: RowChangeKind.inserted,
              keyValues: {'id': 1},
              rowValues: {'id': 1, 'name': 'A'},
            ),
            RowDiff(
              kind: RowChangeKind.inserted,
              keyValues: {'id': 2},
              rowValues: {'id': 2, 'name': 'B'},
            ),
          ],
          deletedRows: [
            RowDiff(
              kind: RowChangeKind.deleted,
              keyValues: {'id': 3},
              rowValues: {'id': 3, 'name': 'C'},
            ),
          ],
          modifiedRows: [],
        ),
      ],
    );

    final text = const DiffTextFormatter().format(diff);

    expect(text, contains('2 inserted'));
    expect(text, contains('1 deleted'));
  });
}
