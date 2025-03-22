// lib/viewmodels/vote_details_view_model.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/match_model.dart';
import '../models/vote_model.dart';
import '../models/vote_details_model.dart';
import '../models/user_profile.dart';
import '../repositories/match_repository.dart';
import '../repositories/vote_repository.dart';
import '../utils/date_helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum VoteDetailsLoadingStatus { idle, loading, success, error }

class VoteDetailsViewModel with ChangeNotifier {
  final VoteRepository _voteRepository;
  final MatchRepository _matchRepository;
  final SupabaseClient _supabase;

  VoteDetailsLoadingStatus _status = VoteDetailsLoadingStatus.idle;
  String _errorMessage = '';
  Match? _match;
  List<VoteDetails> _voteDetails = [];

  VoteDetailsViewModel(this._voteRepository, this._matchRepository, this._supabase);

  // Getters
  VoteDetailsLoadingStatus get status => _status;
  String get errorMessage => _errorMessage;
  Match? get match => _match;
  List<VoteDetails> get voteDetails => _voteDetails;
  bool get isLoading => _status == VoteDetailsLoadingStatus.loading;

  // Load a specific match
  Future<void> loadMatch(String matchId) async {
    _setLoading();

    try {
      _match = await _matchRepository.getMatchById(matchId);
      DateHelpers.logDateInfo('Match start date', _match!.startDate);
      DateHelpers.logDateInfo('Match cutoff time', _match!.votingCutoffTime);
      _setSuccess();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Load all votes for a match
  Future<void> loadMatchVotes(String matchId) async {
    _setLoading();

    try {
      // First check if voting is closed
      if (_match != null) {
        // Use the Match model's isVotingClosed method for consistent logic
        final votingClosed = _match!.isVotingClosed();

        // If voting hasn't closed yet, don't show votes
        if (!votingClosed) {
          debugPrint('Voting not closed yet for match: ${_match!.title}');
          debugPrint('Current time: ${DateTime.now()}');
          debugPrint('Cutoff time: ${_match!.votingCutoffTime}');

          _voteDetails = [];
          _setSuccess();
          return;
        }
      }

      // Get all votes for the match
      final votes = await _voteRepository.getMatchVotes(matchId);
      debugPrint('Loaded ${votes.length} votes for match $matchId');

      // Prepare a list to store the vote details
      List<VoteDetails> details = [];

      // For each vote, fetch the user profile
      for (var vote in votes) {
        try {
          final response = await _supabase
              .from('user_profile')
              .select()
              .eq('id', vote.userId)
              .single();

          UserProfile userProfile = UserProfile.fromJson(response);
          details.add(VoteDetails(vote: vote, userProfile: userProfile));
        } catch (e) {
          debugPrint('Error fetching profile for user ${vote.userId}: $e');
          // If profile not found, still add the vote but without profile
          details.add(VoteDetails(vote: vote));
        }
      }

      _voteDetails = details;
      _setSuccess();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Get vote statistics
  Map<String, dynamic> getVoteStats() {
    if (_match == null || _voteDetails.isEmpty) {
      return {
        'team1Votes': 0,
        'team2Votes': 0,
        'totalVotes': 0,
        'team1Percentage': 0.0,
        'team2Percentage': 0.0,
      };
    }

    final team1Votes = _voteDetails.where((v) => v.vote.vote == _match!.team1).length;
    final team2Votes = _voteDetails.where((v) => v.vote.vote == _match!.team2).length;
    final totalVotes = _voteDetails.length;

    final team1Percentage = totalVotes > 0 ? (team1Votes / totalVotes) * 100 : 0.0;
    final team2Percentage = totalVotes > 0 ? (team2Votes / totalVotes) * 100 : 0.0;

    return {
      'team1Votes': team1Votes,
      'team2Votes': team2Votes,
      'totalVotes': totalVotes,
      'team1Percentage': team1Percentage,
      'team2Percentage': team2Percentage,
    };
  }

  // Determine winner (if match is finished)
  String? getWinner() {
    if (_match == null || _match!.status != MatchStatus.finished || _voteDetails.isEmpty) {
      return null;
    }

    final stats = getVoteStats();
    return stats['team1Votes'] > stats['team2Votes'] ? _match!.team1 : _match!.team2;
  }

  // Get votes for a specific team
  List<VoteDetails> getVotesForTeam(String team) {
    return _voteDetails.where((v) => v.vote.vote == team).toList();
  }

  // Helper methods to update state
  void _setLoading() {
    _status = VoteDetailsLoadingStatus.loading;
    notifyListeners();
  }

  void _setSuccess() {
    _status = VoteDetailsLoadingStatus.success;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = VoteDetailsLoadingStatus.error;
    notifyListeners();
  }
}