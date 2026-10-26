// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:littlelumin/firebase_options.dart';

void main() {
  test('Test Firebase Initialization in flutter test', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await dotenv.load(
      isOptional: true,
      mergeWith: {
        'FIREBASE_PROJECT_ID': 'littlelumin-e7d26',
        'FIREBASE_MESSAGING_SENDER_ID': '1083938880859',
        'FIREBASE_DATABASE_URL': 'https://littlelumin-e7d26-default-rtdb.firebaseio.com',
        'FIREBASE_STORAGE_BUCKET': 'littlelumin-e7d26.firebasestorage.app',
        'FIREBASE_AUTH_DOMAIN': 'littlelumin-e7d26.firebaseapp.com',
        'FIREBASE_WEB_API_KEY': 'test_web_api_key',
        'FIREBASE_WEB_APP_ID': '1:1083938880859:web:9bd7166e6274a440bfae7e',
      },
    );
    expect(DefaultFirebaseOptions.web.projectId, equals('littlelumin-e7d26'));
    expect(DefaultFirebaseOptions.web.apiKey, equals('test_web_api_key'));
  });
}
