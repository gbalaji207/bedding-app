// lib/screens/points/user_point_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/match_model.dart';
import '../../viewmodels/user_point_details_view_model.dart';
import '../../models/user_point_history_model.dart';

class UserPointDetailsScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const UserPointDetailsScreen({
    Key? key,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  State<UserPointDetailsScreen> createState() => _UserPointDetailsScreenState();
}

class _UserPointDetailsScreenState extends State<UserPointDetailsScreen> {
  @override
  void initState() {
    super.initState();
    // Load user point details when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserPointDetailsViewModel>(context, listen: false)
          .loadUserPointDetails();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}\'s Points'),
      ),
      body: Consumer<UserPointDetailsViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.userProfile == null) {
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
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => viewModel.loadUserPointDetails(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => viewModel.loadUserPointDetails(),
            child: _buildContent(viewModel),
          );
        },
      ),
    );
  }

  Widget _buildContent(UserPointDetailsViewModel viewModel) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // User header with avatar and stats
        _buildUserHeader(viewModel),

        const SizedBox(height: 24),

        // Stats cards
        _buildStatCards(viewModel),

        const SizedBox(height: 24),

        // Filter and sort options
        _buildFilterAndSortControls(viewModel),

        const SizedBox(height: 16),

        // Point history list
        ...viewModel.filteredHistory.isEmpty
            ? [_buildEmptyState(viewModel)]
            : viewModel.filteredHistory.map((item) => _buildHistoryItem(item)).toList(),
      ],
    );
  }

  Widget _buildUserHeader(UserPointDetailsViewModel viewModel) {
    final profile = viewModel.userProfile;
    final displayName = profile?.displayName ?? widget.userName;
    final userInitials = _getInitials(displayName);

    return Row(
      children: [
        // User avatar
        CircleAvatar(
          radius: 36,
          backgroundColor: Colors.blue,
          child: Text(
            userInitials,
            style: const TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),

        // User info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                  children: [
                    TextSpan(
                      text: viewModel.totalPoints.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(text: ' Points'),
                    if (viewModel.userRank > 0) ...[
                      const TextSpan(text: ' • Rank '),
                      TextSpan(
                        text: '#${viewModel.userRank}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getRankColor(viewModel.userRank),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCards(UserPointDetailsViewModel viewModel) {
    final stats = viewModel.stats;

    return Row(
      children: [
        // Matches count
        Expanded(
          child: _buildStatCard(
            '${stats['totalMatches'] ?? 0}',
            'Matches',
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),

        // Win rate
        Expanded(
          child: _buildStatCard(
            '${(stats['winRate'] ?? 0.0).toStringAsFixed(1)}%',
            'Win Rate',
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),

        // Average points
        Expanded(
          child: _buildStatCard(
            '${(stats['avgPoints'] ?? 0.0).toStringAsFixed(1)}',
            'Avg Pts',
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSortControls(UserPointDetailsViewModel viewModel) {
    return Row(
      children: [
        // Filter dropdown
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<FilterType>(
                  isExpanded: true,
                  value: viewModel.currentFilter,
                  items: [
                    DropdownMenuItem(
                      value: FilterType.all,
                      child: Text('All Matches (${viewModel.stats['totalMatches'] ?? 0})'),
                    ),
                    DropdownMenuItem(
                      value: FilterType.wins,
                      child: Text('Wins (${viewModel.stats['wonMatches'] ?? 0})'),
                    ),
                    DropdownMenuItem(
                      value: FilterType.losses,
                      child: Text('Losses (${viewModel.stats['lostMatches'] ?? 0})'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      viewModel.setFilter(value);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Sort dropdown
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<SortType>(
                  isExpanded: true,
                  value: viewModel.currentSort,
                  items: const [
                    DropdownMenuItem(
                      value: SortType.dateDesc,
                      child: Text('Recent First'),
                    ),
                    DropdownMenuItem(
                      value: SortType.dateAsc,
                      child: Text('Oldest First'),
                    ),
                    DropdownMenuItem(
                      value: SortType.pointsDesc,
                      child: Text('Highest Points'),
                    ),
                    DropdownMenuItem(
                      value: SortType.pointsAsc,
                      child: Text('Lowest Points'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      viewModel.setSort(value);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(UserPointDetailsViewModel viewModel) {
    String message;
    IconData icon;

    switch (viewModel.currentFilter) {
      case FilterType.wins:
        message = 'No winning matches found';
        icon = Icons.emoji_events;
        break;
      case FilterType.losses:
        message = 'No losing matches found';
        icon = Icons.sentiment_dissatisfied;
        break;
      case FilterType.all:
      default:
        message = 'No match history available';
        icon = Icons.sports_cricket;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(UserPointHistory item) {
    final bool isWin = item.isCorrectVote;
    final Color statusColor = isWin ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Match title with type and points indicator
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Match title with type
                Expanded(
                  child: Flexible(
                    child: Text(
                      '${item.matchTitle} - ${item.matchType == 'fixed' ? 'Fixed' : 'Variable'}',
                      // item.matchTitle + ' - ' + (item.matchType ?? '-'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Points indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isWin ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    isWin
                        ? '+${item.points.abs().toStringAsFixed(2)}'
                        : '${item.points.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Teams and vote/result info in a single row
            Row(
              children: [
                // Teams info
                Expanded(
                  child: Text(
                    '${item.team1} vs ${item.team2}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Vote info
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isWin ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.voteStatus,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Progress bar showing points
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: 1.0, // Always filled
              backgroundColor: Colors.grey[200],
              color: statusColor,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to get user initials
  String _getInitials(String name) {
    if (name.isEmpty) return '';

    final parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }

    if (name.length > 1) {
      return name.substring(0, 2).toUpperCase();
    }

    return name[0].toUpperCase();
  }

  // Helper to get color based on rank
  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber.shade600; // Gold
      case 2:
        return Colors.blueGrey.shade400; // Silver
      case 3:
        return Colors.brown.shade400; // Bronze
      default:
        return Colors.grey.shade700; // Others
    }
  }
}