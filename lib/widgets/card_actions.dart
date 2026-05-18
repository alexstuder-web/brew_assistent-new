import 'package:flutter/material.dart';

class CardActions extends StatelessWidget {
  const CardActions({
    super.key, 
    required this.onEdit, 
    required this.onDelete,
    this.onLabel,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onLabel != null)
          IconButton(
            icon: const Icon(Icons.qr_code_2, color: Colors.blueAccent),
            onPressed: onLabel,
            tooltip: 'Etikette generieren',
          ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: onEdit,
          tooltip: 'Bearbeiten',
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: onDelete,
          tooltip: 'Löschen',
        ),
      ],
    );
  }
}
