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
class _RpState extends Equatable {
  final bool loading;
  final String? error;
  final Map<String, dynamic>? data;
  const _RpState({this.loading = false, this.error, this.data});
  @override
  List<Object?> get props => [loading, error, data];
}

class _RpCubit extends Cubit<_RpState> {
  _RpCubit() : super(const _RpState());

  Future<void> load({String? from, String? to}) async {
    emit(const _RpState(loading: true));
    try {
      final params = <String, dynamic>{};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      final res = await api.get('/finance/reports/receipts-payments',
          queryParams: params.isEmpty ? null : params);
      emit(_RpState(data: res.data));
    } catch (e) {
      emit(_RpState(error: e.toString()));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════
class ReceiptsPaymentsScreen extends StatelessWidget {
  const ReceiptsPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _RpCubit()..load(),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('rp.title')),
        centerTitle: true,
      ),
      body: BlocBuilder<_RpCubit, _RpState>(
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
                    onPressed: () => context.read<_RpCubit>().load(),
                    child: Text(l.t('common.retry')),
                  ),
                ],
              ),
            );
          }

          final data = state.data;
          if (data == null) return const SizedBox.shrink();

          final periodFrom = data['periodFrom'] ?? '';
          final periodTo = data['periodTo'] ?? '';
          final openingBalance = (data['openingBalance'] ?? 0).toDouble();
          final receipts = (data['receipts'] as List?) ?? [];
          final payments = (data['payments'] as List?) ?? [];
          final totalReceipts = (data['totalReceipts'] ?? 0).toDouble();
          final totalPayments = (data['totalPayments'] ?? 0).toDouble();
          final closingBalance = (data['closingBalance'] ?? 0).toDouble();

          return RefreshIndicator(
            onRefresh: () => context.read<_RpCubit>().load(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Period header
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$periodFrom  →  $periodTo',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 16),

                // Opening balance
                _BalanceRow(
                  label: l.t('rp.openingBalance'),
                  amount: openingBalance,
                  color: Colors.blue,
                  icon: Icons.account_balance,
                ),
                const SizedBox(height: 12),

                // Receipts
                _FlowSection(
                  title: l.t('rp.receipts'),
                  items: receipts,
                  total: totalReceipts,
                  isMr: isMr,
                  color: Colors.green,
                  icon: Icons.arrow_downward,
                ),
                const SizedBox(height: 12),

                // Payments
                _FlowSection(
                  title: l.t('rp.payments'),
                  items: payments,
                  total: totalPayments,
                  isMr: isMr,
                  color: Colors.red,
                  icon: Icons.arrow_upward,
                ),
                const SizedBox(height: 12),

                // Closing balance
                _BalanceRow(
                  label: l.t('rp.closingBalance'),
                  amount: closingBalance,
                  color: closingBalance >= 0 ? Colors.blue : Colors.red,
                  icon: Icons.account_balance_wallet,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const _BalanceRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
          Text(
            '${amount < 0 ? "-" : ""}₹${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _FlowSection extends StatelessWidget {
  final String title;
  final List items;
  final double total;
  final bool isMr;
  final Color color;
  final IconData icon;

  const _FlowSection({
    required this.title,
    required this.items,
    required this.total,
    required this.isMr,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const Spacer(),
                Text('₹${total.toStringAsFixed(2)}',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('No entries',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            )
          else
            ...items.map((item) {
              final name = isMr &&
                      (item['accountNameMr'] ?? '').toString().isNotEmpty
                  ? item['accountNameMr']
                  : item['accountName'];
              final code = item['accountCode'] ?? '';
              final amount = (item['amount'] ?? 0).toDouble();
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: color.withAlpha(20), width: 0.5)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text(code,
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textTertiary,
                              fontFamily: 'monospace')),
                    ),
                    Expanded(
                      child: Text(name,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textPrimary)),
                    ),
                    Text('₹${amount.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
