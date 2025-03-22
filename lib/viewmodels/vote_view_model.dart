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
  List<Match> _futureMatches = [];
  Map<String, Vote> _userVotes = {}; // matchId -> Vote

  VoteViewModel(this._voteRepository, this._matchRepository);

  // Getters
  VoteLoadingStatus get status => _status;
  String get errorMessage => _errorMessage;
  List<Match> get futureMatches => _futureMatches;
  Map<String, Vote> get userVotes => _userVotes;
  bool get isLoading => _status == VoteLoadingStatus.loading;

  // Fetch future matches (matches that haven't started yet)
  Future<void> loadFutureMatches() async {
    _setLoading();

    try {
      // Get all matches
      final allMatches = await _matchRepository.getMatches();

      // Filter for future matches (matches that start in the future)
      final now = DateTime.now();
      _futureMatches = allMatches
          .where((match) => match.startDate.isAfter(now))
          .toList();

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

  // Save a vote for a match
  Future<bool> saveVote(String userId, String matchId, String teamVote) async {
    _setLoading();

    try {
      await _voteRepository.saveVote(userId, matchId, teamVote);

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
      await _voteRepository.deleteVote(voteId);

      // Get the current user's ID
      final currentUserId = _userVotes.values.firstWhere((vote) => vote.id == voteId).userId;

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