import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/diff_state.dart';

class FilePickerBar extends StatefulWidget {
  final DiffState state;

  const FilePickerBar({super.key, required this.state});

  @override
  State<FilePickerBar> createState() => _FilePickerBarState();
}

class _FilePickerBarState extends State<FilePickerBar> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _showPasswords = false;
  bool _draggingOld = false;
  bool _draggingNew = false;

  @override
  void initState() {
    super.initState();
    _oldPasswordController.addListener(
        () => widget.state.setOldPassword(_oldPasswordController.text));
    _newPasswordController.addListener(
        () => widget.state.setNewPassword(_newPasswordController.text));
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Expanded(
            child: _dropZone(
              isDragging: _draggingOld,
              onDragEntered: () => setState(() => _draggingOld = true),
              onDragExited: () => setState(() => _draggingOld = false),
              onDropped: (path) {
                setState(() => _draggingOld = false);
                widget.state.setOldFile(path);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _fileButton(
                    context,
                    label: 'Old Database',
                    path: widget.state.oldFilePath,
                    onPick: () => _pickFile(context, isOld: true),
                    isDragging: _draggingOld,
                  ),
                  _passwordField(
                      _oldPasswordController, widget.state.oldFilePath != null),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: _dropZone(
              isDragging: _draggingNew,
              onDragEntered: () => setState(() => _draggingNew = true),
              onDragExited: () => setState(() => _draggingNew = false),
              onDropped: (path) {
                setState(() => _draggingNew = false);
                widget.state.setNewFile(path);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _fileButton(
                    context,
                    label: 'New Database',
                    path: widget.state.newFilePath,
                    onPick: () => _pickFile(context, isOld: false),
                    isDragging: _draggingNew,
                  ),
                  _passwordField(
                      _newPasswordController, widget.state.newFilePath != null),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          FilledButton.icon(
            onPressed:
                widget.state.canCompare ? () => widget.state.runDiff() : null,
            icon: const Icon(Icons.compare_arrows),
            label: const Text('Compare'),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.text_decrease, size: 18),
                  onPressed: widget.state.fontSize > DiffState.minFontSize
                      ? widget.state.decreaseFontSize
                      : null,
                  tooltip: 'Decrease font size',
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
                Text('${widget.state.fontSize.round()}',
                    style: Theme.of(context).textTheme.labelMedium),
                IconButton(
                  icon: const Icon(Icons.text_increase, size: 18),
                  onPressed: widget.state.fontSize < DiffState.maxFontSize
                      ? widget.state.increaseFontSize
                      : null,
                  tooltip: 'Increase font size',
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField(TextEditingController controller, bool fileSelected) {
    if (!fileSelected) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        height: 32,
        child: TextField(
          controller: controller,
          obscureText: !_showPasswords,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            prefixIcon: const Icon(Icons.lock_outline, size: 14),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 28, minHeight: 28),
            hintText: 'Password (optional)',
            hintStyle: const TextStyle(fontSize: 11),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(
                _showPasswords ? Icons.visibility_off : Icons.visibility,
                size: 14,
              ),
              onPressed: () =>
                  setState(() => _showPasswords = !_showPasswords),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropZone({
    required bool isDragging,
    required VoidCallback onDragEntered,
    required VoidCallback onDragExited,
    required void Function(String path) onDropped,
    required Widget child,
  }) {
    return DropTarget(
      onDragEntered: (_) => onDragEntered(),
      onDragExited: (_) => onDragExited(),
      onDragDone: (details) {
        if (details.files.isNotEmpty) {
          onDropped(details.files.first.path);
        }
      },
      child: child,
    );
  }

  Widget _fileButton(
    BuildContext context, {
    required String label,
    required String? path,
    required VoidCallback onPick,
    bool isDragging = false,
  }) {
    final fileName = path?.split('/').last;
    final colors = Theme.of(context).colorScheme;

    return OutlinedButton(
      onPressed: onPick,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        alignment: Alignment.centerLeft,
        side: isDragging
            ? BorderSide(color: colors.primary, width: 2)
            : null,
        backgroundColor:
            isDragging ? colors.primary.withValues(alpha: 0.08) : null,
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
                  Text(isDragging ? 'Drop here...' : 'Click or drop file...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDragging
                              ? colors.primary
                              : colors.outline)),
              ],
            ),
          ),
        ],
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
        widget.state.setOldFile(path);
      } else {
        widget.state.setNewFile(path);
      }
    }
  }
}
