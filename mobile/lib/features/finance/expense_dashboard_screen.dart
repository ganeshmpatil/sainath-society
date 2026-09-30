import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ═══════════════════════════════════════════════════════════════
// State — reuses the I&E endpoint to get expense data
// ═══════════════════════════════════════════════════════════════
class _EdState extends Equatable {
  final bool loading;
  final String? error;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? collection;
  const _EdState({this.loading = false, this.error, this.data, this.collection});
  @override
  List<Object?> get props => [loading, error, data, collection];
}

class _EdCubit extends Cubit<_EdState> {
  _EdCubit() : super(const _EdState());

  Future<void> load() async {
    emit(const _EdState(loading: true));
    try {
      final results = await Future.wait([
        api.get('/finance/reports/income-expenditure'),
        api.get('/finance/reports/collection-dashboard'),
      ]);
      emit(_EdState(
        data: results[0].data,
        collection: results[1].data,
      ));
    } catch (e) {
      emit(_EdState(error: e.toString()));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════
class ExpenseDashboardScreen extends StatelessWidget {
  const ExpenseDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _EdCubit()..load(),
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
        title: Text(l.t('expDash.title')),
        centerTitle: true,
      ),
      body: BlocBuilder<_EdCubit, _EdState>(
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
                    onPressed: () => context.read<_EdCubit>().load(),
                    child: Text(l.t('common.retry')),
                  ),
                ],
              ),
            );
          }

          final data = state.data;
          if (data == null) return const SizedBox.shrink();

          final expenses = (data['expenses'] as List?) ?? [];
          final totalExpense = (data['totalExpense'] ?? 0).toDouble();
          final totalIncome = (data['totalIncome'] ?? 0).toDouble();
          final surplus = (data['surplus'] ?? 0).toDouble();

          // Collection data
          final coll = state.collection ?? {};
          final collectionRate = (coll['collectionRate'] ?? 0).toDouble();
          final totalBilled = (coll['totalBilled'] ?? 0).toDouble();
          final totalCollected = (coll['totalCollected'] ?? 0).toDouble();

          // Sort expenses by amount descending for top categories
          final sorted = List<Map<String, dynamic>>.from(
              expenses.whereType<Map<String, dynamic>>());
          sorted.sort((a, b) =>
              ((b['amount'] ?? 0) as num).compareTo((a['amount'] ?? 0) as num));

          return RefreshIndicator(
            onRefresh: () => context.read<_EdCubit>().load(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary row
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: l.t('expDash.totalExpenses'),
                        value: totalExpense,
                        color: Colors.red,
                        icon: Icons.trending_down,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        label: l.t('expDash.totalIncome'),
                        value: totalIncome,
                        color: Colors.green,
                        icon: Icons.trending_up,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: surplus >= 0
                            ? l.t('expDash.surplus')
                            : l.t('expDash.deficit'),
                        value: surplus.abs(),
                        color: surplus >= 0 ? Colors.blue : Colors.orange,
                        icon: surplus >= 0
                            ? Icons.savings
                            : Icons.warning_amber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        label: l.t('expDash.collectionRate'),
                        value: collectionRate,
                        color: collectionRate >= 80
                            ? Colors.green
                            : Colors.orange,
                        icon: Icons.percent,
                        isPercentage: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Collection bar
                if (totalBilled > 0) ...[
                  Text(l.t('expDash.collectionProgress'),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (totalCollected / totalBilled).clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.grey.withAlpha(30),
                      valueColor: AlwaysStoppedAnimation(
                          collectionRate >= 80 ? Colors.green : Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          '${l.t('expDash.collected')}: ₹${totalCollected.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textTertiary)),
                      Text(
                          '${l.t('expDash.billed')}: ₹${totalBilled.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textTertiary)),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // Expense breakdown (horizontal bar chart style)
                if (sorted.isNotEmpty) ...[
                  Text(l.t('expDash.categoryBreakdown'),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  ...sorted.asMap().entries.map((entry) {
                    final item = entry.value;
                    final name = isMr &&
                            (item['accountNameMr'] ?? '').toString().isNotEmpty
                        ? item['accountNameMr']
                        : item['accountName'];
                    final amount = (item['amount'] ?? 0).toDouble();
                    final pct =
                        totalExpense > 0 ? (amount / totalExpense) * 100 : 0.0;
                    final barColor = _barColors[entry.key % _barColors.length];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(name,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textPrimary)),
                              ),
                              Text(
                                  '₹${amount.toStringAsFixed(0)} (${pct.toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: totalExpense > 0
                                  ? (amount / totalExpense).clamp(0.0, 1.0)
                                  : 0,
                              minHeight: 6,
                              backgroundColor: Colors.grey.withAlpha(20),
                              valueColor: AlwaysStoppedAnimation(barColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ] else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(Icons.pie_chart_outline,
                              size: 48, color: AppColors.textTertiary),
                          const SizedBox(height: 12),
                          Text(l.t('expDash.noExpenses'),
                              style: TextStyle(
                                  color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static const _barColors = [
    Colors.red,
    Colors.orange,
    Colors.blue,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.brown,
  ];
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final bool isPercentage;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isPercentage
                ? '${value.toStringAsFixed(1)}%'
                : '₹${value.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
