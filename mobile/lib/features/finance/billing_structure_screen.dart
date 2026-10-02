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

// ─── State ──────────────────────────────────────────────────────

class _BsState extends Equatable {
  final bool loading;
  final Map<String, dynamic>? structure;
  final List<Map<String, dynamic>> chargeHeads;
  const _BsState({this.loading = false, this.structure, this.chargeHeads = const []});
  @override
  List<Object?> get props => [loading, structure, chargeHeads];
}

class _BsCubit extends Cubit<_BsState> {
  _BsCubit() : super(const _BsState());

  Future<void> load() async {
    emit(const _BsState(loading: true));
    try {
      final res = await api.get('/finance/billing-structure/active');
      final data = res.data as Map<String, dynamic>? ?? {};
      final heads = (data['chargeHeads'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      emit(_BsState(structure: data, chargeHeads: heads));
    } catch (_) {
      emit(const _BsState());
    }
  }

  Future<bool> addChargeHead(String bsId, Map<String, dynamic> body) async {
    try {
      await api.post('/finance/billing-structure/$bsId/charge-heads', data: body);
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateChargeHead(String bsId, String chId, Map<String, dynamic> body) async {
    try {
      await api.patch('/finance/billing-structure/$bsId/charge-heads/$chId', data: body);
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteChargeHead(String bsId, String chId) async {
    try {
      await api.delete('/finance/billing-structure/$bsId/charge-heads/$chId');
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateStructure(String bsId, Map<String, dynamic> body) async {
    try {
      await api.patch('/finance/billing-structure/$bsId', data: body);
      await load();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ─── Screen ─────────────────────────────────────────────────────

class BillingStructureScreen extends StatelessWidget {
  const BillingStructureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _BsCubit()..load(),
      child: const _BsView(),
    );
  }
}

class _BsView extends StatelessWidget {
  const _BsView();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.watch<LocaleCubit>();
    final isMr = context.read<LocaleCubit>().isMarathi;
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('billing.structure')),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showPreview(context),
            ),
        ],
      ),
      body: BlocBuilder<_BsCubit, _BsState>(
        builder: (context, state) {
          if (state.loading) return const ShimmerLoading(itemCount: 6);
          if (state.structure == null) {
            return Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long, size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 12),
                Text(l.t('billing.noStructure'), style: TextStyle(color: AppColors.textTertiary)),
              ],
            ));
          }

          final bs = state.structure!;
          final bsId = bs['id']?.toString() ?? '';
          final interestRate = (bs['interestRate'] ?? 0).toDouble();

          return RefreshIndicator(
            onRefresh: () => context.read<_BsCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Structure info card
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.account_balance, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            isMr ? (bs['nameMr'] ?? bs['name']) : bs['name'],
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          )),
                          if (isAdmin)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _editInterestRate(context, bsId, interestRate),
                            ),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.percent, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('${l.t('billing.interestRate')}: ${interestRate.toStringAsFixed(1)}% ${l.t('billing.perAnnum')}',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Charge heads header
                Row(children: [
                  Text(l.t('billing.chargeHeads'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${state.chargeHeads.length} ${l.t('billing.items')}',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ]),
                const SizedBox(height: 8),

                // Charge heads list
                ...state.chargeHeads.map((ch) => _ChargeHeadTile(
                  ch: ch,
                  bsId: bsId,
                  isMr: isMr,
                  isAdmin: isAdmin,
                )),

                // Total preview for 1200 sqft
                const SizedBox(height: 16),
                _TotalPreview(chargeHeads: state.chargeHeads),
              ],
            ),
          );
        },
      ),
      floatingActionButton: isAdmin
          ? BlocBuilder<_BsCubit, _BsState>(
              builder: (context, state) {
                if (state.structure == null) return const SizedBox();
                return FloatingActionButton.extended(
                  onPressed: () => _addChargeHead(context, state.structure!['id']?.toString() ?? ''),
                  icon: const Icon(Icons.add),
                  label: Text(l.t('billing.addCharge')),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                );
              },
            )
          : null,
    );
  }

  void _showPreview(BuildContext context) async {
    try {
      final res = await api.get('/finance/billing-structure/preview', queryParams: {'areaSqft': '1200'});
      final data = res.data;
      final items = (data['lineItems'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      if (!context.mounted) return;
      final isMr = context.read<LocaleCubit>().isMarathi;

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bill Preview (1200 sqft)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text(isMr ? (item['nameMr'] ?? item['name']) : item['name'], style: const TextStyle(fontSize: 13))),
                if (item['calcMethod'] == 'PER_SQFT')
                  Text('${item['rate']} × ${(item['quantity'] as num).toStringAsFixed(0)}  ', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                Text('\u20B9${(item['amount'] as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            )),
            const Divider(height: 20),
            Row(children: [
              const Expanded(child: Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              Text('\u20B9${(data['total'] as num).toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
          ]),
          ),
        ),
      );
    } catch (_) {}
  }

  void _editInterestRate(BuildContext context, String bsId, double current) {
    final ctrl = TextEditingController(text: current.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('billing.interestRate')),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: '% p.a.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).t('common.cancel'))),
          FilledButton(
            onPressed: () async {
              final rate = double.tryParse(ctrl.text) ?? current;
              await context.read<_BsCubit>().updateStructure(bsId, {'interestRate': rate});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(AppLocalizations.of(context).t('common.save')),
          ),
        ],
      ),
    );
  }

  void _addChargeHead(BuildContext context, String bsId) {
    final nameCtrl = TextEditingController();
    final nameMrCtrl = TextEditingController();
    final rateCtrl = TextEditingController();
    String calcMethod = 'FIXED';
    final l = AppLocalizations.of(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l.t('billing.addCharge'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: l.t('billing.chargeName'))),
            const SizedBox(height: 8),
            TextField(controller: nameMrCtrl, decoration: InputDecoration(labelText: l.t('billing.chargeNameMr'))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'FIXED', label: Text(l.t('billing.fixed'), style: const TextStyle(fontSize: 12))),
                    ButtonSegment(value: 'PER_SQFT', label: Text(l.t('billing.perSqft'), style: const TextStyle(fontSize: 12))),
                  ],
                  selected: {calcMethod},
                  onSelectionChanged: (v) => setState(() => calcMethod = v.first),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: rateCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: calcMethod == 'PER_SQFT' ? '\u20B9 ${l.t('billing.ratePerSqft')}' : '\u20B9 ${l.t('billing.fixedAmount')}',
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text(l.t('common.cancel')))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(
                onPressed: () async {
                  final rate = double.tryParse(rateCtrl.text);
                  if (nameCtrl.text.isEmpty || rate == null || rate <= 0) return;
                  final ok = await context.read<_BsCubit>().addChargeHead(bsId, {
                    'name': nameCtrl.text,
                    'nameMr': nameMrCtrl.text,
                    'calcMethod': calcMethod,
                    'rate': rate,
                  });
                  if (ok && ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(l.t('common.save')),
              )),
            ]),
          ]),
        ),
        ),
      ),
    );
  }
}

// ─── Charge Head Tile ───────────────────────────────────────────

class _ChargeHeadTile extends StatelessWidget {
  final Map<String, dynamic> ch;
  final String bsId;
  final bool isMr;
  final bool isAdmin;
  const _ChargeHeadTile({required this.ch, required this.bsId, required this.isMr, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final name = isMr ? (ch['nameMr'] ?? ch['name']) : ch['name'];
    final method = ch['calcMethod'] ?? 'FIXED';
    final rate = (ch['rate'] ?? 0).toDouble();
    final isPerSqft = method == 'PER_SQFT';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: (isPerSqft ? Colors.blue : Colors.green).withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isPerSqft ? Icons.square_foot : Icons.attach_money,
            color: isPerSqft ? Colors.blue : Colors.green,
            size: 20,
          ),
        ),
        title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
          isPerSqft ? '\u20B9${rate.toStringAsFixed(2)} / sqft' : '\u20B9${rate.toStringAsFixed(0)} flat',
          style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
        ),
        trailing: isAdmin
            ? PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _editChargeHead(context);
                  if (v == 'delete') _deleteChargeHead(context);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(AppLocalizations.of(context).t('common.edit'))),
                  PopupMenuItem(value: 'delete', child: Text(AppLocalizations.of(context).t('common.delete'), style: const TextStyle(color: Colors.red))),
                ],
              )
            : null,
      ),
    );
  }

  void _editChargeHead(BuildContext context) {
    final rateCtrl = TextEditingController(text: (ch['rate'] ?? 0).toString());
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l.t('common.edit')}: ${ch['name']}'),
        content: TextField(
          controller: rateCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: '\u20B9 ${l.t('billing.rate')}'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.t('common.cancel'))),
          FilledButton(
            onPressed: () async {
              final rate = double.tryParse(rateCtrl.text);
              if (rate == null || rate <= 0) return;
              await context.read<_BsCubit>().updateChargeHead(bsId, ch['id'], {'rate': rate});
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l.t('common.save')),
          ),
        ],
      ),
    );
  }

  void _deleteChargeHead(BuildContext context) {
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('common.delete')),
        content: Text('${l.t('billing.deleteChargeConfirm')} "${ch['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.t('common.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<_BsCubit>().deleteChargeHead(bsId, ch['id']);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l.t('common.delete')),
          ),
        ],
      ),
    );
  }
}

// ─── Total Preview ──────────────────────────────────────────────

class _TotalPreview extends StatelessWidget {
  final List<Map<String, dynamic>> chargeHeads;
  const _TotalPreview({required this.chargeHeads});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Calculate for default 1200 sqft flat
    const sampleArea = 1200.0;
    double total = 0;
    for (final ch in chargeHeads) {
      final rate = (ch['rate'] ?? 0).toDouble();
      final method = ch['calcMethod'] ?? 'FIXED';
      total += method == 'PER_SQFT' ? rate * sampleArea : rate;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.t('billing.sampleBill'), style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          Text('1200 sqft ${l.t('billing.flat')}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ])),
        Text('\u20B9${total.toStringAsFixed(0)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
        Text(' /${l.t('billing.month')}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ]),
    );
  }
}
