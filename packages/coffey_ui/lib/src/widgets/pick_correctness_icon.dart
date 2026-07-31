import 'package:flutter/material.dart';

/// Green check / red X / gray dash for a pick's correctness (null = game
/// not final yet). Shared by the live results overlay and the standings
/// pick breakdown.
class PickCorrectnessIcon extends StatelessWidget {
  const PickCorrectnessIcon({super.key, required this.isCorrect, this.size = 20});

  final bool? isCorrect;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (isCorrect == true) {
      return Icon(Icons.check_circle, color: Colors.green.shade600, size: size);
    }
    if (isCorrect == false) {
      return Icon(Icons.cancel, color: Theme.of(context).colorScheme.error, size: size);
    }
    return Icon(
      Icons.remove_circle_outline,
      color: Theme.of(context).colorScheme.outline,
      size: size,
    );
  }
}
