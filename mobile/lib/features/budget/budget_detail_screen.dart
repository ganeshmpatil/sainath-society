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
  final Map<String, dynamic>? budget;
  final List<Map<String, dynamic>> lineItems;
  const _St({this.loading = false, this.error, this.budget, this.lineItems = const []});
}

class _Cu extends Cubit<_St> {
  final String id;
  _Cu(this.id) : super(const _St());

  Future<void> load() async {
    emit(const _St(loading: true));
    try {
      final res = await api.get('/budgets/$id');
      final data = res.data as Map<String, dynamic>;
      final items = (data['lineItems'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      emit(_St(budget: data, lineItems: items));
    } catch (e) {
      emit(_St(error: e.toString()));
    }
  }
}

// ── Screen ────────────────────────────────────────────────────

class BudgetDetailScreen extends StatelessWidget {
  final String id;
  const BudgetDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _Cu(id)..load(),
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
              final b = state.budget;
              final status = b?['status'] as String?;
              final sColor = _statusColor(status);
              final incomeItems = state.lineItems.where((i) => i['category'] == 'INCOME').toList();
              final expenseItems = state.lineItems.where((i) => i['category'] == 'EXPENSE').toList();
              final totalBudgetedIncome = incomeItems.fold<double>(0, (s, i) => s + ((i['budgetedAmount'] as num?)?.toDouble() ?? 0));
              final totalBudgetedExpense = expenseItems.fold<double>(0, (s, i) => s + ((i['budgetedAmount'] as num?)?.toDouble() ?? 0));
              final totalActualIncome = incomeItems.fold<double>(0, (s, i) => s + ((i['actualAmount'] as num?)?.toDouble() ?? 0));
              final totalActualExpense = expenseItems.fold<double>(0, (s, i) => s + ((i['actualAmount'] as num?)?.toDouble() ?? 0));

              return CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(b?['title'] ?? l.t('budget.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(b?['financialYear'] ?? '', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        ])),
                        if (b != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: sColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                            child: Text(_statusLabel(l, status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sColor)),
                          ),
                      ]),
                    ),
                  ),

                  if (state.loading)
                    const SliverToBoxAdapter(child: ShimmerLoading()),

                  // Admin status actions
                  if (!state.loading && isAdmin && b != null && status != 'ACTIVE')
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          if (status == 'DRAFT')
                            Expanded(child: _StatusButton(
                              label: l.t('budget.sendForReview'),
                              color: const Color(0xFFF97316),
                              onTap: () => _changeStatus(context, 'COMMITTEE_REVIEW'),
                            )),
                          if (status == 'COMMITTEE_REVIEW') ...[
                            Expanded(child: _StatusButton(
                              label: l.t('budget.agmApprove'),
                              color: const Color(0xFF3B82F6),
                              onTap: () => _changeStatus(context, 'AGM_APPROVED'),
                            )),
                          ],
                          if (status == 'AGM_APPROVED')
                            Expanded(child: _StatusButton(
                              label: l.t('budget.activate'),
                              color: const Color(0xFF10B981),
                              onTap: () => _changeStatus(context, 'ACTIVE'),
                            )),
                        ]),
                      ),
                    ),

                  // Summary
                  if (!state.loading && b != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(children: [
                            Row(children: [
                              Expanded(child: _SummaryCol(
                                label: l.t('budget.budgeted'),
                                income: totalBudgetedIncome,
                                expense: totalBudgetedExpense,
                              )),
                              Container(width: 1, height: 50, color: AppColors.border),
                              Expanded(child: _SummaryCol(
                                label: l.t('budget.actual'),
                                income: totalActualIncome,
                                expense: totalActualExpense,
                              )),
                            ]),
                          ]),
                        ),
                      ),
                    ),

                  // Income section
                  if (!state.loading) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(children: [
                          Icon(Icons.arrow_downward_rounded, size: 16, color: const Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text(l.t('budget.incomeHeads'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
                          const Spacer(),
                          if (isAdmin && status == 'DRAFT')
                            GestureDetector(
                              onTap: () => _showAddLineItem(context, l, 'INCOME'),
                              child: Icon(Icons.add_circle_rounded, size: 22, color: const Color(0xFF10B981)),
                            ),
                        ]),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        return _LineItemCard(item: incomeItems[i], isAdmin: isAdmin, isDraft: status == 'DRAFT');
                      }, childCount: incomeItems.length),
                    ),
                  ],

                  // Expense section
                  if (!state.loading) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(children: [
                          Icon(Icons.arrow_upward_rounded, size: 16, color: const Color(0xFFEF4444)),
                          const SizedBox(width: 6),
                          Text(l.t('budget.expenseHeads'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
                          const Spacer(),
                          if (isAdmin && status == 'DRAFT')
                            GestureDetector(
                              onTap: () => _showAddLineItem(context, l, 'EXPENSE'),
                              child: Icon(Icons.add_circle_rounded, size: 22, color: const Color(0xFFEF4444)),
                            ),
                        ]),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        return _LineItemCard(item: expenseItems[i], isAdmin: isAdmin, isDraft: status == 'DRAFT');
                      }, childCount: expenseItems.length),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _changeStatus(BuildContext ctx, String newStatus) async {
    try {
      final cubit = ctx.read<_Cu>();
      await api.post('/budgets/${cubit.id}/approve', data: {'status': newStatus});
      cubit.load();
    } catch (_) {}
  }

  void _showAddLineItem(BuildContext ctx, AppLocalizations l, String category) {
    final cubit = ctx.read<_Cu>();
    String headName = '';
    String headNameMr = '';
    String amount = '';

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
          Text(
            category == 'INCOME' ? l.t('budget.addIncome') : l.t('budget.addExpense'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(onChanged: (v) => headName = v, decoration: InputDecoration(labelText: l.t('budget.headName'))),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => headNameMr = v, decoration: InputDecoration(labelText: '${l.t('budget.headName')} (MR)')),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => amount = v,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.t('budget.amount'), prefixText: '\u20B9 '),
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
              if (headName.isEmpty || amount.isEmpty) return;
              try {
                await api.post('/budgets/${cubit.id}/line-items', data: {
                  'category': category,
                  'headName': headName,
                  'headNameMr': headNameMr,
                  'budgetedAmount': double.tryParse(amount) ?? 0,
                });
                if (c.mounted) Navigator.pop(c);
                cubit.load();
              } catch (_) {}
            })),
          ]),
        ]),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────

class _StatusButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _StatusButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _SummaryCol extends StatelessWidget {
  final String label;
  final double income;
  final double expense;
  const _SummaryCol({required this.label, required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    final surplus = income - expense;
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary)),
      const SizedBox(height: 8),
      Text('+\u20B9${_fmt(income)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
      Text('-\u20B9${_fmt(expense)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
      const Divider(height: 12),
      Text(
        '${surplus >= 0 ? '+' : ''}\u20B9${_fmt(surplus)}',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: surplus >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
      ),
    ]);
  }

  String _fmt(double v) => v.abs().toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _LineItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isAdmin;
  final bool isDraft;
  const _LineItemCard({required this.item, required this.isAdmin, required this.isDraft});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;
    final isIncome = item['category'] == 'INCOME';
    final color = isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final budgeted = (item['budgetedAmount'] as num?)?.toDouble() ?? 0;
    final actual = (item['actualAmount'] as num?)?.toDouble() ?? 0;
    final variance = actual - budgeted;
    final headName = (isMr ? item['headNameMr'] : null) ?? item['headName'] ?? '';
    final pct = budgeted > 0 ? (actual / budgeted * 100).clamp(0, 200) : 0.0;

    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(headName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          if (isAdmin && isDraft)
            GestureDetector(
              onTap: () async {
                try {
                  await api.delete('/budgets/line-items/${item['id']}');
                  if (context.mounted) context.read<_Cu>().load();
                } catch (_) {}
              },
              child: Icon(Icons.close_rounded, size: 16, color: AppColors.textTertiary),
            ),
        ]),
        const SizedBox(height: 8),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (pct / 100).clamp(0, 1).toDouble(),
            minHeight: 6,
            backgroundColor: color.withAlpha(25),
            valueColor: AlwaysStoppedAnimation(color.withAlpha(pct > 100 ? 255 : 150)),
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text('${l.t('budget.budgeted')}: \u20B9${budgeted.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          const Spacer(),
          Text('${l.t('budget.actual')}: \u20B9${actual.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ]),
        if (variance != 0)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${variance > 0 ? '+' : ''}\u20B9${variance.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}%)',
              style: TextStyle(fontSize: 10, color: variance > 0 ? (isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444)) : const Color(0xFF10B981), fontWeight: FontWeight.w600),
            ),
          ),
      ]),
    );
  }
}
