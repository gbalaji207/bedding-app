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
    return Match(
      id: json['id'] as String,
      title: json['title'] as String,
      team1: json['team1'] as String,
      team2: json['team2'] as String,
      type: _parseMatchType(json['type'] as String),
      startDate: DateTime.parse(json['start_date'] as String),
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

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'team1': team1,
      'team2': team2,
      'type': type == MatchType.fixed ? 'fixed' : 'variable',
      'start_date': startDate.toIso8601String(),
      'status': status.toString().split('.').last,
    };
  }
}