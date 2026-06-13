import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/filter_chips_row.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/module_screen.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ListCubit(endpoint: '/tasks', listKey: 'tasks')..load(),
        child: const _TV(),
      );
}

class _TV extends StatefulWidget {
  const _TV();
  @override
  State<_TV> createState() => _TVS();
}

class _TVS extends State<_TV> {
  int _fi = 0;
  static const _fl = [
    'common.all',
    'tasks.todo',
    'tasks.inProgress',
    'tasks.done'
  ];
  static const _fv = ['', 'OPEN', 'IN_PROGRESS', 'DONE'];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<ListCubit>().load(),
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
                          Text(l.t('tasks.title'),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(l.t('tasks.subtitle'),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary)),
                        ]),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  child: FilterChipsRow(
                    labels: _fl.map((k) => l.t(k)).toList(),
                    selectedIndex: _fi,
                    onSelected: (i) {
                      setState(() => _fi = i);
                      context.read<ListCubit>().load(
                          _fv[i].isEmpty ? null : {'status': _fv[i]});
                    },
                  ),
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
                    final t = state.items[i];
                    final title =
                        (isMr ? t['titleMr'] : null) ?? t['title'] ?? '';
                    final status = t['status'] ?? 'OPEN';
                    final due = t['dueDate'] ?? '';
                    final priority = t['priority'] ?? 'MEDIUM';
                    return GlassCard(
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: AppColors.statusBgColor(status),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.checklist_rounded,
                              size: 20,
                              color: AppColors.statusColor(status)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              if (due.isNotEmpty)
                                Text(
                                    '${l.t('tasks.dueDate')}: ${_sd(due)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textTertiary)),
                            ],
                          ),
                        ),
                        StatusBadge.priority(priority),
                      ]),
                    );
                  }, childCount: state.items.length),
                );
              }),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSheet(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  void _showCreateSheet(BuildContext parentContext) {
    final cubit = parentContext.read<ListCubit>();
    final l = AppLocalizations.of(parentContext);
    String title = '', description = '';
    String priority = 'MEDIUM';
    DateTime? dueDate;

    final priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];

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
                Text(l.t('tasks.newTask'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextField(
                  onChanged: (v) => title = v,
                  decoration: InputDecoration(
                      labelText: l.t('grievances.subject')),
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (v) => description = v,
                  maxLines: 3,
                  decoration: InputDecoration(
                      labelText: l.t('grievances.description')),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: priority,
                  dropdownColor: AppColors.surface,
                  items: priorities
                      .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                              l.t('grievances.${p.toLowerCase()}'),
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.priorityColor(p)))))
                      .toList(),
                  onChanged: (v) => priority = v!,
                  decoration: InputDecoration(
                      labelText: l.t('grievances.priority')),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setSheetState(() => dueDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withAlpha(40)),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        dueDate != null
                            ? '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}'
                            : l.t('tasks.dueDate'),
                        style: TextStyle(
                            fontSize: 13,
                            color: dueDate != null
                                ? AppColors.textPrimary
                                : AppColors.textTertiary),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: l.t('common.submit'),
                  onPressed: () async {
                    if (title.isEmpty) return;
                    try {
                      final data = <String, dynamic>{
                        'title': title,
                        'description': description,
                        'priority': priority,
                      };
                      if (dueDate != null) {
                        data['dueDate'] =
                            dueDate!.toUtc().toIso8601String();
                      }
                      await api.post('/tasks', data: data);
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _sd(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
