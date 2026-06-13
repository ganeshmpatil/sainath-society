import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/filter_chips_row.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/status_badge.dart';

class _FD extends Equatable {
  final bool loading;
  final double pendingAmount;
  final int unpaidCount;
  final List<Map<String, dynamic>> bills;
  const _FD({this.loading = false, this.pendingAmount = 0, this.unpaidCount = 0, this.bills = const []});
  @override List<Object?> get props => [loading, pendingAmount, unpaidCount, bills];
}

class _FC extends Cubit<_FD> {
  _FC() : super(const _FD());
  Future<void> load([String? status]) async {
    emit(const _FD(loading: true));
    try {
      final duesRes = await api.get('/finance/bills/pending-dues').catchError((_) => Response(requestOptions: RequestOptions(), data: <String, dynamic>{}));
      final billsRes = await api.get('/finance/bills', queryParams: status != null && status.isNotEmpty ? {'status': status} : null).catchError((_) => Response(requestOptions: RequestOptions(), data: <String, dynamic>{}));
      final dues = duesRes.data ?? {}; final bd = billsRes.data ?? {};
      emit(_FD(pendingAmount: (dues['pendingAmount'] ?? 0).toDouble(), unpaidCount: dues['unpaidCount'] ?? 0,
          bills: (bd['bills'] as List?)?.cast<Map<String, dynamic>>() ?? []));
    } catch (_) { emit(const _FD()); }
  }
}

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});
  @override Widget build(BuildContext context) => BlocProvider(create: (_) => _FC()..load(), child: const _FV());
}

class _FV extends StatefulWidget {
  const _FV();
  @override State<_FV> createState() => _FVS();
}

class _FVS extends State<_FV> {
  int _fi = 0;
  static const _fl = ['finance.allBills', 'finance.pending', 'finance.paid', 'finance.overdue'];
  static const _fv = ['', 'ISSUED', 'PAID', 'OVERDUE'];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); context.watch<LocaleCubit>();
    return Scaffold(body: SafeArea(child: RefreshIndicator(
      onRefresh: () => context.read<_FC>().load(), color: AppColors.primary,
      child: BlocBuilder<_FC, _FD>(builder: (context, state) {
        if (state.loading) return const ShimmerLoading(itemCount: 5);
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.t('finance.title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            Text(l.t('finance.subtitle'), style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ]))),
          SliverToBoxAdapter(child: Container(
            margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary.withAlpha(25), AppColors.secondary.withAlpha(25)]),
              borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withAlpha(50))),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.t('finance.myPendingDues'), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('₹${state.pendingAmount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${state.unpaidCount} ${l.t('finance.billsOverdue')}', style: const TextStyle(fontSize: 11, color: AppColors.urgent)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
                child: Text(l.t('finance.payNow'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white))),
            ]),
          )),
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(bottom: 12), child: FilterChipsRow(
            labels: _fl.map((k) => l.t(k)).toList(), selectedIndex: _fi,
            onSelected: (i) { setState(() => _fi = i); context.read<_FC>().load(_fv[i]); },
          ))),
          if (state.bills.isEmpty) SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
              child: Center(child: Text(l.t('common.noRecords'), style: const TextStyle(color: AppColors.textTertiary))))),
          SliverList(delegate: SliverChildBuilderDelegate((ctx, i) => _BC(bill: state.bills[i]), childCount: state.bills.length)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]);
      }),
    )));
  }
}

class _BC extends StatelessWidget {
  final Map<String, dynamic> bill;
  const _BC({required this.bill});
  @override Widget build(BuildContext context) {
    final status = bill['status'] ?? 'ISSUED';
    final amount = (bill['totalAmount'] ?? 0).toDouble();
    final period = bill['billingPeriod'] ?? '';
    final sc = AppColors.statusColor(status);
    return GlassCard(child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: sc.withAlpha(30), borderRadius: BorderRadius.circular(12)),
        child: Icon(Icons.currency_rupee_rounded, size: 20, color: sc)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Maintenance - $period', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ])),
      StatusBadge.status(status),
    ]));
  }
}
