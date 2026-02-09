import 'package:flutter/material.dart';

import '../models/diff_state.dart';
import '../widgets/data_diff_view.dart';
import '../widgets/empty_state.dart';
import '../widgets/file_picker_bar.dart';
import '../widgets/schema_diff_view.dart';
import '../widgets/table_sidebar.dart';

class HomeScreen extends StatelessWidget {
  final DiffState state;

  const HomeScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          FilePickerBar(state: state),
          const Divider(height: 1),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (state.status == DiffStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == DiffStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('Error: ${state.errorMessage}',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    if (state.diff == null) {
      return const EmptyState();
    }
    if (state.diff!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: Colors.green),
            SizedBox(height: 16),
            Text('Databases are identical.'),
          ],
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 260,
          child: TableSidebar(state: state),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _buildContentArea(context)),
      ],
    );
  }

  Widget _buildContentArea(BuildContext context) {
    if (state.selectedTable == null) {
      return const Center(child: Text('Select a table from the sidebar.'));
    }

    return Column(
      children: [
        _buildTabBar(context),
        const Divider(height: 1),
        Expanded(
          child: state.activeTab == ContentTab.schema
              ? SchemaDiffView(
                  state: state,
                  tableName: state.selectedTable!,
                )
              : DataDiffView(
                  state: state,
                  tableName: state.selectedTable!,
                ),
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _tabButton(context, 'Schema', ContentTab.schema),
          const SizedBox(width: 8),
          _tabButton(context, 'Data', ContentTab.data),
          const Spacer(),
          Text(
            _summaryText(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _tabButton(BuildContext context, String label, ContentTab tab) {
    final isActive = state.activeTab == tab;
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) => state.setActiveTab(tab),
    );
  }

  String _summaryText() {
    final d = state.diff!;
    final parts = <String>[];
    if (d.totalInsertedRows > 0) parts.add('+${d.totalInsertedRows}');
    if (d.totalDeletedRows > 0) parts.add('-${d.totalDeletedRows}');
    if (d.totalModifiedRows > 0) parts.add('~${d.totalModifiedRows}');
    return parts.join('  ');
  }
}
