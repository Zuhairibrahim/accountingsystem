import 'package:firebase_core/firebase_core.dart';

/// إعدادات Firebase للويب.
///
/// ضع هنا القيم من Firebase Console → Project Settings → Your apps → Web App
/// (كود firebaseConfig الذي يبدأ بـ apiKey / authDomain / projectId ...).
class FirebaseOptionsHolder {
  FirebaseOptionsHolder._();

  static const FirebaseOptions options = FirebaseOptions(
    apiKey: 'AIzaSyCIu0cEySmpAm2-jlv1n2aP7hD5Yu2nIfg',
    appId: '1:478813552526:web:b933d5332c245f78b1eedf',
    messagingSenderId: '478813552526',
    projectId: 'accountingsystem-fc3f0',
    authDomain: 'accountingsystem-fc3f0.firebaseapp.com',
    storageBucket: 'accountingsystem-fc3f0.firebasestorage.app',
  );
}