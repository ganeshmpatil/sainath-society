import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/module_screen.dart';

class PollsScreen extends StatelessWidget {
  const PollsScreen({super.key});
  @override Widget build(BuildContext context) => BlocProvider(
    create: (_) => ListCubit(endpoint: '/polls', listKey: 'polls')..load(),
    child: const _PV(),
  );
}

class _PV extends StatelessWidget {
  const _PV();
  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); final isMr = context.watch<LocaleCubit>().isMarathi;
    return Scaffold(body: SafeArea(child: RefreshIndicator(
      onRefresh: () => context.read<ListCubit>().load(), color: AppColors.primary,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: Row(children: [
          GestureDetector(onTap: () => context.pop(),
              child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.t('polls.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(l.t('polls.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ]),
        ]))),
        BlocBuilder<ListCubit, ListData>(builder: (context, state) {
          if (state.loading) return const SliverToBoxAdapter(child: ShimmerLoading());
          if (state.items.isEmpty) return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
              child: Center(child: Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)))));
          return SliverList(delegate: SliverChildBuilderDelegate((ctx, i) => _PC(poll: state.items[i], isMr: isMr), childCount: state.items.length));
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    )));
  }
}

class _PC extends StatelessWidget {
  final Map<String, dynamic> poll; final bool isMr;
  const _PC({required this.poll, required this.isMr});
  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = (isMr ? poll['titleMr'] : null) ?? poll['title'] ?? '';
    final desc = (isMr ? poll['descriptionMr'] : null) ?? poll['description'] ?? '';
    final status = poll['status'] ?? 'DRAFT'; final isActive = status == 'ACTIVE';
    final options = (poll['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final tv = options.fold<int>(0, (s, o) => s + ((o['voteCount'] ?? 0) as int));
    final ea = poll['endsAt'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isActive ? LinearGradient(colors: [AppColors.primary.withAlpha(15), AppColors.secondary.withAlpha(15)]) : null,
        color: isActive ? null : AppColors.surface, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? AppColors.primary.withAlpha(50) : AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [StatusBadge.status(status), const Spacer(),
          Text('${isActive ? l.t('polls.endsOn') : l.t('polls.endedOn')}: ${_sd(ea)}',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary))]),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (desc.isNotEmpty) ...[const SizedBox(height: 6), Text(desc, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))],
        if (options.isNotEmpty) ...[const SizedBox(height: 16), ...options.map((o) => _ob(o, tv))],
        if (tv > 0) ...[const SizedBox(height: 14),
          Container(padding: EdgeInsets.only(top: 12), decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.borderLight))),
            child: Row(children: [
              Text('$tv ${l.t('polls.membersVoted')}', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              const Spacer(),
              if (isActive) Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(border: Border.all(color: AppColors.primary.withAlpha(100)), borderRadius: BorderRadius.circular(10)),
                child: Text(l.t('polls.castVote'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary))),
            ])),
        ],
      ]),
    );
  }

  Widget _ob(Map<String, dynamic> o, int t) {
    final text = (isMr ? o['optionTextMr'] : null) ?? o['optionText'] ?? '';
    final v = (o['voteCount'] ?? 0) as int; final p = t > 0 ? v / t * 100 : 0.0;
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        Text('${p.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p > 50 ? AppColors.primary : AppColors.textSecondary))]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(value: p / 100, minHeight: 6, backgroundColor: AppColors.border,
          valueColor: AlwaysStoppedAnimation(p > 50 ? AppColors.primary : AppColors.borderLight))),
    ]));
  }

  String _sd(String iso) { try { final d = DateTime.parse(iso); return '${d.day}/${d.month}/${d.year}'; } catch (_) { return iso; } }
}
