import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';

class BillGenerateScreen extends StatefulWidget {
  const BillGenerateScreen({super.key});
  @override
  State<BillGenerateScreen> createState() => _BillGenerateScreenState();
}

class _BillGenerateScreenState extends State<BillGenerateScreen> {
  String _period = DateFormat('yyyy-MM').format(DateTime.now());
  DateTime _dueDate = DateTime.now().add(const Duration(days: 15));
  Map<String, dynamic>? _preview;
  bool _loading = false;
  bool _generating = false;
  int? _created;
  int? _skipped;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() => _loading = true);
    try {
      final res = await api.get('/finance/billing-structure/preview', queryParams: {'areaSqft': '1200'});
      setState(() {
        _preview = res.data;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      final res = await api.post('/finance/bills/generate', data: {
        'billingPeriod': _period,
        'dueDate': _dueDate.toIso8601String(),
        'maintenanceCharge': 0.0, // Legacy fallback; billing structure takes over
      });
      setState(() {
        _created = res.data['created'];
        _skipped = res.data['skipped'];
        _generating = false;
      });
    } catch (e) {
      setState(() => _generating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.watch<LocaleCubit>();
    final isMr = context.read<LocaleCubit>().state == 'mr';

    return Scaffold(
      appBar: AppBar(title: Text(l.t('billing.generateBills'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Period selector
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.t('billing.billingPeriod'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickPeriod,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.textTertiary),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_month, size: 18),
                      const SizedBox(width: 8),
                      Text(_period, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down, color: AppColors.textTertiary),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l.t('billing.dueDate'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDueDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.textTertiary),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.event, size: 18),
                      const SizedBox(width: 8),
                      Text(DateFormat('dd MMM yyyy').format(_dueDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down, color: AppColors.textTertiary),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Preview card
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_preview != null) ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.preview, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(l.t('billing.sampleBill'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('1200 sqft', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  ]),
                  const Divider(height: 20),
                  ...(_preview!['lineItems'] as List? ?? []).map<Widget>((item) {
                    final name = isMr ? (item['nameMr'] ?? item['name']) : item['name'];
                    final method = item['calcMethod'];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: method == 'PER_SQFT' ? Colors.blue : Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
                        if (method == 'PER_SQFT')
                          Text('\u20B9${item['rate']} \u00D7 ${(item['quantity'] as num).toStringAsFixed(0)}  ',
                              style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                        Text('\u20B9${(item['amount'] as num).toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                    );
                  }),
                  const Divider(height: 20),
                  Row(children: [
                    Expanded(child: Text(l.t('billing.totalPerFlat'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                    Text('\u20B9${(_preview!['total'] as num).toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ]),
                  const SizedBox(height: 4),
                  Text(l.t('billing.variesByArea'), style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Generate button
          if (_created != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.green.withAlpha(80)),
              ),
              child: Column(children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 40),
                const SizedBox(height: 8),
                Text(l.t('billing.generated'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('${l.t('billing.created')}: $_created  |  ${l.t('billing.skipped')}: $_skipped',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ]),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _generating ? null : _generate,
                icon: _generating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.receipt_long),
                label: Text(_generating ? l.t('billing.generating') : l.t('billing.generateBills')),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _pickPeriod() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12),
    );
    if (date != null) {
      setState(() => _period = DateFormat('yyyy-MM').format(date));
    }
  }

  void _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date != null) {
      setState(() => _dueDate = date);
    }
  }
}
