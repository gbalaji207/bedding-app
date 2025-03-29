// lib/screens/points/points_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/constants.dart';
import '../../viewmodels/user_points_view_model.dart';
import '../../repositories/user_points_repository.dart';

class PointsScreen extends StatefulWidget {
  const PointsScreen({Key? key}) : super(key: key);

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  @override
  void initState() {
    super.initState();
    // Load user points when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserPointsViewModel>(context, listen: false).loadUserPoints();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserPointsViewModel>(
      builder: (context, viewModel, child) {
        return Scaffold(
          body: _buildContent(viewModel),
        );
      },
    );
  }

  Widget _buildContent(UserPointsViewModel viewModel) {
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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => viewModel.loadUserPoints(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (viewModel.userPoints.isEmpty) {
      return const Center(
        child: Text('No user points data available'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.loadUserPoints(),
      child: _buildPointsListView(viewModel),
    );
  }

  Widget _buildPointsListView(UserPointsViewModel viewModel) {
    final rankedUsers = viewModel.getUserPointsWithRanks();

    return Column(
      children: [
        // Header with statistics cards
        _buildHeaderStatistics(rankedUsers),

        // Divider between header and list
        const Divider(thickness: 1),

        // List header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: const [
              SizedBox(
                  width: 40,
                  child: Text('Rank',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(width: 8),
              Expanded(
                  flex: 3,
                  child: Text('User',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              SizedBox(
                  width: 60,
                  child: Text('Points',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      textAlign: TextAlign.center)),
            ],
          ),
        ),

        // List of users
        Expanded(
          child: ListView.builder(
            itemCount: rankedUsers.length,
            itemBuilder: (context, index) {
              final user = rankedUsers[index];
              final rank = user['rank'];
              final isTopThree = rank <= 3;

              return Card(
                elevation: isTopThree ? 3 : 1,
                margin: EdgeInsets.symmetric(
                    horizontal: 8, vertical: isTopThree ? 4 : 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: isTopThree
                      ? BorderSide(color: _getRankColor(rank), width: 1.5)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () {
                    // Navigate to user point details screen
                    context.pushNamed(
                      AppRoutes.userPointDetailsName,
                      pathParameters: {'userId': user['id']},
                      extra: {'userName': user['displayName']},
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: _buildRankWidget(rank),
                      title: Text(
                        user['displayName'],
                        style: TextStyle(
                          fontWeight:
                              isTopThree ? FontWeight.bold : FontWeight.normal,
                          fontSize: isTopThree ? 16 : 14,
                        ),
                      ),
                      // Removed user role subtitle
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getPointsBackgroundColor(rank),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${user['totalPoints'].toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: isTopThree
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: Colors
                                .black87, // Always use dark text for better contrast
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderStatistics(List<Map<String, dynamic>> rankedUsers) {
    // Calculate total points in the system
    double totalPoints = 0.0;
    for (final user in rankedUsers) {
      totalPoints += (user['totalPoints'] as double? ?? 0.0);
    }

    // Get top 3 users for podium display
    final topUsers =
        rankedUsers.length >= 3 ? rankedUsers.sublist(0, 3) : rankedUsers;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        children: [
          // Title
          const Text(
            'Points Leaderboard',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${rankedUsers.length} users',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Podium for top 3
          if (rankedUsers.isNotEmpty) _buildPodium(topUsers),
        ],
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> topUsers) {
    // Make sure we have up to 3 users with placeholders
    while (topUsers.length < 3) {
      topUsers.add(
          {'displayName': '', 'totalPoints': 0, 'rank': topUsers.length + 1});
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2nd place
        _buildPodiumItem(topUsers[1], 2, 80),

        // 1st place
        _buildPodiumItem(topUsers[0], 1, 110),

        // 3rd place
        _buildPodiumItem(topUsers[2], 3, 60),
      ],
    );
  }

  Widget _buildPodiumItem(Map<String, dynamic> user, int rank, double height) {
    final bool isEmpty = user['displayName'].isEmpty;

    return Container(
      width: 90,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          // User name and points
          if (!isEmpty) ...[
            CircleAvatar(
              radius: rank == 1 ? 28 : 24,
              backgroundColor: _getRankColor(rank),
              child: Text(
                // Safely get the first character
                (user['displayName'] != null &&
                        user['displayName'].toString().isNotEmpty)
                    ? user['displayName']
                        .toString()
                        .substring(0, 1)
                        .toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user['displayName'],
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              '${user['totalPoints'].toStringAsFixed(2)} pts',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Podium stand
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: _getRankColor(rank),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for colors and styling
  Widget _buildRankWidget(int rank) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: _getRankColor(rank).withOpacity(rank <= 3 ? 1.0 : 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$rank',
          style: TextStyle(
            color: rank <= 3 ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber.shade600; // Gold
      case 2:
        return Colors.blueGrey.shade400; // Silver
      case 3:
        return Colors.brown.shade400; // Bronze
      default:
        return Colors.grey.shade400; // Others
    }
  }

  Color _getPointsBackgroundColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber.shade600; // Gold
      case 2:
        return Colors.blueGrey.shade400; // Silver
      case 3:
        return Colors.brown.shade400; // Bronze
      default:
        return Colors
            .grey.shade300; // Darker grey for better contrast with text
    }
  }
}
