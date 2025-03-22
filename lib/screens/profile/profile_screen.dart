// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    // Initialize the display name controller with the current display name
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      if (appState.userProfile?.displayName != null) {
        _displayNameController.text = appState.userProfile!.displayName!;
      }
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final user = appState.user;
          final userProfile = appState.userProfile;

          if (user == null) {
            return const Center(child: Text('Please log in to view your profile'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                // User avatar
                _buildUserAvatar(userProfile?.displayName ?? user.email ?? 'User'),
                const SizedBox(height: 24),

                // User details card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Profile Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Email
                        _buildInfoRow('Email', user.email ?? 'Not available'),
                        const SizedBox(height: 12),

                        // Display name (editable)
                        if (_isEditing)
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Display Name'),
                                const SizedBox(height: 4),
                                TextFormField(
                                  controller: _displayNameController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    hintText: 'Enter your display name',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a display name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _isEditing = false;
                                          // Reset to the original value
                                          if (userProfile?.displayName != null) {
                                            _displayNameController.text = userProfile!.displayName!;
                                          }
                                        });
                                      },
                                      child: const Text('Cancel'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: appState.isLoading
                                          ? null
                                          : () async {
                                        if (_formKey.currentState!.validate()) {
                                          await appState.updateDisplayName(
                                            _displayNameController.text,
                                            shouldNavigate: false, // Prevent navigation after update
                                          );
                                          if (mounted) {
                                            setState(() {
                                              _isEditing = false;
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Display name updated successfully'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      child: appState.isLoading
                                          ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                          : const Text('Save'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoRow(
                                  'Display Name',
                                  userProfile?.displayName ?? 'Not set',
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _isEditing = true;
                                  });
                                },
                                tooltip: 'Edit display name',
                              ),
                            ],
                          ),
                        const SizedBox(height: 12),

                        // User role
                        _buildInfoRow('Role', userProfile?.userRole ?? 'User'),
                        const SizedBox(height: 12),

                        // Account created date
                        if (userProfile != null)
                          _buildInfoRow(
                            'Account Created',
                            '${userProfile.createdAt.day}/${userProfile.createdAt.month}/${userProfile.createdAt.year}',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Security section
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Security',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.password, color: Colors.blue),
                          title: const Text('Change Password'),
                          subtitle: const Text('Update your account password'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            context.pushNamed(AppRoutes.changePasswordName);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Error message
                if (appState.error != null && !_isEditing)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      appState.error!,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserAvatar(String displayName) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.blue,
          child: Text(
            _getInitials(displayName),
            style: const TextStyle(
              fontSize: 36,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Helper to get initials from a string (email or name)
  String _getInitials(String text) {
    if (text.isEmpty) return 'U';

    // If the text contains a space (like a full name), use first letters of each part
    if (text.contains(' ')) {
      final parts = text.split(' ');
      String initials = '';
      for (var part in parts) {
        if (part.isNotEmpty) {
          initials += part[0].toUpperCase();
          if (initials.length >= 2) break;
        }
      }
      return initials;
    }

    // If it's an email address
    if (text.contains('@')) {
      final localPart = text.split('@').first;

      // If the local part contains a period, use first letters of each part
      if (localPart.contains('.')) {
        final parts = localPart.split('.');
        String initials = '';
        for (var part in parts) {
          if (part.isNotEmpty) {
            initials += part[0].toUpperCase();
            if (initials.length >= 2) break;
          }
        }
        return initials;
      }

      // Otherwise just use the first letter
      return localPart.isNotEmpty ? localPart[0].toUpperCase() : 'U';
    }

    // For any other string, use the first character
    return text[0].toUpperCase();
  }
}