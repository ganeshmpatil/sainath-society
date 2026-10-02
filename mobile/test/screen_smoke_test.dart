import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// Import all screens
import 'package:aangan/features/auth/login_screen.dart';
import 'package:aangan/features/dashboard/dashboard_screen.dart';
import 'package:aangan/features/grievances/grievances_screen.dart';
import 'package:aangan/features/notices/notices_screen.dart';
import 'package:aangan/features/finance/finance_screen.dart';
import 'package:aangan/features/more/more_screen.dart';
import 'package:aangan/features/residents/residents_screen.dart';
import 'package:aangan/features/vehicles/vehicles_screen.dart';
import 'package:aangan/features/meetings/meetings_screen.dart';
import 'package:aangan/features/tasks/tasks_screen.dart';
import 'package:aangan/features/hall_booking/hall_booking_screen.dart';
import 'package:aangan/features/suggestions/suggestions_screen.dart';
import 'package:aangan/features/move_in_out/move_in_out_screen.dart';
import 'package:aangan/features/member_documents/member_documents_screen.dart';
import 'package:aangan/features/calendar/calendar_screen.dart';
import 'package:aangan/features/workflows/workflow_list_screen.dart';
import 'package:aangan/features/important_calls/important_calls_screen.dart';
import 'package:aangan/features/staff/staff_screen.dart';
import 'package:aangan/features/certificates/certificate_screen.dart';
import 'package:aangan/features/amc/amc_screen.dart';
import 'package:aangan/features/visitors/visitor_screen.dart';
import 'package:aangan/features/budget/budget_screen.dart';
import 'package:aangan/features/helpdesk/helpdesk_screen.dart';
import 'package:aangan/features/election/election_screen.dart';
import 'package:aangan/features/audit/audit_screen.dart';
import 'package:aangan/features/guard_patrol/guard_patrol_screen.dart';
import 'package:aangan/features/analytics/analytics_screen.dart';
import 'package:aangan/features/notifications/notifications_screen.dart';
import 'package:aangan/features/profile/profile_screen.dart';
import 'package:aangan/features/finance/chart_of_accounts_screen.dart';
import 'package:aangan/features/finance/journal_entries_screen.dart';
import 'package:aangan/features/finance/defaulter_register_screen.dart';
import 'package:aangan/features/finance/member_statement_screen.dart';
import 'package:aangan/features/finance/income_expenditure_screen.dart';
import 'package:aangan/features/finance/balance_sheet_screen.dart';
import 'package:aangan/features/finance/receipts_payments_screen.dart';
import 'package:aangan/features/finance/vendor_master_screen.dart';
import 'package:aangan/features/finance/expense_dashboard_screen.dart';
import 'package:aangan/features/finance/fund_tracking_screen.dart';
import 'package:aangan/features/finance/tds_dashboard_screen.dart';
import 'package:aangan/features/finance/charge_overrides_screen.dart';
import 'package:aangan/features/auth/change_password_screen.dart';
import 'package:aangan/features/onboarding/society_registration_screen.dart';

import 'package:aangan/core/auth/auth_bloc.dart';
import 'package:aangan/core/auth/auth_state.dart';
import 'package:aangan/core/i18n/locale_cubit.dart';
import 'package:aangan/core/theme/theme_cubit.dart';
import 'package:aangan/core/api/api_client.dart';

// Mock AuthBloc that returns authenticated state
class MockAuthBloc extends AuthBloc {
  MockAuthBloc() : super() {
    // We'll emit authenticated from outside
  }
}

void main() {
  // Screens that don't need authentication
  final publicScreens = <String, Widget>{
    'LoginScreen': const LoginScreen(),
    'SocietyRegistrationScreen': const SocietyRegistrationScreen(),
    'ChangePasswordScreen': const ChangePasswordScreen(forced: false),
  };

  // Screens requiring authenticated context
  final authScreens = <String, Widget>{
    'DashboardScreen': const DashboardScreen(),
    'GrievancesScreen': const GrievancesScreen(),
    'NoticesScreen': const NoticesScreen(),
    'FinanceScreen': const FinanceScreen(),
    'MoreScreen': const MoreScreen(),
    'ResidentsScreen': const ResidentsScreen(),
    'VehiclesScreen': const VehiclesScreen(),
    'MeetingsScreen': const MeetingsScreen(),
    'TasksScreen': const TasksScreen(),
    'HallBookingScreen': const HallBookingScreen(),
    'SuggestionsScreen': const SuggestionsScreen(),
    'MoveInOutScreen': const MoveInOutScreen(),
    'MemberDocumentsScreen': const MemberDocumentsScreen(),
    'CalendarScreen': const CalendarScreen(),
    'WorkflowListScreen': const WorkflowListScreen(),
    'ImportantCallsScreen': const ImportantCallsScreen(),
    'StaffScreen': const StaffScreen(),
    'CertificateScreen': const CertificateScreen(),
    'AMCScreen': const AMCScreen(),
    'VisitorScreen': const VisitorScreen(),
    'BudgetScreen': const BudgetScreen(),
    'HelpdeskScreen': const HelpdeskScreen(),
    'ElectionScreen': const ElectionScreen(),
    'AuditScreen': const AuditScreen(),
    'GuardPatrolScreen': const GuardPatrolScreen(),
    'AnalyticsScreen': const AnalyticsScreen(),
    'NotificationsScreen': const NotificationsScreen(),
    'ProfileScreen': const ProfileScreen(),
    'ChartOfAccountsScreen': const ChartOfAccountsScreen(),
    'JournalEntriesScreen': const JournalEntriesScreen(),
    'DefaulterRegisterScreen': const DefaulterRegisterScreen(),
    'MemberStatementScreen': const MemberStatementScreen(),
    'IncomeExpenditureScreen': const IncomeExpenditureScreen(),
    'BalanceSheetScreen': const BalanceSheetScreen(),
    'ReceiptsPaymentsScreen': const ReceiptsPaymentsScreen(),
    'VendorMasterScreen': const VendorMasterScreen(),
    'ExpenseDashboardScreen': const ExpenseDashboardScreen(),
    'FundTrackingScreen': const FundTrackingScreen(),
    'TdsDashboardScreen': const TdsDashboardScreen(),
    'ChargeOverridesScreen': const ChargeOverridesScreen(),
  };

  setUpAll(() {
    api.init();
  });

  group('Screen Smoke Tests - All screens render without crash', () {
    for (final entry in publicScreens.entries) {
      testWidgets('${entry.key} renders', (tester) async {
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => LocaleCubit()),
              BlocProvider(create: (_) => ThemeCubit()),
              BlocProvider(create: (_) => AuthBloc()),
            ],
            child: MaterialApp(home: entry.value),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(Scaffold), findsWidgets,
            reason: '${entry.key} should have at least one Scaffold');
      });
    }

    for (final entry in authScreens.entries) {
      testWidgets('${entry.key} renders', (tester) async {
        final authBloc = AuthBloc();

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => LocaleCubit()),
              BlocProvider(create: (_) => ThemeCubit()),
              BlocProvider.value(value: authBloc),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => entry.value,
              ),
            ),
          ),
        );
        // Just pump once - we're testing that the widget tree builds without exceptions
        await tester.pump(const Duration(seconds: 1));
        // If we get here without exception, the screen rendered
        expect(tester.takeException(), isNull,
            reason: '${entry.key} should render without throwing');
      });
    }
  });
}
