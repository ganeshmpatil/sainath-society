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
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ── State & Cubit ─────────────────────────────────────────────

class _St {
  final bool loading;
  final String? error;
  final Map<String, dynamic>? election;
  final List<Map<String, dynamic>> positions;
  final List<Map<String, dynamic>> candidates;
  final Map<String, dynamic>? results;
  const _St({this.loading = false, this.error, this.election, this.positions = const [], this.candidates = const [], this.results});
}

class _Cu extends Cubit<_St> {
  final String id;
  _Cu(this.id) : super(const _St());

  Future<void> load() async {
    emit(const _St(loading: true));
    try {
      final res = await api.get('/elections/$id');
      final data = res.data as Map<String, dynamic>;
      final positions = (data['positions'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      final candidates = (data['candidates'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

      Map<String, dynamic>? results;
      if (data['status'] == 'COMPLETED' || data['status'] == 'VOTING_OPEN') {
        try {
          final rRes = await api.get('/elections/$id/results');
          results = rRes.data as Map<String, dynamic>?;
        } catch (_) {}
      }

      emit(_St(election: data, positions: positions, candidates: candidates, results: results));
    } catch (e) {
      emit(_St(error: e.toString()));
    }
  }
}

// ── Screen ────────────────────────────────────────────────────

class ElectionDetailScreen extends StatelessWidget {
  final String id;
  const ElectionDetailScreen({super.key, required this.id});

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
              final e = state.election;
              final status = e?['status'] as String?;
              final sColor = _statusColor(status);
              final titleMr = isMr ? (e?['titleMr'] as String?) : null;
              final title = titleMr ?? e?['title'] ?? '';

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
                          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(l.t('election.title'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        ])),
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

                  // Admin status controls
                  if (!state.loading && state.error == null && isAdmin && e != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(spacing: 8, runSpacing: 8, children: [
                          if (status == 'UPCOMING')
                            _StatusBtn(l.t('election.openNominations'), const Color(0xFFF97316), () => _changeStatus(context, 'NOMINATIONS_OPEN')),
                          if (status == 'NOMINATIONS_OPEN')
                            _StatusBtn(l.t('election.openVoting'), const Color(0xFF3B82F6), () => _changeStatus(context, 'VOTING_OPEN')),
                          if (status == 'VOTING_OPEN')
                            _StatusBtn(l.t('election.declareResults'), const Color(0xFF10B981), () => _changeStatus(context, 'COMPLETED')),
                        ]),
                      ),
                    ),

                  // Positions & Candidates
                  if (!state.loading && state.error == null)
                    ...state.positions.map((pos) {
                      final posTitle = (isMr ? pos['titleMr'] : null) ?? pos['title'] ?? '';
                      final posId = pos['id'] as String?;
                      final posCandidates = state.candidates.where((c) => c['positionId'] == posId).toList();
                      final resultData = state.results;
                      final posResults = resultData != null ? ((resultData['results'] as List?)?.whereType<Map<String, dynamic>>().where((r) => r['positionId'] == posId).toList() ?? []) : <Map<String, dynamic>>[];

                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Icon(Icons.person_pin_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(posTitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ]),
                            const SizedBox(height: 8),
                            ...posCandidates.map((cand) {
                              final candStatus = cand['status'] as String?;
                              final isApproved = candStatus == 'APPROVED';
                              final voteCount = posResults.isNotEmpty
                                  ? posResults.firstWhere((r) => r['candidateId'] == cand['id'], orElse: () => {})['voteCount'] ?? 0
                                  : null;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isApproved ? AppColors.primary.withAlpha(40) : AppColors.border),
                                ),
                                child: Row(children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primary.withAlpha(20),
                                    child: Text(
                                      _initials(cand['memberName'] ?? ''),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(cand['memberName'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text('${cand['flatNo'] ?? ''} • ${candStatus ?? ''}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                    if (cand['manifesto'] != null && cand['manifesto'].toString().isNotEmpty)
                                      Text(cand['manifesto'], style: TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ])),
                                  if (voteCount != null && (status == 'COMPLETED' || isAdmin))
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: const Color(0xFF10B981).withAlpha(20), borderRadius: BorderRadius.circular(8)),
                                      child: Text('$voteCount ${l.t('election.votes')}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                                    ),
                                  if (status == 'VOTING_OPEN' && isApproved)
                                    GestureDetector(
                                      onTap: () => _vote(context, l, posId!, cand['id']),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(8)),
                                        child: Text(l.t('election.vote'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                                      ),
                                    ),
                                  if (isAdmin && candStatus == 'NOMINATED') ...[
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () async {
                                        try {
                                          await api.post('/elections/candidates/${cand['id']}/approve');
                                          if (context.mounted) context.read<_Cu>().load();
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(e is DioException ? (e.response?.data?['error'] ?? 'Request failed') : 'Request failed')),
                                            );
                                          }
                                        }
                                      },
                                      child: Container(
                                        width: 28, height: 28,
                                        decoration: BoxDecoration(color: const Color(0xFF10B981).withAlpha(20), borderRadius: BorderRadius.circular(6)),
                                        child: const Icon(Icons.check_rounded, size: 16, color: Color(0xFF10B981)),
                                      ),
                                    ),
                                  ],
                                ]),
                              );
                            }),
                            // Nominate button
                            if (status == 'NOMINATIONS_OPEN')
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: OutlinedButton.icon(
                                  onPressed: () => _nominate(context, l, posId!),
                                  icon: const Icon(Icons.person_add_rounded, size: 14),
                                  label: Text(l.t('election.nominate'), style: const TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                          ]),
                        ),
                      );
                    }),

                  // Add position (admin, upcoming)
                  if (!state.loading && state.error == null && isAdmin && (status == 'UPCOMING' || status == 'NOMINATIONS_OPEN'))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => _addPosition(context, l),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(l.t('election.addPosition')),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  void _changeStatus(BuildContext ctx, String newStatus) async {
    try {
      await api.patch('/elections/${ctx.read<_Cu>().id}/status', data: {'status': newStatus});
      if (ctx.mounted) ctx.read<_Cu>().load();
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(e is DioException ? (e.response?.data?['error'] ?? 'Request failed') : 'Request failed')),
        );
      }
    }
  }

  void _vote(BuildContext ctx, AppLocalizations l, String positionId, String? candidateId) async {
    if (candidateId == null) return;
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: Text(l.t('election.confirmVote')),
        content: Text(l.t('election.confirmVoteMsg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.t('common.cancel'))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(l.t('election.vote'), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await api.post('/elections/${ctx.read<_Cu>().id}/vote', data: {'positionId': positionId, 'candidateId': candidateId});
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(l.t('election.voteCast')), backgroundColor: const Color(0xFF10B981)));
        ctx.read<_Cu>().load();
      }
    } catch (_) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(l.t('election.alreadyVoted')), backgroundColor: const Color(0xFFEF4444)));
      }
    }
  }

  void _nominate(BuildContext ctx, AppLocalizations l, String positionId) {
    String manifesto = '';
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
              Text(l.t('election.nominate'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(onChanged: (v) => manifesto = v, maxLines: 3, decoration: InputDecoration(labelText: l.t('election.manifesto'))),
              const SizedBox(height: 20),
              GradientButton(label: l.t('election.submitNomination'), onPressed: () async {
                try {
                  await api.post('/elections/${ctx.read<_Cu>().id}/nominate', data: {'positionId': positionId, 'manifesto': manifesto});
                  if (c.mounted) Navigator.pop(c);
                  if (ctx.mounted) ctx.read<_Cu>().load();
                } catch (e) {
                  if (c.mounted) {
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(content: Text(e is DioException ? (e.response?.data?['error'] ?? 'Request failed') : 'Request failed')),
                    );
                  }
                }
              }),
            ]),
          ),
        ),
      ),
    );
  }

  void _addPosition(BuildContext ctx, AppLocalizations l) {
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
              Text(l.t('election.addPosition'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(onChanged: (v) => title = v, decoration: InputDecoration(labelText: l.t('election.positionTitle'))),
              const SizedBox(height: 12),
              TextField(onChanged: (v) => titleMr = v, decoration: InputDecoration(labelText: '${l.t('election.positionTitle')} (MR)')),
              const SizedBox(height: 20),
              GradientButton(label: l.t('common.save'), onPressed: () async {
                if (title.isEmpty) return;
                try {
                  await api.post('/elections/${ctx.read<_Cu>().id}/positions', data: {'title': title, 'titleMr': titleMr});
                  if (c.mounted) Navigator.pop(c);
                  if (ctx.mounted) ctx.read<_Cu>().load();
                } catch (e) {
                  if (c.mounted) {
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(content: Text(e is DioException ? (e.response?.data?['error'] ?? 'Request failed') : 'Request failed')),
                    );
                  }
                }
              }),
            ]),
          ),
        ),
      ),
    );
  }
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _StatusBtn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
