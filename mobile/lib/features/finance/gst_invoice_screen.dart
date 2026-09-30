import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';

// ─── State ────────────────────────────────────────────────────────

class _St extends Equatable {
  final bool loading;
  final Map<String, dynamic>? invoice;
  final String? error;
  const _St({this.loading = false, this.invoice, this.error});
  @override List<Object?> get props => [loading, invoice, error];
}

class _Cu extends Cubit<_St> {
  final String billId;
  _Cu(this.billId) : super(const _St());

  Future<void> load() async {
    emit(const _St(loading: true));
    try {
      final res = await api.get('/finance/bills/$billId/gst-invoice');
      emit(_St(invoice: res.data as Map<String, dynamic>));
    } catch (e) {
      emit(_St(error: e.toString()));
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────

class GSTInvoiceScreen extends StatelessWidget {
  final String billId;
  const GSTInvoiceScreen({super.key, required this.billId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _Cu(billId)..load(),
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
      appBar: AppBar(title: Text(l.t('gst.invoiceTitle'))),
      body: BlocBuilder<_Cu, _St>(builder: (context, state) {
        if (state.loading) return const Center(child: CircularProgressIndicator());
        if (state.error != null) return Center(child: Text(state.error!));
        final inv = state.invoice;
        if (inv == null) return const SizedBox.shrink();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Society header
            _InvoiceHeader(inv: inv, l: l),
            const SizedBox(height: 16),
            const Divider(thickness: 2),
            const SizedBox(height: 12),

            // Invoice details
            _DetailRow(l.t('gst.invoiceNo'), inv['invoiceNo'] ?? ''),
            _DetailRow(l.t('gst.invoiceDate'), inv['invoiceDate'] ?? ''),
            _DetailRow(l.t('gst.billingPeriod'), inv['billingPeriod'] ?? ''),
            _DetailRow(l.t('gst.dueDate'), inv['dueDate'] ?? ''),
            const SizedBox(height: 8),
            _DetailRow(l.t('gst.memberName'), inv['memberName'] ?? ''),
            _DetailRow(l.t('gst.flatNumber'), inv['flatNumber'] ?? ''),

            const SizedBox(height: 16),
            const Divider(),

            // Line items table
            Text(l.t('gst.lineItems'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _LineItemsTable(inv: inv, l: l),

            const SizedBox(height: 16),

            // Totals
            _TotalsSection(inv: inv, l: l),

            const SizedBox(height: 16),

            // GST notice
            if (inv['gstApplicable'] == true)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withAlpha(40)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.t('gst.gstDetails'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('SAC: ${inv['sacCode']}  |  GST Rate: ${inv['gstRate']}%',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(l.t('gst.belowThreshold'),
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
          ]),
        );
      }),
    );
  }
}

class _InvoiceHeader extends StatelessWidget {
  final Map<String, dynamic> inv;
  final AppLocalizations l;
  const _InvoiceHeader({required this.inv, required this.l});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(inv['societyName'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
      Text(inv['societyAddress'] ?? '', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: 4),
      if ((inv['gstin'] ?? '').isNotEmpty)
        Text('GSTIN: ${inv['gstin']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      if ((inv['pan'] ?? '').isNotEmpty)
        Text('PAN: ${inv['pan']}', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(l.t('gst.taxInvoice'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
      ),
    ]);
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(width: 130, child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class _LineItemsTable extends StatelessWidget {
  final Map<String, dynamic> inv;
  final AppLocalizations l;
  const _LineItemsTable({required this.inv, required this.l});

  @override
  Widget build(BuildContext context) {
    final items = (inv['lineItems'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
          ),
          child: Row(children: [
            Expanded(flex: 3, child: Text(l.t('gst.description'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
            SizedBox(width: 60, child: Text('SAC', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
            SizedBox(width: 80, child: Text(l.t('payment.amount'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
          ]),
        ),
        // Items
        ...items.map((item) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
          child: Row(children: [
            Expanded(flex: 3, child: Text(item['description'] ?? '', style: const TextStyle(fontSize: 12))),
            SizedBox(width: 60, child: Text(item['sacCode'] ?? '', style: TextStyle(fontSize: 11, color: AppColors.textTertiary), textAlign: TextAlign.center)),
            SizedBox(width: 80, child: Text('\u20B9${((item['amount'] ?? 0) as num).toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
          ]),
        )),
      ]),
    );
  }
}

class _TotalsSection extends StatelessWidget {
  final Map<String, dynamic> inv;
  final AppLocalizations l;
  const _TotalsSection({required this.inv, required this.l});

  @override
  Widget build(BuildContext context) {
    final baseAmount = ((inv['baseAmount'] ?? 0) as num).toDouble();
    final arrears = ((inv['arrears'] ?? 0) as num).toDouble();
    final interest = ((inv['interest'] ?? 0) as num).toDouble();
    final subTotal = ((inv['subTotal'] ?? 0) as num).toDouble();
    final gstApplicable = inv['gstApplicable'] == true;
    final cgst = ((inv['cgst'] ?? 0) as num).toDouble();
    final sgst = ((inv['sgst'] ?? 0) as num).toDouble();
    final grandTotal = ((inv['grandTotal'] ?? 0) as num).toDouble();
    final paid = ((inv['amountPaid'] ?? 0) as num).toDouble();
    final due = ((inv['balanceDue'] ?? 0) as num).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        _TotalLine(l.t('gst.baseAmount'), baseAmount),
        if (arrears > 0) _TotalLine(l.t('finance.arrears'), arrears),
        if (interest > 0) _TotalLine(l.t('finance.interest'), interest),
        _TotalLine(l.t('gst.subTotal'), subTotal, bold: true),
        if (gstApplicable) ...[
          const Divider(height: 16),
          _TotalLine('CGST (${((inv['gstRate'] ?? 0) as num) / 2}%)', cgst),
          _TotalLine('SGST (${((inv['gstRate'] ?? 0) as num) / 2}%)', sgst),
        ],
        const Divider(height: 16),
        _TotalLine(l.t('gst.grandTotal'), grandTotal, bold: true, large: true),
        if (paid > 0) _TotalLine(l.t('finance.paid'), -paid, color: Colors.green),
        if (due > 0) _TotalLine(l.t('finance.balanceDue'), due, bold: true, color: AppColors.urgent),
      ]),
    );
  }
}

class _TotalLine extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  final bool large;
  final Color? color;
  const _TotalLine(this.label, this.amount, {this.bold = false, this.large = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(
          fontSize: large ? 14 : 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color ?? AppColors.textPrimary,
        ))),
        Text('${amount < 0 ? '-' : ''}\u20B9${amount.abs().toStringAsFixed(0)}', style: TextStyle(
          fontSize: large ? 16 : 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: color ?? AppColors.textPrimary,
        )),
      ]),
    );
  }
}
