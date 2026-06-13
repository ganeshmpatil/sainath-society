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

class MeetingsScreen extends StatelessWidget {
  const MeetingsScreen({super.key});
  @override Widget build(BuildContext context) => BlocProvider(
    create: (_) => ListCubit(endpoint: '/meetings', listKey: 'meetings')..load(),
    child: const _MV(),
  );
}

class _MV extends StatelessWidget {
  const _MV();
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
            Text(l.t('meetings.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(l.t('meetings.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ]),
        ]))),
        BlocBuilder<ListCubit, ListData>(builder: (context, state) {
          if (state.loading) return const SliverToBoxAdapter(child: ShimmerLoading());
          if (state.items.isEmpty) return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
              child: Center(child: Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)))));
          return SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
            final m = state.items[i];
            final title = (isMr ? m['titleMr'] : null) ?? m['title'] ?? '';
            final type = m['meetingType'] ?? 'COMMITTEE';
            final status = m['status'] ?? 'PLANNED';
            final date = m['scheduledAt'] ?? '';
            final loc = m['location'] ?? '';
            return GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [StatusBadge(label: type, color: AppColors.primary), const SizedBox(width: 6), StatusBadge.status(status)]),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textTertiary), const SizedBox(width: 4),
                Text(_fmt(date), style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                if (loc.isNotEmpty) ...[const SizedBox(width: 12),
                  Icon(Icons.location_on_outlined, size: 14, color: AppColors.textTertiary), const SizedBox(width: 4),
                  Text(loc, style: TextStyle(fontSize: 11, color: AppColors.textTertiary))],
              ]),
            ]));
          }, childCount: state.items.length));
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    )));
  }

  String _fmt(String iso) { try { final d = DateTime.parse(iso); return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}'; } catch (_) { return iso; } }
}
