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

// ── State & Cubit ─────────────────────────────────────────────

class _St {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> tickets;
  final Map<String, dynamic> stats;
  const _St({this.loading = false, this.error, this.tickets = const [], this.stats = const {}});
}

class _Cu extends Cubit<_St> {
  _Cu() : super(const _St());

  Future<void> load({String? status}) async {
    emit(const _St(loading: true));
    try {
      final params = <String, dynamic>{};
      if (status != null && status.isNotEmpty) params['status'] = status;
      final results = await Future.wait([
        api.get('/helpdesk', queryParams: params),
        api.get('/helpdesk/stats'),
      ]);
      final tickets = (results[0].data['tickets'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      final stats = results[1].data is Map<String, dynamic> ? results[1].data as Map<String, dynamic> : <String, dynamic>{};
      emit(_St(tickets: tickets, stats: stats));
    } catch (e) {
      emit(_St(error: e.toString()));
    }
  }
}

// ── Screen ────────────────────────────────────────────────────

class HelpdeskScreen extends StatelessWidget {
  const HelpdeskScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _Cu()..load(),
    child: const _View(),
  );
}

class _View extends StatefulWidget {
  const _View();
  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
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

  String _statusLabel(AppLocalizations l, String? status) {
    switch (status) {
      case 'OPEN': return l.t('helpdesk.open');
      case 'IN_PROGRESS': return l.t('helpdesk.inProgress');
      case 'RESOLVED': return l.t('helpdesk.resolved');
      case 'CLOSED': return l.t('helpdesk.closed');
      default: return status ?? '';
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
      case 'GENERAL': return Icons.help_outline_rounded;
      default: return Icons.support_agent_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.watch<LocaleCubit>();
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<_Cu>().load(status: _filter),
          color: AppColors.primary,
          child: BlocBuilder<_Cu, _St>(
            builder: (context, state) {
              return CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () { if (context.canPop()) context.pop(); else context.go('/more'); },
                          child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l.t('helpdesk.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(l.t('helpdesk.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        ])),
                      ]),
                    ),
                  ),

                  // Stats
                  if (!state.loading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          _StatChip(label: l.t('helpdesk.open'), count: state.stats['open'] ?? 0, color: const Color(0xFFF97316), selected: _filter == 'OPEN', onTap: () => _setFilter('OPEN')),
                          const SizedBox(width: 6),
                          _StatChip(label: l.t('helpdesk.inProgress'), count: state.stats['inProgress'] ?? 0, color: const Color(0xFF3B82F6), selected: _filter == 'IN_PROGRESS', onTap: () => _setFilter('IN_PROGRESS')),
                          const SizedBox(width: 6),
                          _StatChip(label: l.t('helpdesk.resolved'), count: state.stats['resolved'] ?? 0, color: const Color(0xFF10B981), selected: _filter == 'RESOLVED', onTap: () => _setFilter('RESOLVED')),
                          const SizedBox(width: 6),
                          _StatChip(label: l.t('common.all'), count: (state.stats['open'] ?? 0) + (state.stats['inProgress'] ?? 0) + (state.stats['resolved'] ?? 0) + (state.stats['closed'] ?? 0), color: const Color(0xFF64748B), selected: _filter == '', onTap: () => _setFilter('')),
                        ]),
                      ),
                    ),

                  if (state.loading)
                    const SliverToBoxAdapter(child: ShimmerLoading()),

                  if (!state.loading && state.tickets.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(child: Column(children: [
                          Icon(Icons.support_agent_rounded, size: 48, color: AppColors.textTertiary.withAlpha(80)),
                          const SizedBox(height: 12),
                          Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)),
                        ])),
                      ),
                    ),

                  // Ticket list
                  if (!state.loading)
                    SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        final t = state.tickets[i];
                        final status = t['status'] as String?;
                        final sColor = _statusColor(status);
                        final pColor = _priorityColor(t['priority'] as String?);
                        final category = t['category'] as String?;

                        return GlassCard(
                          onTap: () async {
                            await context.push('/helpdesk/${t['id']}');
                            if (ctx.mounted) ctx.read<_Cu>().load(status: _filter);
                          },
                          child: Row(children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(color: sColor.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                              child: Icon(_categoryIcon(category), size: 22, color: sColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text(t['ticketNo'] ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary, fontFamily: 'monospace')),
                                const SizedBox(width: 6),
                                Container(
                                  width: 6, height: 6,
                                  decoration: BoxDecoration(color: pColor, shape: BoxShape.circle),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: sColor.withAlpha(25), borderRadius: BorderRadius.circular(6)),
                                  child: Text(_statusLabel(l, status), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: sColor)),
                                ),
                              ]),
                              const SizedBox(height: 3),
                              Text(t['subject'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${t['flatNo'] ?? ''} • ${category ?? ''}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                            ])),
                            Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
                          ]),
                        );
                      }, childCount: state.tickets.length),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTicket(context, l),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  void _setFilter(String f) {
    setState(() => _filter = f == _filter ? '' : f);
    context.read<_Cu>().load(status: _filter);
  }

  void _showCreateTicket(BuildContext ctx, AppLocalizations l) {
    final cubit = ctx.read<_Cu>();
    final authState = ctx.read<AuthBloc>().state;
    final flatId = authState is Authenticated ? authState.user.flatId : '';
    final flatNo = authState is Authenticated ? authState.user.flatNumber : '';

    String subject = '';
    String description = '';
    String category = 'GENERAL';
    String priority = 'MEDIUM';

    final categories = {
      'PLUMBING': l.t('helpdesk.catPlumbing'),
      'ELECTRICAL': l.t('helpdesk.catElectrical'),
      'PARKING': l.t('helpdesk.catParking'),
      'WATER': l.t('helpdesk.catWater'),
      'CLEANLINESS': l.t('helpdesk.catCleanliness'),
      'NOISE': l.t('helpdesk.catNoise'),
      'GENERAL': l.t('helpdesk.catGeneral'),
      'OTHER': l.t('visitor.typeOther'),
    };

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => StatefulBuilder(builder: (c, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 20),
          Text(l.t('helpdesk.create'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          // Category chips
          Wrap(spacing: 6, runSpacing: 6, children: categories.entries.map((e) {
            final selected = category == e.key;
            return ChoiceChip(
              label: Text(e.value, style: TextStyle(fontSize: 11, color: selected ? Colors.white : AppColors.textSecondary)),
              selected: selected,
              selectedColor: AppColors.primary,
              onSelected: (_) => setState(() => category = e.key),
            );
          }).toList()),
          const SizedBox(height: 16),
          TextField(onChanged: (v) => subject = v, decoration: InputDecoration(labelText: l.t('helpdesk.subject'))),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => description = v, maxLines: 3, decoration: InputDecoration(labelText: l.t('helpdesk.description'))),
          const SizedBox(height: 12),
          // Priority selector
          Row(children: [
            Text('${l.t('helpdesk.priority')}: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            ...['LOW', 'MEDIUM', 'HIGH', 'URGENT'].map((p) {
              final selected = priority == p;
              final label = p == 'LOW' ? l.t('helpdesk.low') : p == 'MEDIUM' ? l.t('helpdesk.medium') : p == 'HIGH' ? l.t('helpdesk.high') : l.t('helpdesk.urgent');
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(label, style: TextStyle(fontSize: 10, color: selected ? Colors.white : AppColors.textSecondary)),
                  selected: selected,
                  selectedColor: _priorityColor(p),
                  onSelected: (_) => setState(() => priority = p),
                ),
              );
            }),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(c),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(l.t('common.cancel')),
            )),
            const SizedBox(width: 12),
            Expanded(child: GradientButton(label: l.t('common.save'), onPressed: () async {
              if (subject.isEmpty) return;
              try {
                await api.post('/helpdesk', data: {
                  'subject': subject,
                  'description': description,
                  'category': category,
                  'priority': priority,
                  'flatId': flatId,
                  'flatNo': flatNo,
                });
                if (c.mounted) Navigator.pop(c);
                cubit.load();
              } catch (_) {}
            })),
          ]),
        ])),
      )),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final dynamic count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _StatChip({required this.label, required this.count, required this.color, required this.selected, required this.onTap});

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
            border: Border.all(color: selected ? color : AppColors.border, width: selected ? 2 : 1),
          ),
          child: Column(children: [
            Text('$count', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: TextStyle(fontSize: 8, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}
