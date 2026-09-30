import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ═══════════════════════════════════════════════════════════════
// State — fetches FUND type accounts and their ledger balances
// ═══════════════════════════════════════════════════════════════
class _FtState extends Equatable {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> funds;
  const _FtState({this.loading = false, this.error, this.funds = const []});
  @override
  List<Object?> get props => [loading, error, funds];
}

class _FtCubit extends Cubit<_FtState> {
  _FtCubit() : super(const _FtState());

  Future<void> load() async {
    emit(const _FtState(loading: true));
    try {
      // Get trial balance which has per-account balances
      final tbRes = await api.get('/finance/journal/trial-balance');
      final accounts = (tbRes.data['accounts'] as List?) ?? [];

      // Filter only FUND type accounts
      final fundAccounts = accounts
          .whereType<Map<String, dynamic>>()
          .where((a) => a['accountType'] == 'FUND')
          .toList();

      // For each fund, also fetch the ledger to get recent entries
      final enriched = <Map<String, dynamic>>[];
      for (final fund in fundAccounts) {
        final id = fund['accountId']?.toString() ?? '';
        if (id.isEmpty) continue;

        try {
          final ledgerRes = await api.get('/finance/journal/ledger/$id');
          final ledgerEntries = (ledgerRes.data['ledger'] as List?) ?? [];
          enriched.add({
            ...fund,
            'ledger': ledgerEntries,
            'account': ledgerRes.data['account'],
          });
        } catch (_) {
          enriched.add({...fund, 'ledger': [], 'account': null});
        }
      }

      emit(_FtState(funds: enriched));
    } catch (e) {
      emit(_FtState(error: e.toString()));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Screen
// ═══════════════════════════════════════════════════════════════
class FundTrackingScreen extends StatelessWidget {
  const FundTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _FtCubit()..load(),
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
        title: Text(l.t('fund.title')),
        centerTitle: true,
      ),
      body: BlocBuilder<_FtCubit, _FtState>(
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
                    onPressed: () => context.read<_FtCubit>().load(),
                    child: Text(l.t('common.retry')),
                  ),
                ],
              ),
            );
          }

          if (state.funds.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.savings_outlined,
                      size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(l.t('fund.noFunds'),
                      style: TextStyle(color: AppColors.textTertiary)),
                  const SizedBox(height: 4),
                  Text(l.t('fund.noFundsHint'),
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            );
          }

          // Total fund balance
          double totalBalance = 0;
          for (final f in state.funds) {
            totalBalance +=
                (f['creditBalance'] ?? f['debitBalance'] ?? 0).toDouble();
          }

          return RefreshIndicator(
            onRefresh: () => context.read<_FtCubit>().load(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Total fund corpus
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.withAlpha(20),
                        Colors.purple.withAlpha(8)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.withAlpha(40)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.savings,
                              color: Colors.purple, size: 24),
                          const SizedBox(width: 10),
                          Text(l.t('fund.totalCorpus'),
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${totalBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.purple,
                        ),
                      ),
                      Text(
                        '${state.funds.length} ${l.t('fund.activeFunds')}',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Individual fund cards
                ...state.funds.map((fund) =>
                    _FundCard(fund: fund, isMr: isMr)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FundCard extends StatelessWidget {
  final Map<String, dynamic> fund;
  final bool isMr;
  const _FundCard({required this.fund, required this.isMr});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = isMr && (fund['accountNameMr'] ?? '').toString().isNotEmpty
        ? fund['accountNameMr']
        : fund['accountName'];
    final code = fund['accountCode'] ?? '';
    final balance =
        (fund['creditBalance'] ?? fund['debitBalance'] ?? 0).toDouble();
    final ledger = (fund['ledger'] as List?) ?? [];

    // Calculate contributions (credits) and withdrawals (debits)
    double contributions = 0;
    double withdrawals = 0;
    for (final entry in ledger) {
      if (entry is Map<String, dynamic>) {
        contributions += (entry['creditAmount'] ?? 0).toDouble();
        withdrawals += (entry['debitAmount'] ?? 0).toDouble();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purple.withAlpha(30)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(code,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple,
                          fontFamily: 'monospace')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(name,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
                Text(
                  '₹${balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                _StatChip(
                  label: l.t('fund.contributions'),
                  value: contributions,
                  color: Colors.green,
                  icon: Icons.add_circle_outline,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: l.t('fund.withdrawals'),
                  value: withdrawals,
                  color: Colors.red,
                  icon: Icons.remove_circle_outline,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: l.t('fund.entries'),
                  value: ledger.length.toDouble(),
                  color: Colors.blue,
                  icon: Icons.list,
                  isCount: true,
                ),
              ],
            ),
          ),

          // Recent entries
          if (ledger.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.purple.withAlpha(8),
                border: Border(
                    top: BorderSide(color: Colors.purple.withAlpha(20))),
              ),
              child: Row(
                children: [
                  Text(l.t('fund.recentActivity'),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary)),
                ],
              ),
            ),
            ...ledger
                .take(3)
                .whereType<Map<String, dynamic>>()
                .map((entry) {
              final narration = entry['narration'] ?? '';
              final dr = (entry['debitAmount'] ?? 0).toDouble();
              final cr = (entry['creditAmount'] ?? 0).toDouble();
              final date = _formatDate(entry['date'] ?? '');
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(date,
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textTertiary)),
                    ),
                    Expanded(
                      child: Text(narration,
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (cr > 0)
                      Text('+₹${cr.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700])),
                    if (dr > 0)
                      Text('-₹${dr.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700])),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
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

class _StatChip extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final bool isCount;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.isCount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 2),
            Text(
              isCount
                  ? value.toInt().toString()
                  : '₹${value.toStringAsFixed(0)}',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color),
            ),
            Text(label,
                style: TextStyle(fontSize: 8, color: AppColors.textTertiary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
