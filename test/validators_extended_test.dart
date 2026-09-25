import 'package:flutter_test/flutter_test.dart';
import 'package:littlelumin/utils/validators.dart';

void main() {
  group('Weight Validator', () {
    test('rejects negative', () {
      expect(Validators.weight('-69'), isNotNull);
      expect(Validators.weight('-1'), isNotNull);
    });
    test('rejects zero', () {
      expect(Validators.weight('0'), isNotNull);
    });
    test('rejects below min', () {
      expect(Validators.weight('1.9'), isNotNull);
    });
    test('rejects too high', () {
      expect(Validators.weight('101'), isNotNull);
      expect(Validators.weight('150'), isNotNull);
    });
    test('rejects excessive decimals', () {
      expect(Validators.weight('15.55'), isNotNull);
    });
    test('accepts valid weights', () {
      expect(Validators.weight('2'), isNull);
      expect(Validators.weight('15.5'), isNull);
      expect(Validators.weight('100'), isNull);
    });
  });

  group('Age Validator', () {
    test('rejects negative', () {
      expect(Validators.age('-1'), isNotNull);
    });
    test('rejects non-integer', () {
      expect(Validators.age('4.5'), isNotNull);
    });
    test('rejects over 18', () {
      expect(Validators.age('19'), isNotNull);
    });
    test('accepts valid ages', () {
      expect(Validators.age('0'), isNull);
      expect(Validators.age('4'), isNull);
      expect(Validators.age('18'), isNull);
    });
  });

  group('Height Validator', () {
    test('rejects negative', () {
      expect(Validators.height('-100'), isNotNull);
    });
    test('rejects below 30', () {
      expect(Validators.height('29.9'), isNotNull);
    });
    test('rejects over 200', () {
      expect(Validators.height('201'), isNotNull);
      expect(Validators.height('500'), isNotNull);
    });
    test('rejects excessive decimals', () {
      expect(Validators.height('110.25'), isNotNull);
    });
    test('accepts valid heights', () {
      expect(Validators.height('30'), isNull);
      expect(Validators.height('110'), isNull);
      expect(Validators.height('110.5'), isNull);
      expect(Validators.height('200'), isNull);
    });
  });

  group('NonNegativeNumber & Integer & Duration Validators', () {
    test('integer rejects non-integer, negative, or out-of-range', () {
      expect(Validators.integer('abc', 'Count'), 'Count must be a whole number');
      expect(Validators.integer('-2', 'Count'), 'Count cannot be negative');
      expect(Validators.integer('2', 'Count', min: 3), 'Count must be at least 3');
      expect(Validators.integer('10', 'Count', max: 5), 'Count cannot exceed 5');
      expect(Validators.integer('4', 'Count', min: 1, max: 10), isNull);
    });

    test('durationMinutes enforces 1 to 180', () {
      expect(Validators.durationMinutes('0'), isNotNull);
      expect(Validators.durationMinutes('181'), isNotNull);
      expect(Validators.durationMinutes('-5'), isNotNull);
      expect(Validators.durationMinutes('45'), isNull);
    });

    test('nonNegativeNumber rejects invalid formats', () {
      expect(Validators.nonNegativeNumber('', 'Score'), isNotNull);
      expect(Validators.nonNegativeNumber('-1.5', 'Score'), isNotNull);
      expect(Validators.nonNegativeNumber('12.345', 'Score', decimals: 2), isNotNull);
      expect(Validators.nonNegativeNumber('12.34', 'Score', decimals: 2), isNull);
    });
  });

  group('Dropdown, Gender, SkillDomain, Difficulty Validators', () {
    test('requiredDropdown enforces non-empty selection', () {
      expect(Validators.requiredDropdown(null, 'option'), isNotNull);
      expect(Validators.requiredDropdown('', 'option'), isNotNull);
      expect(Validators.requiredDropdown('Selected Option', 'option'), isNull);
    });

    test('gender validator allows Male, Female, Other', () {
      expect(Validators.gender(null), isNotNull);
      expect(Validators.gender('Alien'), isNotNull);
      expect(Validators.gender('Male'), isNull);
      expect(Validators.gender('Female'), isNull);
      expect(Validators.gender('Other'), isNull);
    });

    test('skillDomain validator checks valid domain', () {
      expect(Validators.skillDomain(null), isNotNull);
      expect(Validators.skillDomain('flying'), isNotNull);
      expect(Validators.skillDomain('cognitive'), isNull);
      expect(Validators.skillDomain('Language'), isNull);
      expect(Validators.skillDomain('motor'), isNull);
      expect(Validators.skillDomain('social'), isNull);
      expect(Validators.skillDomain('emotional'), isNull);
      expect(Validators.skillDomain('creative'), isNull);
    });

    test('difficulty validator checks easy, medium, hard', () {
      expect(Validators.difficulty(null), isNotNull);
      expect(Validators.difficulty('extreme'), isNotNull);
      expect(Validators.difficulty('easy'), isNull);
      expect(Validators.difficulty('Medium'), isNull);
      expect(Validators.difficulty('HARD'), isNull);
    });
  });

  group('Date Validators', () {
    test('pastDate rejects future dates', () {
      expect(Validators.pastDate(null, 'Date'), isNotNull);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(Validators.pastDate(tomorrow, 'Date'), 'Date cannot be in the future');
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(Validators.pastDate(yesterday, 'Date'), isNull);
    });

    test('notTooOld rejects dates over maxYears ago', () {
      expect(Validators.notTooOld(null, 'Date'), isNotNull);
      final ancient = DateTime.now().subtract(const Duration(days: 365 * 105));
      expect(Validators.notTooOld(ancient, 'Date', maxYears: 100), 'Date is too far in the past');
      final valid = DateTime.now().subtract(const Duration(days: 365 * 5));
      expect(Validators.notTooOld(valid, 'Date', maxYears: 100), isNull);
    });
  });

  group('String Sanitation & SafeText Validators', () {
    test('noSpecialChars rejects HTML tags and disallowed symbols', () {
      expect(Validators.noSpecialChars('', 'Title'), isNotNull);
      expect(Validators.noSpecialChars('<script>alert()</script>', 'Title'), isNotNull);
      expect(Validators.noSpecialChars('Title with {brackets}', 'Title'), isNotNull);
      expect(Validators.noSpecialChars('Title with [brackets]', 'Title'), isNotNull);
      expect(Validators.noSpecialChars('Clean Title 123!', 'Title'), isNull);
    });

    test('safeText checks lengths and rejects HTML brackets', () {
      expect(Validators.safeText(null, 'Notes', min: 10), isNotNull);
      expect(Validators.safeText('short', 'Notes', min: 10), isNotNull);
      expect(Validators.safeText('<div>HTML Injection</div>', 'Notes', min: 5), isNotNull);
      expect(Validators.safeText('Valid, detailed observation note without any forbidden tags.', 'Notes', min: 10, max: 200), isNull);
    });

    test('score and percentage validators validate 0-100', () {
      expect(Validators.score('-1'), isNotNull);
      expect(Validators.score('105'), isNotNull);
      expect(Validators.score('85.5'), isNull);

      expect(Validators.percentage('-5'), isNotNull);
      expect(Validators.percentage('100.5'), isNotNull);
      expect(Validators.percentage('99.99'), isNull);
    });

    test('certificateUrl validates URLs strictly', () {
      expect(Validators.certificateUrl(null, 'Cert'), isNotNull);
      expect(Validators.certificateUrl('not-a-url', 'Cert'), isNotNull);
      expect(Validators.certificateUrl('ftp://example.com/cert.pdf', 'Cert'), isNotNull);
      expect(Validators.certificateUrl('https://example.com/cert.pdf', 'Cert'), isNull);
      expect(Validators.certificateUrl('http://example.com/cert.pdf', 'Cert'), isNull);
    });
  });
}
