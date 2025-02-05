// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
    apiKey: 'AIzaSyAvmxeRjfVVJwI_sU8sd1DZY4O1VlHEhXc',
    appId: '1:965172345760:web:1212b0833a1a244cea02c5',
    messagingSenderId: '965172345760',
    projectId: 'chat-application-9de4f',
    authDomain: 'chat-application-9de4f.firebaseapp.com',
    storageBucket: 'chat-application-9de4f.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyChAHxfSgikHfUfe8JU0zii5B2eS_1d_PM',
    appId: '1:965172345760:android:d0c6238d5ad2e021ea02c5',
    messagingSenderId: '965172345760',
    projectId: 'chat-application-9de4f',
    storageBucket: 'chat-application-9de4f.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBWrz7meB3fsweD0Lv8kP4N2cLTORw87EI',
    appId: '1:965172345760:ios:159d0c268c0ecc7dea02c5',
    messagingSenderId: '965172345760',
    projectId: 'chat-application-9de4f',
    storageBucket: 'chat-application-9de4f.firebasestorage.app',
    iosBundleId: 'com.dummyapp.globalchat',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBWrz7meB3fsweD0Lv8kP4N2cLTORw87EI',
    appId: '1:965172345760:ios:159d0c268c0ecc7dea02c5',
    messagingSenderId: '965172345760',
    projectId: 'chat-application-9de4f',
    storageBucket: 'chat-application-9de4f.firebasestorage.app',
    iosBundleId: 'com.dummyapp.globalchat',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAvmxeRjfVVJwI_sU8sd1DZY4O1VlHEhXc',
    appId: '1:965172345760:web:27c6624118aa4458ea02c5',
    messagingSenderId: '965172345760',
    projectId: 'chat-application-9de4f',
    authDomain: 'chat-application-9de4f.firebaseapp.com',
    storageBucket: 'chat-application-9de4f.firebasestorage.app',
  );
}
