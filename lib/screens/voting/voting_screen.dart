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
      padding: const EdgeInsets.all(16.0),
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
    Color team1Color = Colors.grey.shade100;
    Color team2Color = Colors.grey.shade100;
    Color team1BorderColor = Colors.transparent;
    Color team2BorderColor = Colors.transparent;

    if (hasVoted) {
      if (userVote!.vote == match.team1) {
        team1Color = Colors.blue.shade50;
        team1BorderColor = Colors.blue;
      } else {
        team2Color = Colors.orange.shade50;
        team2BorderColor = Colors.orange;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
              // Match title and timer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${match.title} - ${match.type == MatchType.fixed ? 'Fixed' : 'Variable'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (closeToCutoff)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer, size: 12, color: Colors.amber.shade800),
                          const SizedBox(width: 4),
                          Text(
                            timeUntilCutoff.inMinutes > 60
                                ? '${timeUntilCutoff.inHours}h ${timeUntilCutoff.inMinutes % 60}m'
                                : '${timeUntilCutoff.inMinutes}m',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Teams
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: team1Color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: team1BorderColor,
                          width: team1BorderColor != Colors.transparent ? 2 : 1,
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
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: team2Color,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: team2BorderColor,
                          width: team2BorderColor != Colors.transparent ? 2 : 1,
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
              const SizedBox(height: 16),

              // Match date and vote status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMM dd, yyyy - h:mm a').format(match.startDate),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  _buildVoteStatusChip(hasVoted, userVote),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoteStatusChip(bool hasVoted, Vote? vote) {
    if (!hasVoted || vote == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Vote Now',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    final isTeam1 = true; // You need to determine if vote is for team1
    final color = isTeam1 ? Colors.blue.shade100 : Colors.orange.shade100;
    final textColor = isTeam1 ? Colors.blue.shade800 : Colors.orange.shade800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTeam1 ? Colors.blue.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Text(
        'Voted: ${vote.vote}',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 24,
                right: 24,
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
                  const SizedBox(height: 8),

                  // Show the cutoff time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Voting closes at ${DateFormat('h:mm a').format(match.votingCutoffTime)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Select a team to vote:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),

                  // Team 1 Option - Custom radio button style
                  _buildTeamSelectionTile(
                    context,
                    match.team1,
                    match.team1 == selectedTeam,
                        () {
                      setState(() {
                        selectedTeam = match.team1;
                      });
                    },
                    Colors.blue,
                  ),

                  const SizedBox(height: 12),

                  // Team 2 Option - Custom radio button style
                  _buildTeamSelectionTile(
                    context,
                    match.team2,
                    match.team2 == selectedTeam,
                        () {
                      setState(() {
                        selectedTeam = match.team2;
                      });
                    },
                    Colors.orange,
                  ),

                  const SizedBox(height: 32),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
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
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: Theme.of(context).primaryColor,
                          ),
                          child: const Text('Save Vote'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeamSelectionTile(
      BuildContext context,
      String teamName,
      bool isSelected,
      VoidCallback onTap,
      Color accentColor,
      ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor : Colors.white,
                border: Border.all(
                  color: isSelected ? accentColor : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                Icons.check,
                size: 16,
                color: Colors.white,
              )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              teamName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? accentColor : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}