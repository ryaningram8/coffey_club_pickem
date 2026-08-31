// package:web pulls in dart:js_interop, so it can't be imported directly
// from code shared with mobile — this conditional export swaps in the
// mobile implementation on non-web compile targets. Web triggers a plain
// browser download directly (bypassing share_plus's web plugin, whose
// registration wasn't taking effect in testing); mobile opens the native
// share sheet.
export 'pick_sheet_download_io.dart'
    if (dart.library.js_interop) 'pick_sheet_download_web.dart';
