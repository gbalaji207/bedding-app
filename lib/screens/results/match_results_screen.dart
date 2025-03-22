// lib/screens/results/match_results_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../models/match_model.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/match_repository.dart';
import '../../repositories/vote_repository.dart';
import '../../utils/constants.dart';
import '../../viewmodels/vote_details_view_model.dart';

class MatchResultsScreen extends StatefulWidget {
  const MatchResultsScreen({Key? key}) : super(key: key);

  @override
  State<MatchResultsScreen> createState() => _MatchResultsScreenState();
}

class _MatchResultsScreenState extends State<MatchResultsScreen> {
  List<Match> _pastMatches = [];
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
      final matchRepository = Provider.of<MatchRepository>(context, listen: false);

      // Get past matches directly from the database
      _pastMatches = await matchRepository.getPastMatches();

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      match.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      match.status.toString().split('.').last.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
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
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        match.team1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                      ),
                      child: Text(
                        match.team2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                  const Chip(
                    label: Text('View Results'),
                    backgroundColor: Colors.blue,
                    labelStyle: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}