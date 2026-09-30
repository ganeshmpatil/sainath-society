import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ─── State ────────────────────────────────────────────────────────

class _St extends Equatable {
  final bool loading;
  final List<Map<String, dynamic>> overrides;
  final List<Map<String, dynamic>> flats;
  final List<Map<String, dynamic>> chargeHeads;
  const _St({this.loading = false, this.overrides = const [], this.flats = const [], this.chargeHeads = const []});
  @override List<Object?> get props => [loading, overrides, flats, chargeHeads];
}

class _Cu extends Cubit<_St> {
  _Cu() : super(const _St());

  Future<void> load() async {
    emit(const _St(loading: true));
    try {
      final results = await Future.wait([
        api.get('/finance/charge-overrides'),
        api.get('/flats'),
        api.get('/finance/billing-structure'),
      ]);
      final overrides = (results[0].data['overrides'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final flats = (results[1].data['flats'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      // Extract charge heads from active billing structure
      final bsData = results[2].data;
      List<Map<String, dynamic>> heads = [];
      if (bsData != null && bsData['chargeHeads'] != null) {
        heads = (bsData['chargeHeads'] as List).cast<Map<String, dynamic>>();
      }
      emit(_St(overrides: overrides, flats: flats, chargeHeads: heads));
    } catch (_) {
      emit(const _St());
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────

class ChargeOverridesScreen extends StatelessWidget {
  const ChargeOverridesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _Cu()..load(),
      child: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); context.watch<LocaleCubit>();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('override.title')),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddDialog(context, l)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<_Cu>().load(),
        child: BlocBuilder<_Cu, _St>(builder: (context, state) {
          if (state.loading) return const ShimmerLoading(itemCount: 5);
          if (state.overrides.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.tune, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(l.t('override.empty'), style: TextStyle(color: AppColors.textTertiary)),
              const SizedBox(height: 8),
              Text(l.t('override.emptyHint'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary), textAlign: TextAlign.center),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.overrides.length,
            itemBuilder: (_, i) => _OverrideCard(item: state.overrides[i], l: l),
          );
        }),
      ),
    );
  }

  void _showAddDialog(BuildContext context, AppLocalizations l) {
    final cubit = context.read<_Cu>();
    final state = cubit.state;
    if (state.flats.isEmpty || state.chargeHeads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.t('override.needStructure')), backgroundColor: Colors.orange));
      return;
    }

    String? selectedFlatId;
    String? selectedChargeHeadId;
    final rateCtl = TextEditingController();
    final reasonCtl = TextEditingController();
    bool exempt = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx2, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx2).viewInsets.bottom + 20),
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.textTertiary, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(l.t('override.addTitle'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),

              // Flat picker
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: l.t('override.selectFlat'), border: const OutlineInputBorder()),
                items: state.flats.map((f) => DropdownMenuItem(
                  value: f['id']?.toString(),
                  child: Text('${f['flatNumber'] ?? ''} ${f['wing'] != null ? '(${f['wing']['name']})' : ''}'),
                )).toList(),
                onChanged: (v) => selectedFlatId = v,
              ),
              const SizedBox(height: 12),

              // Charge head picker
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: l.t('override.selectCharge'), border: const OutlineInputBorder()),
                items: state.chargeHeads.map((ch) => DropdownMenuItem(
                  value: ch['id']?.toString(),
                  child: Text('${ch['name']} (${ch['calcMethod'] == 'PER_SQFT' ? '₹${ch['rate']}/sqft' : '₹${ch['rate']}'})')
                )).toList(),
                onChanged: (v) => selectedChargeHeadId = v,
              ),
              const SizedBox(height: 12),

              // Exempt toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.t('override.exempt')),
                subtitle: Text(l.t('override.exemptHint'), style: const TextStyle(fontSize: 11)),
                value: exempt,
                onChanged: (v) => setSheetState(() => exempt = v),
              ),

              // Rate override (only if not exempt)
              if (!exempt) ...[
                TextField(
                  controller: rateCtl,
                  decoration: InputDecoration(
                    labelText: l.t('override.overrideRate'),
                    border: const OutlineInputBorder(),
                    prefixText: '₹ ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
              ],

              // Reason
              TextField(
                controller: reasonCtl,
                decoration: InputDecoration(labelText: l.t('override.reason'), border: const OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: () async {
                  if (selectedFlatId == null || selectedChargeHeadId == null) return;
                  if (!exempt && (double.tryParse(rateCtl.text) ?? 0) <= 0) return;
                  try {
                    await api.post('/finance/charge-overrides', data: {
                      'flatId': selectedFlatId,
                      'chargeHeadId': selectedChargeHeadId,
                      'rate': exempt ? 0 : double.parse(rateCtl.text),
                      'exempt': exempt,
                      'reason': reasonCtl.text.trim(),
                    });
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                    cubit.load();
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
      ),
    );
  }
}

class _OverrideCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final AppLocalizations l;
  const _OverrideCard({required this.item, required this.l});

  @override
  Widget build(BuildContext context) {
    final flat = item['flat'] as Map<String, dynamic>?;
    final ch = item['chargeHead'] as Map<String, dynamic>?;
    final exempt = item['exempt'] == true;
    final rate = ((item['rate'] ?? 0) as num).toDouble();
    final reason = item['reason'] ?? '';
    final flatNo = flat?['flatNumber'] ?? '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: exempt ? Colors.orange.withAlpha(30) : Colors.blue.withAlpha(30),
          child: Icon(exempt ? Icons.block : Icons.tune, color: exempt ? Colors.orange : Colors.blue, size: 20),
        ),
        title: Text('$flatNo — ${ch?['name'] ?? ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (exempt)
            Text(l.t('override.exemptLabel'), style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w500))
          else
            Text('₹${rate.toStringAsFixed(2)} (${ch?['calcMethod'] == 'PER_SQFT' ? 'per sqft' : 'fixed'})',
                style: const TextStyle(fontSize: 12)),
          if (reason.isNotEmpty)
            Text(reason, style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ]),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: AppColors.urgent, size: 20),
          onPressed: () async {
            final id = item['id'];
            if (id == null) return;
            try {
              await api.delete('/finance/charge-overrides/$id');
              if (context.mounted) context.read<_Cu>().load();
            } catch (_) {}
          },
        ),
      ),
    );
  }
}
