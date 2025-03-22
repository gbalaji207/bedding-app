// lib/screens/voting/voting_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'dart:async'; // For timer functionality

import '../../models/match_model.dart';
import '../../models/vote_model.dart';
import '../../providers/auth_provider.dart';
import '../../viewmodels/vote_view_model.dart';
import '../../utils/constants.dart';
import '../../utils/date_helpers.dart';

class VotingScreen extends StatefulWidget {
  const VotingScreen({Key? key}) : super(key: key);

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  // Timer to periodically check for cutoff times
  Timer? _cutoffTimer;

  @override
  void initState() {
    super.initState();
    // Load future matches and user votes when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();

      // Set up a timer to refresh the view every minute to account for cutoff times
      _cutoffTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        if (mounted) {
          setState(() {
            // Just trigger a rebuild to evaluate cutoff times
            debugPrint('Timer triggered rebuild to check for cutoff times');
          });
        }
      });
    });
  }

  @override
  void dispose() {
    // Cancel the timer when the screen is disposed
    _cutoffTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final voteViewModel = Provider.of<VoteViewModel>(context, listen: false);
    final appState = Provider.of<AppState>(context, listen: false);

    // Make sure user is logged in
    if (appState.user != null) {
      await voteViewModel.loadFutureMatches();
      await voteViewModel.loadUserVotes(appState.user!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voteViewModel = Provider.of<VoteViewModel>(context);
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _buildContent(voteViewModel, appState),
      ),
    );
  }

  Widget _buildContent(VoteViewModel voteViewModel, AppState appState) {
    if (voteViewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (voteViewModel.errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: ${voteViewModel.errorMessage}',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Get only matches that are still open for voting
    // Re-evaluate isVotingClosed each time to account for time passing
    final votableMatches = voteViewModel.allFutureMatches
        .where((match) => !match.isVotingClosed())
        .toList();

    if (votableMatches.isEmpty) {
      // Check if there are any future matches at all
      if (voteViewModel.allFutureMatches.isEmpty) {
        return const Center(
          child: Text('No upcoming matches found'),
        );
      } else {
        // There are future matches, but voting is closed for all of them
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No matches available for voting',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'All upcoming matches are within 30 minutes of starting.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  context.pushNamed(AppRoutes.resultsName);
                },
                icon: const Icon(Icons.scoreboard),
                label: const Text('View Match Results'),
              ),
            ],
          ),
        );
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: votableMatches.length,
      itemBuilder: (context, index) {
        final match = votableMatches[index];
        return _buildMatchCard(context, match, voteViewModel, appState);
      },
    );
  }

  Widget _buildMatchCard(
      BuildContext context,
      Match match,
      VoteViewModel voteViewModel,
      AppState appState,
      ) {
    // Check if user has already voted for this match
    final hasVoted = voteViewModel.hasVotedForMatch(match.id);
    final userVote = voteViewModel.getVoteForMatch(match.id);

    // Calculate time remaining until cutoff
    final Duration timeUntilCutoff = match.timeUntilVotingCloses;
    final bool closeToCutoff = timeUntilCutoff.inHours < 2;

    // Determine the color for each team based on the user's vote
    Color team1Color = Colors.grey.shade200;
    Color team2Color = Colors.grey.shade200;

    if (hasVoted) {
      if (userVote!.vote == match.team1) {
        team1Color = Colors.blue.shade100;
      } else {
        team2Color = Colors.blue.shade100;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: InkWell(
        onTap: () {
          // Real-time check for cutoff time
          if (match.isVotingClosed()) {
            // If the match has crossed the cutoff time since the screen loaded
            // Show a message and redirect to the voting details
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Voting is now closed for this match.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );

            // Navigate to voting details
            context.push(AppRoutes.buildVotingDetailsPath(match.id));
            return;
          }

          // Show voting options
          _showVotingBottomSheet(context, match, voteViewModel, appState);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${match.title} - ${match.type == MatchType.fixed ? 'Fixed' : 'Variable'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // If user has already voted, show delete option
                  if (hasVoted)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _showDeleteVoteConfirmation(context, match, voteViewModel, appState),
                      tooltip: 'Delete Vote',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: team1Color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasVoted && userVote!.vote == match.team1
                              ? Colors.blue
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        match.team1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: hasVoted && userVote!.vote == match.team1
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
                        color: team2Color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasVoted && userVote!.vote == match.team2
                              ? Colors.blue
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        match.team2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: hasVoted && userVote!.vote == match.team2
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy - h:mm a').format(match.startDate),
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                  _buildVoteStatus(hasVoted, userVote),
                ],
              ),

              // Countdown timer or voting status message
              const SizedBox(height: 8),
              if (closeToCutoff)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer, size: 14, color: Colors.amber.shade800),
                      const SizedBox(width: 4),
                      Text(
                        timeUntilCutoff.inMinutes > 60
                            ? 'Voting closes in ${timeUntilCutoff.inHours}h ${timeUntilCutoff.inMinutes % 60}m'
                            : 'Voting closes in ${timeUntilCutoff.inMinutes}m',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoteStatus(bool hasVoted, Vote? vote) {
    if (!hasVoted || vote == null) {
      return const Chip(
        label: Text('Vote Now'),
        backgroundColor: Colors.amber,
      );
    }

    return Chip(
      label: Text('Voted: ${vote.vote}'),
      backgroundColor: Colors.green.shade100,
    );
  }

  void _showDeleteVoteConfirmation(
      BuildContext context,
      Match match,
      VoteViewModel voteViewModel,
      AppState appState,
      ) {
    // Real-time check for cutoff time
    if (match.isVotingClosed()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voting is now closed for this match. You cannot delete your vote.'),
          backgroundColor: Colors.red,
        ),
      );

      // If the cutoff time has passed, redirect to the voting details screen
      context.push(AppRoutes.buildVotingDetailsPath(match.id));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vote'),
        content: Text('Are you sure you want to delete your vote for ${match.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              // Check for cutoff one more time before proceeding
              if (match.isVotingClosed()) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Voting period has ended. Your vote cannot be deleted now.'),
                      backgroundColor: Colors.red,
                    ),
                  );

                  // Redirect to voting details
                  context.push(AppRoutes.buildVotingDetailsPath(match.id));
                }
                return;
              }

              final vote = voteViewModel.getVoteForMatch(match.id);
              if (vote != null) {
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Deleting your vote...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                try {
                  // Delete vote
                  await voteViewModel.deleteVote(vote.id);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vote deleted successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete vote: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showVotingBottomSheet(
      BuildContext context,
      Match match,
      VoteViewModel voteViewModel,
      AppState appState,
      ) {
    debugPrint("_showVotingBottomSheet - isVotingClosed: ${match.isVotingClosed()}");
    // Real-time check for cutoff time when voting dialog opens
    if (match.isVotingClosed()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voting is now closed for this match.'),
          backgroundColor: Colors.red,
        ),
      );

      // Navigate to voting details instead
      context.push(AppRoutes.buildVotingDetailsPath(match.id));
      return;
    }

    // Default selected team (null means nothing selected yet)
    String? selectedTeam;

    // If user already voted, pre-select that team
    if (voteViewModel.hasVotedForMatch(match.id)) {
      selectedTeam = voteViewModel.getVoteForMatch(match.id)!.vote;
    }

    // Timestamp when the sheet is shown - to later calculate if too much time has passed
    final sheetOpenedTime = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Vote for ${match.title}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),

                  // Show the cutoff time
                  Text(
                    'Voting closes at ${DateFormat('h:mm a').format(match.votingCutoffTime)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Select a team to vote:',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),

                  // Team 1 Option
                  RadioListTile<String>(
                    title: Text(match.team1),
                    value: match.team1,
                    groupValue: selectedTeam,
                    onChanged: (value) {
                      setState(() {
                        selectedTeam = value;
                      });
                    },
                  ),

                  // Team 2 Option
                  RadioListTile<String>(
                    title: Text(match.team2),
                    value: match.team2,
                    groupValue: selectedTeam,
                    onChanged: (value) {
                      setState(() {
                        selectedTeam = value;
                      });
                    },
                  ),

                  const SizedBox(height: 16),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: selectedTeam == null
                            ? null
                            : () async {
                          Navigator.pop(context);

                          // Multiple safeguards against voting after cutoff

                          // 1. Check if the match is now closed
                          if (match.isVotingClosed()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Voting period has ended while you were selecting. Your vote was not saved.'),
                                backgroundColor: Colors.red,
                              ),
                            );

                            // Redirect to voting details
                            context.push(AppRoutes.buildVotingDetailsPath(match.id));
                            return;
                          }

                          // 2. Check if too much time has passed since the sheet was opened
                          final timeElapsed = DateTime.now().difference(sheetOpenedTime);
                          if (timeElapsed > const Duration(minutes: 5)) {
                            // If more than 5 minutes passed, do another check to be safe
                            if (match.isVotingClosed()) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Voting session timed out. Please try again.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                          }

                          // Show loading indicator
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Saving your vote...'),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          // Save vote - the ViewModel will do a final cutoff check
                          final success = await voteViewModel.saveVote(
                            appState.user!.id,
                            match.id,
                            selectedTeam!,
                          );

                          // Show result
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Vote saved successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );

                            // Force reload to refresh the UI
                            _loadData();
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to save vote: ${voteViewModel.errorMessage}',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text('Save Vote'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}