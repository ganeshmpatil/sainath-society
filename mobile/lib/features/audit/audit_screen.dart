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
  final List<Map<String, dynamic>> checklists;
  const _St({this.loading = false, this.error, this.checklists = const []});
}

class _Cu extends Cubit<_St> {
  _Cu() : super(const _St());

  Future<void> load() async {
    emit(const _St(loading: true));
    try {
      final res = await api.get('/audit-checklists');
      final list = (res.data['checklists'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      emit(_St(checklists: list));
    } catch (e) {
      emit(_St(error: e.toString()));
    }
  }
}

// ── Screen ────────────────────────────────────────────────────

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _Cu()..load(),
    child: const _ListView(),
  );
}

class _ListView extends StatelessWidget {
  const _ListView();

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
                          Text(l.t('audit.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(l.t('audit.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        ])),
                      ]),
                    ),
                  ),

                  if (state.loading)
                    const SliverToBoxAdapter(child: ShimmerLoading()),

                  if (!state.loading && state.checklists.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(child: Column(children: [
                          Icon(Icons.fact_check_rounded, size: 48, color: AppColors.textTertiary.withAlpha(80)),
                          const SizedBox(height: 12),
                          Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)),
                        ])),
                      ),
                    ),

                  if (!state.loading)
                    SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        final c = state.checklists[i];
                        final status = c['status'] as String? ?? 'IN_PROGRESS';
                        final sColor = status == 'READY' ? const Color(0xFF10B981) : status == 'SUBMITTED' ? const Color(0xFF3B82F6) : const Color(0xFFF97316);

                        return GlassCard(
                          onTap: () async {
                            await context.push('/audit/${c['id']}');
                            if (ctx.mounted) ctx.read<_Cu>().load();
                          },
                          child: Row(children: [
                            Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(color: sColor.withAlpha(25), borderRadius: BorderRadius.circular(14)),
                              child: Icon(Icons.fact_check_rounded, size: 26, color: sColor),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              Text('FY ${c['financialYear'] ?? ''}', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                              if (c['auditorName'] != null && c['auditorName'].toString().isNotEmpty)
                                Text('Auditor: ${c['auditorName']}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                            ])),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: sColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                              child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: sColor)),
                            ),
                          ]),
                        );
                      }, childCount: state.checklists.length),
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
              onPressed: () => _showCreate(context, l),
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
    );
  }

  void _showCreate(BuildContext ctx, AppLocalizations l) {
    final cubit = ctx.read<_Cu>();
    final currentYear = DateTime.now().year;
    String financialYear = '$currentYear-${currentYear + 1}';
    String title = 'Audit Preparation $financialYear';
    String auditorName = '';

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
          Text(l.t('audit.create'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(controller: TextEditingController(text: financialYear), onChanged: (v) => financialYear = v, decoration: InputDecoration(labelText: l.t('budget.financialYear'))),
          const SizedBox(height: 12),
          TextField(controller: TextEditingController(text: title), onChanged: (v) => title = v, decoration: InputDecoration(labelText: l.t('audit.checklistTitle'))),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => auditorName = v, decoration: InputDecoration(labelText: l.t('audit.auditorName'))),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(l.t('common.cancel')))),
            const SizedBox(width: 12),
            Expanded(child: GradientButton(label: l.t('common.save'), onPressed: () async {
              if (financialYear.isEmpty) return;
              try {
                await api.post('/audit-checklists', data: {'financialYear': financialYear, 'title': title, 'auditorName': auditorName});
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
