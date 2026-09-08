import 'package:intl/intl.dart';

class DateTimeHelper {
  /// Format time using the user's preferred time format
  static String formatTime(String rawTime, String timeFormat, {String fallback = ''}) {
    if (rawTime.isEmpty) return fallback;
    try {
      String tFormat = timeFormat;
      // In NoBox backend, 'HH:mm a' and 'HH:mm A' are used for 12-hour format with AM/PM
      if (tFormat.contains(' a') || tFormat.contains(' A')) {
        tFormat = tFormat.replaceAll('HH', 'hh');
      }
      tFormat = tFormat.replaceAll('A', 'a');
      String iso = rawTime;
      if (!iso.endsWith('Z') && !iso.contains('+')) {
        iso += 'Z';
      }
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat(tFormat).format(dt);
    } catch (_) {
      return fallback;
    }
  }

  /// Format date using the user's preferred date format
  static String formatDate(String rawTime, String dateFormat, {String fallback = ''}) {
    if (rawTime.isEmpty) return fallback;
    try {
      String iso = rawTime;
      if (!iso.endsWith('Z') && !iso.contains('+')) {
        iso += 'Z';
      }
      final dt = DateTime.parse(iso).toLocal();

      String dFormat = dateFormat;
      // Convert moment.js style formats from NOBOX backend to intl formats
      if (dFormat.contains('DD-MMM-YYYY')) dFormat = 'dd-MMM-yyyy';
      else if (dFormat.contains('dddd, MMMM D, YYYY')) dFormat = 'EEEE, MMMM d, yyyy';
      else if (dFormat.contains('MMMM D, YYYY')) dFormat = 'MMMM d, yyyy';
      else {
        dFormat = dFormat.replaceAll('DD', 'dd');
        dFormat = dFormat.replaceAll('YYYY', 'yyyy');
      }
      
      return DateFormat(dFormat).format(dt);
    } catch (_) {
      return fallback;
    }
  }

  /// Format both date and time
  static String formatDateTime(String rawTime, String dateFormat, String timeFormat, {String fallback = ''}) {
    final dateStr = formatDate(rawTime, dateFormat, fallback: '');
    final timeStr = formatTime(rawTime, timeFormat, fallback: fallback);
    if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
      return '$dateStr $timeStr';
    }
    return fallback;
  }

  /// Format relative time (e.g. "a few seconds ago", "5 minutes ago", "2 hours ago", "1 day ago", "3 days ago")
  /// matching Moment.js / Serenity fromNow() on NoBox web.
  static String timeAgo(String rawTime, {String fallback = ''}) {
    if (rawTime.isEmpty) return fallback;
    try {
      String iso = rawTime.trim();
      if (!iso.contains('T') && iso.contains(' ')) {
        iso = iso.replaceFirst(' ', 'T');
      }
      if (!iso.endsWith('Z') && !iso.contains('+')) {
        iso += 'Z';
      }
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.isNegative) {
        return 'just now';
      }

      final seconds = difference.inSeconds;
      final minutes = difference.inMinutes;
      final hours = difference.inHours;
      final days = difference.inDays;

      if (seconds < 45) {
        return 'a few seconds ago';
      } else if (seconds < 90) {
        return 'a minute ago';
      } else if (minutes < 45) {
        return '$minutes minutes ago';
      } else if (minutes < 90) {
        return 'an hour ago';
      } else if (hours < 24) {
        return '$hours hours ago';
      } else if (hours < 48) {
        return '1 day ago';
      } else if (days < 30) {
        return '$days days ago';
      } else if (days < 60) {
        return '1 month ago';
      } else if (days < 365) {
        final months = (days / 30).floor();
        return months <= 1 ? '1 month ago' : '$months months ago';
      } else if (days < 730) {
        return '1 year ago';
      } else {
        final years = (days / 365).floor();
        return '$years years ago';
      }
    } catch (_) {
      return fallback.isNotEmpty ? fallback : rawTime;
    }
  }
}
