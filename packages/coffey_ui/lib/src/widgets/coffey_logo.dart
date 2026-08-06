import 'package:flutter/material.dart';

/// The Coffey Club Pickem crest. Source art has a transparent background,
/// so it drops cleanly onto any surface (app bar, dark mode, etc.).
class CoffeyLogo extends StatelessWidget {
  const CoffeyLogo({super.key, this.height = 32});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'packages/coffey_ui/assets/images/coffey_club_logo.png',
      height: height,
    );
  }
}
