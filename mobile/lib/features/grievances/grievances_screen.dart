import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/filter_chips_row.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/status_badge.dart';
import 'grievances_cubit.dart';

class GrievancesScreen extends StatelessWidget {
  const GrievancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GrievancesCubit()..load(),
      child: const _GrievancesView(),
    );
  }
}

class _GrievancesView extends StatelessWidget {
  const _GrievancesView();

  static const _filters = ['', 'OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];
  static const _filterKeys = [
    'common.all', 'grievances.open', 'grievances.inProgress',
    'grievances.resolved', 'grievances.closed',
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<GrievancesCubit>().load(
                status: context.read<GrievancesCubit>().state.filter),
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('grievances.title'),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      Text(l.t('grievances.subtitle'),
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  child: BlocBuilder<GrievancesCubit, GrievancesState>(
                    builder: (context, state) {
                      final idx = _filters.indexOf(state.filter);
                      return FilterChipsRow(
                        labels: _filterKeys.map((k) => l.t(k)).toList(),
                        selectedIndex: idx >= 0 ? idx : 0,
                        onSelected: (i) =>
                            context.read<GrievancesCubit>().load(status: _filters[i]),
                      );
                    },
                  ),
                ),
              ),
              BlocBuilder<GrievancesCubit, GrievancesState>(
                builder: (context, state) {
                  if (state.loading) {
                    return const SliverToBoxAdapter(
                      child: ShimmerLoading(itemCount: 4),
                    );
                  }
                  if (state.grievances.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Text(l.t('common.noRecords'),
                              style: TextStyle(color: AppColors.textTertiary)),
                        ),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final g = state.grievances[index];
                        return _GrievanceCard(grievance: g, isMr: isMr);
                      },
                      childCount: state.grievances.length,
                    ),
                  );
                },
              ),
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
    final cubit = parentContext.read<GrievancesCubit>();
    final l = AppLocalizations.of(parentContext);
    String title = '';
    String description = '';
    String category = 'MAINTENANCE';
    String priority = 'MEDIUM';

    final categories = ['MAINTENANCE', 'SECURITY', 'NOISE', 'PARKING', 'CLEANLINESS', 'WATER', 'ELECTRICITY', 'OTHER'];
    final priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.borderLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(l.t('grievances.newGrievance'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    _label(l.t('grievances.subject')),
                    const SizedBox(height: 6),
                    TextField(
                      onChanged: (v) => title = v,
                      decoration: InputDecoration(hintText: l.t('grievances.subject')),
                    ),
                    const SizedBox(height: 14),
                    _label(l.t('grievances.description')),
                    const SizedBox(height: 6),
                    TextField(
                      onChanged: (v) => description = v,
                      maxLines: 3,
                      decoration: InputDecoration(hintText: l.t('grievances.description')),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(l.t('grievances.category')),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: category,
                                isExpanded: true,
                                dropdownColor: AppColors.surface,
                                items: categories.map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(l.t('grievances.${c.toLowerCase()}'),
                                      style: const TextStyle(fontSize: 13)),
                                )).toList(),
                                onChanged: (v) => setState(() => category = v!),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label(l.t('grievances.priority')),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: priority,
                                isExpanded: true,
                                dropdownColor: AppColors.surface,
                                items: priorities.map((p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(l.t('grievances.${p.toLowerCase()}'),
                                      style: TextStyle(fontSize: 13, color: AppColors.priorityColor(p))),
                                )).toList(),
                                onChanged: (v) => setState(() => priority = v!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GradientButton(
                      label: l.t('grievances.submitGrievance'),
                      onPressed: () async {
                        if (title.isEmpty) return;
                        final ok = await cubit.create({
                          'title': title,
                          'description': description,
                          'category': category,
                          'priority': priority,
                        });
                        if (ok && context.mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _label(String text) => Text(
    text,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
  );
}

class _GrievanceCard extends StatelessWidget {
  final Map<String, dynamic> grievance;
  final bool isMr;

  const _GrievanceCard({required this.grievance, required this.isMr});

  @override
  Widget build(BuildContext context) {
    final title = (isMr ? grievance['titleMr'] : null) ?? grievance['title'] ?? '';
    final desc = (isMr ? grievance['descriptionMr'] : null) ?? grievance['description'] ?? '';
    final priority = grievance['priority'] ?? 'MEDIUM';
    final status = grievance['status'] ?? 'OPEN';
    final ticket = grievance['ticketNo'] ?? '';
    final date = grievance['createdAt'] ?? '';

    return GlassCard(
      borderColor: AppColors.priorityColor(priority).withAlpha(60),
      onTap: () {
        final id = grievance['id'];
        if (id != null) context.go('/grievances/$id');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(ticket,
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontFamily: 'monospace')),
              const SizedBox(width: 6),
              StatusBadge.priority(priority),
              const SizedBox(width: 6),
              StatusBadge.status(status),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(_formatDate(date),
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              const Spacer(),
              Text('→ Details',
                  style: TextStyle(fontSize: 11, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDate(String iso) {
  try {
    final dt = DateTime.parse(iso);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return '';
  }
}
