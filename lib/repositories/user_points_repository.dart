// lib/repositories/user_points_repository.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class UserPointsRepository {
  final SupabaseClient _supabase;

  UserPointsRepository(this._supabase);

  // Fetch all users with their total points
  Future<List<Map<String, dynamic>>> getUserPoints() async {
    try {
      // Query to get all users with their profile info
      final userProfiles = await _supabase
          .from('user_profile')
          .select('id, display_name, user_role')
          .order('display_name');

      // Initialize result list with user profiles
      final List<Map<String, dynamic>> result = userProfiles.map<Map<String, dynamic>>((json) {
        try {
          final UserProfile profile = UserProfile.fromJson(json);
          return {
            'id': profile.id,
            'displayName': profile.displayName ?? 'User', // Provide fallback
            'userRole': profile.userRole ?? 'user', // Provide fallback
            'totalPoints': 0.0, // Initialize with 0.0 points as double
          };
        } catch (e) {
          debugPrint('Error processing user profile: $e');
          // Return a fallback profile with placeholders
          return {
            'id': json['id'] ?? 'unknown',
            'displayName': json['display_name'] ?? 'Unknown User',
            'userRole': json['user_role'] ?? 'user',
            'totalPoints': 0.0,
          };
        }
      }).toList();

      // Create a map of user IDs to their index in the result list for faster lookups
      final Map<String, int> userIndexMap = {};
      for (int i = 0; i < result.length; i++) {
        userIndexMap[result[i]['id']] = i;
      }

      // Query to get all votes and sum the points for each user
      final votesData = await _supabase
          .from('votes')
          .select('user_id, points')
          .neq('status', 'new'); // Only count votes that are not 'new'

      // Sum the points for each user from their votes
      for (final vote in votesData) {
        try {
          final String? userId = vote['user_id'];
          final dynamic pointsValue = vote['points'];

          // Skip if user_id is null
          if (userId == null) {
            debugPrint('Skipping vote with null user_id');
            continue;
          }

          // Convert points to double safely
          double points = 0.0;
          if (pointsValue is int) {
            points = pointsValue.toDouble();
          } else if (pointsValue is double) {
            points = pointsValue;
          } else if (pointsValue is String) {
            points = double.tryParse(pointsValue) ?? 0.0;
          }

          final int? userIndex = userIndexMap[userId];

          if (userIndex != null) {
            result[userIndex]['totalPoints'] += points;
          }
        } catch (e) {
          debugPrint('Error processing vote: $e');
          // Continue processing other votes
          continue;
        }
      }

      // Sort by total points in descending order
      result.sort((a, b) => b['totalPoints'].compareTo(a['totalPoints']));

      return result;
    } catch (e) {
      debugPrint('Error fetching user points: $e');
      throw Exception('Failed to load user points: $e');
    }
  }
}