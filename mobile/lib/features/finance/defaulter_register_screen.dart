import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ═══════════════════════════════════════════════════════════════
// State
// ═══════════════════════════════════════════════════════════════
class _DfState extends Equatable {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> defaulters;
  final Map<String, dynamic> summary;
  const _DfState({this.loading = false, this.error, this.defaulters = const [], this.summary = const {}});
  @override
  List<Object?> get props => [loading, error, defaulters, summary];
}

class _DfCubit extends Cubit<_DfState> {
  _DfCubit() : super(const _DfState());

  Future<void> load() async {
    emit(const _DfState(loading: true));
    try {
      final results = await Future.wait([
        api.get('/finance/defaulters/register'),
        api.get('/finance/defaulters/summary'),
      ]);
      final list = (results[0].data['defaulters'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      final summaryData = results[1].data as Map<String, dynamic>? ?? {};
      emit(_DfState(defaulters: list, summary: summaryData));
    } catch (e) {
      emit(_DfState(error: e.toString()));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════
class DefaulterRegisterScreen extends StatelessWidget {
  const DefaulterRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _DfCubit()..load(),
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
        title: Text(l.t('defaulter.title')),
        centerTitle: true,
      ),
      body: BlocBuilder<_DfCubit, _DfState>(
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
                    onPressed: () => context.read<_DfCubit>().load(),
                    child: Text(l.t('common.retry')),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<_DfCubit>().load(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                _SummaryCards(summary: state.summary),
                _AgingChart(summary: state.summary),
                if (state.defaulters.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline, size: 48, color: Colors.green[400]),
                          const SizedBox(height: 12),
                          Text(l.t('defaulter.noDefaulters'),
                              style: TextStyle(color: AppColors.textTertiary)),
                        ],
                      ),
                    ),
                  )
                else
                  ...state.defaulters.map((d) => _DefaulterCard(data: d)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Summary Cards
// ═══════════════════════════════════════════════════════════════
class _SummaryCards extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final outstanding = (summary['totalOutstanding'] ?? 0).toDouble();
    final totalMembers = summary['totalMembers'] ?? 0;
    final defaulterCount = summary['defaulterCount'] ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: l.t('defaulter.totalOutstanding'),
              value: '₹${_formatAmount(outstanding)}',
              color: Colors.red,
              icon: Icons.account_balance_wallet,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: l.t('defaulter.membersWithDues'),
              value: '$totalMembers',
              color: Colors.orange,
              icon: Icons.people,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              label: l.t('defaulter.defaulters90'),
              value: '$defaulterCount',
              color: Colors.red[800]!,
              icon: Icons.warning,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 9, color: AppColors.textTertiary),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Aging Chart (horizontal stacked bar)
// ═══════════════════════════════════════════════════════════════
class _AgingChart extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _AgingChart({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final b1 = (summary['bucket0to30Total'] ?? 0).toDouble();
    final b2 = (summary['bucket31to60Total'] ?? 0).toDouble();
    final b3 = (summary['bucket61to90Total'] ?? 0).toDouble();
    final b4 = (summary['bucket90PlusTotal'] ?? 0).toDouble();
    final total = b1 + b2 + b3 + b4;
    if (total == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.t('defaulter.agingAnalysis'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            // Stacked bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 20,
                child: Row(
                  children: [
                    if (b1 > 0) Expanded(flex: (b1 / total * 100).round(), child: Container(color: Colors.green[400])),
                    if (b2 > 0) Expanded(flex: (b2 / total * 100).round(), child: Container(color: Colors.yellow[700])),
                    if (b3 > 0) Expanded(flex: (b3 / total * 100).round(), child: Container(color: Colors.orange)),
                    if (b4 > 0) Expanded(flex: (b4 / total * 100).round(), child: Container(color: Colors.red)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AgingLegend(color: Colors.green[400]!, label: '0-30d', amount: b1),
                _AgingLegend(color: Colors.yellow[700]!, label: '31-60d', amount: b2),
                _AgingLegend(color: Colors.orange, label: '61-90d', amount: b3),
                _AgingLegend(color: Colors.red, label: '90+d', amount: b4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AgingLegend extends StatelessWidget {
  final Color color;
  final String label;
  final double amount;
  const _AgingLegend({required this.color, required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
          ],
        ),
        Text('₹${_formatAmount(amount)}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Defaulter Card
// ═══════════════════════════════════════════════════════════════
class _DefaulterCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DefaulterCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['memberName'] ?? '';
    final flat = data['flatNumber'] ?? '';
    final wing = data['wingName'] ?? '';
    final outstanding = (data['outstanding'] ?? 0).toDouble();
    final days = data['daysOverdue'] ?? 0;
    final isDefaulter = data['isDefaulter'] == true;
    final bills = data['totalBills'] ?? 0;
    final b1 = (data['bucket0to30'] ?? 0).toDouble();
    final b2 = (data['bucket31to60'] ?? 0).toDouble();
    final b3 = (data['bucket61to90'] ?? 0).toDouble();
    final b4 = (data['bucket90Plus'] ?? 0).toDouble();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDefaulter ? Colors.red.withAlpha(80) : AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(name,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          if (isDefaulter) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.withAlpha(20),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('DEFAULTER',
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Colors.red[700])),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('$wing-$flat  |  $bills bills  |  $days days overdue',
                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${_formatAmount(outstanding)}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.red[700])),
                    Text('outstanding',
                        style: TextStyle(fontSize: 9, color: AppColors.textTertiary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Mini aging bar
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: [
                    if (b1 > 0) Expanded(flex: (b1 / outstanding * 100).round().clamp(1, 100), child: Container(color: Colors.green[400])),
                    if (b2 > 0) Expanded(flex: (b2 / outstanding * 100).round().clamp(1, 100), child: Container(color: Colors.yellow[700])),
                    if (b3 > 0) Expanded(flex: (b3 / outstanding * 100).round().clamp(1, 100), child: Container(color: Colors.orange)),
                    if (b4 > 0) Expanded(flex: (b4 / outstanding * 100).round().clamp(1, 100), child: Container(color: Colors.red)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatAmount(double amount) {
  if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
  if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
  return amount.toStringAsFixed(0);
}
