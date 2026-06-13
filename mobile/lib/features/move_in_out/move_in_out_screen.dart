import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/module_screen.dart';

class MoveInOutScreen extends StatelessWidget {
  const MoveInOutScreen({super.key});
  @override Widget build(BuildContext context) => BlocProvider(
    create: (_) => ListCubit(endpoint: '/tenants', listKey: 'tenants')..load(),
    child: const _MV(),
  );
}

class _MV extends StatelessWidget {
  const _MV();
  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); context.watch<LocaleCubit>();
    return Scaffold(body: SafeArea(child: RefreshIndicator(
      onRefresh: () => context.read<ListCubit>().load(), color: AppColors.primary,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: Row(children: [
          GestureDetector(onTap: () => context.pop(),
              child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.t('moveInOut.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(l.t('moveInOut.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ]),
        ]))),
        BlocBuilder<ListCubit, ListData>(builder: (context, state) {
          if (state.loading) return const SliverToBoxAdapter(child: ShimmerLoading());
          if (state.items.isEmpty) return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
              child: Center(child: Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)))));
          return SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
            final t = state.items[i];
            final name = t['tenantName'] ?? t['name'] ?? '';
            final type = t['type'] ?? 'MOVE_IN';
            final isIn = type.contains('IN');
            return GlassCard(child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(
                  color: isIn ? AppColors.resolved.withAlpha(30) : AppColors.urgent.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                child: Icon(isIn ? Icons.login_rounded : Icons.logout_rounded, size: 22,
                    color: isIn ? AppColors.resolved : AppColors.urgent)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(t['flat']?['flatNumber'] ?? '', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ])),
              StatusBadge(label: isIn ? l.t('moveInOut.moveIn') : l.t('moveInOut.moveOut'),
                  color: isIn ? AppColors.resolved : AppColors.urgent),
            ]));
          }, childCount: state.items.length));
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    )));
  }
}
