// Required by the firebase_messaging Flutter web plugin — it auto-registers
// this file from the web root to receive pushes while the tab is
// backgrounded/closed. Config values match apps/web/lib/firebase_options.dart
// (all public client identifiers, not secrets).
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBFk8oqKw9oaMvtsPuEKeH8ktO-nuLdqTU',
  appId: '1:111220524779:web:f46cd93fd7bdc01e1ee0ae',
  messagingSenderId: '111220524779',
  projectId: 'rji-home',
  authDomain: 'rji-home.firebaseapp.com',
  storageBucket: 'rji-home.firebasestorage.app',
});

firebase.messaging();
