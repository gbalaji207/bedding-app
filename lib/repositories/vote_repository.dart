// lib/repositories/vote_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/vote_model.dart';

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

  // Save or update a vote
  Future<void> saveVote(String userId, String matchId, String teamVote) async {
    try {
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
    } catch (e) {
      throw Exception('Failed to save vote: $e');
    }
  }

  // Delete a vote
  Future<void> deleteVote(String voteId) async {
    try {
      final result = await _supabase
          .from('votes')
          .delete()
          .eq('id', voteId)
          .select();

      // Check if deletion was successful
      if (result == null) {
        throw Exception('Vote not found or you do not have permission to delete it');
      }
    } catch (e) {
      throw Exception('Failed to delete vote: $e');
    }
  }
}