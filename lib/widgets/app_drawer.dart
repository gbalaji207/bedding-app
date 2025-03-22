// lib/widgets/common/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the app state to access user details
    final appState = Provider.of<AppState>(context);
    final user = appState.user;
    final userProfile = appState.userProfile;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          // User details header
          UserAccountsDrawerHeader(
            accountName: Text(userProfile?.displayName ?? 'Sports Fan'),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: ClipRRect(
              borderRadius: BorderRadius.circular(50), // Fully circular avatar
              child: Container(
                height: 50, // Maintained size
                width: 50, // Maintained size
                color: Colors.white,
                child: Center(
                  child: Text(
                    _getInitials(
                        userProfile?.displayName ?? user?.email ?? 'User'),
                    style: const TextStyle(fontSize: 20, color: Colors.blue),
                  ),
                ),
              ),
            ),
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
          ),
          // ListTile(
          //   leading: const Icon(Icons.dashboard),
          //   title: const Text('Dashboard'),
          //   onTap: () {
          //     context.goNamed(AppRoutes.dashboardName);
          //     Navigator.pop(context); // Close drawer
          //   },
          // ),
          ListTile(
            leading: const Icon(Icons.how_to_vote),
            title: const Text('Vote for Matches'),
            onTap: () {
              context.goNamed(AppRoutes.votingName);
              Navigator.pop(context); // Close drawer
            },
          ),
          ListTile(
            leading: const Icon(Icons.scoreboard),
            title: const Text('Match Results'),
            onTap: () {
              context.goNamed(AppRoutes.resultsName);
              Navigator.pop(context); // Close drawer
            },
          ),
          ListTile(
            leading: const Icon(Icons.leaderboard),
            title: const Text('Points'),
            onTap: () {
              context.goNamed(AppRoutes.pointsName);
              Navigator.pop(context); // Close drawer
            },
          ),

          // Admin section - shown only to admin users
          if (appState.userRole == 'admin') ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: Text(
                'ADMIN',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.sports_cricket),
              title: const Text('Manage Matches'),
              onTap: () {
                context.goNamed(AppRoutes.matchesName);
                Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
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
