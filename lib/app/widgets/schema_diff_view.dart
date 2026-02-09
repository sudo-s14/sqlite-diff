import 'package:flutter/material.dart';
import 'package:sqlite_diff/sqlite_diff.dart';

import '../models/diff_state.dart';
import '../theme.dart';

class SchemaDiffView extends StatelessWidget {
  final DiffState state;
  final String tableName;

  const SchemaDiffView({
    super.key,
    required this.state,
    required this.tableName,
  });

  @override
  Widget build(BuildContext context) {
    final diff = state.diff!;
    final schema = diff.schemaDiff;

    final addedTable =
        schema.addedTables.where((t) => t.name == tableName).firstOrNull;
    if (addedTable != null) {
      return _buildAddedTable(context, addedTable);
    }

    final removedTable =
        schema.removedTables.where((t) => t.name == tableName).firstOrNull;
    if (removedTable != null) {
      return _buildRemovedTable(context, removedTable);
    }

    final modifiedTable = schema.modifiedTables
        .where((t) => t.tableName == tableName)
        .firstOrNull;
    if (modifiedTable != null) {
      return _buildModifiedTable(context, modifiedTable);
    }

    return const Center(child: Text('No schema changes for this table.'));
  }

  Widget _buildAddedTable(BuildContext context, TableSchema table) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader(
            context, 'Added Table', AppTheme.insertedColor(context)),
        const SizedBox(height: 8),
        _sqlBlock(context, table.createSql, AppTheme.insertedBg(context)),
        const SizedBox(height: 16),
        _columnsTable(context, table.columns, AppTheme.insertedBg(context)),
      ],
    );
  }

  Widget _buildRemovedTable(BuildContext context, TableSchema table) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader(
            context, 'Removed Table', AppTheme.deletedColor(context)),
        const SizedBox(height: 8),
        _sqlBlock(context, table.createSql, AppTheme.deletedBg(context)),
        const SizedBox(height: 16),
        _columnsTable(context, table.columns, AppTheme.deletedBg(context)),
      ],
    );
  }

  Widget _buildModifiedTable(
      BuildContext context, TableSchemaDiff tableDiff) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionHeader(
            context, 'Modified Table', AppTheme.modifiedColor(context)),
        if (tableDiff.createSqlChanged) ...[
          const SizedBox(height: 12),
          Text('CREATE SQL changed:',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          _sqlBlock(context, tableDiff.oldCreateSql,
              AppTheme.deletedBg(context),
              prefix: '- '),
          const SizedBox(height: 4),
          _sqlBlock(context, tableDiff.newCreateSql,
              AppTheme.insertedBg(context),
              prefix: '+ '),
        ],
        if (tableDiff.columnDiffs.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Column Changes:',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          ...tableDiff.columnDiffs.map((col) => _columnDiffCard(context, col)),
        ],
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String text, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 24, color: color),
        const SizedBox(width: 8),
        Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _sqlBlock(BuildContext context, String sql, Color bg,
      {String? prefix}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: SelectableText(
        '${prefix ?? ''}$sql',
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }

  Widget _columnsTable(
      BuildContext context, List<ColumnInfo> columns, Color bg) {
    return Table(
      border: TableBorder.all(color: Theme.of(context).dividerColor),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh),
          children: const [
            _HeaderCell('Name'),
            _HeaderCell('Type'),
            _HeaderCell('Nullable'),
            _HeaderCell('Default'),
            _HeaderCell('PK'),
          ],
        ),
        for (final col in columns)
          TableRow(
            decoration: BoxDecoration(color: bg),
            children: [
              _DataCell(col.name),
              _DataCell(col.type),
              _DataCell(col.nullable ? 'YES' : 'NO'),
              _DataCell(col.defaultValue ?? '-'),
              _DataCell(col.isPrimaryKey ? 'YES' : ''),
            ],
          ),
      ],
    );
  }

  Widget _columnDiffCard(BuildContext context, ColumnDiff col) {
    Color bg;
    Color accent;
    String label;

    if (col.changes.contains(ColumnChangeKind.added)) {
      bg = AppTheme.insertedBg(context);
      accent = AppTheme.insertedColor(context);
      label = '+ ${col.columnName}';
    } else if (col.changes.contains(ColumnChangeKind.removed)) {
      bg = AppTheme.deletedBg(context);
      accent = AppTheme.deletedColor(context);
      label = '- ${col.columnName}';
    } else {
      bg = AppTheme.modifiedBg(context);
      accent = AppTheme.modifiedColor(context);
      label = '~ ${col.columnName}';
    }

    return Card(
      color: bg,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: accent,
                    fontFamily: 'monospace')),
            if (col.oldColumn != null && col.newColumn != null) ...[
              const SizedBox(height: 4),
              for (final change in col.changes)
                if (change != ColumnChangeKind.modified)
                  _changeDetail(
                      context, change, col.oldColumn!, col.newColumn!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _changeDetail(BuildContext context, ColumnChangeKind kind,
      ColumnInfo oldCol, ColumnInfo newCol) {
    String detail;
    switch (kind) {
      case ColumnChangeKind.typeChanged:
        detail = 'Type: ${oldCol.type} -> ${newCol.type}';
      case ColumnChangeKind.nullabilityChanged:
        detail = 'Nullable: ${oldCol.nullable} -> ${newCol.nullable}';
      case ColumnChangeKind.defaultValueChanged:
        detail =
            'Default: ${oldCol.defaultValue ?? "NULL"} -> ${newCol.defaultValue ?? "NULL"}';
      default:
        detail = kind.name;
    }
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(detail,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text,
            style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );
}

class _DataCell extends StatelessWidget {
  final String text;
  const _DataCell(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      );
}
