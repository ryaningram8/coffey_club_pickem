/// Named route constants. Always use these — never hardcode path strings inline.
class AppRoutes {
  AppRoutes._();

  // Auth
  static const String login = '/login';
  static const String signup = '/signup';

  // Player
  static const String home = '/';
  static const String pickSheet = '/week/:weekId';
  static const String liveResults = '/week/:weekId/results';
  static const String weeklyStandings = '/week/:weekId/standings';
  static const String seasonStandings = '/standings';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String notificationPrefs = '/settings/notifications';

  // Commissioner
  static const String commissioner = '/commissioner';
  static const String commissionerWeek = '/commissioner/week/:weekId';
  static const String commissionerGames = '/commissioner/week/:weekId/games';
  static const String commissionerInvites = '/commissioner/invites';
  static const String commissionerPayouts = '/commissioner/payouts/:weekId';

  // Admin
  static const String adminUsers = '/admin/users';
}
