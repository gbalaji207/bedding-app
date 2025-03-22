// lib/repositories/vote_repository.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/vote_model.dart';
import '../models/match_model.dart';

class VoteRepository {
  final SupabaseClient _supabase;

  VoteRepository(this._supabase);

  // Get votes for a specific user
  Future<List<Vote>> getUserVotes(String userId) async {
    try {
      final response = await _supabase
          .from('votes')
          .select()
          .eq('user_id', userId);

      return response.map<Vote>((json) => Vote.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load user votes: $e');
    }
  }

  // Get vote for a specific match and user
  Future<Vote?> getVoteForMatch(String userId, String matchId) async {
    try {
      final response = await _supabase
          .from('votes')
          .select()
          .eq('user_id', userId)
          .eq('match_id', matchId);

      if (response.isNotEmpty) {
        return Vote.fromJson(response.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to load vote: $e');
    }
  }

  // Get all votes for a specific match
  Future<List<Vote>> getMatchVotes(String matchId) async {
    try {
      final response = await _supabase
          .from('votes')
          .select()
          .eq('match_id', matchId);

      return response.map<Vote>((json) => Vote.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load match votes: $e');
    }
  }

  // Get the match details first to verify cutoff time
  Future<Match> _getMatchForCutoffValidation(String matchId) async {
    try {
      final response = await _supabase
          .from('matches')
          .select()
          .eq('id', matchId)
          .single();

      return Match.fromJson(response);
    } catch (e) {
      throw Exception('Failed to validate match cutoff time: $e');
    }
  }

  // Check if voting is allowed for a match
  bool isVotingAllowed(Match match) {
    // Calculate cutoff time (30 minutes before match starts)
    final cutoffTime = match.startDate.subtract(const Duration(minutes: 30));

    // Get current time
    final now = DateTime.now();

    // Debug info to verify the comparison
    debugPrint('Repository - Now (local): $now');
    debugPrint('Repository - Match start time (local): ${match.startDate}');
    debugPrint('Repository - Cutoff (local): $cutoffTime');
    debugPrint('Repository - Is voting allowed: ${now.isBefore(cutoffTime)}');

    // Return true if current time is before cutoff time
    return now.isBefore(cutoffTime);
  }

  // Save or update a vote
  Future<void> saveVote(String userId, String matchId, String teamVote, {Match? match}) async {
    try {
      // If match data is not provided, fetch it directly from the database
      // to ensure we have the most up-to-date information for validation
      final matchForValidation = match ?? await _getMatchForCutoffValidation(matchId);

      // Strict validation to ensure voting hasn't closed
      if (!isVotingAllowed(matchForValidation)) {
        throw Exception('Voting is closed for this match as it starts in less than 30 minutes');
      }

      // Check if vote exists
      final existingVote = await getVoteForMatch(userId, matchId);

      if (existingVote != null) {
        // Update existing vote
        await _supabase
            .from('votes')
            .update({
          'vote': teamVote,
          'status': 'new', // Reset status if vote changes
        })
            .eq('id', existingVote.id);
      } else {
        // Create new vote
        final newVote = Vote.createNew(
          id: const Uuid().v4(),
          userId: userId,
          matchId: matchId,
          vote: teamVote,
        );

        await _supabase
            .from('votes')
            .insert(newVote.toJson());
      }

      debugPrint('Vote saved successfully for match: $matchId, team: $teamVote');
    } catch (e) {
      debugPrint('Error saving vote: $e');
      throw Exception('Failed to save vote: $e');
    }
  }

  // Delete a vote
  Future<void> deleteVote(String voteId) async {
    try {
      // First get the vote to check its match ID
      final voteResponse = await _supabase
          .from('votes')
          .select('match_id')
          .eq('id', voteId)
          .single();

      final matchId = voteResponse['match_id'] as String;

      // Get match data to verify cutoff time
      final match = await _getMatchForCutoffValidation(matchId);

      // Validate that voting is still allowed before deletion
      if (!isVotingAllowed(match)) {
        throw Exception('Cannot delete vote as match starts in less than 30 minutes');
      }

      final result = await _supabase
          .from('votes')
          .delete()
          .eq('id', voteId)
          .select();

      // Check if deletion was successful
      if (result == null) {
        throw Exception('Vote not found or you do not have permission to delete it');
      }

      debugPrint('Vote deleted successfully: $voteId');
    } catch (e) {
      debugPrint('Error deleting vote: $e');
      throw Exception('Failed to delete vote: $e');
    }
  }
}