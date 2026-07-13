// File generated for Sotongware Control Firebase Web.
// Do not put passwords or secrets beyond public Firebase web config here.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for web in this project.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBd9l_VwFPMpavJAXEASghVd5ueJpQHSkw',
    appId: '1:417281978999:web:39ebce3135d7a646d0cc72',
    messagingSenderId: '417281978999',
    projectId: 'sotongware-control',
    authDomain: 'sotongware-control.firebaseapp.com',
    storageBucket: 'sotongware-control.firebasestorage.app',
  );
}
