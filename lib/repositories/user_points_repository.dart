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
      // Use SQL query to directly calculate points in the database
      final response = await _supabase
          .rpc('get_user_points_summary');

      // Transform the response into the format needed by the UI
      final List<Map<String, dynamic>> result = [];

      for (final item in response) {
        result.add({
          'id': item['user_id'],
          'displayName': item['display_name'] ?? 'Unknown User',
          'totalPoints': (item['totalpoints'] is num) ?
          (item['totalpoints'] as num).toDouble() : 0.0,
        });
      }

      return result;
    } catch (e) {
      debugPrint('Error fetching user points: $e');
      throw Exception('Failed to load user points: $e');
    }
  }
}