import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_bloc.dart';
import '../core/auth/auth_state.dart';
import '../features/auth/change_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/bylaws/bylaws_screen.dart';
import '../features/decisions/decisions_screen.dart';
import '../features/finance/finance_screen.dart';
import '../features/flat_details/flat_details_screen.dart';
import '../features/grievances/grievances_screen.dart';
import '../features/grievances/grievance_detail_screen.dart';
import '../features/hall_booking/hall_booking_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/meetings/meetings_screen.dart';
import '../features/member_documents/member_documents_screen.dart';
import '../features/more/more_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/move_in_out/move_in_out_screen.dart';
import '../features/notices/notice_detail_screen.dart';
import '../features/notices/notices_screen.dart';
import '../features/polls/polls_screen.dart';
import '../features/residents/residents_screen.dart';
import '../features/suggestions/suggestions_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/vehicles/vehicles_screen.dart';
import '../shared/widgets/bottom_nav_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

GoRouter buildRouter(AuthBloc authBloc) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: _AuthNotifier(authBloc),
    redirect: (context, state) {
      final authState = authBloc.state;
      final isLoggedIn = authState is Authenticated;
      final goingToAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final goingToChangePassword = state.matchedLocation == '/change-password';

      if (!isLoggedIn && !goingToAuth) return '/login';
      if (isLoggedIn && goingToAuth) return '/';

      // Force password change redirect
      if (isLoggedIn && authState.user.mustChangePassword && !goingToChangePassword) {
        return '/change-password?forced=true';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
        path: '/change-password',
        builder: (_, state) => ChangePasswordScreen(
          forced: state.uri.queryParameters['forced'] == 'true',
        ),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            BottomNavShell(navigationShell: navigationShell),
        branches: [
          // Tab 0: Home / Dashboard
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
          ]),

          // Tab 1: Notices
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/notices',
              builder: (_, __) => const NoticesScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => NoticeDetailScreen(
                    id: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ]),

          // Tab 2: Grievances
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/grievances',
              builder: (_, __) => const GrievancesScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, state) => GrievanceDetailScreen(
                    id: state.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ]),

          // Tab 3: Finance
          StatefulShellBranch(routes: [
            GoRoute(path: '/finance', builder: (_, __) => const FinanceScreen()),
          ]),

          // Tab 4: More
          StatefulShellBranch(routes: [
            GoRoute(path: '/more', builder: (_, __) => const MoreScreen()),
          ]),
        ],
      ),

      // Module screens accessed from "More" tab
      GoRoute(path: '/residents', builder: (_, __) => const ResidentsScreen()),
      GoRoute(path: '/flat-details', builder: (_, __) => const FlatDetailsScreen()),
      GoRoute(path: '/vehicles', builder: (_, __) => const VehiclesScreen()),
      GoRoute(path: '/polls', builder: (_, __) => const PollsScreen()),
      GoRoute(path: '/meetings', builder: (_, __) => const MeetingsScreen()),
      GoRoute(path: '/tasks', builder: (_, __) => const TasksScreen()),
      GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
      GoRoute(path: '/hall-booking', builder: (_, __) => const HallBookingScreen()),
      GoRoute(path: '/bylaws', builder: (_, __) => const BylawsScreen()),
      GoRoute(path: '/decisions', builder: (_, __) => const DecisionsScreen()),
      GoRoute(path: '/suggestions', builder: (_, __) => const SuggestionsScreen()),
      GoRoute(path: '/move-in-out', builder: (_, __) => const MoveInOutScreen()),
      GoRoute(path: '/member-documents', builder: (_, __) => const MemberDocumentsScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    ],
  );
}

/// Bridges Bloc stream to Listenable for GoRouter's refreshListenable.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(AuthBloc bloc) {
    bloc.stream.listen((_) => notifyListeners());
  }
}
