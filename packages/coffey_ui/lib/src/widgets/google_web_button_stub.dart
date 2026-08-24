import 'package:flutter/widgets.dart';

/// Non-web fallback — LoginScreen only calls this behind `if (kIsWeb)`, so it
/// never actually renders, but the symbol must resolve for mobile builds.
Widget buildGoogleWebButton() => const SizedBox.shrink();
