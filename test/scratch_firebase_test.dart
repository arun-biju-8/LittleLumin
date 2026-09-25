// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:littlelumin/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  test('Test Firebase Initialization in flutter test', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(fileName: ".env");
    print('Dotenv loaded.');
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
      print('Firebase initialized with web options.');
      final snap = await FirebaseFirestore.instance.collection('children').limit(2).get();
      print('Children count: ${snap.docs.length}');
    } catch (e, stack) {
      print('Firebase test error: $e\n$stack');
    }
  });
}
