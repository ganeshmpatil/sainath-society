import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/filter_chips_row.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/module_screen.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});
  @override Widget build(BuildContext context) => BlocProvider(
    create: (_) => ListCubit(endpoint: '/tasks', listKey: 'tasks')..load(),
    child: const _TV(),
  );
}

class _TV extends StatefulWidget {
  const _TV();
  @override State<_TV> createState() => _TVS();
}

class _TVS extends State<_TV> {
  int _fi = 0;
  static const _fl = ['common.all', 'tasks.todo', 'tasks.inProgress', 'tasks.done'];
  static const _fv = ['', 'OPEN', 'IN_PROGRESS', 'DONE'];

  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); final isMr = context.watch<LocaleCubit>().isMarathi;
    return Scaffold(body: SafeArea(child: RefreshIndicator(
      onRefresh: () => context.read<ListCubit>().load(), color: AppColors.primary,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Row(children: [
          GestureDetector(onTap: () => context.pop(),
              child: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.t('tasks.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(l.t('tasks.subtitle'), style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ]),
        ]))),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 12, bottom: 12), child: FilterChipsRow(
          labels: _fl.map((k) => l.t(k)).toList(), selectedIndex: _fi,
          onSelected: (i) { setState(() => _fi = i);
            context.read<ListCubit>().load(_fv[i].isEmpty ? null : {'status': _fv[i]}); }))),
        BlocBuilder<ListCubit, ListData>(builder: (context, state) {
          if (state.loading) return const SliverToBoxAdapter(child: ShimmerLoading());
          if (state.items.isEmpty) return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
              child: Center(child: Text(l.t('common.noRecords'), style: const TextStyle(color: AppColors.textTertiary)))));
          return SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
            final t = state.items[i];
            final title = (isMr ? t['titleMr'] : null) ?? t['title'] ?? '';
            final status = t['status'] ?? 'OPEN';
            final due = t['dueDate'] ?? '';
            return GlassCard(child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.statusBgColor(status), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.checklist_rounded, size: 20, color: AppColors.statusColor(status))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (due.isNotEmpty) Text('Due: ${_sd(due)}', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ])),
              StatusBadge.status(status),
            ]));
          }, childCount: state.items.length));
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    )));
  }
  String _sd(String iso) { try { final d = DateTime.parse(iso); return '${d.day}/${d.month}/${d.year}'; } catch (_) { return iso; } }
}
