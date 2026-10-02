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
  final List<Map<String, dynamic>> visitors;
  final List<Map<String, dynamic>> frequentVisitors;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> flats;
  const _St({
    this.loading = false,
    this.error,
    this.visitors = const [],
    this.frequentVisitors = const [],
    this.summary = const {},
    this.flats = const [],
  });
}

class _Cu extends Cubit<_St> {
  _Cu() : super(const _St());

  Future<void> load() async {
    emit(const _St(loading: true));
    try {
      final results = await Future.wait([
        api.get('/visitors'),
        api.get('/visitors/today-summary'),
        api.get('/frequent-visitors'),
        api.get('/flats'),
      ]);
      final visitors = (results[0].data['visitors'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      final summary = results[1].data is Map<String, dynamic> ? results[1].data as Map<String, dynamic> : <String, dynamic>{};
      final fv = (results[2].data['frequentVisitors'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      final flats = (results[3].data['flats'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      emit(_St(visitors: visitors, summary: summary, frequentVisitors: fv, flats: flats));
    } catch (e) {
      emit(_St(error: e.toString()));
    }
  }
}

// ── Screen ────────────────────────────────────────────────────

class VisitorScreen extends StatelessWidget {
  const VisitorScreen({super.key});

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
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.watch<LocaleCubit>();
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<_Cu>().load(),
          color: AppColors.primary,
          child: BlocBuilder<_Cu, _St>(
            builder: (context, state) {
              return NestedScrollView(
                headerSliverBuilder: (context, _) => [
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
                          Text(l.t('visitor.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(l.t('visitor.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        ])),
                      ]),
                    ),
                  ),

                  // Summary tiles
                  if (!state.loading)
                    SliverToBoxAdapter(child: _SummaryRow(summary: state.summary)),

                  // Tabs
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: TabBar(
                          controller: _tabCtrl,
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelColor: AppColors.primary,
                          unselectedLabelColor: AppColors.textTertiary,
                          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          tabs: [
                            Tab(text: l.t('visitor.entryLog')),
                            Tab(text: l.t('visitor.frequentVisitors')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                body: state.loading
                    ? const ShimmerLoading()
                    : state.error != null
                        ? Center(child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: AppColors.urgent),
                              const SizedBox(height: 8),
                              Text(state.error!, style: TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () => context.read<_Cu>().load(),
                                child: Text(l.t('common.retry'), style: TextStyle(color: AppColors.primary)),
                              ),
                            ],
                          ))
                        : TabBarView(
                            controller: _tabCtrl,
                            children: [
                              _EntryLogTab(visitors: state.visitors, isAdmin: isAdmin),
                              _FrequentTab(frequentVisitors: state.frequentVisitors, flats: state.flats, isAdmin: isAdmin),
                            ],
                          ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: BlocBuilder<_Cu, _St>(
        builder: (context, state) {
          return FloatingActionButton(
            onPressed: () => _showAddVisitor(context, l, state.flats),
            child: const Icon(Icons.person_add_rounded, size: 24),
          );
        },
      ),
    );
  }

  void _showAddVisitor(BuildContext ctx, AppLocalizations l, List<Map<String, dynamic>> flats) {
    final cubit = ctx.read<_Cu>();
    final authState = ctx.read<AuthBloc>().state;
    final userFlatId = authState is Authenticated ? authState.user.flatId : null;
    final userFlatNo = authState is Authenticated ? authState.user.flatNumber : '';
    final isAdmin = authState is Authenticated && authState.user.isAdmin;

    String name = '';
    String phone = '';
    String purpose = '';
    String vehicleNo = '';
    String companyName = '';
    String selectedType = 'GUEST';
    String? selectedFlatId = userFlatId;
    String selectedFlatNo = userFlatNo;

    final types = {
      'GUEST': l.t('visitor.typeGuest'),
      'DELIVERY': l.t('visitor.typeDelivery'),
      'CAB': l.t('visitor.typeCab'),
      'DOMESTIC_HELP': l.t('visitor.typeDomesticHelp'),
      'MAINTENANCE': l.t('visitor.typeMaintenance'),
      'OTHER': l.t('visitor.typeOther'),
    };

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (c) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: StatefulBuilder(builder: (c, setState) => Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.t('visitor.addVisitor'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          // Visitor type chips
          Wrap(spacing: 8, runSpacing: 8, children: types.entries.map((e) {
            final selected = selectedType == e.key;
            return ChoiceChip(
              label: Text(e.value, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textSecondary)),
              selected: selected,
              selectedColor: AppColors.primary,
              onSelected: (_) => setState(() => selectedType = e.key),
            );
          }).toList()),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => name = v,
            decoration: InputDecoration(labelText: l.t('visitor.name')),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => phone = v,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l.t('visitor.phone')),
          ),
          const SizedBox(height: 12),
          // Flat selector (admin can pick any flat)
          if (isAdmin && flats.isNotEmpty)
            DropdownButtonFormField<String>(
              value: selectedFlatId,
              decoration: InputDecoration(labelText: l.t('visitor.flatNo')),
              items: flats.map((f) => DropdownMenuItem(
                value: f['id'] as String?,
                child: Text(f['flatNumber'] ?? ''),
              )).toList(),
              onChanged: (v) {
                setState(() {
                  selectedFlatId = v;
                  selectedFlatNo = flats.firstWhere((f) => f['id'] == v, orElse: () => {})['flatNumber'] ?? '';
                });
              },
            ),
          if (!isAdmin)
            TextField(
              readOnly: true,
              controller: TextEditingController(text: selectedFlatNo),
              decoration: InputDecoration(labelText: l.t('visitor.flatNo')),
            ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => purpose = v,
            decoration: InputDecoration(labelText: l.t('visitor.purpose')),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => vehicleNo = v,
            decoration: InputDecoration(labelText: l.t('visitor.vehicleNo')),
          ),
          if (selectedType == 'DELIVERY' || selectedType == 'CAB') ...[
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => companyName = v,
              decoration: InputDecoration(labelText: l.t('visitor.company')),
            ),
          ],
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
              if (name.isEmpty || selectedFlatId == null) return;
              try {
                await api.post('/visitors', data: {
                  'name': name,
                  'phone': phone,
                  'visitorType': selectedType,
                  'purpose': purpose,
                  'flatId': selectedFlatId,
                  'flatNo': selectedFlatNo,
                  'vehicleNo': vehicleNo,
                  'companyName': companyName,
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
        ])),
      )),
    ),
    );
  }
}

// ── Summary Row ───────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _SummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final total = summary['total'] ?? 0;
    final checkedIn = summary['checkedIn'] ?? 0;
    final pending = summary['pending'] ?? 0;
    final checkedOut = summary['checkedOut'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        _StatTile(label: l.t('visitor.total'), value: '$total', color: AppColors.primary),
        const SizedBox(width: 8),
        _StatTile(label: l.t('visitor.checkedIn'), value: '$checkedIn', color: const Color(0xFF10B981)),
        const SizedBox(width: 8),
        _StatTile(label: l.t('visitor.pending'), value: '$pending', color: const Color(0xFFF97316)),
        const SizedBox(width: 8),
        _StatTile(label: l.t('visitor.checkedOut'), value: '$checkedOut', color: const Color(0xFF64748B)),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: color.withAlpha(180)), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ── Entry Log Tab ─────────────────────────────────────────────

class _EntryLogTab extends StatelessWidget {
  final List<Map<String, dynamic>> visitors;
  final bool isAdmin;
  const _EntryLogTab({required this.visitors, required this.isAdmin});

  IconData _iconForType(String? type) {
    switch (type) {
      case 'GUEST': return Icons.person_rounded;
      case 'DELIVERY': return Icons.local_shipping_rounded;
      case 'CAB': return Icons.local_taxi_rounded;
      case 'DOMESTIC_HELP': return Icons.cleaning_services_rounded;
      case 'MAINTENANCE': return Icons.build_rounded;
      default: return Icons.person_outline_rounded;
    }
  }

  Color _colorForStatus(String? status) {
    switch (status) {
      case 'PENDING': return const Color(0xFFF97316);
      case 'APPROVED': case 'CHECKED_IN': return const Color(0xFF10B981);
      case 'CHECKED_OUT': return const Color(0xFF64748B);
      case 'REJECTED': return const Color(0xFFEF4444);
      default: return const Color(0xFF64748B);
    }
  }

  String _statusLabel(AppLocalizations l, String? status) {
    switch (status) {
      case 'PENDING': return l.t('visitor.pending');
      case 'APPROVED': case 'CHECKED_IN': return l.t('visitor.checkedIn');
      case 'CHECKED_OUT': return l.t('visitor.checkedOut');
      case 'REJECTED': return l.t('visitor.rejected');
      default: return status ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (visitors.isEmpty) {
      return Center(child: Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      itemCount: visitors.length,
      itemBuilder: (context, i) {
        final v = visitors[i];
        final status = v['status'] as String?;
        final statusColor = _colorForStatus(status);
        final type = v['visitorType'] as String?;
        final entryTime = v['entryTime'] != null ? DateTime.tryParse(v['entryTime']) : null;
        final exitTime = v['exitTime'] != null ? DateTime.tryParse(v['exitTime']) : null;

        return GlassCard(
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: statusColor.withAlpha(25), borderRadius: BorderRadius.circular(12)),
              child: Icon(_iconForType(type), size: 22, color: statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(v['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withAlpha(25), borderRadius: BorderRadius.circular(6)),
                  child: Text(_statusLabel(l, status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ]),
              const SizedBox(height: 3),
              Text(
                '${v['flatNo'] ?? ''} • ${_typeLabel(l, type)}${v['companyName'] != null && v['companyName'].toString().isNotEmpty ? ' (${v['companyName']})' : ''}',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              if (v['purpose'] != null && v['purpose'].toString().isNotEmpty)
                Text(v['purpose'], style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              if (entryTime != null)
                Text('In: ${_formatTime(entryTime)}${exitTime != null ? '  Out: ${_formatTime(exitTime)}' : ''}',
                    style: TextStyle(fontSize: 10, color: AppColors.textTertiary, fontFamily: 'monospace')),
            ])),
            if (isAdmin && status == 'PENDING') ...[
              const SizedBox(width: 8),
              _ActionButton(icon: Icons.check_rounded, color: const Color(0xFF10B981), onTap: () => _approve(context, v['id'])),
              const SizedBox(width: 4),
              _ActionButton(icon: Icons.close_rounded, color: const Color(0xFFEF4444), onTap: () => _reject(context, v['id'])),
            ],
            if (status == 'APPROVED' || status == 'CHECKED_IN')
              _ActionButton(icon: Icons.logout_rounded, color: const Color(0xFF64748B), onTap: () => _checkout(context, v['id'])),
          ]),
        );
      },
    );
  }

  String _typeLabel(AppLocalizations l, String? type) {
    switch (type) {
      case 'GUEST': return l.t('visitor.typeGuest');
      case 'DELIVERY': return l.t('visitor.typeDelivery');
      case 'CAB': return l.t('visitor.typeCab');
      case 'DOMESTIC_HELP': return l.t('visitor.typeDomesticHelp');
      case 'MAINTENANCE': return l.t('visitor.typeMaintenance');
      default: return l.t('visitor.typeOther');
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _approve(BuildContext ctx, String? id) async {
    if (id == null) return;
    try {
      await api.post('/visitors/$id/approve');
      if (ctx.mounted) ctx.read<_Cu>().load();
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(e is DioException ? (e.response?.data?['error'] ?? 'Request failed') : 'Request failed')),
        );
      }
    }
  }

  void _reject(BuildContext ctx, String? id) async {
    if (id == null) return;
    try {
      await api.post('/visitors/$id/reject');
      if (ctx.mounted) ctx.read<_Cu>().load();
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(e is DioException ? (e.response?.data?['error'] ?? 'Request failed') : 'Request failed')),
        );
      }
    }
  }

  void _checkout(BuildContext ctx, String? id) async {
    if (id == null) return;
    try {
      await api.post('/visitors/$id/checkout');
      if (ctx.mounted) ctx.read<_Cu>().load();
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(e is DioException ? (e.response?.data?['error'] ?? 'Request failed') : 'Request failed')),
        );
      }
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ── Frequent Visitors Tab ─────────────────────────────────────

class _FrequentTab extends StatelessWidget {
  final List<Map<String, dynamic>> frequentVisitors;
  final List<Map<String, dynamic>> flats;
  final bool isAdmin;
  const _FrequentTab({required this.frequentVisitors, required this.flats, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;

    if (frequentVisitors.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textTertiary.withAlpha(80)),
        const SizedBox(height: 12),
        Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _showAddFrequent(context, l, flats),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text(l.t('visitor.addFrequent')),
        ),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      itemCount: frequentVisitors.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: OutlinedButton.icon(
              onPressed: () => _showAddFrequent(context, l, flats),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(l.t('visitor.addFrequent')),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          );
        }
        final fv = frequentVisitors[i - 1];
        final name = (isMr ? fv['nameMr'] : null) ?? fv['name'] ?? '';
        final role = (isMr ? fv['roleMr'] : null) ?? fv['role'] ?? '';
        final blacklisted = fv['isBlacklisted'] == true;

        return GlassCard(
          borderColor: blacklisted ? const Color(0xFFEF4444).withAlpha(40) : null,
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: blacklisted ? const Color(0xFFEF4444).withAlpha(20) : const Color(0xFF3B82F6).withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                blacklisted ? Icons.block_rounded : Icons.person_rounded,
                size: 22,
                color: blacklisted ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                if (blacklisted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFEF4444).withAlpha(20), borderRadius: BorderRadius.circular(6)),
                    child: Text(l.t('visitor.blacklisted'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                  ),
              ]),
              const SizedBox(height: 2),
              Text('${fv['flatNo'] ?? ''} • $role', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              if (fv['phone'] != null && fv['phone'].toString().isNotEmpty)
                Text(fv['phone'], style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontFamily: 'monospace')),
            ])),
            if (!blacklisted && isAdmin) ...[
              _ActionButton(
                icon: Icons.block_rounded,
                color: const Color(0xFFEF4444),
                onTap: () => _blacklist(context, fv['id']),
              ),
              const SizedBox(width: 4),
            ],
            _ActionButton(
              icon: Icons.delete_outline_rounded,
              color: const Color(0xFFEF4444),
              onTap: () => _delete(context, fv['id']),
            ),
          ]),
        );
      },
    );
  }

  void _showAddFrequent(BuildContext ctx, AppLocalizations l, List<Map<String, dynamic>> flats) {
    final cubit = ctx.read<_Cu>();
    final authState = ctx.read<AuthBloc>().state;
    final userFlatId = authState is Authenticated ? authState.user.flatId : null;
    final userFlatNo = authState is Authenticated ? authState.user.flatNumber : '';

    String name = '';
    String nameMr = '';
    String phone = '';
    String role = '';
    String roleMr = '';
    String? selectedFlatId = userFlatId;
    String selectedFlatNo = userFlatNo;

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (c) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: StatefulBuilder(builder: (c, setState) => Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.t('visitor.addFrequent'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(onChanged: (v) => name = v, decoration: InputDecoration(labelText: l.t('visitor.name'))),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => nameMr = v, decoration: InputDecoration(labelText: '${l.t('visitor.name')} (MR)')),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => phone = v, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l.t('visitor.phone'))),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => role = v, decoration: InputDecoration(labelText: l.t('visitor.role'))),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => roleMr = v, decoration: InputDecoration(labelText: '${l.t('visitor.role')} (MR)')),
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
              if (name.isEmpty || selectedFlatId == null) return;
              try {
                await api.post('/frequent-visitors', data: {
                  'name': name,
                  'nameMr': nameMr,
                  'phone': phone,
                  'visitorType': 'DOMESTIC_HELP',
                  'flatId': selectedFlatId,
                  'flatNo': selectedFlatNo,
                  'role': role,
                  'roleMr': roleMr,
                });
                if (c.mounted) Navigator.pop(c);
                if (c.mounted) cubit.load();
              } catch (e) {
                if (c.mounted) {
                  ScaffoldMessenger.of(c).showSnackBar(
                    SnackBar(content: Text(e is DioException ? (e.response?.data?['error'] ?? 'Request failed') : 'Request failed')),
                  );
                }
              }
            })),
          ]),
        ])),
      )),
    ),
    );
  }

  void _blacklist(BuildContext ctx, String? id) async {
    if (id == null) return;
    try {
      await api.post('/frequent-visitors/$id/blacklist', data: {'reason': 'Blacklisted by admin'});
      if (ctx.mounted) ctx.read<_Cu>().load();
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(e is DioException ? (e.response?.data?['error'] ?? 'Request failed') : 'Request failed')),
        );
      }
    }
  }

  void _delete(BuildContext ctx, String? id) async {
    if (id == null) return;
    try {
      await api.delete('/frequent-visitors/$id');
      if (ctx.mounted) ctx.read<_Cu>().load();
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(e is DioException ? (e.response?.data?['error'] ?? 'Request failed') : 'Request failed')),
        );
      }
    }
  }
}
