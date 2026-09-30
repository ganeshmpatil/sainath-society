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
class _StState extends Equatable {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> statement;
  final double totalDebit;
  final double totalCredit;
  final double balance;
  const _StState({
    this.loading = false,
    this.error,
    this.statement = const [],
    this.totalDebit = 0,
    this.totalCredit = 0,
    this.balance = 0,
  });
  @override
  List<Object?> get props => [loading, error, statement, totalDebit, totalCredit, balance];
}

class _StCubit extends Cubit<_StState> {
  final String? memberId;
  _StCubit(this.memberId) : super(const _StState());

  Future<void> load() async {
    emit(const _StState(loading: true));
    try {
      final endpoint = memberId != null
          ? '/finance/defaulters/statement/$memberId'
          : '/finance/defaulters/my-statement';
      final res = await api.get(endpoint);
      final data = res.data;
      final list = (data['statement'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      emit(_StState(
        statement: list,
        totalDebit: (data['totalDebit'] ?? 0).toDouble(),
        totalCredit: (data['totalCredit'] ?? 0).toDouble(),
        balance: (data['balance'] ?? 0).toDouble(),
      ));
    } catch (e) {
      emit(_StState(error: e.toString()));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════
class MemberStatementScreen extends StatelessWidget {
  final String? memberId; // null = current user
  const MemberStatementScreen({super.key, this.memberId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _StCubit(memberId)..load(),
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
        title: Text(l.t('statement.title')),
        centerTitle: true,
      ),
      body: BlocBuilder<_StCubit, _StState>(
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
                    onPressed: () => context.read<_StCubit>().load(),
                    child: Text(l.t('common.retry')),
                  ),
                ],
              ),
            );
          }
          if (state.statement.isEmpty) {
            return Center(
              child: Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<_StCubit>().load(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                // Summary card
                _SummaryCard(
                  totalDebit: state.totalDebit,
                  totalCredit: state.totalCredit,
                  balance: state.balance,
                ),
                // Statement table
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(15),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                          child: Row(
                            children: [
                              SizedBox(width: 60, child: Text('Date', style: _headerStyle)),
                              Expanded(child: Text('Description', style: _headerStyle)),
                              SizedBox(width: 65, child: Text('Debit', style: _headerStyle, textAlign: TextAlign.right)),
                              SizedBox(width: 65, child: Text('Credit', style: _headerStyle, textAlign: TextAlign.right)),
                              SizedBox(width: 70, child: Text('Balance', style: _headerStyle, textAlign: TextAlign.right)),
                            ],
                          ),
                        ),
                        ...state.statement.asMap().entries.map((e) {
                          final row = e.value;
                          final desc = isMr && (row['descriptionMr'] ?? '').isNotEmpty
                              ? row['descriptionMr']
                              : row['description'] ?? '';
                          final debit = (row['debit'] ?? 0).toDouble();
                          final credit = (row['credit'] ?? 0).toDouble();
                          final balance = (row['balance'] ?? 0).toDouble();
                          final date = _formatDate(row['date'] ?? '');
                          final isEven = e.key % 2 == 0;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: isEven ? AppColors.surface : AppColors.borderLight,
                              border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(width: 60, child: Text(date, style: _cellStyle)),
                                Expanded(
                                  child: Text(desc,
                                      style: _cellStyle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                SizedBox(
                                  width: 65,
                                  child: Text(
                                    debit > 0 ? '₹${debit.toStringAsFixed(0)}' : '',
                                    style: TextStyle(fontSize: 11, color: Colors.red[700]),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                SizedBox(
                                  width: 65,
                                  child: Text(
                                    credit > 0 ? '₹${credit.toStringAsFixed(0)}' : '',
                                    style: TextStyle(fontSize: 11, color: Colors.green[700]),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    '₹${balance.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: balance > 0 ? Colors.red[700] : Colors.green[700],
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
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

  static final _headerStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textTertiary);
  static final _cellStyle = TextStyle(fontSize: 11, color: AppColors.textPrimary);

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return raw;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Summary Card
// ═══════════════════════════════════════════════════════════════
class _SummaryCard extends StatelessWidget {
  final double totalDebit;
  final double totalCredit;
  final double balance;
  const _SummaryCard({required this.totalDebit, required this.totalCredit, required this.balance});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withAlpha(15), AppColors.primary.withAlpha(5)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withAlpha(30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryItem(label: 'Total Charges', value: '₹${totalDebit.toStringAsFixed(0)}', color: Colors.red[700]!),
            Container(width: 1, height: 30, color: AppColors.border),
            _SummaryItem(label: 'Total Paid', value: '₹${totalCredit.toStringAsFixed(0)}', color: Colors.green[700]!),
            Container(width: 1, height: 30, color: AppColors.border),
            _SummaryItem(
              label: balance > 0 ? 'Balance Due' : 'Credit',
              value: '₹${balance.abs().toStringAsFixed(0)}',
              color: balance > 0 ? Colors.red[700]! : Colors.green[700]!,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
      ],
    );
  }
}
