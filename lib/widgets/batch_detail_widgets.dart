import 'package:flutter/material.dart';

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    var max = size.width;
    var dashWidth = 3;
    var dashSpace = 3;
    double startX = 0;
    while (startX < max) {
      canvas.drawLine(Offset(startX, size.height / 2),
          Offset(startX + dashWidth, size.height / 2), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class DottedBorderButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;

  const DottedBorderButton({
    super.key,
    required this.onTap,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.grey),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class BatchDetailCardSection extends StatelessWidget {
  const BatchDetailCardSection({
    super.key,
    required this.title,
    required this.children,
    this.icon = Icons.bar_chart,
  });

  final String title;
  final List<Widget> children;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: Colors.grey[400], fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          ...children
        ],
      ),
    );
  }
}
