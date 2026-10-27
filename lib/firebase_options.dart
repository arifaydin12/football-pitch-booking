// PLACEHOLDER - replace by running `flutterfire configure` (see README).
//
// This file is intentionally committed with dummy values so the project
// compiles without credentials. Running `flutterfire configure` overwrites it
// with the options of your own Firebase project. Demo mode
// (`--dart-define=DEMO_MODE=true`) never reads these values.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_FIREBASE_API_KEY',
    appId: 'YOUR_FIREBASE_WEB_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'your-project-id',
    authDomain: 'your-project-id.firebaseapp.com',
    storageBucket: 'your-project-id.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_FIREBASE_API_KEY',
    appId: 'YOUR_FIREBASE_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_FIREBASE_API_KEY',
    appId: 'YOUR_FIREBASE_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.firebasestorage.app',
    iosBundleId: 'com.example.pitchmanager',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_FIREBASE_API_KEY',
    appId: 'YOUR_FIREBASE_MACOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'your-project-id',
    storageBucket: 'your-project-id.firebasestorage.app',
    iosBundleId: 'com.example.pitchmanager',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'YOUR_FIREBASE_API_KEY',
    appId: 'YOUR_FIREBASE_WINDOWS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'your-project-id',
    authDomain: 'your-project-id.firebaseapp.com',
    storageBucket: 'your-project-id.firebasestorage.app',
  );
}
