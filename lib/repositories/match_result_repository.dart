// lib/repositories/match_result_repository.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/match_model.dart';
import '../models/vote_model.dart';
import '../models/user_profile.dart';

class MatchResultRepository {
  final SupabaseClient _supabase;
  final bool _dryRun; // Flag to control whether database updates are performed

  MatchResultRepository(this._supabase, {bool dryRun = false}) : _dryRun = dryRun;

  // Update match result and calculate points
  Future<bool> updateMatchResult({
    required String matchId,
    required Match match,
    required String winningTeam,
    required int basePoints,
    required bool bonusEligible,
  }) async {
    try {
      // 1. Validate match status
      if (match.status == MatchStatus.finished) {
        throw Exception('This match is already finished');
      }

      // 2. Fetch all votes for this match
      final voteResponse = await _supabase
          .from('votes')
          .select()
          .eq('match_id', matchId);

      final votes = voteResponse.map<Vote>((json) => Vote.fromJson(json)).toList();

      // 3. For fixed matches, fetch all user profiles to handle non-voters
      List<UserProfile> allUsers = [];
      if (match.type == MatchType.fixed) {
        final userResponse = await _supabase
            .from('user_profile')
            .select();

        allUsers = userResponse.map<UserProfile>((json) => UserProfile.fromJson(json)).toList();
      }

      // 4. Calculate and apply points
      await _calculateAndApplyPoints(
          match: match,
          votes: votes,
          allUsers: allUsers,
          winningTeam: winningTeam,
          basePoints: basePoints,
          bonusEligible: bonusEligible
      );

      // 5. Update match status to finished and set winner
      if (!_dryRun) {
        await _supabase
            .from('matches')
            .update({
          'status': 'finished',
          'winner': winningTeam,
        })
            .eq('id', matchId);
      } else {
        debugPrint('[DRY RUN] Would update match status to finished and set winner to: $winningTeam');
      }

      return true;
    } catch (e) {
      debugPrint('Error in updateMatchResult: $e');
      rethrow; // Re-throw to be handled by view model
    }
  }

  // Private method to calculate and apply points
  Future<void> _calculateAndApplyPoints({
    required Match match,
    required List<Vote> votes,
    required List<UserProfile> allUsers,
    required String winningTeam,
    required int basePoints,
    required bool bonusEligible,
  }) async {
    try {
      // Calculate game points with bonus if applicable - use double for precision
      final double gamePoints = match.type == MatchType.fixed && bonusEligible
          ? basePoints + (basePoints * 0.5)  // 50% bonus as decimal
          : basePoints.toDouble();

      debugPrint('----------------------');
      debugPrint('POINTS CALCULATION LOG');
      debugPrint('----------------------');
      debugPrint('Match ID: ${match.id}');
      debugPrint('Match Title: ${match.title}');
      debugPrint('Match Type: ${match.type}');
      debugPrint('Winning Team: $winningTeam');
      debugPrint('Base Points: $basePoints');
      debugPrint('Bonus Eligible: $bonusEligible');
      debugPrint('Game Points: ${gamePoints.toStringAsFixed(2)}');
      debugPrint('----------------------');

      // Group votes by result
      final correctVotes = votes.where((vote) => vote.vote == winningTeam).toList();
      final incorrectVotes = votes.where((vote) => vote.vote != winningTeam).toList();

      // Calculate points based on match type
      if (match.type == MatchType.fixed) {
        await _calculateFixedMatchPoints(
          match: match,
          correctVotes: correctVotes,
          incorrectVotes: incorrectVotes,
          allUsers: allUsers,
          winningTeam: winningTeam,
          gamePoints: gamePoints,
        );
      } else {
        await _calculateVariableMatchPoints(
          correctVotes: correctVotes,
          incorrectVotes: incorrectVotes,
          winningTeam: winningTeam,
          basePoints: gamePoints,
        );
      }
    } catch (e) {
      debugPrint('Error in points calculation: $e');
      rethrow;
    }
  }

  Future<void> _calculateFixedMatchPoints({
    required Match match,
    required List<Vote> correctVotes,
    required List<Vote> incorrectVotes,
    required List<UserProfile> allUsers,
    required String winningTeam,
    required double gamePoints,
  }) async {
    // 1. Identify non-voters (users who didn't vote)
    final voterIds = [...correctVotes, ...incorrectVotes].map((v) => v.userId).toSet();
    final nonVoterIds = allUsers
        .map((user) => user.id)
        .where((userId) => !voterIds.contains(userId))
        .toList();

    debugPrint('FIXED MATCH CALCULATION:');
    debugPrint('Total Voters: ${voterIds.length}');
    debugPrint('Correct Voters: ${correctVotes.length}');
    debugPrint('Incorrect Voters: ${incorrectVotes.length}');
    debugPrint('Non-Voters: ${nonVoterIds.length}');

    // 2. Calculate points deducted from incorrect voters and non-voters - using doubles for precision
    final double pointsFromIncorrect = incorrectVotes.length * gamePoints;
    final double pointsFromNonVoters = nonVoterIds.length * (gamePoints / 2); // Division for exact half
    final double totalPointsToDistribute = pointsFromIncorrect + pointsFromNonVoters;

    // 3. Calculate points per correct voter - maintain decimal precision
    final double pointsPerCorrectVoter = correctVotes.isEmpty
        ? 0.0
        : totalPointsToDistribute / correctVotes.length;

    // Format with 2 decimal places for logging
    final String formattedGamePoints = gamePoints.toStringAsFixed(2);
    final String formattedHalfGamePoints = (gamePoints / 2).toStringAsFixed(2);
    final String formattedPointsFromIncorrect = pointsFromIncorrect.toStringAsFixed(2);
    final String formattedPointsFromNonVoters = pointsFromNonVoters.toStringAsFixed(2);
    final String formattedTotalPointsToDistribute = totalPointsToDistribute.toStringAsFixed(2);
    final String formattedPointsPerCorrectVoter = pointsPerCorrectVoter.toStringAsFixed(2);

    debugPrint('Points From Incorrect Voters: $formattedPointsFromIncorrect (${incorrectVotes.length} users x $formattedGamePoints points)');
    debugPrint('Points From Non-Voters: $formattedPointsFromNonVoters (${nonVoterIds.length} users x $formattedHalfGamePoints points)');
    debugPrint('Total Points to Distribute: $formattedTotalPointsToDistribute');
    debugPrint('Points Per Correct Voter: $formattedPointsPerCorrectVoter (total / ${correctVotes.length} users)');
    debugPrint('----------------------');

    // 4. Update database with calculated points

    // 4.1 Update correct votes (won status and add points)
    debugPrint('CORRECT VOTERS (would gain $formattedPointsPerCorrectVoter points each):');
    for (final vote in correctVotes) {
      if (!_dryRun) {
        await _supabase
            .from('votes')
            .update({
          'status': 'won',
          'points': pointsPerCorrectVoter.round(), // Round only at the database update
        })
            .eq('id', vote.id);

        // Update user points in profile
        // await _updateUserPoints(
        //   userId: vote.userId,
        //   pointsChange: pointsPerCorrectVoter.round(),
        //   matchId: match.id,
        // );
      }
      debugPrint(' - User ${vote.userId}: +$formattedPointsPerCorrectVoter points (voted for $winningTeam)');
    }

    // 4.2 Update incorrect votes (lost status and deduct points)
    debugPrint('INCORRECT VOTERS (would lose $formattedGamePoints points each):');
    for (final vote in incorrectVotes) {
      if (!_dryRun) {
        await _supabase
            .from('votes')
            .update({
          'status': 'lost',
          'points': -gamePoints.round(), // Round only at the database update
        })
            .eq('id', vote.id);

        // Update user points in profile
        // await _updateUserPoints(
        //   userId: vote.userId,
        //   pointsChange: -gamePoints.round(),
        //   matchId: match.id,
        // );
      }
      debugPrint(' - User ${vote.userId}: -$formattedGamePoints points (voted for ${vote.vote})');
    }

    // 4.3 Update non-voters (deduct half game points)
    debugPrint('NON-VOTERS (would lose $formattedHalfGamePoints points each):');
    for (final userId in nonVoterIds) {
      if (!_dryRun) {
        // For non-voters, we don't have a vote record, so we'll just update their points
        // await _updateUserPoints(
        //   userId: userId,
        //   pointsChange: -(gamePoints / 2).round(),
        //   matchId: match.id,
        //   reason: 'match_result_non_voter',
        // );
      }
      debugPrint(' - User $userId: -$formattedHalfGamePoints points (did not vote)');
    }

    // Format to ensure rounding is shown correctly
    final String roundedTotal = (correctVotes.length * pointsPerCorrectVoter).toStringAsFixed(2);

    debugPrint('----------------------');
    debugPrint('TOTAL POINT TRANSFER: $formattedTotalPointsToDistribute');
    debugPrint('TOTAL POINTS TO CORRECT VOTERS: $roundedTotal');

    // Check for rounding errors
    final double roundingDifference = totalPointsToDistribute - (correctVotes.length * pointsPerCorrectVoter);
    if (roundingDifference.abs() > 0.01) {
      debugPrint('WARNING: Rounding difference detected: ${roundingDifference.toStringAsFixed(2)} points');
    }

    debugPrint('----------------------');
  }

  Future<void> _calculateVariableMatchPoints({
    required List<Vote> correctVotes,
    required List<Vote> incorrectVotes,
    required String winningTeam,
    required double basePoints,
  }) async {
    debugPrint('VARIABLE MATCH CALCULATION:');
    debugPrint('Total Voters: ${correctVotes.length + incorrectVotes.length}');
    debugPrint('Correct Voters: ${correctVotes.length}');
    debugPrint('Incorrect Voters: ${incorrectVotes.length}');
    debugPrint('Non-Voters: Not penalized in variable matches');

    // 1. Calculate points deducted from incorrect voters - using doubles for precision
    final double pointsFromIncorrect = incorrectVotes.length * basePoints;

    // 2. Calculate points per correct voter - maintain decimal precision
    final double pointsPerCorrectVoter = correctVotes.isEmpty
        ? 0.0
        : pointsFromIncorrect / correctVotes.length;

    // Format with 2 decimal places for logging
    final String formattedBasePoints = basePoints.toStringAsFixed(2);
    final String formattedPointsFromIncorrect = pointsFromIncorrect.toStringAsFixed(2);
    final String formattedPointsPerCorrectVoter = pointsPerCorrectVoter.toStringAsFixed(2);

    debugPrint('Points From Incorrect Voters: $formattedPointsFromIncorrect (${incorrectVotes.length} users x $formattedBasePoints points)');
    debugPrint('Total Points to Distribute: $formattedPointsFromIncorrect');
    debugPrint('Points Per Correct Voter: $formattedPointsPerCorrectVoter (total / ${correctVotes.length} users)');
    debugPrint('----------------------');

    // 3. Update database with calculated points

    // 3.1 Update correct votes (won status and add points)
    debugPrint('CORRECT VOTERS (would gain $formattedPointsPerCorrectVoter points each):');
    for (final vote in correctVotes) {
      if (!_dryRun) {
        await _supabase
            .from('votes')
            .update({
          'status': 'won',
          'points': pointsPerCorrectVoter.round(), // Round only at the database update
        })
            .eq('id', vote.id);

        // Update user points in profile
        // await _updateUserPoints(
        //   userId: vote.userId,
        //   pointsChange: pointsPerCorrectVoter.round(),
        //   matchId: vote.matchId,
        // );
      }
      debugPrint(' - User ${vote.userId}: +$formattedPointsPerCorrectVoter points (voted for $winningTeam)');
    }

    // 3.2 Update incorrect votes (lost status and deduct points)
    debugPrint('INCORRECT VOTERS (would lose $formattedBasePoints points each):');
    for (final vote in incorrectVotes) {
      if (!_dryRun) {
        await _supabase
            .from('votes')
            .update({
          'status': 'lost',
          'points': -basePoints.round(), // Round only at the database update
        })
            .eq('id', vote.id);

        // Update user points in profile
        // await _updateUserPoints(
        //   userId: vote.userId,
        //   pointsChange: -basePoints.round(),
        //   matchId: vote.matchId,
        // );
      }
      debugPrint(' - User ${vote.userId}: -$formattedBasePoints points (voted for ${vote.vote})');
    }

    // Format to ensure rounding is shown correctly
    final String roundedTotal = (correctVotes.length * pointsPerCorrectVoter).toStringAsFixed(2);

    debugPrint('----------------------');
    debugPrint('TOTAL POINT TRANSFER: $formattedPointsFromIncorrect');
    debugPrint('TOTAL POINTS TO CORRECT VOTERS: $roundedTotal');

    // Check for rounding errors
    final double roundingDifference = pointsFromIncorrect - (correctVotes.length * pointsPerCorrectVoter);
    if (roundingDifference.abs() > 0.01) {
      debugPrint('WARNING: Rounding difference detected: ${roundingDifference.toStringAsFixed(2)} points');
    }

    debugPrint('----------------------');
  }

  // Helper to update user points and record in history
  // Future<void> _updateUserPoints({
  //   required String userId,
  //   required int pointsChange,
  //   required String matchId,
  //   String reason = 'match_result',
  // }) async {
  //   try {
  //     if (_dryRun) {
  //       // Skip database update in dry run mode
  //       return;
  //     }
  //
  //     // Use the stored function to update points in a transaction
  //     await _supabase.rpc(
  //       'update_user_points',
  //       params: {
  //         'p_user_id': userId,
  //         'p_points_change': pointsChange,
  //         'p_reason': reason,
  //         'p_match_id': matchId,
  //       },
  //     );
  //
  //     debugPrint('Updated points for user $userId: $pointsChange');
  //   } catch (e) {
  //     debugPrint('Error updating points for user $userId: $e');
  //     // We'll continue processing other users even if one fails
  //     // Consider adding a retry mechanism or logging failures for manual review
  //   }
  // }
}