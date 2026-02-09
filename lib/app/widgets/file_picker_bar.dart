import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/diff_state.dart';

class FilePickerBar extends StatelessWidget {
  final DiffState state;

  const FilePickerBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          _fileButton(
            context,
            label: 'Old Database',
            path: state.oldFilePath,
            onPick: () => _pickFile(context, isOld: true),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, size: 20),
          const SizedBox(width: 12),
          _fileButton(
            context,
            label: 'New Database',
            path: state.newFilePath,
            onPick: () => _pickFile(context, isOld: false),
          ),
          const SizedBox(width: 24),
          FilledButton.icon(
            onPressed: state.canCompare ? () => state.runDiff() : null,
            icon: const Icon(Icons.compare_arrows),
            label: const Text('Compare'),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.text_decrease, size: 18),
                  onPressed: state.fontSize > DiffState.minFontSize
                      ? state.decreaseFontSize
                      : null,
                  tooltip: 'Decrease font size',
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
                Text('${state.fontSize.round()}',
                    style: Theme.of(context).textTheme.labelMedium),
                IconButton(
                  icon: const Icon(Icons.text_increase, size: 18),
                  onPressed: state.fontSize < DiffState.maxFontSize
                      ? state.increaseFontSize
                      : null,
                  tooltip: 'Increase font size',
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fileButton(
    BuildContext context, {
    required String label,
    required String? path,
    required VoidCallback onPick,
  }) {
    final fileName = path?.split('/').last;

    return Expanded(
      child: OutlinedButton(
        onPressed: onPick,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          children: [
            const Icon(Icons.storage, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: Theme.of(context).textTheme.labelSmall),
                  if (fileName != null)
                    Text(fileName,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium),
                  if (fileName == null)
                    Text('Click to select...',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile(BuildContext context, {required bool isOld}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      dialogTitle: isOld ? 'Select Old Database' : 'Select New Database',
    );
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      if (isOld) {
        state.setOldFile(path);
      } else {
        state.setNewFile(path);
      }
    }
  }
}
