// google_sign_in_web is a web-only package (pulls in dart:js_interop),
// so it can't be imported directly from code shared with mobile — this
// conditional export swaps in the stub on non-web compile targets.
export 'google_web_button_stub.dart'
    if (dart.library.js_interop) 'google_web_button_web.dart';
