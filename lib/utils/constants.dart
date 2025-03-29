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
  static const String matchResultUpdate = '/matches/result/:matchId';
  static const String results = '/results';
  static const String points = '/points';
  static const String voting = '/voting'; // Route for voting
  static const String votingDetails = '/voting/details/:matchId'; // Route for voting details
  static const String profile = '/profile'; // Route for user profile
  static const String changePassword = '/profile/change-password'; // Route for changing password

  // Route name constants
  static const String loginName = 'login';
  static const String dashboardName = 'dashboard';
  static const String matchesName = 'matches';
  static const String matchFormName = 'matchForm';
  static const String matchDetailsName = 'matchDetails';
  static const String matchResultUpdateName = 'matchResultUpdate';
  static const String resultsName = 'results';
  static const String pointsName = 'points';
  static const String userPointDetails = '/points/user/:userId';
  static const String userPointDetailsName = 'userPointDetails';
  static const String votingName = 'voting'; // Route name for voting
  static const String votingDetailsName = 'votingDetails'; // Route name for voting details
  static const String profileName = 'profile'; // Route name for user profile
  static const String changePasswordName = 'changePassword'; // Route name for changing password

  // Helper methods for routes with parameters
  static String buildMatchDetailsPath(String matchId) => '/matches/details/$matchId';
  static String buildMatchResultUpdatePath(String matchId) => '/matches/result/$matchId';
  static String buildVotingDetailsPath(String matchId) => '/voting/details/$matchId';
  static String buildUserPointDetailsPath(String userId) => '/points/user/$userId';
}