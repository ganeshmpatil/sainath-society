import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ── State & Cubit ─────────────────────────────────────────────

class _St {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> budgets;
  const _St({this.loading = false, this.error, this.budgets = const []});
}

class _Cu extends Cubit<_St> {
  _Cu() : super(const _St());

  Future<void> load() async {
    emit(const _St(loading: true));
    try {
      final res = await api.get('/budgets');
      final list = (res.data['budgets'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      emit(_St(budgets: list));
    } catch (e) {
      emit(_St(error: e.toString()));
    }
  }
}

// ── Screen ────────────────────────────────────────────────────

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _Cu()..load(),
    child: const _View(),
  );
}

class _View extends StatelessWidget {
  const _View();

  Color _statusColor(String? status) {
    switch (status) {
      case 'DRAFT': return const Color(0xFF64748B);
      case 'COMMITTEE_REVIEW': return const Color(0xFFF97316);
      case 'AGM_APPROVED': return const Color(0xFF3B82F6);
      case 'ACTIVE': return const Color(0xFF10B981);
      default: return const Color(0xFF64748B);
    }
  }

  String _statusLabel(AppLocalizations l, String? status) {
    switch (status) {
      case 'DRAFT': return l.t('budget.draft');
      case 'COMMITTEE_REVIEW': return l.t('budget.committeeReview');
      case 'AGM_APPROVED': return l.t('budget.agmApproved');
      case 'ACTIVE': return l.t('budget.active');
      default: return status ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.watch<LocaleCubit>();
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<_Cu>().load(),
          color: AppColors.primary,
          child: BlocBuilder<_Cu, _St>(
            builder: (context, state) {
              return CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () { if (context.canPop()) context.pop(); else context.go('/more'); },
                          child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l.t('budget.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(l.t('budget.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        ])),
                      ]),
                    ),
                  ),

                  if (state.loading)
                    const SliverToBoxAdapter(child: ShimmerLoading()),

                  if (!state.loading && state.error != null)
                    SliverToBoxAdapter(
                      child: Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60),
                          Icon(Icons.error_outline, size: 48, color: AppColors.urgent),
                          const SizedBox(height: 8),
                          Text(state.error!, style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => context.read<_Cu>().load(),
                            child: Text(l.t('common.retry'), style: TextStyle(color: AppColors.primary)),
                          ),
                        ],
                      )),
                    ),

                  if (!state.loading && state.error == null && state.budgets.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(child: Column(children: [
                          Icon(Icons.account_balance_rounded, size: 48, color: AppColors.textTertiary.withAlpha(80)),
                          const SizedBox(height: 12),
                          Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)),
                        ])),
                      ),
                    ),

                  // Budget list
                  if (!state.loading && state.error == null)
                    SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        final b = state.budgets[i];
                        final status = b['status'] as String?;
                        final sColor = _statusColor(status);
                        final income = (b['totalIncome'] as num?)?.toDouble() ?? 0;
                        final expense = (b['totalExpense'] as num?)?.toDouble() ?? 0;
                        final surplus = income - expense;

                        return GlassCard(
                          onTap: () async {
                            await context.push('/budgets/${b['id']}');
                            if (ctx.mounted) ctx.read<_Cu>().load();
                          },
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(color: sColor.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                                child: Icon(Icons.account_balance_wallet_rounded, size: 22, color: sColor),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(b['title'] ?? b['financialYear'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                Text(b['financialYear'] ?? '', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                              ])),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: sColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                                child: Text(_statusLabel(l, status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sColor)),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              _MiniStat(label: l.t('budget.income'), value: _formatAmount(income), color: const Color(0xFF10B981)),
                              const SizedBox(width: 12),
                              _MiniStat(label: l.t('budget.expense'), value: _formatAmount(expense), color: const Color(0xFFEF4444)),
                              const SizedBox(width: 12),
                              _MiniStat(
                                label: l.t('budget.surplus'),
                                value: _formatAmount(surplus),
                                color: surplus >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              ),
                            ]),
                          ]),
                        );
                      }, childCount: state.budgets.length),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showCreateBudget(context, l),
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }

  void _showCreateBudget(BuildContext ctx, AppLocalizations l) {
    final cubit = ctx.read<_Cu>();
    final currentYear = DateTime.now().year;
    String financialYear = '$currentYear-${currentYear + 1}';
    String title = 'Annual Budget $financialYear';

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 20),
          Text(l.t('budget.create'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: TextEditingController(text: financialYear),
            onChanged: (v) => financialYear = v,
            decoration: InputDecoration(labelText: l.t('budget.financialYear'), hintText: '2026-2027'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: title),
            onChanged: (v) => title = v,
            decoration: InputDecoration(labelText: l.t('budget.budgetTitle')),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(c),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(l.t('common.cancel')),
            )),
            const SizedBox(width: 12),
            Expanded(child: GradientButton(label: l.t('common.save'), onPressed: () async {
              if (financialYear.isEmpty) return;
              try {
                await api.post('/budgets', data: {
                  'financialYear': financialYear,
                  'title': title,
                });
                if (c.mounted) Navigator.pop(c);
                if (c.mounted) cubit.load();
              } catch (e) {
                if (c.mounted) {
                  ScaffoldMessenger.of(c).showSnackBar(
                    SnackBar(content: Text(e is DioException ? (e.response?.data?['error'] ?? l.t('common.requestFailed')) : l.t('common.requestFailed'))),
                  );
                }
              }
            })),
          ]),
        ]),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: color.withAlpha(180))),
        ]),
      ),
    );
  }
}
