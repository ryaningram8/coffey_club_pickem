import 'package:flutter/material.dart';

/// Caps and centers screen content on wide viewports (desktop web) while
/// staying full-bleed on narrow ones (mobile/web-narrow) — every list-style
/// screen body (game cards, standings rows, admin lists) is full-bleed
/// single-column by default, which stretches unreadably across a wide
/// browser window without this.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 640,
  });

  final Widget child;
  final double maxWidth;

  /// Below this viewport width, content stays full-bleed (matches mobile
  /// and narrow web windows).
  static const double breakpoint = 720;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= breakpoint) return child;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        );
      },
    );
  }
}
