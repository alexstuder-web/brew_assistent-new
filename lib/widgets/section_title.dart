import 'package:flutter/material.dart';

/// Einheitliche Section-Überschrift für Rezept-Seiten.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.color});

  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
