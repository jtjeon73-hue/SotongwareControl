import 'package:firebase_core/firebase_core.dart';

bool isFirebaseReady() {
  try {
    Firebase.app();
    return true;
  } catch (_) {
    return false;
  }
}
