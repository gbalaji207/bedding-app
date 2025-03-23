// lib/screens/voting/voting_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/match_model.dart';
import '../../models/vote_details_model.dart';
import '../../models/user_profile.dart';
import '../../models/vote_model.dart';
import '../../viewmodels/vote_details_view_model.dart';

class VotingDetailsScreen extends StatefulWidget {
  final String matchId;

  const VotingDetailsScreen({
    Key? key,
    required this.matchId,
  }) : super(key: key);

  @override
  State<VotingDetailsScreen> createState() => _VotingDetailsScreenState();
}

class _VotingDetailsScreenState extends State<VotingDetailsScreen> {
  // State variable to track all users for fixed matches
  List<UserProfile> _allUsers = [];
  bool _isLoadingUsers = false;

  @override
  void initState() {
    super.initState();
    // Load match and votes when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final viewModel = Provider.of<VoteDetailsViewModel>(context, listen: false);
    await viewModel.loadMatch(widget.matchId);
    await viewModel.loadMatchVotes(widget.matchId);

    // For fixed matches, load all users
    if (viewModel.match?.type == MatchType.fixed) {
      await _loadAllUsers();
    }
  }

  // Method to load all users from the database
  Future<void> _loadAllUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    try {
      final viewModel =
          Provider.of<VoteDetailsViewModel>(context, listen: false);
      // Use the viewModel to fetch all users
      _allUsers = await viewModel.getAllUsers();
    } catch (e) {
      debugPrint('Error loading all users: $e');
    } finally {
      setState(() {
        _isLoadingUsers = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoteDetailsViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading || _isLoadingUsers) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (viewModel.errorMessage.isNotEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error: ${viewModel.errorMessage}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (viewModel.match == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Match Not Found')),
            body: const Center(child: Text('Match not found')),
          );
        }

        // Check if voting is closed using the Match model
        final match = viewModel.match!;
        final votingClosed = match.isVotingClosed();

        // If voting hasn't closed yet, show a message and navigation back
        if (!votingClosed) {
          return Scaffold(
            appBar: AppBar(
              title: Text(match.title),
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.watch_later_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Voting Details Not Available Yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Voting details will be visible once voting closes at ${DateFormat('MMM dd, yyyy - h:mm a').format(match.votingCutoffTime)}',
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(votingClosed
                ? '${match.title} - Results'
                : '${match.title} - Voting Details'),
            elevation: 0,
          ),
          body: _buildContent(viewModel),
        );
      },
    );
  }

  Widget _buildContent(VoteDetailsViewModel viewModel) {
    final match = viewModel.match!;
    final votes = viewModel.voteDetails;
    final isFixedMatch = match.type == MatchType.fixed;

    // For fixed matches, we need to consider all users
    // For variable matches, we only consider users who voted but still sort them
    final List<VoteDetails> effectiveVotes = isFixedMatch
        ? _getEffectiveVotesForFixedMatch(votes, match)
        : _sortVotesForVariableMatch(votes, match);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Match details
            _buildMatchHeader(match),
            const SizedBox(height: 24),

            // Vote summary
            _buildVoteSummary(match, viewModel.voteDetails),
            const SizedBox(height: 20),

            // Votes list
            _buildVotesList(match, effectiveVotes),
          ],
        ),
      ),
    );
  }

  // Helper method to create effective votes list for fixed matches (including non-voters)
  List<VoteDetails> _getEffectiveVotesForFixedMatch(
      List<VoteDetails> actualVotes, Match match) {
    // Create a map of userId -> VoteDetails to check if a user has voted
    final Map<String, VoteDetails> votesByUserId = {
      for (var vote in actualVotes) vote.vote.userId: vote
    };

    // Create a list of "virtual" votes for users who didn't vote
    final List<VoteDetails> allVotes = List.from(actualVotes);

    // Add entries for users who didn't vote
    for (var user in _allUsers) {
      if (!votesByUserId.containsKey(user.id)) {
        // Create a "non-vote" entry
        allVotes.add(
          VoteDetails(
            vote: Vote(
              id: 'no-vote-${user.id}',
              userId: user.id,
              matchId: match.id,
              vote: 'Did not vote',
              status: 'non-voter',
            ),
            userProfile: user,
          ),
        );
      }
    }

    // Sort the list:
    // 1. Team1 voters first
    // 2. Team2 voters second
    // 3. Non-voters last
    // 4. Within each group, sort alphabetically by display name
    final team1 = match.team1;
    final team2 = match.team2;

    allVotes.sort((a, b) {
      // First determine category for each vote (team1, team2, or non-voter)
      int getCategoryValue(VoteDetails vote) {
        if (vote.vote.status == 'non-voter') return 2; // Non-voters last
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

    return allVotes;
  }

  // Helper method to sort votes for variable matches (team1 then team2)
  List<VoteDetails> _sortVotesForVariableMatch(
      List<VoteDetails> votes, Match match) {
    final team1 = match.team1;
    final sortedVotes = List<VoteDetails>.from(votes);

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

  Widget _buildMatchHeader(Match match) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          '${match.team1} vs ${match.team2}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Match type
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            match.type == MatchType.fixed ? 'Fixed Match' : 'Variable Match',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Match date
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              match.formattedStartDate,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVoteSummary(Match match, List<VoteDetails> voteDetails) {
    // Count votes for each team and non-voters based on vote status
    final team1Votes = voteDetails.where((v) => v.vote.vote == match.team1).length;
    final team2Votes = voteDetails.where((v) => v.vote.vote == match.team2).length;
    final nonVoters = voteDetails.where((v) => v.vote.status == 'no_vote').length;

    // Calculate totals based on match type
    final totalVoters = team1Votes + team2Votes;
    final totalUsers = totalVoters + nonVoters;

    // Calculate percentages based on total users (for fixed matches) or total votes (for variable)
    final denominatorForPercentage = match.type == MatchType.fixed ? totalUsers : totalVoters;

    final team1Percentage = denominatorForPercentage > 0
        ? (team1Votes / denominatorForPercentage) * 100
        : 0.0;
    final team2Percentage = denominatorForPercentage > 0
        ? (team2Votes / denominatorForPercentage) * 100
        : 0.0;
    final nonVotersPercentage = denominatorForPercentage > 0
        ? (nonVoters / denominatorForPercentage) * 100
        : 0.0;

    // Check if match has started to adjust the UI
    final now = DateTime.now();
    final matchHasStarted = now.isAfter(match.startDate);
    final isFinished = match.status == MatchStatus.finished;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              matchHasStarted ? 'Voting Results' : 'Current Votes',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Show different chart for fixed vs variable matches
            if (match.type == MatchType.fixed) ...[
              // For fixed matches, show a chart that includes non-voters
              Row(
                children: [
                  // Team 1
                  Expanded(
                    flex: team1Votes > 0 ? team1Votes : 1,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.horizontal(
                          left: const Radius.circular(4),
                          right: team2Votes == 0 && nonVoters == 0
                              ? const Radius.circular(4)
                              : Radius.zero,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: team1Percentage >= 15
                          ? Text(
                        '${team1Percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                          : const SizedBox(),
                    ),
                  ),

                  // Team 2
                  Expanded(
                    flex: team2Votes > 0 ? team2Votes : 1,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.horizontal(
                          right: nonVoters == 0 ? const Radius.circular(4) : Radius.zero,
                          left: team1Votes == 0 ? const Radius.circular(4) : Radius.zero,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: team2Percentage >= 15
                          ? Text(
                        '${team2Percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                          : const SizedBox(),
                    ),
                  ),

                  // Non-voters (only for fixed matches)
                  Expanded(
                    flex: nonVoters > 0 ? nonVoters : 1,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.horizontal(
                          right: const Radius.circular(4),
                          left: team1Votes == 0 && team2Votes == 0
                              ? const Radius.circular(4)
                              : Radius.zero,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: nonVotersPercentage >= 15
                          ? Text(
                        '${nonVotersPercentage.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                          : const SizedBox(),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // For variable matches, show the original chart (only voters)
              Row(
                children: [
                  // Team 1
                  Expanded(
                    flex: team1Votes > 0 ? team1Votes : 1,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.horizontal(
                          left: const Radius.circular(4),
                          right: team2Votes == 0 ? const Radius.circular(4) : Radius.zero,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: team1Percentage >= 25
                          ? Text(
                        '${team1Percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                          : const SizedBox(),
                    ),
                  ),

                  // Team 2
                  Expanded(
                    flex: team2Votes > 0 ? team2Votes : 1,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.horizontal(
                          right: const Radius.circular(4),
                          left: team1Votes == 0 ? const Radius.circular(4) : Radius.zero,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: team2Percentage >= 25
                          ? Text(
                        '${team2Percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                          : const SizedBox(),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Legend
            if (match.type == MatchType.fixed) ...[
              // Legend for fixed matches (includes non-voters)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem(Colors.blue, match.team1, team1Votes),
                  _buildLegendItem(Colors.orange, match.team2, team2Votes),
                  _buildLegendItem(Colors.grey, 'Did not vote', nonVoters),
                ],
              ),
            ] else ...[
              // Legend for variable matches
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem(Colors.blue, match.team1, team1Votes),
                  _buildLegendItem(Colors.orange, match.team2, team2Votes),
                ],
              ),
            ],

            // Add winner indicator for finished matches
            if (isFinished) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Winner: ${team1Votes > team2Votes ? match.team1 : match.team2}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String team, int votes) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text('$team ($votes)'),
      ],
    );
  }

  Widget _buildVotesList(Match match, List<VoteDetails> effectiveVotes) {
    if (effectiveVotes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No votes yet for this match',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    // Check if match is finished to show points
    final bool isFinished = match.status == MatchStatus.finished;

    // Sort votes: Team1 first, Team2 second, Non-voters last
    // Within each category, sort alphabetically
    final sortedVotes = List<VoteDetails>.from(effectiveVotes);
    sortedVotes.sort((a, b) {
      // Determine the sorting category
      int getCategoryValue(VoteDetails vote) {
        if (vote.vote.status == 'no_vote') return 2; // Non-voters last
        if (vote.vote.vote == match.team1) return 0; // Team1 first
        return 1; // Team2 second
      }

      final aCat = getCategoryValue(a);
      final bCat = getCategoryValue(b);

      // If categories differ, sort by category
      if (aCat != bCat) return aCat.compareTo(bCat);

      // Within same category, sort alphabetically
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    // Count votes for section headers
    final team1Votes =
        sortedVotes.where((v) => v.vote.vote == match.team1).length;
    final team2Votes =
        sortedVotes.where((v) => v.vote.vote == match.team2).length;
    final nonVoterCount =
        sortedVotes.where((v) => v.vote.status == 'no_vote').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First section header for Team 1
        if (team1Votes > 0) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              '${match.team1} ($team1Votes)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.blue[700],
              ),
            ),
          ),
        ],

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedVotes.length,
          separatorBuilder: (context, index) {
            if (index < sortedVotes.length - 1) {
              // Check for section transitions
              final currentVote = sortedVotes[index];
              final nextVote = sortedVotes[index + 1];

              // Transition from Team 1 to Team 2
              if (currentVote.vote.vote == match.team1 &&
                  nextVote.vote.vote == match.team2) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(thickness: 1.5),
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                      child: Text(
                        '${match.team2} ($team2Votes)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                );
              }

              // Transition to Non-voters
              if (nextVote.vote.status == 'no_vote' &&
                  currentVote.vote.status != 'no_vote') {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(thickness: 1.5),
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                      child: Text(
                        'Did Not Vote ($nonVoterCount)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                );
              }
            }

            // Regular divider
            return const Divider();
          },
          itemBuilder: (context, index) {
            final voteDetails = sortedVotes[index];
            final bool isNonVoter = voteDetails.vote.status == 'no_vote';

            // Set color based on vote
            Color voteColor;
            if (isNonVoter) {
              voteColor = Colors.grey;
            } else if (voteDetails.vote.vote == match.team1) {
              voteColor = Colors.blue;
            } else {
              voteColor = Colors.orange;
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: voteColor,
                child: Text(
                  voteDetails.displayName.isNotEmpty
                      ? voteDetails.displayName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(voteDetails.displayName),
              subtitle: Text(isNonVoter
                  ? 'Did not vote'
                  : 'Voted: ${voteDetails.vote.vote}'),

              // Display points for all users when match is finished
              trailing: isFinished
                  ? _buildPointsIndicator(voteDetails.vote)
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: voteColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isNonVoter ? 'No Vote' : voteDetails.vote.vote,
                        style: TextStyle(
                          color: voteColor.withOpacity(0.8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            );
          },
        ),
      ],
    );
  }

// Helper widget to display points for each user
  Widget _buildPointsIndicator(Vote vote) {
    final bool wonVote = vote.status == 'won';
    final bool isNonVoter = vote.status == 'no_vote';
    final points = vote.points;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        // Non-voters and lost votes get red background, won votes get green
        color: (isNonVoter || !wonVote)
            ? Colors.red.shade100
            : Colors.green.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isNonVoter || !wonVote) ? Colors.red : Colors.green,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            (isNonVoter || !wonVote) ? Icons.cancel : Icons.check_circle,
            size: 14,
            color: (isNonVoter || !wonVote) ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            // Format points with decimal places as needed
            wonVote
                ? '+${points is int ? points : points.toStringAsFixed(2)}'
                : '${points is int ? points : points.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: (isNonVoter || !wonVote)
                  ? Colors.red.shade800
                  : Colors.green.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
