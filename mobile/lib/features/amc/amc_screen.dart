import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ─── State ────────────────────────────────────────────────────────

class _St extends Equatable {
  final bool loading;
  final List<Map<String, dynamic>> contracts;
  final Map<String, dynamic> summary;
  const _St({this.loading = false, this.contracts = const [], this.summary = const {}});
  @override List<Object?> get props => [loading, contracts, summary];
}

class _Cu extends Cubit<_St> {
  _Cu() : super(const _St());
  Future<void> load() async {
    emit(const _St(loading: true));
    try {
      final results = await Future.wait([
        api.get('/amc-contracts'),
        api.get('/amc-contracts/summary'),
      ]);
      final contracts = (results[0].data['contracts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final summary = results[1].data as Map<String, dynamic>? ?? {};
      emit(_St(contracts: contracts, summary: summary));
    } catch (_) {
      emit(const _St());
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────

class AMCScreen extends StatelessWidget {
  const AMCScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => _Cu()..load(), child: const _Body());
  }
}

class _Body extends StatelessWidget {
  const _Body();

  bool _isAdmin(BuildContext context) {
    final s = context.read<AuthBloc>().state;
    return s is Authenticated && s.user.role == 'ADMIN';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); context.watch<LocaleCubit>();
    final isAdmin = _isAdmin(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('amc.title')),
        actions: [
          if (isAdmin) IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddContract(context, l)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<_Cu>().load(),
        child: BlocBuilder<_Cu, _St>(builder: (context, state) {
          if (state.loading) return const ShimmerLoading(itemCount: 5);
          return CustomScrollView(slivers: [
            // Summary cards
            SliverToBoxAdapter(child: _SummarySection(summary: state.summary, l: l)),

            if (state.contracts.isEmpty)
              SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.all(40),
                child: Center(child: Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary))),
              ))
            else
              SliverList(delegate: SliverChildBuilderDelegate(
                (_, i) => _ContractCard(contract: state.contracts[i], l: l),
                childCount: state.contracts.length,
              )),
          ]);
        }),
      ),
    );
  }

  void _showAddContract(BuildContext context, AppLocalizations l) {
    final descCtl = TextEditingController();
    final amountCtl = TextEditingController();
    final startCtl = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));
    final endCtl = TextEditingController(text: DateTime.now().add(const Duration(days: 365)).toIso8601String().substring(0, 10));
    String serviceType = 'ELEVATOR';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (sheetCtx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: StatefulBuilder(
        builder: (ctx2, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.t('amc.addContract'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: serviceType,
                decoration: InputDecoration(labelText: l.t('amc.serviceType'), border: const OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'ELEVATOR', child: Text('Elevator / Lift')),
                  DropdownMenuItem(value: 'FIRE_SAFETY', child: Text('Fire Safety')),
                  DropdownMenuItem(value: 'PEST_CONTROL', child: Text('Pest Control')),
                  DropdownMenuItem(value: 'WATER_TANK', child: Text('Water Tank Cleaning')),
                  DropdownMenuItem(value: 'CCTV', child: Text('CCTV')),
                  DropdownMenuItem(value: 'GENERATOR', child: Text('Generator')),
                  DropdownMenuItem(value: 'GARDEN', child: Text('Garden')),
                  DropdownMenuItem(value: 'HOUSEKEEPING', child: Text('Housekeeping')),
                  DropdownMenuItem(value: 'PLUMBING', child: Text('Plumbing')),
                  DropdownMenuItem(value: 'ELECTRICAL', child: Text('Electrical')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) => setSheetState(() => serviceType = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: descCtl,
                  decoration: InputDecoration(labelText: l.t('amc.description'), border: const OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: amountCtl,
                  decoration: InputDecoration(labelText: l.t('amc.contractAmount'), border: const OutlineInputBorder(), prefixText: '\u20B9 '),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: startCtl, readOnly: true,
                    decoration: InputDecoration(labelText: l.t('amc.startDate'), border: const OutlineInputBorder()),
                    onTap: () async {
                      final d = await showDatePicker(context: ctx2, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (d != null) startCtl.text = d.toIso8601String().substring(0, 10);
                    })),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: endCtl, readOnly: true,
                    decoration: InputDecoration(labelText: l.t('amc.endDate'), border: const OutlineInputBorder()),
                    onTap: () async {
                      final d = await showDatePicker(context: ctx2, initialDate: DateTime.now().add(const Duration(days: 365)), firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (d != null) endCtl.text = d.toIso8601String().substring(0, 10);
                    })),
              ]),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: () async {
                  try {
                    // For MVP, use first vendor or create without vendorId
                    // In full implementation, add vendor picker
                    await api.post('/amc-contracts', data: {
                      'vendorId': '00000000-0000-0000-0000-000000000000', // placeholder
                      'serviceType': serviceType,
                      'description': descCtl.text.trim(),
                      'contractAmount': double.tryParse(amountCtl.text) ?? 0,
                      'startDate': startCtl.text,
                      'endDate': endCtl.text,
                    });
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                    if (context.mounted) context.read<_Cu>().load();
                  } catch (e) {
                    if (sheetCtx.mounted) {
                      ScaffoldMessenger.of(sheetCtx).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                    }
                  }
                },
                child: Text(l.t('common.save')),
              )),
            ],
          )),
        ),
      )),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final Map<String, dynamic> summary;
  final AppLocalizations l;
  const _SummarySection({required this.summary, required this.l});

  @override
  Widget build(BuildContext context) {
    final active = (summary['activeContracts'] ?? 0) as int;
    final expiring = (summary['expiringSoon'] ?? 0) as int;
    final expired = (summary['expiredContracts'] ?? 0) as int;
    final total = ((summary['totalContractValue'] ?? 0) as num).toDouble();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        _SummaryTile(label: l.t('amc.active'), value: '$active', color: Colors.green),
        const SizedBox(width: 8),
        _SummaryTile(label: l.t('amc.expiring'), value: '$expiring', color: Colors.orange),
        const SizedBox(width: 8),
        _SummaryTile(label: l.t('amc.expired'), value: '$expired', color: Colors.red),
        const SizedBox(width: 8),
        _SummaryTile(label: l.t('amc.totalValue'), value: '\u20B9${(total / 1000).toStringAsFixed(0)}K', color: AppColors.primary),
      ]),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, color: color), textAlign: TextAlign.center),
      ]),
    ));
  }
}

class _ContractCard extends StatelessWidget {
  final Map<String, dynamic> contract;
  final AppLocalizations l;
  const _ContractCard({required this.contract, required this.l});

  IconData _serviceIcon(String type) {
    switch (type) {
      case 'ELEVATOR': return Icons.elevator;
      case 'FIRE_SAFETY': return Icons.local_fire_department;
      case 'PEST_CONTROL': return Icons.bug_report;
      case 'WATER_TANK': return Icons.water_drop;
      case 'CCTV': return Icons.videocam;
      case 'GENERATOR': return Icons.power;
      case 'GARDEN': return Icons.nature;
      case 'HOUSEKEEPING': return Icons.cleaning_services;
      case 'PLUMBING': return Icons.plumbing;
      case 'ELECTRICAL': return Icons.electrical_services;
      default: return Icons.handyman;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = contract['serviceType'] ?? '';
    final desc = contract['description'] ?? '';
    final amount = ((contract['contractAmount'] ?? 0) as num).toDouble();
    final status = contract['status'] ?? '';
    final vendor = contract['vendor'] as Map<String, dynamic>?;
    final vendorName = vendor?['name'] ?? '';
    final startDate = contract['startDate']?.toString().substring(0, 10) ?? '';
    final endDate = contract['endDate']?.toString().substring(0, 10) ?? '';

    // Calculate days until expiry
    int daysLeft = 0;
    bool isExpiring = false;
    bool isExpired = false;
    try {
      final end = DateTime.parse(endDate);
      daysLeft = end.difference(DateTime.now()).inDays;
      isExpiring = daysLeft > 0 && daysLeft <= 30;
      isExpired = daysLeft < 0;
    } catch (_) {}

    Color statusColor = isExpired ? Colors.red : isExpiring ? Colors.orange : Colors.green;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_serviceIcon(type), color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type.replaceAll('_', ' '), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              if (desc.isNotEmpty) Text(desc, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('\u20B9${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withAlpha(20), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  isExpired ? '${l.t('amc.expired')} (${-daysLeft}d)' :
                  isExpiring ? '${daysLeft}d ${l.t('amc.left')}' :
                  status,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ),
            ]),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            if (vendorName.isNotEmpty) ...[
              Icon(Icons.business, size: 12, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(vendorName, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(width: 12),
            ],
            Icon(Icons.date_range, size: 12, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Text('$startDate \u2192 $endDate', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ]),
      ),
    );
  }
}
