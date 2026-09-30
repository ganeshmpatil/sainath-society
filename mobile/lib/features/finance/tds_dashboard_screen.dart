import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ═══════════════════════════════════════════════════════════════
// State
// ═══════════════════════════════════════════════════════════════
class _TdsState extends Equatable {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> summary;
  final List<Map<String, dynamic>> pending;
  final List<Map<String, dynamic>> payments;
  const _TdsState({
    this.loading = false,
    this.error,
    this.summary = const [],
    this.pending = const [],
    this.payments = const [],
  });
  @override
  List<Object?> get props => [loading, error, summary, pending, payments];
}

class _TdsCubit extends Cubit<_TdsState> {
  _TdsCubit() : super(const _TdsState());

  Future<void> load() async {
    emit(const _TdsState(loading: true));
    try {
      final results = await Future.wait([
        api.get('/finance/vendor-payments/tds-summary'),
        api.get('/finance/vendor-payments/tds-pending'),
        api.get('/finance/vendor-payments'),
      ]);
      final summaryList = (results[0].data['summary'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      final pendingList = (results[1].data['payments'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      final paymentsList = (results[2].data['payments'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      emit(_TdsState(
        summary: summaryList,
        pending: pendingList,
        payments: paymentsList,
      ));
    } catch (e) {
      emit(_TdsState(error: e.toString()));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════
class TdsDashboardScreen extends StatelessWidget {
  const TdsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _TdsCubit()..load(),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('tds.title')),
        centerTitle: true,
      ),
      body: BlocBuilder<_TdsCubit, _TdsState>(
        builder: (context, state) {
          if (state.loading) return const ShimmerLoading();
          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.t('common.error'),
                      style: TextStyle(color: AppColors.textTertiary)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.read<_TdsCubit>().load(),
                    child: Text(l.t('common.retry')),
                  ),
                ],
              ),
            );
          }

          // Calculate totals from summary
          double totalDeducted = 0;
          double totalDeposited = 0;
          double totalPending = 0;
          for (final s in state.summary) {
            totalDeducted += (s['totalDeducted'] ?? 0).toDouble();
            totalDeposited += (s['totalDeposited'] ?? 0).toDouble();
            totalPending += (s['pending'] ?? 0).toDouble();
          }

          return RefreshIndicator(
            onRefresh: () => context.read<_TdsCubit>().load(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary cards
                Row(
                  children: [
                    Expanded(
                      child: _SummaryTile(
                        label: l.t('tds.totalDeducted'),
                        value: totalDeducted,
                        color: Colors.blue,
                        icon: Icons.account_balance,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryTile(
                        label: l.t('tds.deposited'),
                        value: totalDeposited,
                        color: Colors.green,
                        icon: Icons.check_circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SummaryTile(
                        label: l.t('tds.pendingDeposit'),
                        value: totalPending,
                        color: totalPending > 0 ? Colors.red : Colors.grey,
                        icon: Icons.pending_actions,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Section-wise breakdown
                if (state.summary.isNotEmpty) ...[
                  Text(l.t('tds.sectionWise'),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  ...state.summary.map((s) => _SectionRow(data: s)),
                  const SizedBox(height: 16),
                ],

                // Pending TDS deposits
                if (state.pending.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withAlpha(30)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber,
                                color: Colors.red, size: 18),
                            const SizedBox(width: 6),
                            Text(l.t('tds.pendingDeposits'),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red)),
                            const Spacer(),
                            Text('${state.pending.length}',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(l.t('tds.depositReminder'),
                            style: TextStyle(
                                fontSize: 10, color: AppColors.textTertiary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Recent vendor payments
                Text(l.t('tds.recentPayments'),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                if (state.payments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 40, color: AppColors.textTertiary),
                          const SizedBox(height: 8),
                          Text(l.t('tds.noPayments'),
                              style: TextStyle(
                                  color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                  )
                else
                  ...state.payments.take(20).map((p) => _PaymentCard(payment: p)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRecordPaymentDialog(context),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }

  void _showRecordPaymentDialog(BuildContext ctx) {
    final l = AppLocalizations.of(ctx);
    final cubit = ctx.read<_TdsCubit>();

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RecordPaymentSheet(l: l, cubit: cubit),
    );
  }
}

class _RecordPaymentSheet extends StatefulWidget {
  final AppLocalizations l;
  final _TdsCubit cubit;
  const _RecordPaymentSheet({required this.l, required this.cubit});

  @override
  State<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<_RecordPaymentSheet> {
  List<Map<String, dynamic>> vendors = [];
  List<Map<String, dynamic>> accounts = [];
  String? selectedVendorId;
  String? selectedAccountId;
  final amountCtl = TextEditingController();
  final narrationCtl = TextEditingController();
  final dateCtl = TextEditingController();
  String paymentMode = 'BANK';
  final refCtl = TextEditingController();
  bool loading = false;

  @override
  void initState() {
    super.initState();
    dateCtl.text = DateTime.now().toIso8601String().substring(0, 10);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        api.get('/finance/vendors'),
        api.get('/finance/accounts/leaf'),
      ]);
      if (mounted) {
        setState(() {
          vendors = (results[0].data['vendors'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              [];
          accounts = (results[1].data['accounts'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .where((a) => a['type'] == 'EXPENSE')
                  .toList() ??
              [];
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.t('tds.recordPayment'),
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            // Vendor dropdown
            DropdownButtonFormField<String>(
              value: selectedVendorId,
              decoration: InputDecoration(
                labelText: l.t('tds.selectVendor'),
                border: const OutlineInputBorder(),
              ),
              items: vendors
                  .map((v) => DropdownMenuItem(
                      value: v['id']?.toString(),
                      child: Text(v['name'] ?? '', overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => selectedVendorId = v),
            ),
            const SizedBox(height: 12),
            // Expense account
            DropdownButtonFormField<String>(
              value: selectedAccountId,
              decoration: InputDecoration(
                labelText: l.t('tds.expenseAccount'),
                border: const OutlineInputBorder(),
              ),
              items: accounts
                  .map((a) => DropdownMenuItem(
                      value: a['id']?.toString(),
                      child: Text('${a['code']} - ${a['name']}',
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => selectedAccountId = v),
            ),
            const SizedBox(height: 12),
            // Amount
            TextField(
              controller: amountCtl,
              decoration: InputDecoration(
                labelText: l.t('tds.grossAmount'),
                border: const OutlineInputBorder(),
                prefixText: '₹ ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            // Date
            TextField(
              controller: dateCtl,
              decoration: InputDecoration(
                labelText: l.t('tds.paymentDate'),
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today, size: 18),
              ),
              readOnly: true,
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (d != null) {
                  dateCtl.text = d.toIso8601String().substring(0, 10);
                }
              },
            ),
            const SizedBox(height: 12),
            // Narration
            TextField(
              controller: narrationCtl,
              decoration: InputDecoration(
                labelText: l.t('tds.narration'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Payment mode
            DropdownButtonFormField<String>(
              initialValue: paymentMode,
              decoration: InputDecoration(
                labelText: l.t('tds.paymentMode'),
                border: const OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'BANK', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'UPI', child: Text('UPI')),
                DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
              ],
              onChanged: (v) => setState(() => paymentMode = v!),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: loading ? null : _submit,
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.t('tds.recordPayment')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (selectedVendorId == null || amountCtl.text.isEmpty) return;
    setState(() => loading = true);
    try {
      await api.post('/finance/vendor-payments', data: {
        'vendorId': selectedVendorId,
        'paymentDate': dateCtl.text,
        'grossAmount': double.tryParse(amountCtl.text) ?? 0,
        'narration': narrationCtl.text.trim(),
        'paymentMode': paymentMode,
        'reference': refCtl.text.trim(),
        'expenseAccountId': selectedAccountId ?? '',
      });
      if (mounted) Navigator.pop(context);
      widget.cubit.load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text('₹${value.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 9, color: AppColors.textTertiary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SectionRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final section = data['section'] ?? '';
    final deducted = (data['totalDeducted'] ?? 0).toDouble();
    final deposited = (data['totalDeposited'] ?? 0).toDouble();
    final pending = (data['pending'] ?? 0).toDouble();
    final count = (data['paymentCount'] ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(section,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange[800])),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('₹${deducted.toStringAsFixed(0)} deducted',
                    style: TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                Text('$count payments',
                    style: TextStyle(fontSize: 9, color: AppColors.textTertiary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (deposited > 0)
                Text('✓ ₹${deposited.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 10, color: Colors.green[700])),
              if (pending > 0)
                Text('⏳ ₹${pending.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 10, color: Colors.red[700])),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final vendor = payment['vendor'] as Map<String, dynamic>?;
    final vendorName = vendor?['name'] ?? 'Unknown';
    final gross = (payment['grossAmount'] ?? 0).toDouble();
    final tds = (payment['tdsAmount'] ?? 0).toDouble();
    final net = (payment['netAmount'] ?? 0).toDouble();
    final section = payment['tdsSection'] ?? '';
    final rate = (payment['tdsRate'] ?? 0).toDouble();
    final date = _formatDate(payment['paymentDate'] ?? '');
    final mode = payment['paymentMode'] ?? '';
    final deposited = payment['tdsDeposited'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(vendorName,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
              Text(date,
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _AmtChip('Gross', gross, Colors.blue),
              const SizedBox(width: 6),
              if (tds > 0)
                _AmtChip('TDS $section@${rate.toStringAsFixed(0)}%', tds, Colors.orange),
              if (tds > 0) const SizedBox(width: 6),
              _AmtChip('Net', net, Colors.green),
              const Spacer(),
              if (tds > 0)
                Icon(
                  deposited ? Icons.check_circle : Icons.pending,
                  size: 16,
                  color: deposited ? Colors.green : Colors.orange,
                ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(mode,
                    style: TextStyle(
                        fontSize: 9, color: AppColors.textTertiary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year % 100}';
    } catch (_) {
      return raw;
    }
  }
}

class _AmtChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _AmtChip(this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: ₹${amount.toStringAsFixed(0)}',
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
