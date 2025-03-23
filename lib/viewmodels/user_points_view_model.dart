// lib/viewmodels/user_points_view_model.dart
import 'package:flutter/foundation.dart';
import '../repositories/user_points_repository.dart';

enum PointsLoadingStatus { idle, loading, loaded, error }

class UserPointsViewModel with ChangeNotifier {
  final UserPointsRepository _repository;

  PointsLoadingStatus _status = PointsLoadingStatus.idle;
  String _errorMessage = '';
  List<Map<String, dynamic>> _userPoints = [];

  UserPointsViewModel(this._repository);

  // Getters
  PointsLoadingStatus get status => _status;
  String get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get userPoints => _userPoints;
  bool get isLoading => _status == PointsLoadingStatus.loading;

  // Fetch all user points
  Future<void> loadUserPoints() async {
    _setLoading();

    try {
      _userPoints = await _repository.getUserPoints();

      // Additional validation to ensure we have valid data
      _userPoints = _userPoints.where((userPoint) {
        // Ensure required fields exist and are valid
        return userPoint['id'] != null &&
            userPoint['displayName'] != null &&
            userPoint['totalPoints'] != null;
      }).toList();

      _setSuccess();
    } catch (e) {
      debugPrint('Error in loadUserPoints: $e');
      _setError(e.toString());
    }
  }

  // Calculate rank numbers for display with ties considered
  List<Map<String, dynamic>> getUserPointsWithRanks() {
    if (_userPoints.isEmpty) return [];

    final result = List<Map<String, dynamic>>.from(_userPoints);

    try {
      // Fix ranking logic to ensure ranks are positive and sequential
      double currentPoints = result.isNotEmpty && result[0]['totalPoints'] != null
          ? result[0]['totalPoints']
          : 0.0;

      int currentRank = 1;

      for (int i = 0; i < result.length; i++) {
        // Ensure totalPoints is not null
        if (result[i]['totalPoints'] == null) {
          result[i]['totalPoints'] = 0.0;
        }

        // First entry gets rank 1
        if (i == 0) {
          result[i]['rank'] = 1;
          continue;
        }

        // Check for tie (same points as previous entry)
        if (result[i]['totalPoints'] == result[i-1]['totalPoints']) {
          // Same rank as previous entry
          result[i]['rank'] = result[i-1]['rank'];
        } else {
          // New points value, rank is current position + 1
          result[i]['rank'] = i + 1;
          currentRank = i + 1;
          currentPoints = result[i]['totalPoints'];
        }
      }
    } catch (e) {
      debugPrint('Error calculating ranks: $e');
      // Fallback: assign sequential ranks if the calculation fails
      for (int i = 0; i < result.length; i++) {
        result[i]['rank'] = i + 1;
      }
    }

    return result;
  }

  // Helper methods
  void _setLoading() {
    _status = PointsLoadingStatus.loading;
    notifyListeners();
  }

  void _setSuccess() {
    _status = PointsLoadingStatus.loaded;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _status = PointsLoadingStatus.error;
    notifyListeners();
  }
}