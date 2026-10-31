import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'auth_gate.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: kIsWeb ? _webOptions() : null);
  runApp(const MomoApp());
}

/// Android reads android/app/google-services.json by itself. The web has no
/// such file, so it needs the values from the Firebase console's Web app.
///
/// Copy firebase-web.example.json to firebase-web.json, fill it in, then run:
/// flutter run -d web-server --dart-define-from-file=firebase-web.json
FirebaseOptions _webOptions() {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  if (apiKey.isEmpty || appId.isEmpty || projectId.isEmpty) {
    throw StateError(
      'Web Firebase config is missing. Copy firebase-web.example.json to '
      'firebase-web.json, fill it from Firebase console (Project settings, '
      'Your apps, Web app), then run with '
      '--dart-define-from-file=firebase-web.json. On Android use '
      'google-services.json instead.',
    );
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: senderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? null : authDomain,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
  );
}

class MomoApp extends StatelessWidget {
  const MomoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoMo Wallet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: momoYellow,
          primary: momoBlue,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F6F2),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      home: const AuthGate(),
    );
  }
}
