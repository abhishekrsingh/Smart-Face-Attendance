class DateHelper {
  /// Returns true if the given date is Saturday or Sunday
  static bool isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  /// Returns 'Saturday' or 'Sunday' or null if weekday
  static String? weekendLabel(DateTime date) {
    if (date.weekday == DateTime.saturday) return 'Saturday';
    if (date.weekday == DateTime.sunday) return 'Sunday';
    return null;
  }

  /// Shortcut for today
  static bool get isTodayWeekend => isWeekend(DateTime.now());
}
