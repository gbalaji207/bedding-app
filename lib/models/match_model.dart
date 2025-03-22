// lib/models/match_model.dart
import 'package:intl/intl.dart';

enum MatchType { fixed, variable }

enum MatchStatus { draft, live, finished }

class Match {
  final String id;
  final String title;
  final String team1;
  final String team2;
  final MatchType type;
  final DateTime startDate;
  final MatchStatus status;

  Match({
    required this.id,
    required this.title,
    required this.team1,
    required this.team2,
    required this.type,
    required this.startDate,
    required this.status,
  });

  // Factory constructor to create a Match from JSON data
  factory Match.fromJson(Map<String, dynamic> json) {
    // Parse the date from ISO format and convert to local time
    DateTime parsedDate = DateTime.parse(json['start_date'] as String);
    // Convert UTC time from database to local time
    DateTime localStartDate = parsedDate.toLocal();

    return Match(
      id: json['id'] as String,
      title: json['title'] as String,
      team1: json['team1'] as String,
      team2: json['team2'] as String,
      type: _parseMatchType(json['type'] as String),
      startDate: localStartDate,
      status: _parseMatchStatus(json['status'] as String),
    );
  }

  // Helper method to parse match type
  static MatchType _parseMatchType(String type) {
    return type.toLowerCase() == 'fixed'
        ? MatchType.fixed
        : MatchType.variable;
  }

  // Helper method to parse match status
  static MatchStatus _parseMatchStatus(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return MatchStatus.draft;
      case 'live':
        return MatchStatus.live;
      case 'finished':
        return MatchStatus.finished;
      default:
        return MatchStatus.draft;
    }
  }

  // Format startDate to readable string
  String get formattedStartDate {
    return DateFormat('MMM dd, yyyy - h:mm a').format(startDate);
  }

  // Get cutoff time (30 minutes before match start) in local time
  DateTime get votingCutoffTime {
    return startDate.subtract(const Duration(minutes: 30));
  }

  // Check if voting is closed for this match
  bool isVotingClosed() {
    final now = DateTime.now();
    return now.isAfter(votingCutoffTime);
  }

  // Calculate time remaining until voting closes
  Duration get timeUntilVotingCloses {
    final now = DateTime.now();
    final cutoff = votingCutoffTime;

    if (now.isAfter(cutoff)) {
      return Duration.zero;
    }

    return cutoff.difference(now);
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'team1': team1,
      'team2': team2,
      'type': type == MatchType.fixed ? 'fixed' : 'variable',
      'start_date': startDate.toUtc().toIso8601String(), // Convert back to UTC for storage
      'status': status.toString().split('.').last,
    };
  }
}