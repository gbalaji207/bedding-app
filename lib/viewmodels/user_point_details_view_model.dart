// lib/viewmodels/user_point_details_view_model.dart
import 'package:flutter/foundation.dart';
import '../models/user_point_history_model.dart';
import '../models/user_profile.dart';
import '../repositories/user_point_history_repository.dart';

enum FilterType { all, wins, losses }

enum SortType { dateDesc, dateAsc, pointsDesc, pointsAsc }

class UserPointDetailsViewModel with ChangeNotifier {
  final UserPointHistoryRepository _repository;
  final String userId;

  bool _isLoading = false;
  String _errorMessage = '';
  UserProfile? _userProfile;
  double _totalPoints = 0.0;
  int _userRank = 0;
  List<UserPointHistory> _history = [];
  Map<String, dynamic> _stats = {};

  // Filtering and sorting state
  FilterType _currentFilter = FilterType.all;
  SortType _currentSort = SortType.dateDesc;

  UserPointDetailsViewModel(this._repository, this.userId);

  // Getters
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  UserProfile? get userProfile => _userProfile;
  double get totalPoints => _totalPoints;
  int get userRank => _userRank;
  Map<String, dynamic> get stats => _stats;
  FilterType get currentFilter => _currentFilter;
  SortType get currentSort => _currentSort;

  // Getter for filtered and sorted history
  List<UserPointHistory> get filteredHistory {
    List<UserPointHistory> filtered = List.from(_history);

    // Apply filter
    switch (_currentFilter) {
      case FilterType.wins:
        filtered = filtered.where((item) => item.isCorrectVote).toList();
        break;
      case FilterType.losses:
        filtered = filtered.where((item) => !item.isCorrectVote).toList();
        break;
      case FilterType.all:
      default:
      // No filtering needed
        break;
    }

    // Apply sort
    switch (_currentSort) {
      case SortType.dateAsc:
        filtered.sort((a, b) => a.matchDate.compareTo(b.matchDate));
        break;
      case SortType.pointsDesc:
        filtered.sort((a, b) => b.points.abs().compareTo(a.points.abs()));
        break;
      case SortType.pointsAsc:
        filtered.sort((a, b) => a.points.abs().compareTo(b.points.abs()));
        break;
      case SortType.dateDesc:
      default:
        filtered.sort((a, b) => b.matchDate.compareTo(a.matchDate));
        break;
    }

    return filtered;
  }

  // Load all user point details
  Future<void> loadUserPointDetails() async {
    _setLoading(true);
    _clearError();

    try {
      // Fetch user profile
      _userProfile = await _repository.getUserProfile(userId);

      // Fetch total points
      _totalPoints = await _repository.getUserTotalPoints(userId);

      // Fetch user rank
      _userRank = await _repository.getUserRank(userId);

      // Fetch user point history
      _history = await _repository.getUserPointHistory(userId);

      // Fetch user voting statistics
      _stats = await _repository.getUserVotingStats(userId);

      _setLoading(false);
    } catch (e) {
      _setError('Failed to load user point details: $e');
    }
  }

  // Set filter type
  void setFilter(FilterType filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  // Set sort type
  void setSort(SortType sort) {
    _currentSort = sort;
    notifyListeners();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _isLoading = false;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = '';
    notifyListeners();
  }
}