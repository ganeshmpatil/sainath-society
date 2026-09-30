import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ── State & Cubit ─────────────────────────────────────────────

class _St {
  final bool loading;
  final String? error;
  final Map<String, dynamic>? checklist;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> progress;
  const _St({this.loading = false, this.error, this.checklist, this.items = const [], this.progress = const {}});
}

class _Cu extends Cubit<_St> {
  final String id;
  _Cu(this.id) : super(const _St());

  Future<void> load() async {
    emit(const _St(loading: true));
    try {
      final res = await api.get('/audit-checklists/$id');
      final data = res.data as Map<String, dynamic>;
      final checklist = data['checklist'] as Map<String, dynamic>? ?? data;
      final items = (data['items'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? (checklist['items'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      final progress = (data['progress'] as Map<String, dynamic>?) ?? {};
      emit(_St(checklist: checklist, items: items, progress: progress));
    } catch (e) {
      emit(_St(error: e.toString()));
    }
  }

  Future<void> toggleItem(String itemId, bool completed) async {
    try {
      await api.patch('/audit-checklists/items/$itemId/toggle', data: {'completed': completed});
      load();
    } catch (e) {
      emit(_St(checklist: state.checklist, items: state.items, progress: state.progress, error: e.toString()));
    }
  }
}

// ── Screen ────────────────────────────────────────────────────

class AuditDetailScreen extends StatelessWidget {
  final String id;
  const AuditDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _Cu(id)..load(),
    child: const _View(),
  );
}

class _View extends StatelessWidget {
  const _View();

  static const _categoryOrder = ['FINANCIAL', 'REGISTERS', 'COMPLIANCE', 'DOCUMENTS'];

  String _categoryLabel(AppLocalizations l, String cat) {
    switch (cat) {
      case 'FINANCIAL': return l.t('audit.catFinancial');
      case 'REGISTERS': return l.t('audit.catRegisters');
      case 'COMPLIANCE': return l.t('audit.catCompliance');
      case 'DOCUMENTS': return l.t('audit.catDocuments');
      default: return cat;
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'FINANCIAL': return Icons.account_balance_wallet_rounded;
      case 'REGISTERS': return Icons.menu_book_rounded;
      case 'COMPLIANCE': return Icons.gavel_rounded;
      case 'DOCUMENTS': return Icons.folder_rounded;
      default: return Icons.checklist_rounded;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'FINANCIAL': return const Color(0xFF3B82F6);
      case 'REGISTERS': return const Color(0xFFF97316);
      case 'COMPLIANCE': return const Color(0xFF8B5CF6);
      case 'DOCUMENTS': return const Color(0xFF10B981);
      default: return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<_Cu>().load(),
          color: AppColors.primary,
          child: BlocBuilder<_Cu, _St>(
            builder: (context, state) {
              final cl = state.checklist;
              final completed = state.progress['completed'] ?? 0;
              final total = state.progress['total'] ?? 0;
              final pct = total > 0 ? (completed / total) : 0.0;

              // Group items by category
              final grouped = <String, List<Map<String, dynamic>>>{};
              for (final item in state.items) {
                final cat = item['category'] as String? ?? 'OTHER';
                grouped.putIfAbsent(cat, () => []).add(item);
              }

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
                          Text(cl?['title'] ?? l.t('audit.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text('FY ${cl?['financialYear'] ?? ''}', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
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

                  // Progress bar
                  if (!state.loading && state.error == null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(l.t('audit.progress'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const Spacer(),
                              Text('$completed / $total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ]),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: pct.toDouble(),
                                minHeight: 10,
                                backgroundColor: AppColors.primary.withAlpha(20),
                                valueColor: AlwaysStoppedAnimation(pct >= 1.0 ? const Color(0xFF10B981) : AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('${(pct * 100).toStringAsFixed(0)}% ${l.t('audit.complete')}',
                                style: TextStyle(fontSize: 11, color: pct >= 1.0 ? const Color(0xFF10B981) : AppColors.textTertiary)),
                          ]),
                        ),
                      ),
                    ),

                  // Items by category
                  if (!state.loading && state.error == null)
                    ..._categoryOrder.where((cat) => grouped.containsKey(cat)).expand((cat) {
                      final items = grouped[cat]!;
                      final catColor = _categoryColor(cat);
                      final catCompleted = items.where((i) => i['isCompleted'] == true).length;
                      return [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(children: [
                              Icon(_categoryIcon(cat), size: 16, color: catColor),
                              const SizedBox(width: 8),
                              Text(_categoryLabel(l, cat), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: catColor)),
                              const Spacer(),
                              Text('$catCompleted/${items.length}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                            ]),
                          ),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate((ctx, i) {
                            final item = items[i];
                            final done = item['isCompleted'] == true;
                            final title = (isMr ? item['titleMr'] : null) ?? item['title'] ?? '';

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: done ? const Color(0xFF10B981).withAlpha(10) : AppColors.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: done ? const Color(0xFF10B981).withAlpha(40) : AppColors.border),
                                ),
                                child: Row(children: [
                                  if (isAdmin)
                                    GestureDetector(
                                      onTap: () => context.read<_Cu>().toggleItem(item['id'], !done),
                                      child: Container(
                                        width: 24, height: 24,
                                        decoration: BoxDecoration(
                                          color: done ? const Color(0xFF10B981) : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: done ? const Color(0xFF10B981) : AppColors.textTertiary, width: 2),
                                        ),
                                        child: done ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                                      ),
                                    )
                                  else
                                    Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 20, color: done ? const Color(0xFF10B981) : AppColors.textTertiary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: done ? AppColors.textTertiary : AppColors.textPrimary,
                                        decoration: done ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                            );
                          }, childCount: items.length),
                        ),
                      ];
                    }),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
