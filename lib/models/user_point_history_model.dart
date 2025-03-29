// lib/models/user_point_history_model.dart
import 'package:flutter/foundation.dart';

class UserPointHistory {
  final String id;
  final String matchId;
  final String userId;
  final String matchTitle;
  final String team1;
  final String team2;
  final String userVote;
  final String winner;
  final DateTime matchDate;
  final double points;
  final bool isCorrectVote;
  final String? matchType;

  UserPointHistory({
    required this.id,
    required this.matchId,
    required this.userId,
    required this.matchTitle,
    required this.team1,
    required this.team2,
    required this.userVote,
    required this.winner,
    required this.matchDate,
    required this.points,
    required this.isCorrectVote,
    this.matchType,
  });

  factory UserPointHistory.fromJson(Map<String, dynamic> json) {
    // Parse date from ISO format
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['match_date'] as String);
    } catch (e) {
      debugPrint('Error parsing match date: $e');
      parsedDate = DateTime.now(); // Fallback to current date
    }

    // Extract vote and winner, handling potential nulls
    final String userVote = json['user_vote'] as String? ?? '';
    final String winner = json['winner'] as String? ?? '';

    // Determine if the vote was correct
    final bool isCorrectVote = userVote.isNotEmpty && userVote == winner;

    return UserPointHistory(
      id: json['id'] as String? ?? '',
      matchId: json['match_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      matchTitle: json['match_title'] as String? ?? 'Unknown Match',
      team1: json['team1'] as String? ?? 'Team 1',
      team2: json['team2'] as String? ?? 'Team 2',
      userVote: userVote,
      winner: winner,
      matchDate: parsedDate,
      points: (json['points'] as num?)?.toDouble() ?? 0.0,
      isCorrectVote: isCorrectVote,
      matchType: json['match_type'] as String?,
    );
  }

  // Helper method to get the vote status as a string
  String get voteStatus {
    if (userVote.isEmpty) return 'Did not vote';
    return 'Voted: $userVote';
  }

  // Helper method to get result status
  String get resultStatus {
    if (winner.isEmpty) return 'No result yet';
    return 'Result: $winner';
  }
}