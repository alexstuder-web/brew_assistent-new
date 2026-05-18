import 'package:flutter/material.dart';
import '../../models/how_to_topic.dart';

class HowToTabBar extends StatelessWidget {
  final HowToTopic topic;
  final int selectedPageIndex;
  final Function(int) onPageSelected;
  final Function(int, int) onReorderPages;
  final VoidCallback onAddPage;
  final Function(BuildContext, Offset, int) onSecondaryTap;

  const HowToTabBar({
    super.key,
    required this.topic,
    required this.selectedPageIndex,
    required this.onPageSelected,
    required this.onReorderPages,
    required this.onAddPage,
    required this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor.withAlpha(50)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: topic.pages.length,
              onReorder: onReorderPages,
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 4,
                  color: Colors.transparent,
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final page = topic.pages[index];
                final isSelected = selectedPageIndex == index;
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(page.id),
                  index: index,
                  child: GestureDetector(
                    onTap: () => onPageSelected(index),
                    onSecondaryTapDown: (details) => onSecondaryTap(context, details.globalPosition, index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withAlpha(50) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        page.title.isEmpty ? 'Seite ${index + 1}' : page.title,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: onAddPage,
            tooltip: 'Neue Seite hinzufügen',
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
