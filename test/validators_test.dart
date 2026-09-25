import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/utils/validators.dart';

void main() {
  group('Universal Validators Tests', () {
    test('Email validator correctly evaluates valid and invalid emails', () {
      expect(Validators.email(''), 'Email is required');
      expect(Validators.email(null), 'Email is required');
      expect(Validators.email('invalid'), 'Email must contain @');
      expect(Validators.email('invalid@domain'), 'Email must have a domain');
      expect(Validators.email('test..user@domain.com'), 'Email cannot have consecutive dots');
      expect(Validators.email('valid.parent@example.com'), isNull);
    });

    test('Name validator enforces 3-50 chars and alphabetic characters', () {
      expect(Validators.name(''), 'Name is required');
      expect(Validators.name('Al'), 'Name must be at least 3 characters');
      expect(Validators.name('John123'), 'Name can only contain letters and spaces');
      expect(Validators.name('Dr. Smith'), 'Name can only contain letters and spaces');
      expect(Validators.name('Alice Wonder'), isNull);
    });

    test('Strong password requires 8+ chars, uppercase, lowercase, digit, no spaces', () {
      expect(Validators.strongPassword('short'), 'Password must be at least 8 characters');
      expect(Validators.strongPassword('nouppercase12'), 'Need 1 uppercase letter');
      expect(Validators.strongPassword('NOLOWERCASE12'), 'Need 1 lowercase letter');
      expect(Validators.strongPassword('NoDigitsHere!'), 'Need 1 number');
      expect(Validators.strongPassword('Has Space123'), 'Password cannot contain spaces');
      expect(Validators.strongPassword('ValidPass123'), isNull);
    });

    test('Phone validator enforces 10-digit Indian phone rules', () {
      expect(Validators.phone('12345'), 'Phone must be exactly 10 digits');
      expect(Validators.phone('1234567890'), 'Must start with 6, 7, 8, or 9');
      expect(Validators.phone('9876543210'), isNull);
      expect(Validators.phone('7890123456'), isNull);
    });

    test('URL validator validates http and https schemes', () {
      expect(Validators.url('', 'Certificate'), 'Certificate is required');
      expect(Validators.url('ftp://file.com', 'Certificate'), 'Enter a valid URL starting with http:// or https://');
      expect(Validators.url('https://drive.google.com/cert.pdf', 'Certificate'), isNull);
      expect(Validators.url('http://example.com/license', 'Certificate'), isNull);
    });

    test('Date of birth enforces age between 2 and 10', () {
      expect(Validators.dateOfBirth(null), 'Date of birth is required');
      final tooYoung = DateTime.now().subtract(const Duration(days: 300));
      expect(Validators.dateOfBirth(tooYoung), 'Child must be at least 2 years old');
      final tooOld = DateTime.now().subtract(const Duration(days: 365 * 12));
      expect(Validators.dateOfBirth(tooOld), 'Child must be under 10 years old');
      final validAge = DateTime.now().subtract(const Duration(days: 365 * 4));
      expect(Validators.dateOfBirth(validAge), isNull);
    });
  });
}
