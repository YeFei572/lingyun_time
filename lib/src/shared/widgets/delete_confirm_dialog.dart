import 'package:flutter/material.dart';

Future<bool> showDeleteConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = '删除',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
      final dangerBackground = isDark
          ? scheme.errorContainer.withValues(alpha: 0.28)
          : scheme.errorContainer.withValues(alpha: 0.72);

      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        iconPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: dangerBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.error.withValues(alpha: 0.16)),
          ),
          child: Icon(Icons.delete_outline, color: scheme.error, size: 30),
        ),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            height: 1.45,
            fontSize: 14,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  ),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(confirmText),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );

  return confirmed ?? false;
}
