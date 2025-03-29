// lib/config/app_router.dart - Updated Points Screen route
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voting_app/screens/matches/match_form_screen.dart';
import 'package:voting_app/screens/voting/voting_details_screen.dart';
import 'package:voting_app/screens/voting/voting_screen.dart';
import 'package:voting_app/screens/profile/profile_screen.dart';
import 'package:voting_app/screens/profile/change_password_screen.dart';
import 'package:voting_app/viewmodels/vote_details_view_model.dart';
import 'package:voting_app/viewmodels/user_points_view_model.dart'; // Import the ViewModel
import 'package:voting_app/repositories/user_points_repository.dart'; // Import the Repository

import '../providers/auth_provider.dart';
import '../repositories/match_repository.dart';
import '../repositories/match_result_repository.dart';
import '../repositories/user_point_history_repository.dart';
import '../repositories/vote_repository.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/matches/match_result_update_screen.dart';
import '../screens/matches/matches_screen.dart';
import '../screens/matches/match_details_screen.dart';
import '../screens/points/user_point_details_screen.dart';
import '../screens/results/match_results_screen.dart';
import '../screens/points/points_screen.dart';
import '../viewmodels/match_result_view_model.dart';
import '../viewmodels/match_view_model.dart';
import '../viewmodels/user_point_details_view_model.dart';
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
          return appState.isLoggedIn ? AppRoutes.voting : AppRoutes.login;
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
          } else if (location == AppRoutes.profile) {
            title = 'My Profile';
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
            builder: (context, state) => Provider<MatchRepository>(
              create: (_) =>
                  Provider.of<MatchRepository>(context, listen: false),
              child: const MatchResultsScreen(),
            ),
          ),
          // Updated Points Screen route with the UserPointsViewModel
          GoRoute(
            path: AppRoutes.points,
            name: AppRoutes.pointsName,
            builder: (context, state) => ChangeNotifierProvider(
              create: (context) => UserPointsViewModel(
                Provider.of<UserPointsRepository>(context, listen: false),
              ),
              child: const PointsScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.voting,
            name: AppRoutes.votingName,
            builder: (context, state) => const VotingScreen(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: AppRoutes.profileName,
            builder: (context, state) => const ProfileScreen(),
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
        path: AppRoutes.userPointDetails,
        name: AppRoutes.userPointDetailsName,
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final userName = state.extra != null
              ? (state.extra as Map<String, dynamic>)['userName'] as String? ??
                  'User'
              : 'User';

          return Scaffold(
            body: ChangeNotifierProvider(
              create: (context) => UserPointDetailsViewModel(
                Provider.of<UserPointHistoryRepository>(context, listen: false),
                userId,
              ),
              child: UserPointDetailsScreen(
                userId: userId,
                userName: userName,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/matches/add',
        name: AppRoutes.matchFormName,
        builder: (context, state) {
          // First check if matchId is passed as an extra
          final Map<String, dynamic>? extras =
              state.extra as Map<String, dynamic>?;
          final String? matchId =
              extras != null ? extras['matchId'] as String? : null;

          return Scaffold(
            appBar: AppBar(
              title: Text(matchId != null ? 'Edit Match' : 'Add Match'),
            ),
            body: MatchFormScreen(matchId: matchId),
          );
        },
      ),
      // Voting details route
      GoRoute(
        path: '/voting/details/:matchId',
        name: AppRoutes.votingDetailsName,
        builder: (context, state) {
          final matchId = state.pathParameters['matchId']!;

          return ChangeNotifierProvider(
            create: (context) => VoteDetailsViewModel(
              Provider.of<VoteRepository>(context, listen: false),
              Provider.of<MatchRepository>(context, listen: false),
              Supabase.instance.client,
            ),
            child: VotingDetailsScreen(matchId: matchId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.matchResultUpdate,
        name: AppRoutes.matchResultUpdateName,
        builder: (context, state) {
          final matchId = state.pathParameters['matchId']!;

          // Return the screen with the providers it needs
          return Scaffold(
            body: MultiProvider(
              providers: [
                // Provide the match result repository
                Provider<MatchResultRepository>(
                  create: (context) => MatchResultRepository(
                    Supabase.instance.client,
                    dryRun:
                        false, // Set to true for dry run mode, false for actual database updates
                  ),
                ),
                // Provide the match result view model
                ChangeNotifierProvider<MatchResultViewModel>(
                  create: (context) => MatchResultViewModel(
                    Provider.of<MatchRepository>(context, listen: false),
                    Provider.of<MatchResultRepository>(context, listen: false),
                  ),
                ),
              ],
              child: MatchResultUpdateScreen(
                matchId: matchId,
                onSuccess: () {
                  // Refresh match data in the MatchViewModel
                  try {
                    Provider.of<MatchViewModel>(context, listen: false)
                        .refreshData();
                  } catch (e) {
                    // Ignore errors here
                  }
                },
              ),
            ),
          );
        },
      ),
      // Change password route
      GoRoute(
        path: AppRoutes.changePassword,
        name: AppRoutes.changePasswordName,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
    ],
    redirect: (context, state) {
      final isLoggedIn = appState.isLoggedIn;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;

      // Skip redirection for change password screen
      if (state.matchedLocation == AppRoutes.changePassword) {
        return null;
      }

      if (!isLoggedIn && !isLoggingIn) {
        return AppRoutes.login;
      }

      if (isLoggedIn && isLoggingIn) {
        return AppRoutes
            .voting; // Direct users to the voting screen after login
      }

      return null;
    },
  );
}
