// lib/utils/constants.dart
class AppRoutes {
  // Private constructor to prevent instantiation
  AppRoutes._();

  // Route paths
  static const String root = '/';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String matches = '/matches';
  static const String matchDetails = '/matches/details/:matchId'; // Path pattern with parameter
  static const String results = '/results';
  static const String points = '/points';
  static const String voting = '/voting'; // New route for voting
  static const String votingDetails = '/voting/details/:matchId'; // New route for voting details

  // Route name constants
  static const String loginName = 'login';
  static const String dashboardName = 'dashboard';
  static const String matchesName = 'matches';
  static const String matchFormName = 'matchForm';
  static const String matchDetailsName = 'matchDetails';
  static const String resultsName = 'results';
  static const String pointsName = 'points';
  static const String votingName = 'voting'; // New route name for voting
  static const String votingDetailsName = 'votingDetails'; // New route name for voting details

  // Helper methods for routes with parameters
  static String buildMatchDetailsPath(String matchId) => '/matches/details/$matchId';
  static String buildVotingDetailsPath(String matchId) => '/voting/details/$matchId';
}