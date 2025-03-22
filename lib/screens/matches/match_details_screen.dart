// lib/screens/matches/match_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../models/match_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../viewmodels/match_view_model.dart';

class MatchDetailsScreen extends StatefulWidget {
  final String matchId;

  const MatchDetailsScreen({
    Key? key,
    required this.matchId,
  }) : super(key: key);

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {
  Match? _match;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadMatchDetails();
  }

  Future<void> _loadMatchDetails() async {
    final viewModel = Provider.of<MatchViewModel>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final match = await viewModel.getMatchById(widget.matchId);
      setState(() {
        _match = match;
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
    final authProvider = Provider.of<AppState>(context, listen: false);
    final isAdmin = authProvider.userRole == 'admin';

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_errorMessage',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMatchDetails,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_match == null) {
      return const Center(child: Text('Match not found'));
    }

    // Display match details
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _match!.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildStatusChip(_match!.status),
            ],
          ),
          const SizedBox(height: 24),

          // Teams
          _buildDetailsSection(
            'Teams',
            Column(
              children: [
                _buildTeamRow('Team 1', _match!.team1),
                const Divider(),
                _buildTeamRow('Team 2', _match!.team2),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Match Info
          _buildDetailsSection(
            'Match Info',
            Column(
              children: [
                _buildInfoRow('Type', _match!.type == MatchType.fixed ? 'Fixed Match' : 'Variable Match'),
                const Divider(),
                _buildInfoRow('Date & Time', _match!.formattedStartDate),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Admin Actions
          if (isAdmin) _buildAdminActions(context),
        ],
      ),
    );
  }

  Widget _buildStatusChip(MatchStatus status) {
    Color statusColor;
    String statusText = status.toString().split('.').last.toUpperCase();

    switch (status) {
      case MatchStatus.live:
        statusColor = Colors.green;
        break;
      case MatchStatus.finished:
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailsSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: content,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamRow(String label, String teamName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              teamName,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Admin Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate to edit match form with matchId in extras
                  context.pushNamed(
                    AppRoutes.matchFormName,
                    extra: {'matchId': _match!.id},
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text('Edit Match'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showDeleteConfirmation(context),
                icon: const Icon(Icons.delete),
                label: const Text('Delete Match'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Match'),
        content: Text('Are you sure you want to delete ${_match!.title}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Delete match and navigate back
              final viewModel = Provider.of<MatchViewModel>(context, listen: false);
              viewModel.deleteMatch(_match!.id);
              Navigator.pop(context); // Close dialog
              context.pop(); // Navigate back
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}