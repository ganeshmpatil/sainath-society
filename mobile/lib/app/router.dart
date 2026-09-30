import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_bloc.dart';
import '../core/auth/auth_state.dart';
import '../features/auth/change_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/finance/finance_screen.dart';
import '../features/grievances/grievances_screen.dart';
import '../features/grievances/grievance_detail_screen.dart';
import '../features/hall_booking/hall_booking_screen.dart';
import '../features/meetings/meeting_detail_screen.dart';
import '../features/meetings/meetings_screen.dart';
import '../features/member_documents/member_documents_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/more/more_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/move_in_out/move_in_out_screen.dart';
import '../features/notices/notice_detail_screen.dart';
import '../features/notices/notices_screen.dart';
import '../features/important_calls/important_calls_screen.dart';
import '../features/residents/residents_screen.dart';
import '../features/suggestions/suggestions_screen.dart';
import '../features/tasks/tasks_screen.dart';
import '../features/vehicles/vehicles_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/workflows/workflow_list_screen.dart';
import '../features/workflows/workflow_detail_screen.dart';
import '../features/finance/chart_of_accounts_screen.dart';
import '../features/finance/journal_entries_screen.dart';
import '../features/finance/defaulter_register_screen.dart';
import '../features/finance/member_statement_screen.dart';
import '../features/finance/income_expenditure_screen.dart';
import '../features/finance/ledger_screen.dart';
import '../features/finance/balance_sheet_screen.dart';
import '../features/finance/receipts_payments_screen.dart';
import '../features/finance/vendor_master_screen.dart';
import '../features/finance/expense_dashboard_screen.dart';
import '../features/finance/fund_tracking_screen.dart';
import '../features/finance/tds_dashboard_screen.dart';
import '../features/finance/charge_overrides_screen.dart';
import '../features/staff/staff_screen.dart';
import '../features/certificates/certificate_screen.dart';
import '../features/amc/amc_screen.dart';
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
      final goingToAuth = state.matchedLocation == '/login';
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
      GoRoute(path: '/vehicles', builder: (_, __) => const VehiclesScreen()),
      GoRoute(
        path: '/meetings',
        builder: (_, __) => const MeetingsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => MeetingDetailScreen(
              id: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(path: '/tasks', builder: (_, __) => const TasksScreen()),
      GoRoute(path: '/hall-booking', builder: (_, __) => const HallBookingScreen()),
      GoRoute(path: '/suggestions', builder: (_, __) => const SuggestionsScreen()),
      GoRoute(path: '/move-in-out', builder: (_, __) => const MoveInOutScreen()),
      GoRoute(path: '/member-documents', builder: (_, __) => const MemberDocumentsScreen()),
      GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
      GoRoute(
        path: '/workflows',
        builder: (_, __) => const WorkflowListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => WorkflowDetailScreen(id: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(path: '/chart-of-accounts', builder: (_, __) => const ChartOfAccountsScreen()),
      GoRoute(path: '/journal-entries', builder: (_, __) => const JournalEntriesScreen()),
      GoRoute(path: '/defaulter-register', builder: (_, __) => const DefaulterRegisterScreen()),
      GoRoute(path: '/my-statement', builder: (_, __) => const MemberStatementScreen()),
      GoRoute(path: '/income-expenditure', builder: (_, __) => const IncomeExpenditureScreen()),
      GoRoute(
        path: '/ledger/:accountId',
        builder: (_, state) => LedgerScreen(
          accountId: state.pathParameters['accountId']!,
          accountName: state.uri.queryParameters['name'] ?? 'Ledger',
        ),
      ),
      GoRoute(path: '/balance-sheet', builder: (_, __) => const BalanceSheetScreen()),
      GoRoute(path: '/receipts-payments', builder: (_, __) => const ReceiptsPaymentsScreen()),
      GoRoute(path: '/vendor-master', builder: (_, __) => const VendorMasterScreen()),
      GoRoute(path: '/expense-dashboard', builder: (_, __) => const ExpenseDashboardScreen()),
      GoRoute(path: '/fund-tracking', builder: (_, __) => const FundTrackingScreen()),
      GoRoute(path: '/tds-dashboard', builder: (_, __) => const TdsDashboardScreen()),
      GoRoute(path: '/charge-overrides', builder: (_, __) => const ChargeOverridesScreen()),
      GoRoute(path: '/staff', builder: (_, __) => const StaffScreen()),
      GoRoute(path: '/certificates', builder: (_, __) => const CertificateScreen()),
      GoRoute(path: '/amc-contracts', builder: (_, __) => const AMCScreen()),
      GoRoute(path: '/important-calls', builder: (_, __) => const ImportantCallsScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
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
