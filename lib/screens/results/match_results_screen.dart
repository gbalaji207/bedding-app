// lib/screens/results/match_results_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../models/match_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/vote_repository.dart';
import '../../utils/constants.dart';
import '../../viewmodels/vote_details_view_model.dart';
import '../../models/vote_model.dart';

class MatchResultsScreen extends StatefulWidget {
  const MatchResultsScreen({Key? key}) : super(key: key);

  @override
  State<MatchResultsScreen> createState() => _MatchResultsScreenState();
}

class _MatchResultsScreenState extends State<MatchResultsScreen> {
  List<Match> _pastMatches = [];
  Map<String, Vote> _userVotes = {}; // matchId -> Vote object
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPastMatches();
  }

  Future<void> _loadPastMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final matchRepository =
      Provider.of<MatchRepository>(context, listen: false);
      final voteRepository =
      Provider.of<VoteRepository>(context, listen: false);
      final appState = Provider.of<AppState>(context, listen: false);

      // Get past matches directly from the database
      _pastMatches = await matchRepository.getPastMatches();

      // Load user votes if user is logged in
      if (appState.user != null) {
        final votes = await voteRepository.getUserVotes(appState.user!.id);

        // Create a map of matchId -> Vote object
        _userVotes = {for (var vote in votes) vote.matchId: vote};
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadPastMatches,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: $_errorMessage',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPastMatches,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_pastMatches.isEmpty) {
      return const Center(
        child: Text('No past matches found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _pastMatches.length,
      itemBuilder: (context, index) {
        final match = _pastMatches[index];
        return _buildMatchCard(context, match);
      },
    );
  }

  Widget _buildMatchCard(BuildContext context, Match match) {
    // Check if user voted for this match
    final vote = _userVotes[match.id];
    final hasVoted = vote != null;
    final userVote = hasVoted ? vote!.vote : null;

    // Check if match is finished
    final isFinished = match.status == MatchStatus.finished;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: InkWell(
        onTap: () {
          // Navigate to voting details screen to see results
          context.push(AppRoutes.buildVotingDetailsPath(match.id));
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title with match type
              Text(
                '${match.title} - ${match.type == MatchType.fixed
                    ? 'Fixed'
                    : 'Variable'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Team vs Team
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                        // Highlight the team if user voted for it
                        border: Border.all(
                          color: hasVoted && vote!.vote == match.team1
                              ? Colors.blue
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        match.team1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: hasVoted && vote!.vote == match.team1
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                        // Highlight the team if user voted for it
                        border: Border.all(
                          color: hasVoted && vote!.vote == match.team2
                              ? Colors.orange
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        match.team2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: hasVoted && vote!.vote == match.team2
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom row with vote info and points
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Show voted team if user casted a vote (align right)
                  if (hasVoted)
                    Chip(
                      label: Text('You voted: ${vote!.vote}'),
                      backgroundColor: vote.vote == match.team1
                          ? Colors.blue.shade100
                          : Colors.orange.shade100,
                      labelStyle: TextStyle(
                        color: vote.vote == match.team1
                            ? Colors.blue.shade800
                            : Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  // Show points if match is finished and user voted
                  if (isFinished && hasVoted)
                    _buildPointsIndicator(match, userVote),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPointsIndicator(Match match, String? userVote) {
    // Get the vote object for this match
    final vote = _userVotes[match.id];
    if (vote == null) return const SizedBox();

    // Get the vote status and points from the Vote object
    final wonVote = vote.status == 'won';
    final points = vote.points;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: wonVote ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: wonVote ? Colors.green : Colors.red,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            wonVote ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: wonVote ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            // Display actual points with decimal places if needed
            wonVote ? '+${points is int ? points : points.toStringAsFixed(2)}' : '${points is int ? points : points.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: wonVote ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
