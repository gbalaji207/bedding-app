// lib/screens/matches/matches_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../models/match_model.dart';
import '../../utils/constants.dart';
import '../../providers/auth_provider.dart';
import '../../viewmodels/match_view_model.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({Key? key}) : super(key: key);

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch matches when the screen is first loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MatchViewModel>(context, listen: false).fetchMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<MatchViewModel>(context);
    final authProvider = Provider.of<AppState>(context, listen: false);
    final isAdmin = authProvider.userRole ==
        'admin'; // Assuming userRole is available in AppState

    return Scaffold(
      body: _buildBody(viewModel),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
        onPressed: () => context.pushNamed(AppRoutes.matchFormName),
        child: const Icon(Icons.add),
        tooltip: 'Add Match',
      )
          : null,
    );
  }

  Widget _buildBody(MatchViewModel viewModel) {
    switch (viewModel.status) {
      case LoadingStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadingStatus.error:
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
                onPressed: () => viewModel.fetchMatches(),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      case LoadingStatus.loaded:
        if (viewModel.matches.isEmpty) {
          return const Center(child: Text('No matches found'));
        }
        return RefreshIndicator(
          onRefresh: () => viewModel.fetchMatches(),
          child: ListView.builder(
            itemCount: viewModel.matches.length,
            itemBuilder: (context, index) {
              return _buildMatchCard(context, viewModel.matches[index]);
            },
          ),
        );
      default:
        return const Center(child: Text('Pull down to load matches'));
    }
  }

  Widget _buildMatchCard(BuildContext context, Match match) {
    // Choose a color based on the match status
    Color statusColor;
    switch (match.status) {
      case MatchStatus.live:
        statusColor = Colors.green;
        break;
      case MatchStatus.finished:
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          context.push(AppRoutes.buildMatchDetailsPath(match.id));
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${match.title} - ${match.team1} vs ${match.team2}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      match.status.toString().split('.').last.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                match.type == MatchType.fixed
                    ? 'Fixed Match'
                    : 'Variable Match',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                match.formattedStartDate,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
