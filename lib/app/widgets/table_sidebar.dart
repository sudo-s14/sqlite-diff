import 'package:flutter/material.dart';

import '../models/diff_state.dart';
import '../theme.dart';

class TableSidebar extends StatelessWidget {
  final DiffState state;

  const TableSidebar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final entries = state.sidebarEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Tables',
              style: Theme.of(context).textTheme.titleSmall),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isSelected = entry.tableName == state.selectedTable;

              return ListTile(
                dense: true,
                selected: isSelected,
                selectedTileColor:
                    Theme.of(context).colorScheme.primaryContainer,
                title: Text(entry.tableName),
                leading: _schemaIcon(context, entry.schemaStatus),
                trailing: entry.dataChangeCount > 0
                    ? _badge(context, entry.dataChangeCount)
                    : null,
                onTap: () => state.selectTable(entry.tableName),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _schemaIcon(BuildContext context, TableSchemaStatus status) {
    switch (status) {
      case TableSchemaStatus.added:
        return Icon(Icons.add_circle,
            size: 16, color: AppTheme.insertedColor(context));
      case TableSchemaStatus.removed:
        return Icon(Icons.remove_circle,
            size: 16, color: AppTheme.deletedColor(context));
      case TableSchemaStatus.modified:
        return Icon(Icons.edit,
            size: 16, color: AppTheme.modifiedColor(context));
      case TableSchemaStatus.unchanged:
        return const Icon(Icons.table_chart, size: 16);
    }
  }

  Widget _badge(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        count.toString(),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }
}
