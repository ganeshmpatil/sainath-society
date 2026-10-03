import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shimmer_loading.dart';

class PendingPaymentsScreen extends StatefulWidget {
  const PendingPaymentsScreen({super.key});
  @override
  State<PendingPaymentsScreen> createState() => _PendingPaymentsScreenState();
}

class _PendingPaymentsScreenState extends State<PendingPaymentsScreen> {
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await api.get('/payments/pending');
      final list = (res.data['payments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (mounted) setState(() { _payments = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm(String paymentId) async {
    final l = AppLocalizations.of(context);
    try {
      await api.post('/payments/$paymentId/confirm');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('payment.confirmed')), backgroundColor: Colors.green));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _reject(String paymentId) async {
    final l = AppLocalizations.of(context);
    final reasonCtl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('payment.reject')),
        content: TextField(
          controller: reasonCtl,
          decoration: InputDecoration(
            labelText: l.t('payment.rejectReason'),
            border: const OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.t('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l.t('payment.reject')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await api.post('/payments/$paymentId/reject', data: {'reason': reasonCtl.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('payment.rejected')), backgroundColor: Colors.orange));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    }
  }

  void _viewProof(String paymentId) async {
    try {
      final res = await api.getBytes('/payments/$paymentId/proof');
      final bytes = res.data!;
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: InteractiveViewer(
            child: Image.memory(Uint8List.fromList(bytes), fit: BoxFit.contain),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No proof available'), backgroundColor: Colors.red));
      }
    }
  }

  String _formatDate(dynamic d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return d.toString(); }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('payment.pendingPayments')),
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const ShimmerLoading(itemCount: 4)
          : _payments.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_outline, size: 64, color: AppColors.textTertiary.withAlpha(80)),
                  const SizedBox(height: 12),
                  Text(l.t('payment.noPending'), style: TextStyle(color: AppColors.textTertiary)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _payments.length,
                    itemBuilder: (_, i) => _PaymentCard(
                      payment: _payments[i],
                      onConfirm: () => _confirm(_payments[i]['id']),
                      onReject: () => _reject(_payments[i]['id']),
                      onViewProof: () => _viewProof(_payments[i]['id']),
                      formatDate: _formatDate,
                      l: l,
                    ),
                  ),
                ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback onViewProof;
  final String Function(dynamic) formatDate;
  final AppLocalizations l;

  const _PaymentCard({
    required this.payment,
    required this.onConfirm,
    required this.onReject,
    required this.onViewProof,
    required this.formatDate,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final bill = payment['bill'] as Map<String, dynamic>? ?? {};
    final member = bill['member'] as Map<String, dynamic>? ?? {};
    final flat = bill['flat'] as Map<String, dynamic>? ?? {};
    final amount = ((payment['amount'] ?? 0) as num).toDouble();
    final mode = payment['paymentMode'] ?? '';
    final reference = payment['reference'] ?? '';
    final date = formatDate(payment['paymentDate']);
    final hasProof = payment['hasProof'] == true;
    final memberName = member['name'] ?? '';
    final flatNumber = flat['flatNumber'] ?? '';
    final billPeriod = bill['billingPeriod'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withAlpha(80)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header: member + flat + period
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.pending_actions, size: 20, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(memberName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text('$flatNumber \u2022 $billPeriod',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ])),
          Text('\u20B9${amount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),

        // Payment details
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.borderLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            _detailRow(l.t('payment.mode'), mode),
            if (reference.isNotEmpty) _detailRow(l.t('payment.reference'), reference),
            _detailRow(l.t('payment.date'), date),
          ]),
        ),
        const SizedBox(height: 12),

        // Actions
        Row(children: [
          if (hasProof) ...[
            OutlinedButton.icon(
              onPressed: onViewProof,
              icon: const Icon(Icons.image, size: 16),
              label: Text(l.t('payment.viewProof'), style: const TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
          ],
          const Spacer(),
          OutlinedButton(
            onPressed: onReject,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(l.t('payment.reject'), style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text(l.t('payment.confirm'), style: const TextStyle(fontSize: 12)),
          ),
        ]),
      ]),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}
