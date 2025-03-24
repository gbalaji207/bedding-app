// lib/screens/voting/voting_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/match_model.dart';
import '../../models/vote_details_model.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoteDetailsViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
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
            _buildVoteSummary(viewModel),
            const SizedBox(height: 20),

            // Votes list
            _buildVotesList(viewModel),
          ],
        ),
      ),
    );
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

  Widget _buildVoteSummary(VoteDetailsViewModel viewModel) {
    final summary = viewModel.voteSummary;
    final isFixedMatch = summary['isFixedMatch'];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary['isFinished'] ? 'Voting Results' : 'Current Votes',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            if (isFixedMatch) _buildFixedMatchChart(summary) else _buildVariableMatchChart(summary),
            const SizedBox(height: 16),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(Colors.blue, summary['team1'], summary['team1Votes']),
                _buildLegendItem(Colors.orange, summary['team2'], summary['team2Votes']),
                if (isFixedMatch)
                  _buildLegendItem(Colors.grey, 'Did not vote', summary['nonVoters']),
              ],
            ),

            // Add winner indicator for finished matches
            if (summary['isFinished'] && summary['winner'] != null) ...[
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
                        'Winner: ${summary['winner']}',
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

  Widget _buildFixedMatchChart(Map<String, dynamic> summary) {
    final team1Votes = summary['team1Votes'];
    final team2Votes = summary['team2Votes'];
    final nonVoters = summary['nonVoters'];
    final team1Percentage = summary['team1Percentage'];
    final team2Percentage = summary['team2Percentage'];
    final nonVotersPercentage = summary['nonVotersPercentage'];

    return Row(
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

        // Non-voters
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
    );
  }

  Widget _buildVariableMatchChart(Map<String, dynamic> summary) {
    final team1Votes = summary['team1Votes'];
    final team2Votes = summary['team2Votes'];
    final team1Percentage = summary['team1Percentage'];
    final team2Percentage = summary['team2Percentage'];

    return Row(
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
    );
  }

  Widget _buildLegendItem(Color color, String label, int count) {
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
        Text('$label ($count)'),
      ],
    );
  }

  Widget _buildVotesList(VoteDetailsViewModel viewModel) {
    final processedVotes = viewModel.processedVotes;
    final match = viewModel.match!;

    if (processedVotes.isEmpty) {
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

    // Get sections for the list
    final sections = viewModel.getVotesSections();

    // Check if match is finished
    final bool isFinished = match.status == MatchStatus.finished;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First section header if available
        if (sections.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              sections[0]['title'],
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: sections[0]['color'],
              ),
            ),
          ),
        ],

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: processedVotes.length,
          separatorBuilder: (context, index) {
            if (index < processedVotes.length - 1) {
              final currentVote = processedVotes[index];
              final nextVote = processedVotes[index + 1];

              // Check if we're transitioning to a new section
              final currentType = viewModel.getVoteType(currentVote);
              final nextType = viewModel.getVoteType(nextVote);

              if (currentType != nextType) {
                // Find the section for this transition
                final nextSection = sections.firstWhere(
                      (section) => section['type'] == nextType,
                  orElse: () => {'title': '', 'color': Colors.grey},
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(thickness: 1.5),
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                      child: Text(
                        nextSection['title'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: nextSection['color'],
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
            final voteDetails = processedVotes[index];
            final bool isNonVoter = voteDetails.vote.status == 'no_vote';
            final voteColor = viewModel.getVoteColor(voteDetails);

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
                ? '+${points is int ? points : points.toStringAsFixed(1)}'
                : '${points is int ? points : points.toStringAsFixed(1)}',
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