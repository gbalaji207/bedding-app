// lib/repositories/match_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match_model.dart';

class MatchRepository {
  final SupabaseClient _supabaseClient;

  MatchRepository(this._supabaseClient);

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

  Future<Match> getMatchById(String id) async {
    try {
      final response = await _supabaseClient
          .from('matches')
          .select()
          .eq('id', id)
          .single();

      return Match.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load match details: $e');
    }
  }

  Future<void> createMatch(Match match) async {
    try {
      await _supabaseClient
          .from('matches')
          .insert(match.toJson());
    } catch (e) {
      throw Exception('Failed to create match: $e');
    }
  }

  Future<void> updateMatch(Match match) async {
    try {
      await _supabaseClient
          .from('matches')
          .update(match.toJson())
          .eq('id', match.id);
    } catch (e) {
      throw Exception('Failed to update match: $e');
    }
  }

  Future<void> deleteMatch(String id) async {
    try {
      await _supabaseClient
          .from('matches')
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete match: $e');
    }
  }
}