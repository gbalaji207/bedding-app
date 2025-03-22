// lib/viewmodels/match_view_model.dart
import 'package:flutter/foundation.dart';

import '../../models/match_model.dart';
import '../../repositories/match_repository.dart';

enum LoadingStatus { idle, loading, loaded, error }

class MatchViewModel with ChangeNotifier {
  final MatchRepository _repository;

  List<Match> _matches = [];
  LoadingStatus _status = LoadingStatus.idle;
  String _errorMessage = '';

  MatchViewModel(this._repository);

  // Getters
  List<Match> get matches => _matches;

  LoadingStatus get status => _status;

  String get errorMessage => _errorMessage;

  bool get isLoading => _status == LoadingStatus.loading;

  // Fetch all matches
  Future<void> fetchMatches() async {
    _setLoading();

    try {
      final matches = await _repository.getMatches();
      _setLoaded(matches);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Fetch a specific match by ID
  Future<Match?> getMatchById(String id) async {
    try {
      return await _repository.getMatchById(id);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  // Create a new match
  Future<void> createMatch(Match match) async {
    try {
      await _repository.createMatch(match);
      await fetchMatches(); // Refresh the list
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Update an existing match
  Future<void> updateMatch(Match match) async {
    try {
      await _repository.updateMatch(match);
      await fetchMatches(); // Refresh the list
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Delete a match
  Future<void> deleteMatch(String id) async {
    try {
      await _repository.deleteMatch(id);
      await fetchMatches(); // Refresh the list
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Helper methods to update state
  void _setLoading() {
    _status = LoadingStatus.loading;
    notifyListeners();
  }

  void _setLoaded(List<Match> matches) {
    _matches = matches;
    _status = LoadingStatus.loaded;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = LoadingStatus.error;
    notifyListeners();
  }

  // Refresh all data (matches)
  Future<void> refreshData() async {
    _setLoading();

    try {
      // Fetch all matches again
      await fetchMatches();
    } catch (e) {
      _setError(e.toString());
    }
  }
}
