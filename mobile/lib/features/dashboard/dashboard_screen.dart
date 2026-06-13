import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/language_toggle.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/utils/date_format.dart';
import '../notifications/notification_badge.dart';
import 'dashboard_cubit.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DashboardCubit()..load(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  String _greeting(AppLocalizations l) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l.t('common.goodMorning');
    if (hour < 17) return l.t('common.goodAfternoon');
    return l.t('common.goodEvening');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;
    context.watch<LocaleCubit>(); // rebuild on locale change

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<DashboardCubit>().load(),
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // App bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_greeting(l)},',
                              style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                            ),
                            Text(
                              user?.name ?? '',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      const LanguageToggle(),
                      const SizedBox(width: 10),
                      const NotificationBell(),
                    ],
                  ),
                ),
              ),

              // Admin badge
              if (user?.isAdmin == true)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary.withAlpha(30), AppColors.secondary.withAlpha(30)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.secondary.withAlpha(60)),
                        ),
                        child: Text(
                          '${l.t('common.admin')} / ${user!.flatNumber}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Stats + Content
              BlocBuilder<DashboardCubit, DashboardState>(
                builder: (context, state) {
                  if (state is DashboardLoading) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: ShimmerLoading(itemCount: 6, itemHeight: 80),
                      ),
                    );
                  }

                  if (state is DashboardError) {
                    return SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: AppColors.urgent),
                              const SizedBox(height: 12),
                              Text(l.t('common.error'), style: TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => context.read<DashboardCubit>().load(),
                                child: Text(l.t('common.retry')),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final data = (state as DashboardLoaded).data;
                  return SliverList(
                    delegate: SliverChildListDelegate([
                      // Quick actions
                      SectionHeader(title: l.t('common.quickActions')),
                      _QuickActionsGrid(),
                      const SizedBox(height: 16),

                      // Recent Notices
                      SectionHeader(
                        title: l.t('dashboard.recentNotices'),
                        onSeeAll: () => context.go('/notices'),
                      ),
                      ...data.recentNotices.take(3).map((n) => _NoticeItem(notice: n)),
                      if (data.recentNotices.isEmpty)
                        _emptyMessage(l.t('common.noRecords')),
                      const SizedBox(height: 12),

                      // Active Grievances
                      SectionHeader(
                        title: l.t('dashboard.activeGrievancesList'),
                        onSeeAll: () => context.go('/grievances'),
                      ),
                      ...data.activeGrievances.take(3).map((g) => _GrievanceItem(grievance: g)),
                      if (data.activeGrievances.isEmpty)
                        _emptyMessage(l.t('common.noRecords')),
                      const SizedBox(height: 100),
                    ]),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyMessage(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final _actions = const [
    _QA(Icons.campaign_rounded, 'nav.notices', '/notices', Color(0x30EF4444)),
    _QA(Icons.report_problem_rounded, 'nav.grievances', '/grievances', Color(0x30F97316)),
    _QA(Icons.account_balance_wallet_rounded, 'nav.finance', '/finance', Color(0x3010B981)),
    _QA(Icons.home_rounded, 'nav.flatDetails', '/flat-details', Color(0x303B82F6)),
    _QA(Icons.how_to_vote_rounded, 'nav.polls', '/polls', Color(0x30A855F7)),
    _QA(Icons.directions_car_rounded, 'nav.vehicles', '/vehicles', Color(0x3006B6D4)),
    _QA(Icons.people_rounded, 'nav.residents', '/residents', Color(0x30EC4899)),
    _QA(Icons.groups_rounded, 'nav.meetings', '/meetings', Color(0x30EAB308)),
    _QA(Icons.grid_view_rounded, 'common.more', '/more', Color(0x3064748B)),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.85,
        children: _actions.map((a) {
          return GestureDetector(
            onTap: () => context.go(a.route),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: a.color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(a.icon, size: 20, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.t(a.labelKey),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QA {
  final IconData icon;
  final String labelKey;
  final String route;
  final Color color;
  const _QA(this.icon, this.labelKey, this.route, this.color);
}

class _NoticeItem extends StatelessWidget {
  final Map<String, dynamic> notice;
  const _NoticeItem({required this.notice});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.read<LocaleCubit>().isMarathi;
    final title = (isMr ? notice['titleMr'] : null) ?? notice['title'] ?? '';
    final date = notice['createdAt'] ?? '';

    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.urgentBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.campaign_rounded, size: 20, color: AppColors.urgent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  _formatDate(date),
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          if (notice['isPinned'] == true)
            StatusBadge(label: l.t('common.new'), color: AppColors.urgent),
        ],
      ),
    );
  }
}

class _GrievanceItem extends StatelessWidget {
  final Map<String, dynamic> grievance;
  const _GrievanceItem({required this.grievance});

  @override
  Widget build(BuildContext context) {
    final isMr = context.read<LocaleCubit>().isMarathi;
    final title = (isMr ? grievance['titleMr'] : null) ?? grievance['title'] ?? '';
    final priority = grievance['priority'] ?? 'MEDIUM';
    final ticket = grievance['ticketNo'] ?? '';

    return GlassCard(
      onTap: () {
        final id = grievance['id'];
        if (id != null) context.go('/grievances/$id');
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.priorityBgColor(priority),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.warning_amber_rounded, size: 20,
                color: AppColors.priorityColor(priority)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(ticket,
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontFamily: 'monospace')),
              ],
            ),
          ),
          StatusBadge.priority(priority),
        ],
      ),
    );
  }
}

String _formatDate(String iso) => formatTimeAgo(iso);
