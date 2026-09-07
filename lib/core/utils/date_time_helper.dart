import 'package:intl/intl.dart';

class DateTimeHelper {
  /// Format time using the user's preferred time format
  static String formatTime(String rawTime, String timeFormat, {String fallback = ''}) {
    if (rawTime.isEmpty) return fallback;
    try {
      final tFormat = timeFormat.replaceAll('A', 'a');
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
}
