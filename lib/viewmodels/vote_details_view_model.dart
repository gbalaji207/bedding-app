// lib/viewmodels/vote_details_view_model.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/match_model.dart';
import '../models/vote_model.dart';
import '../models/vote_details_model.dart';
import '../models/user_profile.dart';
import '../repositories/match_repository.dart';
import '../repositories/vote_repository.dart';
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
      _setSuccess();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Load all votes for a match
  Future<void> loadMatchVotes(String matchId) async {
    _setLoading();

    try {
      // First check if match has started
      if (_match != null) {
        final now = DateTime.now();
        final matchHasStarted = now.isAfter(_match!.startDate);

        // If match hasn't started yet, don't show votes
        if (!matchHasStarted) {
          _voteDetails = [];
          _setSuccess();
          return;
        }
      }

      // Get all votes for the match
      final votes = await _voteRepository.getMatchVotes(matchId);

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