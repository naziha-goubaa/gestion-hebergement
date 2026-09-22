// ⚠️  IMPORTANT — Ce fichier doit être généré avec vos propres clés Firebase.
//
// ÉTAPES :
//   1. Créez un projet sur https://console.firebase.google.com
//   2. Activez : Authentication (Email/Password), Firestore, Storage
//   3. Installez flutterfire CLI :
//        dart pub global activate flutterfire_cli
//   4. Dans ce dossier, exécutez :
//        flutterfire configure
//      → remplacez ce fichier par celui généré automatiquement.
//
// En attendant, les valeurs ci-dessous sont des PLACEHOLDERS qui permettent
// à l'IDE de compiler, mais l'app ne démarrera pas sans les vraies clés.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions ne supporte pas cette plateforme.',
        );
    }
  }

  // ── Web (Admin) ─────────────────────────────────────────────────────────────

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAP0iUPIrf0L-cx3FsZPGRZ-AFLAfkIJrw',
    appId: '1:730914223626:web:d62f65aa9e45d21210d1f3',
    messagingSenderId: '730914223626',
    projectId: 'gestion-hebergement',
    authDomain: 'gestion-hebergement.firebaseapp.com',
    storageBucket: 'gestion-hebergement.firebasestorage.app',
  );
  // ── Android (Mobile Étudiant) ────────────────────────────────────────────────

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCCJ7wxbZja6LqCAcHyuwHDtx88Y3WEFzc',
    appId: '1:730914223626:android:48150dd2ec3e025910d1f3',
    messagingSenderId: '730914223626',
    projectId: 'gestion-hebergement',
    storageBucket: 'gestion-hebergement.firebasestorage.app',
  );
  // ── iOS ─────────────────────────────────────────────────────────────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.cfscms.gestionHebergement',
  );

  // ── Windows (utilise la même config que Web) ─────────────────────────────────
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAP0iUPIrf0L-cx3FsZPGRZ-AFLAfkIJrw',
    appId: '1:730914223626:web:d62f65aa9e45d21210d1f3',
    messagingSenderId: '730914223626',
    projectId: 'gestion-hebergement',
    authDomain: 'gestion-hebergement.firebaseapp.com',
    storageBucket: 'gestion-hebergement.firebasestorage.app',
  );
}
