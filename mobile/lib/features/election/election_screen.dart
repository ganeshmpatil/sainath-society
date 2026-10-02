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
  final List<Map<String, dynamic>> elections;
  const _St({this.loading = false, this.error, this.elections = const []});
}

class _Cu extends Cubit<_St> {
  _Cu() : super(const _St());

  Future<void> load() async {
    emit(const _St(loading: true));
    try {
      final res = await api.get('/elections');
      final list = (res.data['elections'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      emit(_St(elections: list));
    } catch (e) {
      emit(_St(error: e.toString()));
    }
  }
}

// ── Screen ────────────────────────────────────────────────────

class ElectionScreen extends StatelessWidget {
  const ElectionScreen({super.key});

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
      case 'UPCOMING': return const Color(0xFF64748B);
      case 'NOMINATIONS_OPEN': return const Color(0xFFF97316);
      case 'VOTING_OPEN': return const Color(0xFF3B82F6);
      case 'COMPLETED': return const Color(0xFF10B981);
      case 'CANCELLED': return const Color(0xFFEF4444);
      default: return const Color(0xFF64748B);
    }
  }

  String _statusLabel(AppLocalizations l, String? status) {
    switch (status) {
      case 'UPCOMING': return l.t('election.upcoming');
      case 'NOMINATIONS_OPEN': return l.t('election.nominationsOpen');
      case 'VOTING_OPEN': return l.t('election.votingOpen');
      case 'COMPLETED': return l.t('election.completed');
      case 'CANCELLED': return l.t('election.cancelled');
      default: return status ?? '';
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
                          Text(l.t('election.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(l.t('election.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
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

                  if (!state.loading && state.error == null && state.elections.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(child: Column(children: [
                          Icon(Icons.how_to_vote_rounded, size: 48, color: AppColors.textTertiary.withAlpha(80)),
                          const SizedBox(height: 12),
                          Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)),
                        ])),
                      ),
                    ),

                  if (!state.loading && state.error == null)
                    SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, i) {
                        final e = state.elections[i];
                        final status = e['status'] as String?;
                        final sColor = _statusColor(status);
                        final title = (isMr ? e['titleMr'] : null) ?? e['title'] ?? '';
                        final votingStart = e['votingStartDate'] != null ? DateTime.tryParse(e['votingStartDate']) : null;
                        final votingEnd = e['votingEndDate'] != null ? DateTime.tryParse(e['votingEndDate']) : null;

                        return GlassCard(
                          onTap: () async {
                            await context.push('/elections/${e['id']}');
                            if (ctx.mounted) ctx.read<_Cu>().load();
                          },
                          child: Row(children: [
                            Container(
                              width: 50, height: 50,
                              decoration: BoxDecoration(
                                color: sColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.how_to_vote_rounded, size: 26, color: sColor),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              if (votingStart != null && votingEnd != null)
                                Text(
                                  '${l.t('election.voting')}: ${_fmtDate(votingStart)} - ${_fmtDate(votingEnd)}',
                                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                ),
                            ])),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: sColor.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                              child: Text(_statusLabel(l, status), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: sColor)),
                            ),
                          ]),
                        );
                      }, childCount: state.elections.length),
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

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  void _showCreate(BuildContext ctx, AppLocalizations l) {
    final cubit = ctx.read<_Cu>();
    String title = '';
    String titleMr = '';

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (c) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l.t('election.create'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(onChanged: (v) => title = v, decoration: InputDecoration(labelText: l.t('election.electionTitle'))),
              const SizedBox(height: 12),
              TextField(onChanged: (v) => titleMr = v, decoration: InputDecoration(labelText: '${l.t('election.electionTitle')} (MR)')),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(c),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(l.t('common.cancel')),
                )),
                const SizedBox(width: 12),
                Expanded(child: GradientButton(label: l.t('common.save'), onPressed: () async {
                  if (title.isEmpty) return;
                  final now = DateTime.now();
                  try {
                    await api.post('/elections', data: {
                      'title': title,
                      'titleMr': titleMr,
                      'nominationStartDate': now.toIso8601String(),
                      'nominationEndDate': now.add(const Duration(days: 7)).toIso8601String(),
                      'votingStartDate': now.add(const Duration(days: 10)).toIso8601String(),
                      'votingEndDate': now.add(const Duration(days: 17)).toIso8601String(),
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
        ),
      ),
    );
  }
}
