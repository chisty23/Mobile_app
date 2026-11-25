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
}
