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
class _BsState extends Equatable {
  final bool loading;
  final String? error;
  final Map<String, dynamic>? data;
  const _BsState({this.loading = false, this.error, this.data});
  @override
  List<Object?> get props => [loading, error, data];
}

class _BsCubit extends Cubit<_BsState> {
  _BsCubit() : super(const _BsState());

  Future<void> load({String? asOf}) async {
    emit(const _BsState(loading: true));
    try {
      final params = <String, dynamic>{};
      if (asOf != null) params['asOf'] = asOf;
      final res = await api.get('/finance/reports/balance-sheet',
          queryParams: params.isEmpty ? null : params);
      emit(_BsState(data: res.data));
    } catch (e) {
      emit(_BsState(error: e.toString()));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════
class BalanceSheetScreen extends StatelessWidget {
  const BalanceSheetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _BsCubit()..load(),
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
        title: Text(l.t('bs.title')),
        centerTitle: true,
      ),
      body: BlocBuilder<_BsCubit, _BsState>(
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
                    onPressed: () => context.read<_BsCubit>().load(),
                    child: Text(l.t('common.retry')),
                  ),
                ],
              ),
            );
          }

          final data = state.data;
          if (data == null) return const SizedBox.shrink();

          final asOf = data['asOf'] ?? '';
          final assets = (data['assets'] as List?) ?? [];
          final liabilities = (data['liabilities'] as List?) ?? [];
          final funds = (data['funds'] as List?) ?? [];
          final totalAssets = (data['totalAssets'] ?? 0).toDouble();
          final totalLiabilities = (data['totalLiabilities'] ?? 0).toDouble();
          final totalFunds = (data['totalFunds'] ?? 0).toDouble();
          final surplus = (data['surplus'] ?? 0).toDouble();

          return RefreshIndicator(
            onRefresh: () => context.read<_BsCubit>().load(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Date header
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${l.t('bs.asOf')} $asOf',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 16),

                // Assets section
                _SectionCard(
                  title: l.t('bs.assets'),
                  items: assets,
                  isMr: isMr,
                  total: totalAssets,
                  color: Colors.blue,
                  icon: Icons.account_balance_wallet,
                ),
                const SizedBox(height: 12),

                // Liabilities section
                _SectionCard(
                  title: l.t('bs.liabilities'),
                  items: liabilities,
                  isMr: isMr,
                  total: totalLiabilities,
                  color: Colors.red,
                  icon: Icons.credit_card,
                ),
                const SizedBox(height: 12),

                // Funds section
                _SectionCard(
                  title: l.t('bs.funds'),
                  items: funds,
                  isMr: isMr,
                  total: totalFunds,
                  color: Colors.purple,
                  icon: Icons.savings,
                ),
                const SizedBox(height: 12),

                // Surplus from I&E
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (surplus >= 0 ? Colors.green : Colors.red)
                        .withAlpha(12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: (surplus >= 0 ? Colors.green : Colors.red)
                            .withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          surplus >= 0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: surplus >= 0 ? Colors.green : Colors.red,
                          size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            surplus >= 0
                                ? l.t('bs.surplus')
                                : l.t('bs.deficit'),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                      ),
                      Text(
                        '${surplus < 0 ? "-" : ""}₹${surplus.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: surplus >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Balance check
                _BalanceCheckCard(
                  totalAssets: totalAssets,
                  totalLiabilities: totalLiabilities,
                  totalFunds: totalFunds,
                  surplus: surplus,
                  l: l,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List items;
  final bool isMr;
  final double total;
  final Color color;
  final IconData icon;

  const _SectionCard({
    required this.title,
    required this.items,
    required this.isMr,
    required this.total,
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
          // Header
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
              final balance = (item['balance'] ?? 0).toDouble();
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
                    Text('₹${balance.toStringAsFixed(2)}',
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

class _BalanceCheckCard extends StatelessWidget {
  final double totalAssets;
  final double totalLiabilities;
  final double totalFunds;
  final double surplus;
  final AppLocalizations l;

  const _BalanceCheckCard({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalFunds,
    required this.surplus,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final rightSide = totalLiabilities + totalFunds + surplus;
    final balanced = (totalAssets - rightSide).abs() < 0.01;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (balanced ? Colors.green : Colors.orange).withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: (balanced ? Colors.green : Colors.orange).withAlpha(40)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(balanced ? Icons.check_circle : Icons.warning_amber,
                  color: balanced ? Colors.green : Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(balanced ? l.t('bs.balanced') : l.t('bs.imbalanced'),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: balanced ? Colors.green : Colors.orange)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.t('bs.assets'),
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textTertiary)),
                    Text('₹${totalAssets.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text('=',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${l.t('bs.liabilities')} + ${l.t('bs.funds')} + ${l.t('bs.surplus')}',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textTertiary)),
                    Text('₹${rightSide.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
