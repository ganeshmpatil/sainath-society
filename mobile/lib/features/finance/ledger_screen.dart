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
class _LdState extends Equatable {
  final bool loading;
  final String? error;
  final Map<String, dynamic>? account;
  final List<Map<String, dynamic>> ledger;
  const _LdState({this.loading = false, this.error, this.account, this.ledger = const []});
  @override
  List<Object?> get props => [loading, error, account, ledger];
}

class _LdCubit extends Cubit<_LdState> {
  final String accountId;
  _LdCubit(this.accountId) : super(const _LdState());

  Future<void> load({String? from, String? to}) async {
    emit(const _LdState(loading: true));
    try {
      final params = <String, dynamic>{};
      if (from != null) params['from'] = from;
      if (to != null) params['to'] = to;
      final res = await api.get('/finance/journal/ledger/$accountId',
          queryParams: params.isEmpty ? null : params);
      final data = res.data;
      final list = (data['ledger'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      emit(_LdState(
        account: data['account'] as Map<String, dynamic>?,
        ledger: list,
      ));
    } catch (e) {
      emit(_LdState(error: e.toString()));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// Screen — opened from Chart of Accounts by tapping a leaf account
// ═══════════════════════════════════════════════════════════════
class LedgerScreen extends StatelessWidget {
  final String accountId;
  final String accountName;
  const LedgerScreen({super.key, required this.accountId, required this.accountName});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _LdCubit(accountId)..load(),
      child: _View(accountName: accountName),
    );
  }
}

class _View extends StatelessWidget {
  final String accountName;
  const _View({required this.accountName});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(accountName, style: const TextStyle(fontSize: 16)),
        centerTitle: true,
      ),
      body: BlocBuilder<_LdCubit, _LdState>(
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
                    onPressed: () => context.read<_LdCubit>().load(),
                    child: Text(l.t('common.retry')),
                  ),
                ],
              ),
            );
          }

          final account = state.account;
          final code = account?['code'] ?? '';
          final type = account?['type'] ?? '';

          if (state.ledger.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.book_outlined, size: 48, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text(l.t('ledger.noEntries'),
                      style: TextStyle(color: AppColors.textTertiary)),
                  const SizedBox(height: 4),
                  Text('$code | $type',
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            );
          }

          // Closing balance
          final lastBalance = (state.ledger.last['runningBalance'] ?? 0).toDouble();

          return RefreshIndicator(
            onRefresh: () => context.read<_LdCubit>().load(),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                // Account info header
                _AccountHeader(account: account, closingBalance: lastBalance),
                // Ledger table
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _TableHeader(),
                        ...state.ledger.asMap().entries.map((e) =>
                            _LedgerRow(row: e.value, isEven: e.key % 2 == 0)),
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
}

class _AccountHeader extends StatelessWidget {
  final Map<String, dynamic>? account;
  final double closingBalance;
  const _AccountHeader({required this.account, required this.closingBalance});

  @override
  Widget build(BuildContext context) {
    final code = account?['code'] ?? '';
    final type = account?['type'] ?? '';
    final color = _typeColor(type);
    final isDebitNormal = type == 'ASSET' || type == 'EXPENSE';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(code,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, fontFamily: 'monospace')),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(type,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Closing Balance',
                    style: TextStyle(fontSize: 9, color: AppColors.textTertiary)),
                Text(
                  '${closingBalance < 0 ? "-" : ""}₹${closingBalance.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDebitNormal
                        ? (closingBalance >= 0 ? color : Colors.red)
                        : (closingBalance <= 0 ? color : Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'ASSET': return Colors.blue;
      case 'LIABILITY': return Colors.red;
      case 'INCOME': return Colors.green;
      case 'EXPENSE': return Colors.orange;
      case 'FUND': return Colors.purple;
      default: return Colors.grey;
    }
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: Row(
        children: [
          SizedBox(width: 55, child: Text('Date', style: _h)),
          Expanded(flex: 3, child: Text('Narration', style: _h)),
          SizedBox(width: 60, child: Text('Debit', style: _h, textAlign: TextAlign.right)),
          SizedBox(width: 60, child: Text('Credit', style: _h, textAlign: TextAlign.right)),
          SizedBox(width: 70, child: Text('Balance', style: _h, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  static final _h = TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textTertiary);
}

class _LedgerRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isEven;
  const _LedgerRow({required this.row, required this.isEven});

  @override
  Widget build(BuildContext context) {
    final narration = row['narration'] ?? '';
    final dr = (row['debitAmount'] ?? 0).toDouble();
    final cr = (row['creditAmount'] ?? 0).toDouble();
    final balance = (row['runningBalance'] ?? 0).toDouble();
    final date = _formatDate(row['date'] ?? '');
    final entryNo = row['entryNo'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isEven ? AppColors.surface : AppColors.borderLight,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: TextStyle(fontSize: 10, color: AppColors.textPrimary)),
                Text(entryNo, style: TextStyle(fontSize: 8, color: AppColors.textTertiary, fontFamily: 'monospace')),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(narration,
                style: TextStyle(fontSize: 10, color: AppColors.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 60,
            child: Text(
              dr > 0 ? '₹${dr.toStringAsFixed(0)}' : '',
              style: TextStyle(fontSize: 10, color: Colors.green[700]),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              cr > 0 ? '₹${cr.toStringAsFixed(0)}' : '',
              style: TextStyle(fontSize: 10, color: Colors.red[700]),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              '${balance < 0 ? "-" : ""}₹${balance.abs().toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
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
