// lib/viewmodels/match_result_view_model.dart
import 'package:flutter/foundation.dart';
import '../models/match_model.dart';
import '../repositories/match_repository.dart';
import '../repositories/match_result_repository.dart';

class MatchResultViewModel with ChangeNotifier {
  final MatchRepository _matchRepository;
  final MatchResultRepository _resultRepository;

  bool _isLoading = false;
  String _errorMessage = '';
  bool _isSuccess = false;
  Match? _match;

  // Getters
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  bool get isSuccess => _isSuccess;
  Match? get match => _match;
  bool get hasMatch => _match != null;

  MatchResultViewModel(this._matchRepository, this._resultRepository);

  // Fetch match data
  Future<void> loadMatch(String matchId) async {
    try {
      _setLoading();

      // Fetch the match from repository
      _match = await _matchRepository.getMatchById(matchId);

      _setSuccess();
    } catch (e) {
      debugPrint('Error loading match: $e');
      _setError(e.toString());
    }
  }

  // Update match result and calculate points
  Future<bool> updateMatchResult(
      String matchId,
      String winningTeam,
      int basePoints,
      bool bonusEligible,
      ) async {
    try {
      _setLoading();

      // 1. Fetch the match if not already loaded
      if (_match == null) {
        await loadMatch(matchId);
        if (_match == null) {
          _setError('Failed to load match details');
          return false;
        }
      }

      // 2. Use the repository to update the match result
      await _resultRepository.updateMatchResult(
        matchId: matchId,
        match: _match!,
        winningTeam: winningTeam,
        basePoints: basePoints,
        bonusEligible: bonusEligible,
      );

      // 3. Reload the match to get updated data
      await loadMatch(matchId);

      _setSuccess();
      return true;
    } catch (e) {
      debugPrint('Error updating match result: $e');
      _setError(e.toString());
      return false;
    }
  }

  void _setLoading() {
    _isLoading = true;
    _errorMessage = '';
    _isSuccess = false;
    notifyListeners();
  }

  void _setError(String message) {
    _isLoading = false;
    _errorMessage = message;
    _isSuccess = false;
    notifyListeners();
  }

  void _setSuccess() {
    _isLoading = false;
    _errorMessage = '';
    _isSuccess = true;
    notifyListeners();
  }
}