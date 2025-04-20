// lib/viewmodels/vote_details_view_model.dart
import 'package:flutter/material.dart';
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
  List<UserProfile> _allUsers = [];
  bool _isLoadingUsers = false;

  // Processed vote data
  List<VoteDetails>? _processedVotes;
  Map<String, dynamic>? _voteSummary;

  VoteDetailsViewModel(this._voteRepository, this._matchRepository, this._supabase);

  // Getters
  VoteDetailsLoadingStatus get status => _status;
  String get errorMessage => _errorMessage;
  Match? get match => _match;
  List<VoteDetails> get voteDetails => _voteDetails;
  bool get isLoading => _status == VoteDetailsLoadingStatus.loading || _isLoadingUsers;
  List<UserProfile> get allUsers => _allUsers;
  bool get isLoadingUsers => _isLoadingUsers;

  // Getter for processed votes
  List<VoteDetails> get processedVotes {
    if (_processedVotes == null) {
      _processVotes();
    }
    return _processedVotes!;
  }

  // Getter for vote summary data
  Map<String, dynamic> get voteSummary {
    if (_voteSummary == null) {
      _calculateVoteSummary();
    }
    return _voteSummary!;
  }

  // Reset processed data when underlying data changes
  void _resetProcessedData() {
    _processedVotes = null;
    _voteSummary = null;
  }

  // Load a specific match
  Future<void> loadMatch(String matchId) async {
    _setLoading();

    try {
      _match = await _matchRepository.getMatchById(matchId);
      DateHelpers.logDateInfo('Match start date', _match!.startDate);
      DateHelpers.logDateInfo('Match cutoff time', _match!.votingCutoffTime);

      _resetProcessedData();
      _setSuccess();

      // For fixed matches, automatically load all users
      if (_match?.type == MatchType.fixed) {
        loadAllUsers();
      }
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
          _resetProcessedData();
          _setSuccess();
          return;
        }
      }

      // Get all votes for the match (including no_vote records)
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
      _resetProcessedData();
      _setSuccess();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // Load all users in the system
  Future<void> loadAllUsers() async {
    _isLoadingUsers = true;
    notifyListeners();

    try {
      _allUsers = await getAllUsers();
      _resetProcessedData();
    } catch (e) {
      debugPrint('Error loading all users: $e');
      _setError('Failed to load all users: $e');
    } finally {
      _isLoadingUsers = false;
      notifyListeners();
    }
  }

  // Get all users from the database
  Future<List<UserProfile>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('user_profile')
          .select();

      return response.map<UserProfile>((json) => UserProfile.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching all users: $e');
      _setError('Failed to load all users: $e');
      return [];
    }
  }

  // Process votes based on match type
  void _processVotes() {
    if (_match == null) {
      _processedVotes = [];
      return;
    }

    if (_match!.type == MatchType.fixed) {
      _processedVotes = _processFixedMatchVotes();
    } else {
      _processedVotes = _processVariableMatchVotes();
    }
  }

  // Process votes for fixed match, handling non-voters differently based on match status
  List<VoteDetails> _processFixedMatchVotes() {
    // Create a map of userId -> VoteDetails to check if a user has voted
    final Map<String, VoteDetails> votesByUserId = {
      for (var vote in _voteDetails) vote.vote.userId: vote
    };

    // Create a list to hold all effective votes
    final List<VoteDetails> effectiveVotes = List.from(_voteDetails);

    // Check if match is finished (non-voters already have vote records with 'no_vote' status)
    final isFinished = _match!.status == MatchStatus.finished;

    // If not finished, we need to identify non-voters by comparing with all users
    if (!isFinished && _allUsers.isNotEmpty) {
      // Add entries for users who didn't vote
      for (var user in _allUsers) {
        if (!votesByUserId.containsKey(user.id)) {
          // Create a "non-vote" entry
          effectiveVotes.add(
            VoteDetails(
              vote: Vote(
                id: 'no-vote-${user.id}',
                userId: user.id,
                matchId: _match!.id,
                vote: '',
                status: 'no_vote',
                points: 0,
              ),
              userProfile: user,
            ),
          );
        }
      }
    }

    // Sort votes into groups: team1, team2, non-voters
    final team1 = _match!.team1;
    final team2 = _match!.team2;

    effectiveVotes.sort((a, b) {
      // First determine category for each vote (team1, team2, or non-voter)
      int getCategoryValue(VoteDetails vote) {
        if (vote.vote.status == 'no_vote') return 2; // Non-voters last
        if (vote.vote.vote == team1) return 0; // Team1 first
        return 1; // Team2 second
      }

      final aCat = getCategoryValue(a);
      final bCat = getCategoryValue(b);

      // If categories are different, sort by category
      if (aCat != bCat) {
        return aCat.compareTo(bCat);
      }

      // If categories are the same, sort alphabetically by display name
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    return effectiveVotes;
  }

  // Process votes for variable match (only actual voters, grouped by team)
  List<VoteDetails> _processVariableMatchVotes() {
    if (_match == null) return [];

    final team1 = _match!.team1;
    final sortedVotes = List<VoteDetails>.from(_voteDetails);

    // Sort by team (team1 first, team2 second) and then alphabetically by name
    sortedVotes.sort((a, b) {
      // First sort by team (team1 first, team2 second)
      if (a.vote.vote == team1 && b.vote.vote != team1) {
        return -1; // a is team1, b is not team1
      }
      if (a.vote.vote != team1 && b.vote.vote == team1) {
        return 1; // a is not team1, b is team1
      }

      // If same team, sort alphabetically by name
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    return sortedVotes;
  }

  // Calculate vote summary data
  void _calculateVoteSummary() {
    if (_match == null) {
      _voteSummary = _getEmptyVoteSummary();
      return;
    }

    final votes = processedVotes;

    if (_match!.type == MatchType.fixed) {
      _voteSummary = _calculateFixedMatchSummary(votes);
    } else {
      _voteSummary = _calculateVariableMatchSummary(votes);
    }
  }

  // Calculate summary for fixed matches
  Map<String, dynamic> _calculateFixedMatchSummary(List<VoteDetails> voteDetails) {
    if (_match == null) return _getEmptyVoteSummary();

    // Count votes for each team and non-voters
    final team1Votes = voteDetails.where((v) => v.vote.vote == _match!.team1).length;
    final team2Votes = voteDetails.where((v) => v.vote.vote == _match!.team2).length;
    final nonVoters = voteDetails.where((v) => v.vote.status == 'no_vote').length;

    // Calculate totals
    final totalUsers = team1Votes + team2Votes + nonVoters;

    // Calculate percentages based on total users
    final team1Percentage = totalUsers > 0 ? (team1Votes / totalUsers) * 100 : 0.0;
    final team2Percentage = totalUsers > 0 ? (team2Votes / totalUsers) * 100 : 0.0;
    final nonVotersPercentage = totalUsers > 0 ? (nonVoters / totalUsers) * 100 : 0.0;

    // Check if match is finished
    final isFinished = _match!.status == MatchStatus.finished;

    // Use the actual winner field from the match if it's finished
    String? winner;
    if (isFinished) {
      // Get the winner directly from the match data
      winner = _match!.winner;
    }

    return {
      'isFixedMatch': true,
      'team1': _match!.team1,
      'team2': _match!.team2,
      'team1Votes': team1Votes,
      'team2Votes': team2Votes,
      'nonVoters': nonVoters,
      'totalUsers': totalUsers,
      'team1Percentage': team1Percentage,
      'team2Percentage': team2Percentage,
      'nonVotersPercentage': nonVotersPercentage,
      'isFinished': isFinished,
      'winner': winner,
    };
  }

  // Calculate summary for variable matches
  Map<String, dynamic> _calculateVariableMatchSummary(List<VoteDetails> voteDetails) {
    if (_match == null) return _getEmptyVoteSummary();

    // Count votes for each team
    final team1Votes = voteDetails.where((v) => v.vote.vote == _match!.team1).length;
    final team2Votes = voteDetails.where((v) => v.vote.vote == _match!.team2).length;
    final totalVotes = team1Votes + team2Votes;

    // Calculate percentages based on total votes
    final team1Percentage = totalVotes > 0 ? (team1Votes / totalVotes) * 100 : 0.0;
    final team2Percentage = totalVotes > 0 ? (team2Votes / totalVotes) * 100 : 0.0;

    // Check if match is finished
    final isFinished = _match!.status == MatchStatus.finished;

    // Use the actual winner field from the match if it's finished
    String? winner;
    if (isFinished) {
      // Get the winner directly from the match data
      winner = _match!.winner;
    }

    return {
      'isFixedMatch': false,
      'team1': _match!.team1,
      'team2': _match!.team2,
      'team1Votes': team1Votes,
      'team2Votes': team2Votes,
      'nonVoters': 0,
      'totalVotes': totalVotes,
      'team1Percentage': team1Percentage,
      'team2Percentage': team2Percentage,
      'nonVotersPercentage': 0.0,
      'isFinished': isFinished,
      'winner': winner,
    };
  }

  // Empty vote summary for initialization
  Map<String, dynamic> _getEmptyVoteSummary() {
    return {
      'isFixedMatch': false,
      'team1': '',
      'team2': '',
      'team1Votes': 0,
      'team2Votes': 0,
      'nonVoters': 0,
      'totalVotes': 0,
      'team1Percentage': 0.0,
      'team2Percentage': 0.0,
      'nonVotersPercentage': 0.0,
      'isFinished': false,
      'winner': null,
    };
  }

  // Get section info for the votes list
  List<Map<String, dynamic>> getVotesSections() {
    if (_match == null) return [];

    final votes = processedVotes;
    final summary = voteSummary;

    final List<Map<String, dynamic>> sections = [];

    // Team 1 section
    if (summary['team1Votes'] > 0) {
      sections.add({
        'title': '${summary['team1']} (${summary['team1Votes']})',
        'color': Colors.blue[700],
        'type': 'team1',
      });
    }

    // Team 2 section
    if (summary['team2Votes'] > 0) {
      sections.add({
        'title': '${summary['team2']} (${summary['team2Votes']})',
        'color': Colors.orange[700],
        'type': 'team2',
      });
    }

    // Non-voters section (only for fixed matches)
    if (summary['isFixedMatch'] && summary['nonVoters'] > 0) {
      sections.add({
        'title': 'Did Not Vote (${summary['nonVoters']})',
        'color': Colors.grey[700],
        'type': 'nonVoter',
      });
    }

    return sections;
  }

  // Helper method to get vote type
  String getVoteType(VoteDetails voteDetails) {
    if (_match == null) return 'unknown';

    if (voteDetails.vote.status == 'no_vote') {
      return 'nonVoter';
    } else if (voteDetails.vote.vote == _match!.team1) {
      return 'team1';
    } else {
      return 'team2';
    }
  }

  // Helper method to get color for a vote
  Color getVoteColor(VoteDetails voteDetails) {
    final voteType = getVoteType(voteDetails);

    switch (voteType) {
      case 'team1':
        return Colors.blue;
      case 'team2':
        return Colors.orange;
      case 'nonVoter':
        return Colors.grey;
      default:
        return Colors.grey;
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