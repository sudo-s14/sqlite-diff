import 'package:flutter/material.dart';
import 'package:sqlite_diff/sqlite_diff.dart';

import '../theme.dart';

class RowDetailPanel extends StatelessWidget {
  final RowDiff row;

  const RowDetailPanel({super.key, required this.row});

  @override
  Widget build(BuildContext context) {
    final changes = row.cellChanges ?? [];

    return Container(
      margin: const EdgeInsets.only(left: 28, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppTheme.modifiedColor(context).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cell Changes (${changes.length})',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          for (final change in changes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      change.columnName,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _valueLine(context, '- ',
                            _formatValue(change.oldValue),
                            AppTheme.deletedColor(context)),
                        _valueLine(context, '+ ',
                            _formatValue(change.newValue),
                            AppTheme.insertedColor(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _valueLine(
      BuildContext context, String prefix, String value, Color color) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(
            text: prefix,
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        TextSpan(text: value),
      ]),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    );
  }

  String _formatValue(Object? value) {
    if (value == null) return 'NULL';
    if (value is String) return '"$value"';
    if (value is List<int>) return 'BLOB(${value.length} bytes)';
    return value.toString();
  }
}
