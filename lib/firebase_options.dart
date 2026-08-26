// Firebase configuration for the Super Admin console.
//
// This is a SEPARATE web app registration inside the SAME Firebase project as
// the Salon CRM (crmapp-1299dddb), so the console reads the live business data
// without any duplication. Web API keys are public by design — every access
// decision is enforced by Firestore Security Rules, never by hiding this key.
// No service-account or admin credential is present in this frontend.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAQ8LY9AWyVyfMbxOMGxoNSvjEqgXXu-eM',
    appId: '1:886981548742:web:dd180b8769f4b08bf415c7',
    messagingSenderId: '886981548742',
    projectId: 'crmapp-1299dddb',
    authDomain: 'crmapp-1299dddb.firebaseapp.com',
    storageBucket: 'crmapp-1299dddb.firebasestorage.app',
    measurementId: 'G-F32KEG8B1S',
  );

  static FirebaseOptions get currentPlatform => web;
}
