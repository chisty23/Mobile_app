/// Shared formatting helpers for currency, dates, and campus locations.
class AppFormatters {
  AppFormatters._();

  static const List<String> campusLocations = [
    'All Locations',
    'Campus Dorm / Hall',
    'DU / TSC Area',
    'BUET Campus',
    'Bashundhara / NSU',
    'Dhanmondi',
    'Mirpur',
    'Uttara',
    'Banani / Gulshan',
    'Mohammadpur',
    'Other Area',
  ];

  static const List<String> listingLocations = [
    'Campus Dorm / Hall',
    'DU / TSC Area',
    'BUET Campus',
    'Bashundhara / NSU',
    'Dhanmondi',
    'Mirpur',
    'Uttara',
    'Banani / Gulshan',
    'Mohammadpur',
    'Other Area',
  ];

  /// Formats an integer BDT amount with commas (e.g. `12,500 ৳`).
  static String formatBDT(int value) {
    final negative = value < 0;
    final text = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final pos = text.length - i;
      buffer.write(text[i]);
      if (pos > 1 && pos % 3 == 1) buffer.write(',');
    }
    return '${negative ? '-' : ''}${buffer.toString()} ৳';
  }

  /// Formats a DateTime into concise relative elapsed time.
  static String formatRelativeTime(DateTime? time) {
    if (time == null) return 'Recently';
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[time.month - 1]} ${time.day}';
  }

  /// Normalizes local BD (`01XXXXXXXXX`) and international phone numbers to E.164 format.
  static String normalizePhone(String input) {
    var cleaned = input.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.isEmpty) return '';
    if (cleaned.startsWith('00')) {
      cleaned = '+${cleaned.substring(2)}';
    }
    if (RegExp(r'^01[3-9]\d{8}$').hasMatch(cleaned)) {
      return '+88$cleaned';
    }
    if (RegExp(r'^8801[3-9]\d{8}$').hasMatch(cleaned)) {
      return '+$cleaned';
    }
    if (!cleaned.startsWith('+') && RegExp(r'^\d{8,15}$').hasMatch(cleaned)) {
      return '+$cleaned';
    }
    return cleaned;
  }

  /// Validates a normalized phone number (`+8801...` or international E.164).
  static bool isValidPhone(String input) {
    final norm = normalizePhone(input);
    if (norm.startsWith('+880')) {
      return RegExp(r'^\+8801[3-9]\d{8}$').hasMatch(norm);
    }
    return RegExp(r'^\+\d{8,15}$').hasMatch(norm);
  }

  /// Validates an authentic Gmail address (`@gmail.com` or `@googlemail.com`).
  static bool isValidGmail(String input) {
    final trimmed = input.trim().toLowerCase();
    return RegExp(r'^[a-z0-9._%+\-]+@(gmail\.com|googlemail\.com)$')
        .hasMatch(trimmed);
  }

  /// Validates general email syntax (used for sign-in / legacy accounts).
  static bool isValidEmail(String input) {
    final trimmed = input.trim();
    return RegExp(r'^[\w\.\+\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$').hasMatch(trimmed);
  }

  /// Detects if user input looks like a phone number rather than an email address.
  static bool looksLikePhone(String input) {
    final trimmed = input.trim();
    return trimmed.isNotEmpty && !trimmed.contains('@') && isValidPhone(trimmed);
  }

  /// Masks an email address cleanly for recovery prompts (e.g. `mo***@gmail.com`).
  static String maskEmail(String email) {
    final parts = email.trim().split('@');
    if (parts.length != 2 || parts.first.isEmpty) return email;
    final local = parts.first;
    final prefix = local.length <= 2 ? local[0] : local.substring(0, 2);
    return '$prefix***@${parts[1]}';
  }

  /// Masks a phone number for display hints (e.g. `+880****5678`).
  static String maskPhone(String phone) {
    final norm = normalizePhone(phone);
    if (norm.length <= 6) return norm;
    return '${norm.substring(0, 4)}****${norm.substring(norm.length - 4)}';
  }
}
