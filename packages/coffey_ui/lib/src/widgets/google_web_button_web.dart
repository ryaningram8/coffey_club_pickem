import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

/// Renders GIS's own "Sign in with Google" button. This is the only way to
/// get a real ID token on web — see auth_repository.dart's
/// `webGoogleSignInResults` for where the resulting credential is consumed.
///
/// No init call needed here: AuthRepository's `GoogleSignIn(...)` already
/// triggers it once on construction, and renderButton() internally waits on
/// that via its own FutureBuilder (showing "Getting ready" until set up) —
/// calling initWithParams() a second time here just races the first call on
/// the plugin's shared singleton state.
Widget buildGoogleWebButton() => gsi_web.renderButton(
  configuration: gsi_web.GSIButtonConfiguration(
    theme: gsi_web.GSIButtonTheme.outline,
    size: gsi_web.GSIButtonSize.large,
    text: gsi_web.GSIButtonText.continueWith,
    shape: gsi_web.GSIButtonShape.pill,
  ),
);
