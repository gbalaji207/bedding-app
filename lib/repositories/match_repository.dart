// lib/repositories/match_repository.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match_model.dart';

class MatchRepository {
  final SupabaseClient _supabaseClient;

  MatchRepository(this._supabaseClient);

  // Get all matches
  Future<List<Match>> getMatches() async {
    try {
      final response = await _supabaseClient
          .from('matches')
          .select()
          .order('start_date', ascending: true);

      return response.map<Match>((json) => Match.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load matches: $e');
    }
  }

  // Get future matches (matches that haven't started yet)
  Future<List<Match>> getFutureMatches() async {
    try {
      // Call the stored procedure
      final response = await _supabaseClient
          .rpc('get_future_matches');

      debugPrint('Got ${response.length} future matches from server procedure');

      // Convert to Match objects
      return response.map<Match>((json) => Match.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load future matches: $e');
    }
  }

  // Get past matches (matches that have already started)
  Future<List<Match>> getPastMatches() async {
    try {
      // Call the stored procedure
      final response = await _supabaseClient.rpc('get_past_matches');

      debugPrint('Got ${response.length} past matches from server procedure');

      // Convert to Match objects
      return response.map<Match>((json) => Match.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load past matches: $e');
    }
  }

  // Get a specific match by ID
  Future<Match> getMatchById(String id) async {
    try {
      final response =
          await _supabaseClient.from('matches').select().eq('id', id).single();

      // Convert to local time in Match.fromJson constructor
      return Match.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load match details: $e');
    }
  }

  // Create a new match
  Future<void> createMatch(Match match) async {
    try {
      // Match.toJson handles converting local time to UTC for storage
      await _supabaseClient.from('matches').insert(match.toJson());
    } catch (e) {
      throw Exception('Failed to create match: $e');
    }
  }

  // Update an existing match
  Future<void> updateMatch(Match match) async {
    try {
      // Match.toJson handles converting local time to UTC for storage
      await _supabaseClient
          .from('matches')
          .update(match.toJson())
          .eq('id', match.id);
    } catch (e) {
      throw Exception('Failed to update match: $e');
    }
  }

  // Delete a match
  Future<void> deleteMatch(String id) async {
    try {
      await _supabaseClient.from('matches').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete match: $e');
    }
  }
}
