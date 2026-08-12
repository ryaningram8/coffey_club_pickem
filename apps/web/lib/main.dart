import 'package:coffey_ui/coffey_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (_) {
    // No Firebase config for this build yet (firebase_options.dart / VAPID
    // key / service worker) — push notifications stay off, rest of the app
    // works normally.
  }
  runApp(const CoffeyApp());
}
