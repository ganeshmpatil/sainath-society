import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/module_screen.dart';

class MeetingsScreen extends StatelessWidget {
  const MeetingsScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) =>
            ListCubit(endpoint: '/meetings', listKey: 'meetings')..load(),
        child: const _MV(),
      );
}

class _MV extends StatelessWidget {
  const _MV();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<ListCubit>().load(),
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Icon(Icons.arrow_back_ios_rounded,
                          size: 20, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.t('meetings.title'),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(l.t('meetings.subtitle'),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary)),
                        ]),
                  ]),
                ),
              ),
              BlocBuilder<ListCubit, ListData>(builder: (context, state) {
                if (state.loading) {
                  return const SliverToBoxAdapter(child: ShimmerLoading());
                }
                if (state.items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text(l.t('common.noRecords'),
                            style:
                                TextStyle(color: AppColors.textTertiary)),
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate((ctx, i) {
                    final m = state.items[i];
                    final title =
                        (isMr ? m['titleMr'] : null) ?? m['title'] ?? '';
                    final type = m['meetingType'] ?? 'COMMITTEE';
                    final status = m['status'] ?? 'PLANNED';
                    final date = m['scheduledAt'] ?? '';
                    final loc = m['location'] ?? '';
                    return GlassCard(
                      onTap: () => context.push('/meetings/${m['id']}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            StatusBadge(
                                label: type, color: AppColors.primary),
                            const SizedBox(width: 6),
                            StatusBadge.status(status),
                          ]),
                          const SizedBox(height: 8),
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 14, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text(_fmt(date),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary)),
                            if (loc.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.location_on_outlined,
                                  size: 14, color: AppColors.textTertiary),
                              const SizedBox(width: 4),
                              Text(loc,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary)),
                            ],
                          ]),
                        ],
                      ),
                    );
                  }, childCount: state.items.length),
                );
              }),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showCreateSheet(context),
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
    );
  }

  void _showCreateSheet(BuildContext parentContext) {
    final cubit = parentContext.read<ListCubit>();
    final l = AppLocalizations.of(parentContext);
    String title = '', agenda = '', location = '';
    String meetingType = 'COMMITTEE';
    DateTime? scheduledAt;

    final types = ['COMMITTEE', 'AGM', 'SGM', 'EMERGENCY', 'REVIEW'];

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(l.t('meetings.newMeeting'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextField(
                  onChanged: (v) => title = v,
                  decoration:
                      InputDecoration(labelText: l.t('grievances.subject')),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: meetingType,
                  dropdownColor: AppColors.surface,
                  items: types
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                              l.t('meetings.${t.toLowerCase()}'),
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => meetingType = v!,
                  decoration: InputDecoration(
                      labelText: l.t('grievances.category')),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null && context.mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 10, minute: 0),
                      );
                      if (time != null) {
                        setSheetState(() {
                          scheduledAt = DateTime(date.year, date.month,
                              date.day, time.hour, time.minute);
                        });
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(12),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.primary.withAlpha(40)),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        scheduledAt != null
                            ? '${scheduledAt!.day}/${scheduledAt!.month}/${scheduledAt!.year} ${scheduledAt!.hour}:${scheduledAt!.minute.toString().padLeft(2, '0')}'
                            : l.t('meetings.scheduled'),
                        style: TextStyle(
                            fontSize: 13,
                            color: scheduledAt != null
                                ? AppColors.textPrimary
                                : AppColors.textTertiary),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (v) => location = v,
                  decoration:
                      InputDecoration(labelText: l.t('meetings.location')),
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (v) => agenda = v,
                  maxLines: 3,
                  decoration:
                      InputDecoration(labelText: l.t('meetings.agenda')),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(l.t('common.cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GradientButton(
                        label: l.t('common.submit'),
                        onPressed: () async {
                          if (title.isEmpty || scheduledAt == null) return;
                          try {
                            await api.post('/meetings', data: {
                              'title': title,
                              'meetingType': meetingType,
                              'scheduledAt': scheduledAt!.toUtc().toIso8601String(),
                              'location': location,
                              'agenda': agenda,
                            });
                            if (context.mounted) Navigator.pop(context);
                            cubit.load();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        '${l.t('common.error')}: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
