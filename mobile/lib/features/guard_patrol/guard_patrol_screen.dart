import 'package:dio/dio.dart';
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
  final List<Map<String, dynamic>> rounds;
  final List<Map<String, dynamic>> checkpoints;
  final List<Map<String, dynamic>> incidents;
  const _St({
    this.loading = false,
    this.error,
    this.rounds = const [],
    this.checkpoints = const [],
    this.incidents = const [],
  });
}

class _Cu extends Cubit<_St> {
  _Cu() : super(const _St());

  Future<void> load() async {
    emit(const _St(loading: true));
    try {
      final results = await Future.wait([
        api.get('/patrol/rounds'),
        api.get('/patrol/checkpoints'),
        api.get('/patrol/incidents'),
      ]);
      final rounds = (results[0].data['rounds'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      final checkpoints = (results[1].data['checkpoints'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      final incidents = (results[2].data['incidents'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      emit(_St(rounds: rounds, checkpoints: checkpoints, incidents: incidents));
    } catch (e) {
      emit(_St(error: e.toString()));
    }
  }

  Future<void> loadRounds({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    try {
      final res = await api.get('/patrol/rounds', queryParams: params);
      final rounds = (res.data['rounds'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      emit(_St(rounds: rounds, checkpoints: state.checkpoints, incidents: state.incidents));
    } catch (e) {
      emit(_St(rounds: state.rounds, checkpoints: state.checkpoints, incidents: state.incidents, error: e.toString()));
    }
  }

  Future<void> loadIncidents({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    try {
      final res = await api.get('/patrol/incidents', queryParams: params);
      final incidents = (res.data['incidents'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      emit(_St(rounds: state.rounds, checkpoints: state.checkpoints, incidents: incidents));
    } catch (e) {
      emit(_St(rounds: state.rounds, checkpoints: state.checkpoints, incidents: state.incidents, error: e.toString()));
    }
  }
}

// ── Screen ────────────────────────────────────────────────────

class GuardPatrolScreen extends StatelessWidget {
  const GuardPatrolScreen({super.key});

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

class _ViewState extends State<_View> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _roundStatusColor(String? status) {
    switch (status) {
      case 'IN_PROGRESS': return const Color(0xFF3B82F6);
      case 'COMPLETED': return const Color(0xFF10B981);
      case 'MISSED': return const Color(0xFFEF4444);
      default: return const Color(0xFF64748B);
    }
  }

  Color _severityColor(String? severity) {
    switch (severity) {
      case 'CRITICAL': return const Color(0xFFEF4444);
      case 'HIGH': return const Color(0xFFF97316);
      case 'MEDIUM': return const Color(0xFF3B82F6);
      case 'LOW': return const Color(0xFF10B981);
      default: return const Color(0xFF64748B);
    }
  }

  Color _incidentStatusColor(String? status) {
    switch (status) {
      case 'REPORTED': return const Color(0xFFF97316);
      case 'INVESTIGATING': return const Color(0xFF3B82F6);
      case 'RESOLVED': return const Color(0xFF10B981);
      case 'CLOSED': return const Color(0xFF64748B);
      default: return const Color(0xFF64748B);
    }
  }

  String _roundStatusLabel(AppLocalizations l, String? status) {
    switch (status) {
      case 'IN_PROGRESS': return l.t('patrol.inProgress');
      case 'COMPLETED': return l.t('patrol.completed');
      case 'MISSED': return l.t('patrol.missed');
      default: return status ?? '';
    }
  }

  String _incidentStatusLabel(AppLocalizations l, String? status) {
    switch (status) {
      case 'REPORTED': return l.t('patrol.reported');
      case 'INVESTIGATING': return l.t('patrol.investigating');
      case 'RESOLVED': return l.t('patrol.resolved');
      default: return status ?? '';
    }
  }

  IconData _shiftIcon(String? shift) {
    switch (shift) {
      case 'MORNING': return Icons.wb_sunny_rounded;
      case 'AFTERNOON': return Icons.wb_cloudy_rounded;
      case 'NIGHT': return Icons.nights_stay_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  IconData _incidentTypeIcon(String? type) {
    switch (type) {
      case 'SECURITY': return Icons.security_rounded;
      case 'MAINTENANCE': return Icons.build_rounded;
      case 'SAFETY': return Icons.health_and_safety_rounded;
      case 'NOISE': return Icons.volume_up_rounded;
      case 'TRESPASS': return Icons.no_accounts_rounded;
      default: return Icons.report_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.watch<LocaleCubit>();
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;

    return BlocBuilder<_Cu, _St>(
      builder: (context, state) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () { if (context.canPop()) context.pop(); else context.go('/more'); },
                      child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.t('nav.guardPatrol'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(l.t('patrol.rounds'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                    ])),
                    if (isAdmin)
                      IconButton(
                        icon: Icon(Icons.add_rounded, color: AppColors.primary),
                        onPressed: () => _tabController.index == 0
                            ? _showStartRound(context, l)
                            : _tabController.index == 1
                                ? _showAddCheckpoint(context, l)
                                : _showReportIncident(context, l, isAdmin),
                      ),
                  ]),
                ),
                // Tabs
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: l.t('patrol.rounds')),
                    Tab(text: l.t('patrol.checkpoints')),
                    Tab(text: l.t('patrol.incidents')),
                  ],
                ),
                Expanded(
                  child: state.loading
                      ? const ShimmerLoading()
                      : state.error != null
                          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.error_outline_rounded, size: 40, color: AppColors.textTertiary),
                              const SizedBox(height: 8),
                              Text(l.t('common.error'), style: TextStyle(color: AppColors.textTertiary)),
                              TextButton(onPressed: () => context.read<_Cu>().load(), child: Text(l.t('common.retry'))),
                            ]))
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _RoundsTab(
                                  rounds: state.rounds,
                                  isAdmin: isAdmin,
                                  shiftIcon: _shiftIcon,
                                  statusColor: _roundStatusColor,
                                  statusLabel: (s) => _roundStatusLabel(l, s),
                                  onStartRound: () => _showStartRound(context, l),
                                  onRefresh: () => context.read<_Cu>().load(),
                                  l: l,
                                ),
                                _CheckpointsTab(
                                  checkpoints: state.checkpoints,
                                  isAdmin: isAdmin,
                                  onAdd: () => _showAddCheckpoint(context, l),
                                  onDelete: (id) async {
                                    await api.delete('/patrol/checkpoints/$id');
                                    if (context.mounted) context.read<_Cu>().load();
                                  },
                                  onRefresh: () => context.read<_Cu>().load(),
                                  l: l,
                                ),
                                _IncidentsTab(
                                  incidents: state.incidents,
                                  isAdmin: isAdmin,
                                  severityColor: _severityColor,
                                  statusColor: _incidentStatusColor,
                                  statusLabel: (s) => _incidentStatusLabel(l, s),
                                  typeIcon: _incidentTypeIcon,
                                  onReport: () => _showReportIncident(context, l, isAdmin),
                                  onUpdateStatus: (id) => _showUpdateIncidentStatus(context, l, id),
                                  onRefresh: () => context.read<_Cu>().load(),
                                  l: l,
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ),
          floatingActionButton: !state.loading
              ? FloatingActionButton(
                  onPressed: () {
                    if (_tabController.index == 0 && isAdmin) {
                      _showStartRound(context, l);
                    } else if (_tabController.index == 1 && isAdmin) {
                      _showAddCheckpoint(context, l);
                    } else if (_tabController.index == 2) {
                      _showReportIncident(context, l, isAdmin);
                    }
                  },
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                )
              : null,
        );
      },
    );
  }

  void _showStartRound(BuildContext ctx, AppLocalizations l) {
    final cubit = ctx.read<_Cu>();
    String guardName = '';
    String shiftType = 'MORNING';

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (c) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: StatefulBuilder(builder: (c, setState) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.t('patrol.startRound'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => guardName = v,
            decoration: InputDecoration(labelText: l.t('patrol.guardName')),
          ),
          const SizedBox(height: 12),
          Text(l.t('patrol.shift'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(children: [
            for (final s in [('MORNING', l.t('patrol.morning')), ('AFTERNOON', l.t('patrol.afternoon')), ('NIGHT', l.t('patrol.night'))])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s.$2, style: TextStyle(fontSize: 11, color: shiftType == s.$1 ? Colors.white : AppColors.textSecondary)),
                  selected: shiftType == s.$1,
                  selectedColor: AppColors.primary,
                  onSelected: (_) => setState(() => shiftType = s.$1),
                ),
              ),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(c),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(l.t('common.cancel')),
            )),
            const SizedBox(width: 12),
            Expanded(child: GradientButton(label: l.t('patrol.startRound'), onPressed: () async {
              if (guardName.isEmpty) return;
              try {
                await api.post('/patrol/rounds', data: {'guardName': guardName, 'shiftType': shiftType});
                if (c.mounted) Navigator.pop(c);
                if (c.mounted) cubit.load();
              } catch (e) {
                if (c.mounted) {
                  ScaffoldMessenger.of(c).showSnackBar(
                    SnackBar(content: Text(e is DioException ? (e.response?.data?['error'] ?? l.t('common.requestFailed')) : l.t('common.requestFailed'))),
                  );
                }
              }
            })),
          ]),
        ]),
        ),
      )),
    );
  }

  void _showAddCheckpoint(BuildContext ctx, AppLocalizations l) {
    final cubit = ctx.read<_Cu>();
    String name = '';
    String nameMr = '';
    String location = '';

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (c) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.t('patrol.addCheckpoint'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(onChanged: (v) => name = v, decoration: InputDecoration(labelText: l.t('patrol.checkpoint'))),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => nameMr = v, decoration: const InputDecoration(labelText: 'Checkpoint Name (Marathi)')),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => location = v, decoration: InputDecoration(labelText: l.t('patrol.location'))),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(c),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(l.t('common.cancel')),
            )),
            const SizedBox(width: 12),
            Expanded(child: GradientButton(label: l.t('common.save'), onPressed: () async {
              if (name.isEmpty) return;
              try {
                await api.post('/patrol/checkpoints', data: {'name': name, 'nameMr': nameMr, 'location': location});
                if (c.mounted) Navigator.pop(c);
                if (c.mounted) cubit.load();
              } catch (e) {
                if (c.mounted) {
                  ScaffoldMessenger.of(c).showSnackBar(
                    SnackBar(content: Text(e is DioException ? (e.response?.data?['error'] ?? l.t('common.requestFailed')) : l.t('common.requestFailed'))),
                  );
                }
              }
            })),
          ]),
        ]),
        ),
      ),
    );
  }

  void _showReportIncident(BuildContext ctx, AppLocalizations l, bool isAdmin) {
    final cubit = ctx.read<_Cu>();
    String title = '';
    String description = '';
    String incidentType = 'SECURITY';
    String severity = 'LOW';
    String location = '';

    final types = {
      'SECURITY': l.t('patrol.security'),
      'MAINTENANCE': l.t('patrol.maintenance'),
      'SAFETY': l.t('patrol.safety'),
      'NOISE': l.t('patrol.noise'),
      'TRESPASS': l.t('patrol.trespass'),
      'OTHER': l.t('visitor.typeOther'),
    };

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (c) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: StatefulBuilder(builder: (c, setState) => SingleChildScrollView(
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.t('patrol.reportIncident'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Text(l.t('patrol.incidentType'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: types.entries.map((e) {
            final sel = incidentType == e.key;
            return ChoiceChip(
              label: Text(e.value, style: TextStyle(fontSize: 11, color: sel ? Colors.white : AppColors.textSecondary)),
              selected: sel,
              selectedColor: AppColors.primary,
              onSelected: (_) => setState(() => incidentType = e.key),
            );
          }).toList()),
          const SizedBox(height: 12),
          Text(l.t('patrol.severity'), style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(children: [
            for (final sev in [
              ('LOW', l.t('patrol.low'), const Color(0xFF10B981)),
              ('MEDIUM', l.t('patrol.medium'), const Color(0xFF3B82F6)),
              ('HIGH', l.t('patrol.high'), const Color(0xFFF97316)),
              ('CRITICAL', l.t('patrol.critical'), const Color(0xFFEF4444)),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(sev.$2, style: TextStyle(fontSize: 10, color: severity == sev.$1 ? Colors.white : AppColors.textSecondary)),
                  selected: severity == sev.$1,
                  selectedColor: sev.$3,
                  onSelected: (_) => setState(() => severity = sev.$1),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => title = v, decoration: InputDecoration(labelText: l.t('helpdesk.subject'))),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => description = v, maxLines: 3, decoration: InputDecoration(labelText: l.t('helpdesk.description'))),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => location = v, decoration: InputDecoration(labelText: l.t('patrol.location'))),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(c),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(l.t('common.cancel')),
            )),
            const SizedBox(width: 12),
            Expanded(child: GradientButton(label: l.t('patrol.reportIncident'), onPressed: () async {
              if (title.isEmpty) return;
              try {
                await api.post('/patrol/incidents', data: {
                  'title': title,
                  'description': description,
                  'incidentType': incidentType,
                  'severity': severity,
                  'location': location,
                });
                if (c.mounted) Navigator.pop(c);
                if (c.mounted) cubit.load();
              } catch (e) {
                if (c.mounted) {
                  ScaffoldMessenger.of(c).showSnackBar(
                    SnackBar(content: Text(e is DioException ? (e.response?.data?['error'] ?? l.t('common.requestFailed')) : l.t('common.requestFailed'))),
                  );
                }
              }
            })),
          ]),
        ]),
        ),
      ),
      ),
      ),
    );
  }

  void _showUpdateIncidentStatus(BuildContext ctx, AppLocalizations l, String id) {
    final cubit = ctx.read<_Cu>();
    String status = 'INVESTIGATING';
    String notes = '';

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (c) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: StatefulBuilder(builder: (c, setState) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.t('common.updateStatus'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in [
              ('INVESTIGATING', l.t('patrol.investigating')),
              ('RESOLVED', l.t('patrol.resolved')),
              ('CLOSED', l.t('helpdesk.closed')),
            ])
              ChoiceChip(
                label: Text(s.$2, style: TextStyle(fontSize: 11, color: status == s.$1 ? Colors.white : AppColors.textSecondary)),
                selected: status == s.$1,
                selectedColor: AppColors.primary,
                onSelected: (_) => setState(() => status = s.$1),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => notes = v, maxLines: 2, decoration: InputDecoration(labelText: l.t('common.notes'))),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(c),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(l.t('common.cancel')),
            )),
            const SizedBox(width: 12),
            Expanded(child: GradientButton(label: l.t('common.save'), onPressed: () async {
              try {
                await api.put('/patrol/incidents/$id/status', data: {'status': status, 'notes': notes});
                if (c.mounted) Navigator.pop(c);
                if (c.mounted) cubit.load();
              } catch (e) {
                if (c.mounted) {
                  ScaffoldMessenger.of(c).showSnackBar(
                    SnackBar(content: Text(e is DioException ? (e.response?.data?['error'] ?? l.t('common.requestFailed')) : l.t('common.requestFailed'))),
                  );
                }
              }
            })),
          ]),
        ]),
        ),
      ),
      ),
    );
  }
}

// ── Rounds Tab ────────────────────────────────────────────────

class _RoundsTab extends StatelessWidget {
  final List<Map<String, dynamic>> rounds;
  final bool isAdmin;
  final IconData Function(String?) shiftIcon;
  final Color Function(String?) statusColor;
  final String Function(String?) statusLabel;
  final VoidCallback onStartRound;
  final VoidCallback onRefresh;
  final AppLocalizations l;

  const _RoundsTab({
    required this.rounds,
    required this.isAdmin,
    required this.shiftIcon,
    required this.statusColor,
    required this.statusLabel,
    required this.onStartRound,
    required this.onRefresh,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppColors.primary,
      child: rounds.isEmpty
          ? ListView(children: [
              const SizedBox(height: 80),
              Center(child: Column(children: [
                Icon(Icons.security_rounded, size: 48, color: AppColors.textTertiary.withAlpha(80)),
                const SizedBox(height: 12),
                Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)),
                if (isAdmin) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: onStartRound,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l.t('patrol.startRound')),
                  ),
                ],
              ])),
            ])
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rounds.length,
              itemBuilder: (context, i) {
                final r = rounds[i];
                final status = r['status'] as String?;
                final sColor = statusColor(status);
                final shift = r['shiftType'] as String?;
                final scanned = r['scannedCheckpoints'] ?? 0;
                final total = r['totalCheckpoints'] ?? 0;

                return GlassCard(
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: sColor.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                      child: Icon(shiftIcon(shift), size: 22, color: sColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(r['guardName'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: sColor.withAlpha(25), borderRadius: BorderRadius.circular(6)),
                          child: Text(statusLabel(status), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: sColor)),
                        ),
                      ]),
                      const SizedBox(height: 3),
                      Text('${shift ?? ''} • ${l.t('patrol.scanned')}: $scanned/$total', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                    ])),
                  ]),
                );
              },
            ),
    );
  }
}

// ── Checkpoints Tab ───────────────────────────────────────────

class _CheckpointsTab extends StatelessWidget {
  final List<Map<String, dynamic>> checkpoints;
  final bool isAdmin;
  final VoidCallback onAdd;
  final Future<void> Function(String) onDelete;
  final VoidCallback onRefresh;
  final AppLocalizations l;

  const _CheckpointsTab({
    required this.checkpoints,
    required this.isAdmin,
    required this.onAdd,
    required this.onDelete,
    required this.onRefresh,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppColors.primary,
      child: checkpoints.isEmpty
          ? ListView(children: [
              const SizedBox(height: 80),
              Center(child: Column(children: [
                Icon(Icons.qr_code_rounded, size: 48, color: AppColors.textTertiary.withAlpha(80)),
                const SizedBox(height: 12),
                Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)),
                if (isAdmin) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l.t('patrol.addCheckpoint')),
                  ),
                ],
              ])),
            ])
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: checkpoints.length,
              itemBuilder: (context, i) {
                final cp = checkpoints[i];
                final isActive = cp['isActive'] as bool? ?? true;

                return GlassCard(
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary.withAlpha(25) : AppColors.border.withAlpha(60),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.qr_code_rounded, size: 22, color: isActive ? AppColors.primary : AppColors.textTertiary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cp['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      if ((cp['location'] as String?)?.isNotEmpty == true)
                        Text(cp['location'] as String, style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                    ])),
                    if (isAdmin)
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.textTertiary),
                        onPressed: () => onDelete(cp['id'] as String),
                      ),
                  ]),
                );
              },
            ),
    );
  }
}

// ── Incidents Tab ─────────────────────────────────────────────

class _IncidentsTab extends StatelessWidget {
  final List<Map<String, dynamic>> incidents;
  final bool isAdmin;
  final Color Function(String?) severityColor;
  final Color Function(String?) statusColor;
  final String Function(String?) statusLabel;
  final IconData Function(String?) typeIcon;
  final VoidCallback onReport;
  final void Function(String) onUpdateStatus;
  final VoidCallback onRefresh;
  final AppLocalizations l;

  const _IncidentsTab({
    required this.incidents,
    required this.isAdmin,
    required this.severityColor,
    required this.statusColor,
    required this.statusLabel,
    required this.typeIcon,
    required this.onReport,
    required this.onUpdateStatus,
    required this.onRefresh,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppColors.primary,
      child: incidents.isEmpty
          ? ListView(children: [
              const SizedBox(height: 80),
              Center(child: Column(children: [
                Icon(Icons.report_outlined, size: 48, color: AppColors.textTertiary.withAlpha(80)),
                const SizedBox(height: 12),
                Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: onReport,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.t('patrol.reportIncident')),
                ),
              ])),
            ])
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: incidents.length,
              itemBuilder: (context, i) {
                final inc = incidents[i];
                final severity = inc['severity'] as String?;
                final status = inc['status'] as String?;
                final sColor = severityColor(severity);
                final stColor = statusColor(status);

                return GlassCard(
                  onTap: isAdmin ? () => onUpdateStatus(inc['id'] as String) : null,
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: sColor.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                      child: Icon(typeIcon(inc['incidentType'] as String?), size: 22, color: sColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(inc['title'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: stColor.withAlpha(25), borderRadius: BorderRadius.circular(6)),
                          child: Text(statusLabel(status), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: stColor)),
                        ),
                      ]),
                      const SizedBox(height: 3),
                      Row(children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: sColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text('${inc['incidentType'] ?? ''} • ${inc['reportedByName'] ?? ''}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                      ]),
                    ])),
                    if (isAdmin)
                      Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textTertiary),
                  ]),
                );
              },
            ),
    );
  }
}
