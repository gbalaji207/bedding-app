// lib/screens/matches/match_result_update_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/match_model.dart';
import '../../viewmodels/match_result_view_model.dart';
import '../../repositories/match_repository.dart';

class MatchResultUpdateScreen extends StatefulWidget {
  final String matchId;
  final VoidCallback? onSuccess;

  const MatchResultUpdateScreen({
    Key? key,
    required this.matchId,
    this.onSuccess,
  }) : super(key: key);

  @override
  State<MatchResultUpdateScreen> createState() => _MatchResultUpdateScreenState();
}

class _MatchResultUpdateScreenState extends State<MatchResultUpdateScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedWinner;
  final TextEditingController _pointsController = TextEditingController();
  bool _bonusEligible = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Initialize with default values
    _pointsController.text = '100'; // Default points value

    // Load match data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMatchData();
    });
  }

  Future<void> _loadMatchData() async {
    final viewModel = Provider.of<MatchResultViewModel>(context, listen: false);
    await viewModel.loadMatch(widget.matchId);
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Match Result'),
      ),
      body: Consumer<MatchResultViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!viewModel.hasMatch) {
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
                      onPressed: _loadMatchData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return const Center(child: Text('Match not found'));
          }

          // We have the match data, build the form
          return _buildContent(viewModel);
        },
      ),
    );
  }

  Widget _buildContent(MatchResultViewModel viewModel) {
    final match = viewModel.match!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Match info header
            Text(
              match.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${match.team1} vs ${match.team2}',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
              ),
            ),
            Text(
              match.formattedStartDate,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            // Winner selection
            const Text(
              'Which team won?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            RadioListTile<String>(
              title: Text(match.team1),
              value: match.team1,
              groupValue: _selectedWinner,
              onChanged: (value) {
                setState(() {
                  _selectedWinner = value;
                });
              },
              activeColor: Colors.blue,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: _selectedWinner == match.team1
                      ? Colors.blue
                      : Colors.grey.shade300,
                ),
              ),
            ),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: Text(match.team2),
              value: match.team2,
              groupValue: _selectedWinner,
              onChanged: (value) {
                setState(() {
                  _selectedWinner = value;
                });
              },
              activeColor: Colors.orange,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: _selectedWinner == match.team2
                      ? Colors.orange
                      : Colors.grey.shade300,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Points
            const Text(
              'Points',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the base points for this match:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _pointsController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Points',
                hintText: 'Enter points value (e.g. 100)',
                prefixIcon: Icon(Icons.stars),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter points value';
                }
                final number = int.tryParse(value);
                if (number == null) {
                  return 'Please enter a valid number';
                }
                if (number <= 0) {
                  return 'Points must be greater than zero';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Bonus eligibility (only for fixed matches)
            if (match.type == MatchType.fixed) ...[
              const Text(
                'Bonus Eligibility',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Is this match eligible for 50% bonus points?',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Bonus Eligible'),
                subtitle: Text(
                  _bonusEligible
                      ? 'Yes, apply 50% bonus to base points'
                      : 'No, use base points only',
                ),
                value: _bonusEligible,
                onChanged: (value) {
                  setState(() {
                    _bonusEligible = value;
                  });
                },
                activeColor: Colors.green,
              ),
            ],
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: viewModel.isLoading ? null : () => _submitResult(viewModel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: viewModel.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Update Result',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Warning message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action will finalize the match result and update all user points. It cannot be undone.',
                      style: TextStyle(color: Colors.amber.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitResult(MatchResultViewModel viewModel) async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate winner selection
    if (_selectedWinner == null) {
      setState(() {
        _errorMessage = 'Please select a winning team';
      });
      return;
    }

    // Show confirmation dialog
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) {
      return;
    }

    try {
      setState(() {
        _errorMessage = null;
      });

      // Prepare result data
      final int points = int.parse(_pointsController.text);

      // Update match result and calculate points
      final success = await viewModel.updateMatchResult(
        widget.matchId,
        _selectedWinner!,
        points,
        _bonusEligible,
      );

      if (success && mounted) {
        // Call onSuccess callback if provided
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Match result updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Return true to indicate success using GoRouter
        context.pop(true);
      } else if (mounted) {
        setState(() {
          _errorMessage = viewModel.errorMessage.isNotEmpty
              ? viewModel.errorMessage
              : 'Failed to update match result';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update result: $e';
      });
    }
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Result Update'),
        content: Text(
          'Are you sure you want to finalize this match with ${_selectedWinner} as the winner?\n\n'
              'This will update all user points and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
        false;
  }
}