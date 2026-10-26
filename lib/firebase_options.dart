// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Default [FirebaseOptions] for use with your Firebase apps.
/// Reads credentials dynamically from environment configuration (.env) with fallbacks.
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

  static String _env(String key, [String fallback = '']) {
    // 1. Runtime environment from flutter_dotenv (.env asset)
    try {
      final val = dotenv.env[key];
      if (val != null && val.trim().isNotEmpty) return val.trim();
    } catch (_) {
      // dotenv is optional when no local .env is available.
    }

    // 2. Build-time environment variable (--dart-define)
    final fromEnv = String.fromEnvironment(key);
    if (fromEnv.trim().isNotEmpty) return fromEnv.trim();

    // 3. Fallback to default
    return fallback;
  }

  static FirebaseOptions get web => FirebaseOptions(
        apiKey: _env('FIREBASE_WEB_API_KEY', 'AIzaSyBvd6I5O84UEHG34TJCUBiKlTMBDKvj5h8'),
        appId: _env('FIREBASE_WEB_APP_ID', '1:1083938880859:web:9bd7166e6274a440bfae7e'),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID', '1083938880859'),
        projectId: _env('FIREBASE_PROJECT_ID', 'littlelumin-e7d26'),
        authDomain: _env('FIREBASE_AUTH_DOMAIN', 'littlelumin-e7d26.firebaseapp.com'),
        databaseURL: _env('FIREBASE_DATABASE_URL', 'https://littlelumin-e7d26-default-rtdb.firebaseio.com'),
        storageBucket: _env('FIREBASE_STORAGE_BUCKET', 'littlelumin-e7d26.firebasestorage.app'),
        measurementId: _env('FIREBASE_WEB_MEASUREMENT_ID', 'G-JSC6VSJTCQ'),
      );

  static FirebaseOptions get android => FirebaseOptions(
        apiKey: _env('FIREBASE_ANDROID_API_KEY'),
        appId: _env('FIREBASE_ANDROID_APP_ID'),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID'),
        databaseURL: _env('FIREBASE_DATABASE_URL'),
        storageBucket: _env('FIREBASE_STORAGE_BUCKET'),
      );

  static FirebaseOptions get ios => FirebaseOptions(
        apiKey: _env('FIREBASE_IOS_API_KEY'),
        appId: _env('FIREBASE_IOS_APP_ID'),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID'),
        databaseURL: _env('FIREBASE_DATABASE_URL'),
        storageBucket: _env('FIREBASE_STORAGE_BUCKET'),
        androidClientId: _env('FIREBASE_ANDROID_CLIENT_ID'),
        iosClientId: _env('FIREBASE_IOS_CLIENT_ID'),
        iosBundleId: _env('FIREBASE_IOS_BUNDLE_ID'),
      );

  static FirebaseOptions get macos => FirebaseOptions(
        apiKey: _env('FIREBASE_IOS_API_KEY'),
        appId: _env('FIREBASE_IOS_APP_ID'),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID'),
        databaseURL: _env('FIREBASE_DATABASE_URL'),
        storageBucket: _env('FIREBASE_STORAGE_BUCKET'),
        androidClientId: _env('FIREBASE_ANDROID_CLIENT_ID'),
        iosClientId: _env('FIREBASE_IOS_CLIENT_ID'),
        iosBundleId: _env('FIREBASE_IOS_BUNDLE_ID'),
      );

  static FirebaseOptions get windows => FirebaseOptions(
        apiKey: _env('FIREBASE_WINDOWS_API_KEY'),
        appId: _env('FIREBASE_WINDOWS_APP_ID'),
        messagingSenderId: _env('FIREBASE_MESSAGING_SENDER_ID'),
        projectId: _env('FIREBASE_PROJECT_ID'),
        authDomain: _env('FIREBASE_AUTH_DOMAIN'),
        databaseURL: _env('FIREBASE_DATABASE_URL'),
        storageBucket: _env('FIREBASE_STORAGE_BUCKET'),
        measurementId: _env('FIREBASE_WINDOWS_MEASUREMENT_ID'),
      );
}
