// lib/screens/voting/voting_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../models/match_model.dart';
import '../../models/vote_model.dart';
import '../../providers/auth_provider.dart';
import '../../viewmodels/vote_view_model.dart';
import '../../utils/constants.dart';

class VotingScreen extends StatefulWidget {
  const VotingScreen({Key? key}) : super(key: key);

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  @override
  void initState() {
    super.initState();
    // Load future matches and user votes when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
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

    if (voteViewModel.futureMatches.isEmpty) {
      return const Center(
        child: Text('No upcoming matches found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: voteViewModel.futureMatches.length,
      itemBuilder: (context, index) {
        final match = voteViewModel.futureMatches[index];
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

    // Check if voting is closed (match starts in less than 30 mins)
    final now = DateTime.now();
    final cutoffTime = match.startDate.subtract(const Duration(minutes: 30));
    final votingClosed = now.isAfter(cutoffTime);

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
          // Check if voting is closed
          if (votingClosed) {
            // If voting is closed, show voting details
            context.push(AppRoutes.buildVotingDetailsPath(match.id));
          } else {
            // If voting is still open, show voting options
            _showVotingBottomSheet(context, match, voteViewModel, appState);
          }
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
              // Add a hint for users based on match time
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    votingClosed
                        ? 'Tap to see voting results'
                        : 'Tap to vote for a team',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
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
    // Default selected team (null means nothing selected yet)
    String? selectedTeam;

    // If user already voted, pre-select that team
    if (voteViewModel.hasVotedForMatch(match.id)) {
      selectedTeam = voteViewModel.getVoteForMatch(match.id)!.vote;
    }

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

                          // Show loading indicator
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Saving your vote...'),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          // Save vote
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