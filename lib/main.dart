// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voting_app/providers/auth_provider.dart';
import 'package:voting_app/repositories/match_repository.dart';
import 'package:voting_app/repositories/vote_repository.dart';
import 'package:voting_app/repositories/user_points_repository.dart';
import 'package:voting_app/viewmodels/match_view_model.dart';
import 'package:voting_app/viewmodels/vote_view_model.dart';
import 'package:voting_app/viewmodels/user_points_view_model.dart';

import 'config/app_router.dart';
import 'config/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://njhquvqalvjbhbmsxbjb.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5qaHF1dnFhbHZqYmhibXN4YmpiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDI1NTE3MTAsImV4cCI6MjA1ODEyNzcxMH0.GL-oqFF1ec45NDFJ_gToplBcpmFITjfSR25Og_tpjZg',
  );

  runApp(const MyApp());
}

// Access Supabase client anywhere in the app
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Create providers for the entire app
    return MultiProvider(
      providers: [
        // Auth provider
        ChangeNotifierProvider(
          create: (_) => AppState(),
        ),
        // Match repository
        Provider<MatchRepository>(
          create: (_) => MatchRepository(supabase),
        ),
        // Vote repository
        Provider<VoteRepository>(
          create: (_) => VoteRepository(supabase),
        ),
        // User Points repository
        Provider<UserPointsRepository>(
          create: (_) => UserPointsRepository(supabase),
        ),
        // Match view model
        ChangeNotifierProxyProvider<MatchRepository, MatchViewModel>(
          create: (context) => MatchViewModel(
            Provider.of<MatchRepository>(context, listen: false),
          ),
          update: (context, repository, previous) =>
          previous ?? MatchViewModel(repository),
        ),
        // Vote view model
        ChangeNotifierProxyProvider2<VoteRepository, MatchRepository, VoteViewModel>(
          create: (context) => VoteViewModel(
            Provider.of<VoteRepository>(context, listen: false),
            Provider.of<MatchRepository>(context, listen: false),
          ),
          update: (context, voteRepository, matchRepository, previous) =>
          previous ?? VoteViewModel(voteRepository, matchRepository),
        ),
        // User Points view model
        ChangeNotifierProxyProvider<UserPointsRepository, UserPointsViewModel>(
          create: (context) => UserPointsViewModel(
            Provider.of<UserPointsRepository>(context, listen: false),
          ),
          update: (context, repository, previous) =>
          previous ?? UserPointsViewModel(repository),
        ),
      ],
      child: const AppWithRouter(),
    );
  }
}

class AppWithRouter extends StatelessWidget {
  const AppWithRouter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get AppState from the provider
    final appState = Provider.of<AppState>(context);

    // Create router with the AppState from Provider
    final appRouter = AppRouter(appState);

    return MaterialApp.router(
      title: 'Sports App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      routerConfig: appRouter.router,
    );
  }
}