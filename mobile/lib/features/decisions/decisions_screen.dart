import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/module_screen.dart';

class DecisionsScreen extends StatelessWidget {
  const DecisionsScreen({super.key});
  @override Widget build(BuildContext context) => BlocProvider(
    create: (_) => ListCubit(endpoint: '/decisions', listKey: 'decisions')..load(),
    child: const _DV(),
  );
}

class _DV extends StatelessWidget {
  const _DV();
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
            Text(l.t('decisions.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(l.t('decisions.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ]),
        ]))),
        BlocBuilder<ListCubit, ListData>(builder: (context, state) {
          if (state.loading) return const SliverToBoxAdapter(child: ShimmerLoading());
          if (state.items.isEmpty) return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
              child: Center(child: Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)))));
          return SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
            final d = state.items[i];
            final title = (isMr ? d['titleMr'] : null) ?? d['title'] ?? '';
            final date = d['decidedAt'] ?? d['createdAt'] ?? '';
            return GlassCard(child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.secondary.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.gavel_rounded, size: 22, color: AppColors.secondary)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (date.isNotEmpty) Text(date.substring(0, 10), style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ])),
            ]));
          }, childCount: state.items.length));
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    )));
  }
}
