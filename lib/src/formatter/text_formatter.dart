import '../models/database_diff.dart';
import '../models/schema_diff.dart';
import '../models/table_data_diff.dart';

/// Formats a [DatabaseDiff] as human-readable text, similar to git diff.
class DiffTextFormatter {
  /// Whether to include ANSI color codes.
  final bool colorize;

  /// Whether to include sections for unchanged tables.
  final bool showUnchanged;

  const DiffTextFormatter({
    this.colorize = false,
    this.showUnchanged = false,
  });

  // ANSI codes
  static const _red = '\x1B[31m';
  static const _green = '\x1B[32m';
  static const _yellow = '\x1B[33m';
  static const _cyan = '\x1B[36m';
  static const _bold = '\x1B[1m';
  static const _reset = '\x1B[0m';

  String format(DatabaseDiff diff) {
    final buf = StringBuffer();

    _writeHeader(buf, diff);

    if (diff.isEmpty) {
      buf.writeln('Databases are identical.');
      return buf.toString();
    }

    if (diff.schemaDiff.removedTables.isNotEmpty ||
        diff.schemaDiff.addedTables.isNotEmpty ||
        diff.schemaDiff.modifiedTables.isNotEmpty) {
      _writeSchemaDiff(buf, diff.schemaDiff);
    }

    final tablesWithChanges = diff.tablesWithDataChanges;
    if (tablesWithChanges.isNotEmpty) {
      _writeDataDiffs(buf, tablesWithChanges);
    }

    _writeSummary(buf, diff);

    return buf.toString();
  }

  void _writeHeader(StringBuffer buf, DatabaseDiff diff) {
    buf.writeln(_style('=== Database Diff ===', _bold));
    if (diff.oldLabel != null) {
      buf.writeln(_style('--- ${diff.oldLabel}', _red));
    }
    if (diff.newLabel != null) {
      buf.writeln(_style('+++ ${diff.newLabel}', _green));
    }
    buf.writeln();
  }

  void _writeSchemaDiff(StringBuffer buf, SchemaDiff schema) {
    buf.writeln(_style('=== Schema Changes ===', _bold));
    buf.writeln();

    if (schema.removedTables.isNotEmpty) {
      buf.writeln(_style('-- Removed Tables --', _red));
      for (final table in schema.removedTables) {
        buf.writeln(_style('- ${table.name}', _red));
      }
      buf.writeln();
    }

    if (schema.addedTables.isNotEmpty) {
      buf.writeln(_style('++ Added Tables ++', _green));
      for (final table in schema.addedTables) {
        buf.writeln(_style('+ ${table.name}', _green));
      }
      buf.writeln();
    }

    if (schema.modifiedTables.isNotEmpty) {
      buf.writeln(_style('~~ Modified Tables ~~', _yellow));
      for (final table in schema.modifiedTables) {
        buf.writeln(_style('~ ${table.tableName}', _yellow));
        for (final col in table.columnDiffs) {
          _writeColumnDiff(buf, col);
        }
        if (table.createSqlChanged &&
            table.columnDiffs.isEmpty) {
          buf.writeln('  SQL changed');
          buf.writeln(_style('  - ${table.oldCreateSql}', _red));
          buf.writeln(_style('  + ${table.newCreateSql}', _green));
        }
      }
      buf.writeln();
    }

    if (showUnchanged && schema.unchangedTables.isNotEmpty) {
      buf.writeln('Unchanged tables: ${schema.unchangedTables.join(', ')}');
      buf.writeln();
    }
  }

  void _writeColumnDiff(StringBuffer buf, ColumnDiff col) {
    if (col.changes.contains(ColumnChangeKind.removed)) {
      final c = col.oldColumn!;
      buf.writeln(_style(
          '  - Column removed: ${c.name} (${_columnDesc(c)})', _red));
    } else if (col.changes.contains(ColumnChangeKind.added)) {
      final c = col.newColumn!;
      buf.writeln(_style(
          '  + Column added: ${c.name} (${_columnDesc(c)})', _green));
    } else {
      buf.writeln(
          _style('  ~ Column changed: ${col.columnName}', _yellow));
      final oldCol = col.oldColumn!;
      final newCol = col.newColumn!;
      if (col.changes.contains(ColumnChangeKind.typeChanged)) {
        buf.writeln('    type: ${oldCol.type} -> ${newCol.type}');
      }
      if (col.changes.contains(ColumnChangeKind.nullabilityChanged)) {
        buf.writeln(
            '    nullable: ${oldCol.nullable} -> ${newCol.nullable}');
      }
      if (col.changes.contains(ColumnChangeKind.defaultValueChanged)) {
        buf.writeln(
            '    default: ${oldCol.defaultValue} -> ${newCol.defaultValue}');
      }
    }
  }

  String _columnDesc(col) {
    final parts = <String>[col.type as String];
    if (!(col.nullable as bool)) parts.add('NOT NULL');
    if (col.defaultValue != null) parts.add('DEFAULT ${col.defaultValue}');
    if (col.isPrimaryKey as bool) parts.add('PK');
    return parts.join(' ');
  }

  void _writeDataDiffs(StringBuffer buf, List<TableDataDiff> diffs) {
    buf.writeln(_style('=== Data Changes ===', _bold));
    buf.writeln();

    for (final tableDiff in diffs) {
      final keyStr = tableDiff.keyColumns.join(', ');
      buf.writeln(_style(
          '--- Table: ${tableDiff.tableName} (key: $keyStr) ---', _cyan));

      for (final row in tableDiff.insertedRows) {
        buf.writeln(_style('+ INSERT ${_formatRow(row.rowValues)}', _green));
      }

      for (final row in tableDiff.deletedRows) {
        buf.writeln(_style('- DELETE ${_formatRow(row.rowValues)}', _red));
      }

      for (final row in tableDiff.modifiedRows) {
        final keyStr = _formatRow(row.keyValues);
        final changes = row.cellChanges!
            .map((c) => '${c.columnName}: ${_formatValue(c.oldValue)}'
                ' -> ${_formatValue(c.newValue)}')
            .join(', ');
        buf.writeln(_style('~ MODIFY $keyStr $changes', _yellow));
      }

      buf.writeln();
    }
  }

  void _writeSummary(StringBuffer buf, DatabaseDiff diff) {
    final parts = <String>[];

    final schemaChanges = diff.schemaDiff.addedTables.length +
        diff.schemaDiff.removedTables.length +
        diff.schemaDiff.modifiedTables.length;
    if (schemaChanges > 0) {
      parts.add('$schemaChanges schema change(s)');
    }

    final dataChanges = diff.tablesWithDataChanges.length;
    if (dataChanges > 0) {
      parts.add('$dataChanges table(s) with data changes');
    }

    final inserted = diff.totalInsertedRows;
    final deleted = diff.totalDeletedRows;
    final modified = diff.totalModifiedRows;

    if (inserted > 0) parts.add('$inserted inserted');
    if (deleted > 0) parts.add('$deleted deleted');
    if (modified > 0) parts.add('$modified modified');

    if (parts.isNotEmpty) {
      buf.writeln('Summary: ${parts.join(', ')}');
    }
  }

  String _formatRow(Map<String, Object?> row) {
    final entries =
        row.entries.map((e) => '${e.key}: ${_formatValue(e.value)}');
    return '{${entries.join(', ')}}';
  }

  String _formatValue(Object? value) {
    if (value == null) return 'NULL';
    if (value is String) return '"$value"';
    if (value is List<int>) return 'BLOB(${value.length} bytes)';
    return value.toString();
  }

  String _style(String text, String code) {
    if (!colorize) return text;
    return '$code$text$_reset';
  }
}
