// lib/viewmodels/vote_view_model.dart
import 'package:flutter/foundation.dart';
import '../models/match_model.dart';
import '../models/vote_model.dart';
import '../repositories/match_repository.dart';
import '../repositories/vote_repository.dart';

enum VoteLoadingStatus { idle, loading, success, error }

class VoteViewModel with ChangeNotifier {
  final VoteRepository _voteRepository;
  final MatchRepository _matchRepository;

  VoteLoadingStatus _status = VoteLoadingStatus.idle;
  String _errorMessage = '';
  List<Match> _allFutureMatches = []; // All future matches from the repository
  Map<String, Vote> _userVotes = {}; // matchId -> Vote

  VoteViewModel(this._voteRepository, this._matchRepository);

  // Getters
  VoteLoadingStatus get status => _status;
  String get errorMessage => _errorMessage;

  // Get only the matches where voting is still open
  List<Match> get futureMatches => _allFutureMatches
      .where((match) => !match.isVotingClosed())
      .toList();

  // Get all future matches, including those with closed voting
  List<Match> get allFutureMatches => _allFutureMatches;

  Map<String, Vote> get userVotes => _userVotes;
  bool get isLoading => _status == VoteLoadingStatus.loading;

  // Fetch future matches (matches that haven't started yet)
  Future<void> loadFutureMatches() async {
    _setLoading();

    try {
      // Get future matches directly from the database
      _allFutureMatches = await _matchRepository.getFutureMatches();

      // Log information about matches and their voting status
      for (var match in _allFutureMatches) {
        final isClosed = match.isVotingClosed();
        debugPrint('Match: ${match.title}, Start: ${match.startDate}, Cutoff: ${match.votingCutoffTime}, Voting Closed: $isClosed');
      }

      _setSuccess();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Load user votes for a specific user
  Future<void> loadUserVotes(String userId) async {
    _setLoading();

    try {
      final votes = await _voteRepository.getUserVotes(userId);

      // Create a map of matchId -> Vote for easy lookup
      _userVotes = {for (var vote in votes) vote.matchId: vote};

      _setSuccess();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Check if user has voted for a specific match
  bool hasVotedForMatch(String matchId) {
    return _userVotes.containsKey(matchId);
  }

  // Get user's vote for a specific match
  Vote? getVoteForMatch(String matchId) {
    return _userVotes[matchId];
  }

  // Get a specific match by ID
  Match? getMatchById(String matchId) {
    try {
      return _allFutureMatches.firstWhere((match) => match.id == matchId);
    } catch (e) {
      return null;
    }
  }

  // Check if voting is closed for a match
  bool isVotingClosed(Match match) {
    return match.isVotingClosed();
  }

  // Save a vote for a match
  Future<bool> saveVote(String userId, String matchId, String teamVote) async {
    _setLoading();

    try {
      // Get the match to check if voting is still allowed
      final match = getMatchById(matchId);

      if (match != null) {
        // Check if voting is closed using the Match model
        if (match.isVotingClosed()) {
          _setError('Voting is closed for this match as it starts in less than 30 minutes');
          return false;
        }
      }

      // Save the vote with the match for time validation
      await _voteRepository.saveVote(userId, matchId, teamVote, match: match);

      // Reload user votes to update the UI
      await loadUserVotes(userId);

      _setSuccess();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Delete a vote
  Future<bool> deleteVote(String voteId) async {
    _setLoading();

    try {
      // First check if the related match is within 30 minutes of starting
      final vote = _userVotes.values.firstWhere((v) => v.id == voteId);
      final matchId = vote.matchId;
      final match = getMatchById(matchId);

      if (match != null) {
        // Check if voting is closed using the Match model
        if (match.isVotingClosed()) {
          _setError('Cannot delete vote as match starts in less than 30 minutes');
          return false;
        }
      }

      await _voteRepository.deleteVote(voteId);

      // Get the current user's ID
      final currentUserId = vote.userId;

      // Reload user votes to update the UI
      await loadUserVotes(currentUserId);

      _setSuccess();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // Helper methods to update state
  void _setLoading() {
    _status = VoteLoadingStatus.loading;
    notifyListeners();
  }

  void _setSuccess() {
    _status = VoteLoadingStatus.success;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = VoteLoadingStatus.error;
    notifyListeners();
  }
}