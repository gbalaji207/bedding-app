// lib/widgets/common/app_scaffold.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'app_drawer.dart';
import '../../utils/constants.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;
  final String? title;

  // Remove the appState parameter - we'll get it from Provider instead
  const AppScaffold({
    Key? key,
    required this.child,
    this.title,
  }) : super(key: key);

  // Show logout confirmation dialog
  Future<void> _showLogoutConfirmation(BuildContext context, AppState appState) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    ) ?? false; // Default to false if dialog is dismissed

    if (shouldLogout) {
      await appState.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get AppState from Provider
    final appState = Provider.of<AppState>(context);

    // Check if the current route is the match details route
    final location = GoRouterState.of(context).matchedLocation;
    final bool isMatchDetailsScreen = location.contains('details');

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Sports App'),
        automaticallyImplyLeading: !isMatchDetailsScreen,
        leading: isMatchDetailsScreen
            ? BackButton(
          onPressed: () => context.pop(),
        )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: appState.isLoading
                ? null // Disable when loading
                : () => _showLogoutConfirmation(context, appState),
          ),
        ],
      ),
      drawer: isMatchDetailsScreen ? null : const AppDrawer(),
      body: child,
    );
  }
}