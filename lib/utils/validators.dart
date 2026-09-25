// lib/utils/validators.dart

class Validators {
  // ============ EXISTING (kept) ============

  /// Email
  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final email = v.trim();
    if (!email.contains('@')) return 'Email must contain @';
    if (!email.contains('.')) return 'Email must have a domain';
    final re = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!re.hasMatch(email)) return 'Enter a valid email address';
    if (email.contains('..')) return 'Email cannot have consecutive dots';
    return null;
  }

  /// Required name
  static String? name(String? v) {
    if (v == null || v.trim().isEmpty) return 'Name is required';
    final n = v.trim();
    if (n.length < 3) return 'Name must be at least 3 characters';
    if (n.length > 50) return 'Name cannot exceed 50 characters';
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(n)) {
      return 'Name can only contain letters and spaces';
    }
    return null;
  }

  /// Strong password
  static String? strongPassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (v.length > 64) return 'Password cannot exceed 64 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Need 1 uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Need 1 lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Need 1 number';
    if (v.contains(' ')) return 'Password cannot contain spaces';
    return null;
  }

  /// Login password
  static String? loginPassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  /// Confirm password
  static String? confirmPassword(String? v, String original) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != original) return 'Passwords do not match';
    return null;
  }

  /// Phone (Indian 10-digit)
  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    final p = v.trim().replaceAll(RegExp(r'[\s-]'), '');
    if (p.length != 10) return 'Phone must be exactly 10 digits';
    if (!RegExp(r'^[0-9]+$').hasMatch(p)) return 'Phone can only contain digits';
    if (!RegExp(r'^[6-9]').hasMatch(p)) return 'Must start with 6, 7, 8, or 9';
    return null;
  }

  /// Required field
  static String? required(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  /// Min length
  static String? minLength(String? v, int min, String label) {
    if (v == null || v.trim().length < min) {
      return '$label must be at least $min characters';
    }
    return null;
  }

  /// URL (for certificate links)
  static String? url(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    final uri = Uri.tryParse(v.trim());
    if (uri == null || !uri.hasScheme || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return 'Enter a valid URL starting with http:// or https://';
    }
    return null;
  }

  /// Free-text notes (max length, safe text)
  static String? notes(String? v, {int max = 500}) {
    if (v == null || v.trim().isEmpty) return null;
    return safeText(v, 'Notes', min: 0, max: max);
  }

  /// Date of birth (2-10 years old)
  static String? dateOfBirth(DateTime? dob) {
    if (dob == null) return 'Date of birth is required';
    final now = DateTime.now();
    final age = now.difference(dob).inDays / 365.25;
    if (age < 2) return 'Child must be at least 2 years old';
    if (age > 10) return 'Child must be under 10 years old';
    return null;
  }

  // ============ NEW VALIDATORS ============

  /// Numeric — non-negative (for weight, height, counts)
  static String? nonNegativeNumber(
    String? v,
    String label, {
    double? min,
    double? max,
    int decimals = 2,
  }) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    final n = double.tryParse(v.trim());
    if (n == null) return '$label must be a number';
    if (n < 0) return '$label cannot be negative';
    if (min != null && n < min) return '$label must be at least $min';
    if (max != null && n > max) return '$label cannot exceed $max';
    // Check decimals
    final parts = v.trim().split('.');
    if (parts.length == 2 && parts[1].length > decimals) {
      return '$label can have at most $decimals decimal places';
    }
    return null;
  }

  /// Age in years (integer 0-18)
  static String? age(String? v) {
    if (v == null || v.trim().isEmpty) return 'Age is required';
    final n = int.tryParse(v.trim());
    if (n == null) return 'Age must be a whole number';
    if (n < 0) return 'Age cannot be negative';
    if (n > 18) return 'Age cannot exceed 18 years';
    return null;
  }

  /// Height (cm) — 30 to 200
  static String? height(String? v) {
    return nonNegativeNumber(v, 'Height', min: 30, max: 200, decimals: 1);
  }

  /// Weight (kg) — 2 to 100
  static String? weight(String? v) {
    return nonNegativeNumber(v, 'Weight', min: 2, max: 100, decimals: 1);
  }

  /// Generic integer
  static String? integer(String? v, String label, {int? min, int? max}) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    final n = int.tryParse(v.trim());
    if (n == null) return '$label must be a whole number';
    if (n < 0) return '$label cannot be negative';
    if (min != null && n < min) return '$label must be at least $min';
    if (max != null && n > max) return '$label cannot exceed $max';
    return null;
  }

  /// Duration (minutes) — 1 to 180
  static String? durationMinutes(String? v) {
    return integer(v, 'Duration', min: 1, max: 180);
  }

  /// Dropdown required
  static String? requiredDropdown(String? v, String label) {
    if (v == null || v.trim().isEmpty) return 'Please select $label';
    return null;
  }

  /// Date — must not be in the future
  static String? pastDate(DateTime? date, String label) {
    if (date == null) return '$label is required';
    if (date.isAfter(DateTime.now())) return '$label cannot be in the future';
    return null;
  }

  /// Date — must not be too far in the past
  static String? notTooOld(DateTime? date, String label, {int maxYears = 100}) {
    if (date == null) return '$label is required';
    final cutoff = DateTime.now().subtract(Duration(days: 365 * maxYears));
    if (date.isBefore(cutoff)) return '$label is too far in the past';
    return null;
  }

  /// No special characters (for names, titles that shouldn't have emojis/HTML)
  static String? noSpecialChars(String? v, String label, {int max = 200}) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    final s = v.trim();
    if (s.length > max) return '$label cannot exceed $max characters';
    // Reject HTML/script tags and unusual symbols
    final forbidden = RegExp(r'[<>{}[\]\\|`~^]');
    if (forbidden.hasMatch(s)) return '$label contains invalid characters';
    return null;
  }

  /// Multi-line safe text (for notes, observations)
  static String? safeText(String? v, String label, {int min = 0, int max = 500}) {
    if (v == null) return min > 0 ? '$label is required' : null;
    final s = v.trim();
    if (min > 0 && s.isEmpty) return '$label is required';
    if (s.length < min) return '$label must be at least $min characters';
    if (s.length > max) return '$label cannot exceed $max characters';
    final forbidden = RegExp(r'[<>{}]');
    if (forbidden.hasMatch(s)) return '$label contains invalid characters';
    return null;
  }


  /// Score (0-100)
  static String? score(String? v) {
    return nonNegativeNumber(v, 'Score', min: 0, max: 100, decimals: 1);
  }

  /// Percentage (0-100)
  static String? percentage(String? v) {
    return nonNegativeNumber(v, 'Percentage', min: 0, max: 100, decimals: 2);
  }

  /// Certificate URL — must be http(s) and end with common doc extensions
  static String? certificateUrl(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    final uri = Uri.tryParse(v.trim());
    if (uri == null || !uri.hasScheme) return 'Enter a valid URL';
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'URL must start with http:// or https://';
    }
    return null;
  }

  /// Gender dropdown
  static String? gender(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please select gender';
    const allowed = ['Male', 'Female', 'Other'];
    if (!allowed.contains(v)) return 'Please select a valid gender';
    return null;
  }

  /// Skill domain
  static String? skillDomain(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please select a skill domain';
    const allowed = ['cognitive', 'language', 'motor', 'social', 'emotional', 'creative'];
    if (!allowed.contains(v.toLowerCase())) return 'Please select a valid skill';
    return null;
  }

  /// Difficulty
  static String? difficulty(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please select difficulty';
    const allowed = ['easy', 'medium', 'hard'];
    if (!allowed.contains(v.toLowerCase())) return 'Please select a valid difficulty';
    return null;
  }
}
