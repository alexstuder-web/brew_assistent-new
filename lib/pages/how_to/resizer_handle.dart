import 'package:flutter/material.dart';

class ResizerHandle extends StatelessWidget {
  final Function(DragUpdateDetails) onHorizontalDragUpdate;

  const ResizerHandle({
    super.key,
    required this.onHorizontalDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: onHorizontalDragUpdate,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: Container(
          width: 4,
          color: Colors.transparent,
          child: Center(
            child: Container(
              width: 1,
              color: Theme.of(context).dividerColor.withAlpha(80),
            ),
          ),
        ),
      ),
    );
  }
}
