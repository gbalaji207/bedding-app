// lib/screens/voting/voting_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/match_model.dart';
import '../../models/vote_details_model.dart';
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
          return const Center(child: CircularProgressIndicator());
        }

        if (viewModel.errorMessage.isNotEmpty) {
          return Center(
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
          );
        }

        if (viewModel.match == null) {
          return const Center(child: Text('Match not found'));
        }

        // Check if voting is closed using the Match model
        final match = viewModel.match!;
        final votingClosed = match.isVotingClosed();

        // If voting hasn't closed yet, show a message and navigation back
        if (!votingClosed) {
          return Scaffold(
            appBar: AppBar(
              title: Text('${match.title}'),
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

    // Count votes for each team
    final team1Votes = votes.where((v) => v.vote.vote == match.team1).length;
    final team2Votes = votes.where((v) => v.vote.vote == match.team2).length;

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
            _buildVoteSummary(match, team1Votes, team2Votes),
            const SizedBox(height: 20),

            // Votes list
            _buildVotesList(viewModel, match),
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

  Widget _buildVoteSummary(Match match, int team1Votes, int team2Votes) {
    final totalVotes = team1Votes + team2Votes;
    final team1Percentage = totalVotes > 0 ? (team1Votes / totalVotes) * 100 : 0.0;
    final team2Percentage = totalVotes > 0 ? (team2Votes / totalVotes) * 100 : 0.0;

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
            const SizedBox(height: 16),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(Colors.blue, match.team1, team1Votes),
                _buildLegendItem(Colors.orange, match.team2, team2Votes),
              ],
            ),

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
        Text('$team ($votes votes)'),
      ],
    );
  }

  Widget _buildVotesList(VoteDetailsViewModel viewModel, Match match) {
    final votes = viewModel.voteDetails;

    if (votes.isEmpty) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Votes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: votes.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final voteDetails = votes[index];
            final isTeam1 = voteDetails.vote.vote == match.team1;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isTeam1 ? Colors.blue : Colors.orange,
                child: Text(
                  voteDetails.displayName.isNotEmpty
                      ? voteDetails.displayName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(voteDetails.displayName),
              subtitle: Text('Voted: ${voteDetails.vote.vote}'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isTeam1 ? Colors.blue.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  voteDetails.vote.vote,
                  style: TextStyle(
                    color: isTeam1 ? Colors.blue.shade800 : Colors.orange.shade800,
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
}