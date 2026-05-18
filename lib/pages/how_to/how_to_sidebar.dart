import 'package:flutter/material.dart';
import '../../models/how_to_topic.dart';

class HowToSidebar extends StatelessWidget {
  final List<HowToTopic> topics;
  final int selectedIndex;
  final Function(int) onTopicSelected;
  final Function(int, int) onReorderTopics;
  final Function(int) onDeleteTopic;
  final VoidCallback onAddTopic;
  final double width;

  const HowToSidebar({
    super.key,
    required this.topics,
    required this.selectedIndex,
    required this.onTopicSelected,
    required this.onReorderTopics,
    required this.onDeleteTopic,
    required this.onAddTopic,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
          border: Border(
            right: BorderSide(color: Theme.of(context).dividerColor.withAlpha(50)),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ReorderableListView.builder(
                itemCount: topics.length,
                onReorder: onReorderTopics,
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) {
                  final t = topics[index];
                  final isSelected = selectedIndex == index;
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(t.id),
                    index: index,
                    child: ListTile(
                      title: Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                      trailing: isSelected ? IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                        onPressed: () => onDeleteTopic(index),
                        tooltip: 'Thema löschen',
                      ) : null,
                      selected: isSelected,
                      onTap: () => onTopicSelected(index),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: onAddTopic,
                icon: const Icon(Icons.add),
                label: const Text('Neues Thema'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
