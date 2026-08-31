import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';

/// Opens the native share sheet with the pick-sheet PDF, built in-memory —
/// there's no need to write a temp file first.
Future<void> savePickSheetPdf(Uint8List bytes, String filename) async {
  final file = XFile.fromData(bytes, name: filename, mimeType: 'application/pdf');
  await SharePlus.instance.share(ShareParams(files: [file]));
}
