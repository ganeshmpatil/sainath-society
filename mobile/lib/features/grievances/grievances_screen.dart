import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/shimmer_loading.dart';
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

class _GrievancesView extends StatefulWidget {
  const _GrievancesView();

  @override
  State<_GrievancesView> createState() => _GrievancesViewState();
}

class _GrievancesViewState extends State<_GrievancesView> {
  String _filter = '';

  Color _statusColor(String? status) {
    switch (status) {
      case 'OPEN': return const Color(0xFFF97316);
      case 'IN_PROGRESS': return const Color(0xFF3B82F6);
      case 'RESOLVED': return const Color(0xFF10B981);
      case 'CLOSED': return const Color(0xFF64748B);
      default: return const Color(0xFF64748B);
    }
  }

  Color _priorityColor(String? priority) {
    switch (priority) {
      case 'URGENT': return const Color(0xFFEF4444);
      case 'HIGH': return const Color(0xFFF97316);
      case 'MEDIUM': return const Color(0xFF3B82F6);
      case 'LOW': return const Color(0xFF64748B);
      default: return const Color(0xFF64748B);
    }
  }

  IconData _categoryIcon(String? category) {
    switch (category) {
      case 'PLUMBING': return Icons.water_damage_rounded;
      case 'ELECTRICAL': return Icons.electrical_services_rounded;
      case 'PARKING': return Icons.local_parking_rounded;
      case 'WATER': return Icons.water_drop_rounded;
      case 'CLEANLINESS': return Icons.cleaning_services_rounded;
      case 'NOISE': return Icons.volume_up_rounded;
      case 'SECURITY': return Icons.security_rounded;
      case 'MAINTENANCE': return Icons.build_rounded;
      case 'ELECTRICITY': return Icons.bolt_rounded;
      case 'GENERAL': return Icons.help_outline_rounded;
      default: return Icons.report_problem_rounded;
    }
  }

  void _setFilter(String f) {
    setState(() => _filter = f == _filter ? '' : f);
    context.read<GrievancesCubit>().load(status: _filter);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<GrievancesCubit>().load(status: _filter),
          color: AppColors.primary,
          child: BlocBuilder<GrievancesCubit, GrievancesState>(
            builder: (context, state) {
              return CustomScrollView(
                slivers: [
                  // Header
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

                  // Stats chips row
                  if (!state.loading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Row(children: [
                          _StatChip(
                            label: l.t('grievances.open'),
                            count: state.stats['open'] ?? 0,
                            color: const Color(0xFFF97316),
                            selected: _filter == 'OPEN',
                            onTap: () => _setFilter('OPEN'),
                          ),
                          const SizedBox(width: 6),
                          _StatChip(
                            label: l.t('grievances.inProgress'),
                            count: state.stats['inProgress'] ?? 0,
                            color: const Color(0xFF3B82F6),
                            selected: _filter == 'IN_PROGRESS',
                            onTap: () => _setFilter('IN_PROGRESS'),
                          ),
                          const SizedBox(width: 6),
                          _StatChip(
                            label: l.t('grievances.resolved'),
                            count: state.stats['resolved'] ?? 0,
                            color: const Color(0xFF10B981),
                            selected: _filter == 'RESOLVED',
                            onTap: () => _setFilter('RESOLVED'),
                          ),
                          const SizedBox(width: 6),
                          _StatChip(
                            label: l.t('common.all'),
                            count: (state.stats['open'] ?? 0) +
                                (state.stats['inProgress'] ?? 0) +
                                (state.stats['resolved'] ?? 0) +
                                (state.stats['closed'] ?? 0),
                            color: const Color(0xFF64748B),
                            selected: _filter == '',
                            onTap: () => _setFilter(''),
                          ),
                        ]),
                      ),
                    ),

                  // Loading
                  if (state.loading)
                    const SliverToBoxAdapter(child: ShimmerLoading(itemCount: 4)),

                  // Error
                  if (!state.loading && state.error != null)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 60),
                            Icon(Icons.error_outline, size: 48, color: AppColors.urgent),
                            const SizedBox(height: 8),
                            Text(state.error!, style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => context.read<GrievancesCubit>().load(),
                              child: Text(l.t('common.retry'),
                                  style: TextStyle(color: AppColors.primary)),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Empty
                  if (!state.loading && state.error == null && state.grievances.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(children: [
                            Icon(Icons.report_problem_rounded,
                                size: 48,
                                color: AppColors.textTertiary.withAlpha(80)),
                            const SizedBox(height: 12),
                            Text(l.t('common.noRecords'),
                                style: TextStyle(color: AppColors.textTertiary)),
                          ]),
                        ),
                      ),
                    ),

                  // Grievance list
                  if (!state.loading && state.error == null)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, index) {
                          final g = state.grievances[index];
                          return _GrievanceCard(
                            grievance: g,
                            isMr: isMr,
                            statusColor: _statusColor,
                            priorityColor: _priorityColor,
                            categoryIcon: _categoryIcon,
                          );
                        },
                        childCount: state.grievances.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
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
    final authState = parentContext.read<AuthBloc>().state;
    final flatId = authState is Authenticated ? authState.user.flatId : '';
    final flatNo = authState is Authenticated ? authState.user.flatNumber : '';

    String type = 'COMPLAINT';
    String title = '';
    String description = '';
    String category = 'MAINTENANCE';
    String priority = 'MEDIUM';

    final categories = [
      'MAINTENANCE', 'SECURITY', 'NOISE', 'PARKING', 'CLEANLINESS',
      'WATER', 'ELECTRICITY', 'PLUMBING', 'ELECTRICAL', 'GENERAL', 'OTHER',
    ];
    final priorities = ['LOW', 'MEDIUM', 'HIGH', 'URGENT'];

    String categoryLabel(String c) {
      switch (c) {
        case 'MAINTENANCE': return l.t('grievances.maintenance');
        case 'SECURITY': return l.t('grievances.security');
        case 'NOISE': return l.t('grievances.noise');
        case 'PARKING': return l.t('grievances.parking');
        case 'CLEANLINESS': return l.t('grievances.cleanliness');
        case 'WATER': return l.t('grievances.water');
        case 'ELECTRICITY': return l.t('grievances.electricity');
        case 'PLUMBING': return l.t('grievances.plumbing');
        case 'ELECTRICAL': return l.t('grievances.electrical');
        case 'GENERAL': return l.t('grievances.general');
        case 'OTHER': return l.t('grievances.other');
        default: return c;
      }
    }

    String priorityLabel(String p) {
      switch (p) {
        case 'LOW': return l.t('grievances.low');
        case 'MEDIUM': return l.t('grievances.medium');
        case 'HIGH': return l.t('grievances.high');
        case 'URGENT': return l.t('grievances.urgent');
        default: return p;
      }
    }

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
                    const SizedBox(height: 16),

                    // Type selector
                    _label(l.t('grievances.type')),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      ChoiceChip(
                        label: Text(l.t('grievances.typeComplaint'),
                            style: TextStyle(
                              fontSize: 12,
                              color: type == 'COMPLAINT' ? Colors.white : AppColors.textSecondary,
                            )),
                        selected: type == 'COMPLAINT',
                        selectedColor: AppColors.primary,
                        onSelected: (_) => setState(() => type = 'COMPLAINT'),
                      ),
                      ChoiceChip(
                        label: Text(l.t('grievances.typeMaintenanceRequest'),
                            style: TextStyle(
                              fontSize: 12,
                              color: type == 'MAINTENANCE_REQUEST' ? Colors.white : AppColors.textSecondary,
                            )),
                        selected: type == 'MAINTENANCE_REQUEST',
                        selectedColor: AppColors.primary,
                        onSelected: (_) => setState(() => type = 'MAINTENANCE_REQUEST'),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Category chips
                    _label(l.t('grievances.category')),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: categories.map((c) {
                      final selected = category == c;
                      return ChoiceChip(
                        label: Text(categoryLabel(c),
                            style: TextStyle(
                              fontSize: 11,
                              color: selected ? Colors.white : AppColors.textSecondary,
                            )),
                        selected: selected,
                        selectedColor: AppColors.primary,
                        onSelected: (_) => setState(() => category = c),
                      );
                    }).toList()),
                    const SizedBox(height: 16),

                    // Subject / Title
                    _label(l.t('grievances.subject')),
                    const SizedBox(height: 6),
                    TextField(
                      onChanged: (v) => title = v,
                      decoration: InputDecoration(hintText: l.t('grievances.subject')),
                    ),
                    const SizedBox(height: 14),

                    // Description
                    _label(l.t('grievances.description')),
                    const SizedBox(height: 6),
                    TextField(
                      onChanged: (v) => description = v,
                      maxLines: 3,
                      decoration: InputDecoration(hintText: l.t('grievances.description')),
                    ),
                    const SizedBox(height: 14),

                    // Priority chips
                    Row(children: [
                      Text('${l.t('grievances.priority')}: ',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 8),
                      ...priorities.map((p) {
                        final selected = priority == p;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(priorityLabel(p),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: selected ? Colors.white : AppColors.textSecondary,
                                )),
                            selected: selected,
                            selectedColor: _priorityColor(p),
                            onSelected: (_) => setState(() => priority = p),
                          ),
                        );
                      }),
                    ]),
                    const SizedBox(height: 20),

                    // Buttons
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
                            label: l.t('grievances.submitGrievance'),
                            onPressed: () async {
                              if (title.isEmpty) return;
                              final ok = await cubit.create({
                                'title': title,
                                'description': description,
                                'category': category,
                                'priority': priority,
                                'type': type,
                                'flatId': flatId,
                                'flatNo': flatNo,
                              });
                              if (ok && context.mounted) Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
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
  final Color Function(String?) statusColor;
  final Color Function(String?) priorityColor;
  final IconData Function(String?) categoryIcon;

  const _GrievanceCard({
    required this.grievance,
    required this.isMr,
    required this.statusColor,
    required this.priorityColor,
    required this.categoryIcon,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = (isMr ? grievance['titleMr'] : null) ?? grievance['title'] ?? '';
    final desc = (isMr ? grievance['descriptionMr'] : null) ?? grievance['description'] ?? '';
    final priority = grievance['priority'] ?? 'MEDIUM';
    final status = grievance['status'] ?? 'OPEN';
    final ticket = grievance['ticketNo'] ?? '';
    final category = grievance['category'] as String?;
    final type = grievance['type'] as String?;
    final sColor = statusColor(status);
    final pColor = priorityColor(priority);

    String statusLabel(String? s) {
      switch (s) {
        case 'OPEN': return l.t('grievances.open');
        case 'IN_PROGRESS': return l.t('grievances.inProgress');
        case 'RESOLVED': return l.t('grievances.resolved');
        case 'CLOSED': return l.t('grievances.closed');
        default: return s ?? '';
      }
    }

    String typeLabel(String? t) {
      if (t == 'MAINTENANCE_REQUEST') return l.t('grievances.typeMaintenanceRequest');
      return l.t('grievances.typeComplaint');
    }

    Color typeColor(String? t) {
      if (t == 'MAINTENANCE_REQUEST') return const Color(0xFF3B82F6);
      return const Color(0xFFF97316);
    }

    return GlassCard(
      onTap: () {
        final id = grievance['id'];
        if (id != null) context.go('/grievances/$id');
      },
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: sColor.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(categoryIcon(category), size: 22, color: sColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(ticket,
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary, fontFamily: 'monospace',
                  )),
              const SizedBox(width: 6),
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: pColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: typeColor(type).withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(typeLabel(type),
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: typeColor(type))),
              ),
              const Spacer(),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statusLabel(status),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: sColor)),
              ),
            ]),
            const SizedBox(height: 3),
            Text(title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (desc.isNotEmpty)
              Text(desc,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final dynamic count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(30) : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(children: [
            Text('$count',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            Text(label,
                style: TextStyle(fontSize: 8, color: color),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

