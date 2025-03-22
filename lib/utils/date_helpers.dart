// lib/utils/date_helpers.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Helper class for date-related operations
class DateHelpers {
  /// Format a date to a readable string
  static String formatDate(DateTime date, {String format = 'MMM dd, yyyy - h:mm a'}) {
    return DateFormat(format).format(date);
  }

  /// Get the current time in the local timezone
  static DateTime getCurrentLocalTime() {
    return DateTime.now();
  }

  /// Format a duration into a human-readable string
  static String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return 'less than a minute';
    }
  }

  /// Get time remaining message
  static String getTimeRemainingMessage(DateTime targetDate) {
    final now = DateTime.now();
    if (now.isAfter(targetDate)) {
      return 'Time elapsed';
    }

    final duration = targetDate.difference(now);
    return 'Time remaining: ${formatDuration(duration)}';
  }

  /// Log date information for debugging
  static void logDateInfo(String label, DateTime date) {
    debugPrint('$label: ${date.toString()}');
    debugPrint('$label (Local): ${date.toLocal()}');
    debugPrint('$label (UTC): ${date.toUtc()}');
    debugPrint('$label (ISO): ${date.toIso8601String()}');
  }
}