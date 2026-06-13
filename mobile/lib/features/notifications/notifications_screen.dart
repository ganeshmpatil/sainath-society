import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/utils/date_format.dart';
import '../../shared/widgets/shimmer_loading.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await api.get('/notifications/inbox');
      final list = (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() {
        _notifications = list;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markRead(String id, int index) async {
    try {
      await api.post('/notifications/$id/read');
      setState(() {
        _notifications[index]['status'] = 'READ';
        _notifications[index]['readAt'] = DateTime.now().toIso8601String();
      });
    } catch (_) {}
  }

  IconData _eventIcon(String? eventType) {
    switch (eventType) {
      case 'GRIEVANCE_CREATED':
      case 'GRIEVANCE_STATUS_CHANGED':
        return Icons.report_problem_rounded;
      case 'NOTICE_CREATED':
        return Icons.campaign_rounded;
      case 'MEETING_SCHEDULED':
        return Icons.groups_rounded;
      case 'TASK_ASSIGNED':
        return Icons.checklist_rounded;
      case 'POLL_PUBLISHED':
        return Icons.how_to_vote_rounded;
      case 'BILL_GENERATED':
      case 'BILL_PAID':
        return Icons.account_balance_wallet_rounded;
      case 'HALL_BOOKING_DECIDED':
        return Icons.event_available_rounded;
      case 'TENANT_APPROVED':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _eventColor(String? eventType) {
    switch (eventType) {
      case 'GRIEVANCE_CREATED':
      case 'GRIEVANCE_STATUS_CHANGED':
        return AppColors.urgent;
      case 'NOTICE_CREATED':
        return AppColors.primary;
      case 'MEETING_SCHEDULED':
        return AppColors.resolved;
      case 'TASK_ASSIGNED':
        return const Color(0xFFF97316);
      case 'POLL_PUBLISHED':
        return const Color(0xFFEAB308);
      case 'BILL_GENERATED':
      case 'BILL_PAID':
        return AppColors.resolved;
      default:
        return AppColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Icon(Icons.arrow_back_ios_rounded,
                            size: 20, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.t('notifications.title'),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(l.t('notifications.subtitle'),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (_loading)
                const SliverToBoxAdapter(child: ShimmerLoading()),

              if (!_loading && _notifications.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none_rounded,
                            size: 48, color: AppColors.textTertiary),
                        const SizedBox(height: 12),
                        Text(l.t('notifications.empty'),
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                ),

              if (!_loading && _notifications.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final n = _notifications[i];
                      final isRead = n['status'] == 'READ';
                      final body = (isMr && (n['bodyMr'] ?? '').toString().isNotEmpty)
                          ? n['bodyMr']
                          : n['body'] ?? '';
                      final subject = n['subject'] ?? '';
                      final eventType = n['eventType'] ?? '';
                      final createdAt = n['createdAt'] ?? '';

                      return GestureDetector(
                        onTap: () {
                          if (!isRead) {
                            _markRead(n['id'], i);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isRead
                                ? AppColors.surface
                                : AppColors.primary.withAlpha(8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isRead
                                  ? AppColors.border
                                  : AppColors.primary.withAlpha(30),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      _eventColor(eventType).withAlpha(25),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _eventIcon(eventType),
                                  size: 20,
                                  color: _eventColor(eventType),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subject,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isRead
                                            ? FontWeight.w500
                                            : FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      body.toString(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatTimeAgo(createdAt),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _notifications.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}
