import 'package:flutter/material.dart';

/// Zeigt einen standardisierten Lösch-Bestätigungsdialog an.
///
/// Führt [onDelete] nur aus, wenn der Benutzer bestätigt.
Future<void> confirmDelete(
  BuildContext context,
  String title,
  Future<void> Function() onDelete,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content:
          const Text('Dieser Vorgang kann nicht rückgängig gemacht werden.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Löschen'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await onDelete();
  }
}
