import 'package:timeago/timeago.dart' as timeago;

class TimeUtils {
  /// Converts a UTC DateTime to Turkey time (UTC+3)
  static DateTime toTurkeyTime(DateTime utcTime) {
    return utcTime.add(const Duration(hours: 3));
  }
  
  /// Formats a DateTime in Turkey time using timeago
  static String formatTimeAgo(DateTime utcTime, {String locale = 'tr'}) {
    final turkeyTime = toTurkeyTime(utcTime);
    return timeago.format(turkeyTime, locale: locale);
  }
  
  /// Checks if a UTC DateTime is within the last 24 hours in Turkey time
  static bool isWithinLast24Hours(DateTime utcTime) {
    final turkeyTime = toTurkeyTime(utcTime);
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return turkeyTime.isAfter(cutoff);
  }
}
