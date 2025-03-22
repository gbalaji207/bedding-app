// lib/config/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:voting_app/screens/matches/match_form_screen.dart';
import 'package:voting_app/screens/voting/voting_screen.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/matches/matches_screen.dart';
import '../screens/matches/match_details_screen.dart';
import '../screens/results/match_results_screen.dart';
import '../screens/points/points_screen.dart';
import '../widgets/app_scaffold.dart';
import '../utils/constants.dart';

class AppRouter {
  final AppState appState;

  AppRouter(this.appState);

  late final GoRouter router = GoRouter(
    refreshListenable: appState,
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.root,
    routes: [
      GoRoute(
        path: AppRoutes.root,
        redirect: (context, state) {
          return appState.isLoggedIn ? AppRoutes.dashboard : AppRoutes.login;
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => LoginScreen(appState: appState),
      ),
      ShellRoute(
        builder: (context, state, child) {
          // Get the current route name to determine the title
          final location = state.matchedLocation;

          String title = 'Sports App';
          if (location.startsWith(AppRoutes.dashboard)) {
            title = 'Dashboard';
          } else if (location == AppRoutes.matches) {
            title = 'Matches';
          } else if (location.startsWith(AppRoutes.results)) {
            title = 'Match Results';
          } else if (location.startsWith(AppRoutes.points)) {
            title = 'Points Table';
          } else if (location == AppRoutes.voting) {
            title = 'Vote for Matches';
          }

          // Update to not pass appState directly
          return AppScaffold(
            child: child,
            title: title,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: AppRoutes.dashboardName,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.matches,
            name: AppRoutes.matchesName,
            builder: (context, state) => const MatchesScreen(),
          ),
          GoRoute(
            path: AppRoutes.results,
            name: AppRoutes.resultsName,
            builder: (context, state) => const MatchResultsScreen(),
          ),
          GoRoute(
            path: AppRoutes.points,
            name: AppRoutes.pointsName,
            builder: (context, state) => const PointsScreen(),
          ),
          GoRoute(
            path: AppRoutes.voting,
            name: AppRoutes.votingName,
            builder: (context, state) => const VotingScreen(),
          ),
        ],
      ),
      // Match details route outside of ShellRoute
      GoRoute(
        path: '/matches/details/:matchId',
        name: AppRoutes.matchDetailsName,
        builder: (context, state) {
          final matchId = state.pathParameters['matchId']!;
          return Scaffold(
            appBar: AppBar(
              title: Text('Match #$matchId Details'),
            ),
            body: MatchDetailsScreen(matchId: matchId),
          );
        },
      ),
      GoRoute(
        path: '/matches/add',
        name: AppRoutes.matchFormName,
        builder: (context, state) {
          // First check if matchId is passed as an extra
          final Map<String, dynamic>? extras = state.extra as Map<String, dynamic>?;
          final String? matchId = extras != null ? extras['matchId'] as String? : null;

          return Scaffold(
            appBar: AppBar(
              title: Text(matchId != null ? 'Edit Match' : 'Add Match'),
            ),
            body: MatchFormScreen(matchId: matchId),
          );
        },
      ),
    ],
    redirect: (context, state) {
      final isLoggedIn = appState.isLoggedIn;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;

      if (!isLoggedIn && !isLoggingIn) {
        return AppRoutes.login;
      }

      if (isLoggedIn && isLoggingIn) {
        return AppRoutes.dashboard;
      }

      return null;
    },
  );
}