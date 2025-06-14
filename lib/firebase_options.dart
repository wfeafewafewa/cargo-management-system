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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyDmAgMC4zkl2kMlMU4Kq9qX8sUK97_g684',
    appId: '1:250171152700:web:9c2474b94a058529b46639',
    messagingSenderId: '250171152700',
    projectId: 'cargo-management-system-b61b8',
    authDomain: 'cargo-management-system-b61b8.firebaseapp.com',
    storageBucket: 'cargo-management-system-b61b8.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAAw_X2gRVbpximxsf2YrBDxEl7mZRVoA0',
    appId: '1:250171152700:android:84bca261acc9e416b46639',
    messagingSenderId: '250171152700',
    projectId: 'cargo-management-system-b61b8',
    storageBucket: 'cargo-management-system-b61b8.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCil2_2J7QHV1KnVfIr78MdGXDJND1chsw',
    appId: '1:250171152700:ios:448b20d9355145b1b46639',
    messagingSenderId: '250171152700',
    projectId: 'cargo-management-system-b61b8',
    storageBucket: 'cargo-management-system-b61b8.firebasestorage.app',
    iosClientId: '250171152700-gu1vu7cdtmfdmvs0pgi4lfqv5g1rfoh4.apps.googleusercontent.com',
    iosBundleId: 'com.example.cargoManagement',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDmAgMC4zkl2kMlMU4Kq9qX8sUK97_g684',
    appId: '1:250171152700:web:580241c4f158c43bb46639',
    messagingSenderId: '250171152700',
    projectId: 'cargo-management-system-b61b8',
    authDomain: 'cargo-management-system-b61b8.firebaseapp.com',
    storageBucket: 'cargo-management-system-b61b8.firebasestorage.app',
  );
}
