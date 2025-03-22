// lib/screens/matches/match_form_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../models/match_model.dart';
import '../../viewmodels/match_view_model.dart';

class MatchFormScreen extends StatefulWidget {
  final String? matchId;

  const MatchFormScreen({
    Key? key,
    this.matchId,
  }) : super(key: key);

  @override
  State<MatchFormScreen> createState() => _MatchFormScreenState();
}

class _MatchFormScreenState extends State<MatchFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _team1Controller = TextEditingController();
  final TextEditingController _team2Controller = TextEditingController();
  final TextEditingController _dateTimeController = TextEditingController();

  DateTime _selectedDateTime = DateTime.now();
  MatchType _selectedType = MatchType.fixed;
  MatchStatus _selectedStatus = MatchStatus.draft;

  bool _isLoading = false;
  bool _isEditMode = false;
  Match? _existingMatch;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.matchId != null;

    if (_isEditMode) {
      _loadMatchData();
    } else {
      // Set default date/time for new matches
      _dateTimeController.text =
          DateFormat('MMM dd, yyyy - h:mm a').format(_selectedDateTime);
    }
  }

  Future<void> _loadMatchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final viewModel = Provider.of<MatchViewModel>(context, listen: false);
      final match = await viewModel.getMatchById(widget.matchId!);

      if (match != null) {
        setState(() {
          _existingMatch = match;
          _titleController.text = match.title;
          _team1Controller.text = match.team1;
          _team2Controller.text = match.team2;
          _selectedType = match.type;
          _selectedDateTime = match.startDate;
          _selectedStatus = match.status;
          _dateTimeController.text = match.formattedStartDate;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading match: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _team1Controller.dispose();
    _team2Controller.dispose();
    _dateTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Match Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Teams
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _team1Controller,
                    decoration: const InputDecoration(
                      labelText: 'Team 1',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _team2Controller,
                    decoration: const InputDecoration(
                      labelText: 'Team 2',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Match Type
            Text(
              'Match Type',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<MatchType>(
                    title: const Text('Fixed'),
                    value: MatchType.fixed,
                    groupValue: _selectedType,
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<MatchType>(
                    title: const Text('Variable'),
                    value: MatchType.variable,
                    groupValue: _selectedType,
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status
            Text(
              'Match Status',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<MatchStatus>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: MatchStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.toString().split('.').last),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
            ),
            const SizedBox(height: 24),

            // Date and Time
            TextFormField(
              controller: _dateTimeController,
              decoration: const InputDecoration(
                labelText: 'Date & Time',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: () => _selectDateTime(context),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select date and time';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _saveMatch,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _isEditMode ? 'Update Match' : 'Create Match',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _dateTimeController.text =
              DateFormat('MMM dd, yyyy - h:mm a').format(_selectedDateTime);
        });
      }
    }
  }

  void _saveMatch() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() {
          _isLoading = true;
        });

        final viewModel = Provider.of<MatchViewModel>(context, listen: false);

        // Prepare match data
        final match = Match(
          id: _isEditMode ? _existingMatch!.id : const Uuid().v4(),
          title: _titleController.text,
          team1: _team1Controller.text,
          team2: _team2Controller.text,
          type: _selectedType,
          startDate: _selectedDateTime,
          status: _selectedStatus,
        );

        // Save or update
        if (_isEditMode) {
          await viewModel.updateMatch(match);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Match updated successfully')),
            );
          }
        } else {
          await viewModel.createMatch(match);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Match created successfully')),
            );
          }
        }

        // Navigate back
        if (mounted) {
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}
