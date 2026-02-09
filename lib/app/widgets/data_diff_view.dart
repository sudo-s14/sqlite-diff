import 'package:flutter/material.dart';
import 'package:sqlite_diff/sqlite_diff.dart';

import '../models/diff_state.dart';
import '../theme.dart';
import 'row_detail_panel.dart';

class DataDiffView extends StatelessWidget {
  final DiffState state;
  final String tableName;

  const DataDiffView({
    super.key,
    required this.state,
    required this.tableName,
  });

  @override
  Widget build(BuildContext context) {
    final tableDataDiff =
        state.diff!.dataDiffs.where((d) => d.tableName == tableName).firstOrNull;

    if (tableDataDiff == null || tableDataDiff.isEmpty) {
      return const Center(child: Text('No data changes for this table.'));
    }

    return Column(
      children: [
        // Summary bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _summaryBar(context, tableDataDiff),
        ),
        // Column headers
        _buildColumnHeaders(context, tableDataDiff),
        // Scrollable rows
        Expanded(
          child: ListView(
            children: [
              for (final row in tableDataDiff.insertedRows)
                _buildRowTile(
                    context, row, RowChangeKind.inserted, tableDataDiff),
              for (final row in tableDataDiff.deletedRows)
                _buildRowTile(
                    context, row, RowChangeKind.deleted, tableDataDiff),
              for (final row in tableDataDiff.modifiedRows)
                _buildModifiedRowTile(context, row, tableDataDiff),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryBar(BuildContext context, TableDataDiff diff) {
    return Row(
      children: [
        if (diff.insertedRows.isNotEmpty)
          _summaryChip(context, '+${diff.insertedRows.length} inserted',
              AppTheme.insertedColor(context)),
        if (diff.deletedRows.isNotEmpty) ...[
          const SizedBox(width: 8),
          _summaryChip(context, '-${diff.deletedRows.length} deleted',
              AppTheme.deletedColor(context)),
        ],
        if (diff.modifiedRows.isNotEmpty) ...[
          const SizedBox(width: 8),
          _summaryChip(context, '~${diff.modifiedRows.length} modified',
              AppTheme.modifiedColor(context)),
        ],
        const Spacer(),
        Text('Key: ${diff.keyColumns.join(", ")}',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _summaryChip(BuildContext context, String text, Color color) {
    return Chip(
      label: Text(text, style: TextStyle(color: color, fontSize: 12)),
      side: BorderSide(color: color),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildColumnHeaders(BuildContext context, TableDataDiff diff) {
    final columns = diff.comparedColumns;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      child: Row(
        children: [
          const SizedBox(width: 28),
          for (final col in columns)
            Expanded(
              child: Text(col,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildRowTile(BuildContext context, RowDiff row,
      RowChangeKind kind, TableDataDiff tableDiff) {
    final Color bg;
    final Color accent;
    final IconData icon;

    switch (kind) {
      case RowChangeKind.inserted:
        bg = AppTheme.insertedBg(context);
        accent = AppTheme.insertedColor(context);
        icon = Icons.add;
      case RowChangeKind.deleted:
        bg = AppTheme.deletedBg(context);
        accent = AppTheme.deletedColor(context);
        icon = Icons.remove;
      case RowChangeKind.modified:
        bg = AppTheme.modifiedBg(context);
        accent = AppTheme.modifiedColor(context);
        icon = Icons.edit;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
            bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 12),
          for (final col in tableDiff.comparedColumns)
            Expanded(
              child: Text(
                _formatValue(row.rowValues[col]),
                style:
                    const TextStyle(fontFamily: 'monospace', fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModifiedRowTile(
      BuildContext context, RowDiff row, TableDataDiff tableDiff) {
    final rowKey = row.keyValues.entries
        .map((e) => '${e.key}=${e.value}')
        .join(',');
    final isExpanded = state.expandedRowKeys.contains(rowKey);

    return Column(
      children: [
        InkWell(
          onTap: () => state.toggleRowExpansion(rowKey),
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.modifiedBg(context),
              border: Border(
                  bottom:
                      BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: AppTheme.modifiedColor(context),
                ),
                const SizedBox(width: 12),
                for (final col in tableDiff.comparedColumns)
                  Expanded(
                    child: Text(
                      _formatValue(row.rowValues[col]),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: _isCellChanged(row, col)
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (isExpanded) RowDetailPanel(row: row),
      ],
    );
  }

  bool _isCellChanged(RowDiff row, String col) {
    return row.cellChanges?.any((c) => c.columnName == col) ?? false;
  }

  String _formatValue(Object? value) {
    if (value == null) return 'NULL';
    if (value is String) return value;
    if (value is List<int>) return 'BLOB(${value.length}B)';
    return value.toString();
  }
}
