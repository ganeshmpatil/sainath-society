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
class _IeState extends Equatable {
  final bool loading;
  final String? error;
  final Map<String, dynamic> data;
  const _IeState({this.loading = false, this.error, this.data = const {}});
  @override
  List<Object?> get props => [loading, error, data];
}

class _IeCubit extends Cubit<_IeState> {
  _IeCubit() : super(const _IeState());

  Future<void> load({String? from, String? to}) async {
    emit(const _IeState(loading: true));
    try {
      final params = <String, dynamic>{};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      final res = await api.get('/finance/reports/income-expenditure',
          queryParams: params.isEmpty ? null : params);
      emit(_IeState(data: res.data as Map<String, dynamic>? ?? {}));
    } catch (e) {
      emit(_IeState(error: e.toString()));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════
class IncomeExpenditureScreen extends StatelessWidget {
  const IncomeExpenditureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _IeCubit()..load(),
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
        title: Text(l.t('ie.title')),
        centerTitle: true,
      ),
      body: BlocBuilder<_IeCubit, _IeState>(
        builder: (context, state) {
          if (state.loading) return const ShimmerLoading();
          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.t('common.error'), style: TextStyle(color: AppColors.textTertiary)),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.read<_IeCubit>().load(),
                    child: Text(l.t('common.retry')),
                  ),
                ],
              ),
            );
          }

          final income = (state.data['income'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
          final expenses = (state.data['expenses'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
          final totalIncome = (state.data['totalIncome'] ?? 0).toDouble();
          final totalExpense = (state.data['totalExpense'] ?? 0).toDouble();
          final surplus = (state.data['surplus'] ?? 0).toDouble();
          final periodFrom = state.data['periodFrom'] ?? '';
          final periodTo = state.data['periodTo'] ?? '';

          return RefreshIndicator(
            onRefresh: () => context.read<_IeCubit>().load(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                // Period info
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '${l.t('ie.period')}: ${_formatDate(periodFrom)} - ${_formatDate(periodTo)}',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                ),
                // Surplus/Deficit card
                _SurplusCard(totalIncome: totalIncome, totalExpense: totalExpense, surplus: surplus),
                // Income section
                _SectionHeader(
                  title: l.t('ie.income'),
                  total: totalIncome,
                  color: Colors.green[700]!,
                  icon: Icons.trending_up,
                ),
                if (income.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.t('ie.noJournalEntries'),
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  )
                else
                  ...income.map((item) => _LineItemRow(item: item, isMr: isMr, color: Colors.green[700]!)),
                const SizedBox(height: 8),
                // Expense section
                _SectionHeader(
                  title: l.t('ie.expenses'),
                  total: totalExpense,
                  color: Colors.red[700]!,
                  icon: Icons.trending_down,
                ),
                if (expenses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.t('ie.noJournalEntries'),
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  )
                else
                  ...expenses.map((item) => _LineItemRow(item: item, isMr: isMr, color: Colors.red[700]!)),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

class _SurplusCard extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;
  final double surplus;
  const _SurplusCard({required this.totalIncome, required this.totalExpense, required this.surplus});

  @override
  Widget build(BuildContext context) {
    final isSurplus = surplus >= 0;
    final color = isSurplus ? Colors.green[700]! : Colors.red[700]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withAlpha(20), color.withAlpha(5)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _AmountColumn(label: 'Income', amount: totalIncome, color: Colors.green[700]!),
            Text('-', style: TextStyle(fontSize: 24, color: AppColors.textTertiary)),
            _AmountColumn(label: 'Expenses', amount: totalExpense, color: Colors.red[700]!),
            Text('=', style: TextStyle(fontSize: 24, color: AppColors.textTertiary)),
            _AmountColumn(
              label: isSurplus ? 'Surplus' : 'Deficit',
              amount: surplus.abs(),
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountColumn extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _AmountColumn({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('₹${amount.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final double total;
  final Color color;
  final IconData icon;
  const _SectionHeader({required this.title, required this.total, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          const Spacer(),
          Text('₹${total.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isMr;
  final Color color;
  const _LineItemRow({required this.item, required this.isMr, required this.color});

  @override
  Widget build(BuildContext context) {
    final name = isMr && (item['accountNameMr'] ?? '').isNotEmpty
        ? item['accountNameMr']
        : item['accountName'] ?? '';
    final code = item['accountCode'] ?? '';
    final amount = (item['amount'] ?? 0).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(code,
                style: TextStyle(fontSize: 10, color: AppColors.textTertiary, fontFamily: 'monospace')),
          ),
          Expanded(
            child: Text(name, style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          Text('₹${amount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
