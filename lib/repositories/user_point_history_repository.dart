// lib/repositories/user_point_history_repository.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_point_history_model.dart';
import '../models/user_profile.dart';

class UserPointHistoryRepository {
  final SupabaseClient _supabase;

  UserPointHistoryRepository(this._supabase);

  // Get user profile by ID
  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('user_profile')
          .select('*')
          .eq('id', userId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  // Get user's total points
  Future<double> getUserTotalPoints(String userId) async {
    try {
      final response = await _supabase
          .from('votes')
          .select('points')
          .eq('user_id', userId)
          .neq('status', 'new');

      double totalPoints = 0.0;
      for (final vote in response) {
        // Parse points value safely to handle different number formats
        final pointsValue = vote['points'];
        double points = 0.0;

        if (pointsValue is int) {
          points = pointsValue.toDouble();
        } else if (pointsValue is double) {
          points = pointsValue;
        } else if (pointsValue is String) {
          points = double.tryParse(pointsValue) ?? 0.0;
        }

        totalPoints += points;
      }

      return totalPoints;
    } catch (e) {
      debugPrint('Error calculating user total points: $e');
      return 0.0;
    }
  }

  // Get user's rank in the point leaderboard
  Future<int> getUserRank(String userId) async {
    try {
      // Get all users with their total points
      final response = await _supabase.rpc(
        'get_users_by_points',
      );

      // Find the current user's rank
      for (int i = 0; i < response.length; i++) {
        if (response[i]['user_id'] == userId) {
          return i + 1; // Ranks start from 1
        }
      }

      return 0; // User not found in ranking
    } catch (e) {
      debugPrint('Error getting user rank: $e');
      return 0;
    }
  }

  // Get complete point history for a user
  Future<List<UserPointHistory>> getUserPointHistory(String userId) async {
    try {
      // Join votes with matches to get complete information
      final response = await _supabase
          .from('votes')
          .select('''
            id, 
            user_id, 
            match_id, 
            vote, 
            status, 
            points,
            matches:match_id (
              id, 
              title, 
              team1, 
              team2, 
              winner, 
              start_date,
              type
            )
          ''')
          .eq('user_id', userId)
          .neq('status', 'new') // Only include votes that are processed (won or lost)
          .order('created_at', ascending: false);

      // Process the joined results into our model
      List<UserPointHistory> history = [];

      for (final item in response) {
        try {
          final matchData = item['matches'] as Map<String, dynamic>;

          history.add(UserPointHistory(
            id: item['id'] as String? ?? '',
            matchId: item['match_id'] as String? ?? '',
            userId: item['user_id'] as String? ?? '',
            matchTitle: matchData['title'] as String? ?? 'Unknown Match',
            team1: matchData['team1'] as String? ?? 'Team 1',
            team2: matchData['team2'] as String? ?? 'Team 2',
            userVote: item['vote'] as String? ?? '',
            winner: matchData['winner'] as String? ?? '',
            matchDate: DateTime.parse(matchData['start_date'] as String).toLocal(),
            points: (item['points'] as num?)?.toDouble() ?? 0.0,
            isCorrectVote: (item['status'] == 'won'),
            matchType: matchData['type'] as String?,
          ));
        } catch (e) {
          debugPrint('Error processing point history item: $e');
          // Continue processing other items
        }
      }

      return history;
    } catch (e) {
      debugPrint('Error fetching user point history: $e');
      throw Exception('Failed to load point history: $e');
    }
  }

  // Get user's voting statistics
  Future<Map<String, dynamic>> getUserVotingStats(String userId) async {
    try {
      final history = await getUserPointHistory(userId);

      // Calculate statistics
      final totalMatches = history.length;
      final wonMatches = history.where((item) => item.isCorrectVote).length;
      final lostMatches = history.where((item) => !item.isCorrectVote).length;

      // Calculate win rate
      final winRate = totalMatches > 0 ? (wonMatches / totalMatches) * 100 : 0.0;

      // Calculate total points and average points per match
      double totalPoints = 0.0;
      double highestPoints = 0.0;
      double lowestPoints = 0.0;

      for (final item in history) {
        totalPoints += item.points;

        // Track highest winning points
        if (item.isCorrectVote && item.points > highestPoints) {
          highestPoints = item.points;
        }

        // Track lowest losing points
        if (!item.isCorrectVote && item.points < lowestPoints) {
          lowestPoints = item.points;
        }
      }

      final avgPoints = totalMatches > 0 ? totalPoints / totalMatches : 0.0;

      return {
        'totalMatches': totalMatches,
        'wonMatches': wonMatches,
        'lostMatches': lostMatches,
        'winRate': winRate,
        'totalPoints': totalPoints,
        'avgPoints': avgPoints,
        'highestPoints': highestPoints,
        'lowestPoints': lowestPoints,
      };
    } catch (e) {
      debugPrint('Error calculating user voting stats: $e');
      throw Exception('Failed to calculate voting statistics: $e');
    }
  }
}