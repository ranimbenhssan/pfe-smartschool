import 'package:flutter/material.dart';
import '../theme/theme.dart';

class ClassBadge extends StatelessWidget {
  final String label;
  final Color color;

  const ClassBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: AppTypography.caption.copyWith(color: color)),
    );
  }
}
