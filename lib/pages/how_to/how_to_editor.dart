import 'package:flutter/material.dart';

class HowToEditor extends StatelessWidget {
  final TextEditingController pageTitleController;
  final TextEditingController pageContentController;
  final VoidCallback onDeletePage;

  const HowToEditor({
    super.key,
    required this.pageTitleController,
    required this.pageContentController,
    required this.onDeletePage,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: pageTitleController,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    decoration: const InputDecoration(
                      hintText: 'Seitentitel...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDeletePage,
                  tooltip: 'Diese Seite löschen',
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: pageContentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Inhalt schreiben...',
                  border: InputBorder.none,
                ),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
