import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/column_info.dart';
import '../models/table_schema.dart';

/// Reads table schemas from a SQLite database.
class SchemaReader {
  final Database _db;

  SchemaReader(this._db);

  /// Returns all user table names (excludes sqlite_* internal tables).
  Future<List<String>> readTableNames() async {
    final result = await _db.rawQuery(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name NOT LIKE 'sqlite_%' "
      "ORDER BY name",
    );
    return result.map((row) => row['name'] as String).toList();
  }

  /// Reads the full schema for a specific table.
  Future<TableSchema> readTableSchema(String tableName) async {
    final createResult = await _db.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tableName],
    );
    final createSql = createResult.first['sql'] as String;

    final columnsResult = await _db.rawQuery('PRAGMA table_info("$tableName")');

    final columns = <ColumnInfo>[];
    final primaryKeyColumns = <String>[];

    for (final row in columnsResult) {
      final pkIndex = row['pk'] as int;
      final isPk = pkIndex > 0;
      final colName = row['name'] as String;

      columns.add(ColumnInfo(
        name: colName,
        type: (row['type'] as String?) ?? '',
        nullable: (row['notnull'] as int) == 0,
        defaultValue: row['dflt_value'] as String?,
        isPrimaryKey: isPk,
        primaryKeyIndex: isPk ? pkIndex - 1 : -1,
      ));

      if (isPk) {
        primaryKeyColumns.add(colName);
      }
    }

    // Sort primary key columns by their pk index
    primaryKeyColumns.sort((a, b) {
      final aCol = columns.firstWhere((c) => c.name == a);
      final bCol = columns.firstWhere((c) => c.name == b);
      return aCol.primaryKeyIndex.compareTo(bCol.primaryKeyIndex);
    });

    final withoutRowId =
        createSql.toUpperCase().contains('WITHOUT ROWID');

    return TableSchema(
      name: tableName,
      createSql: createSql,
      columns: columns,
      primaryKeyColumns: primaryKeyColumns,
      withoutRowId: withoutRowId,
    );
  }

  /// Reads all table schemas.
  Future<Map<String, TableSchema>> readAllSchemas() async {
    final names = await readTableNames();
    final schemas = <String, TableSchema>{};
    for (final name in names) {
      schemas[name] = await readTableSchema(name);
    }
    return schemas;
  }
}
