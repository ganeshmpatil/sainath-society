import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/module_screen.dart';

class SuggestionsScreen extends StatelessWidget {
  const SuggestionsScreen({super.key});
  @override Widget build(BuildContext context) => BlocProvider(
    create: (_) => ListCubit(endpoint: '/suggestions', listKey: 'suggestions')..load(),
    child: const _SV(),
  );
}

class _SV extends StatelessWidget {
  const _SV();
  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); final isMr = context.watch<LocaleCubit>().isMarathi;
    return Scaffold(
      body: SafeArea(child: RefreshIndicator(
        onRefresh: () => context.read<ListCubit>().load(), color: AppColors.primary,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: Row(children: [
            GestureDetector(onTap: () => context.pop(),
                child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.t('suggestions.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text(l.t('suggestions.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            ]),
          ]))),
          BlocBuilder<ListCubit, ListData>(builder: (context, state) {
            if (state.loading) return const SliverToBoxAdapter(child: ShimmerLoading());
            if (state.items.isEmpty) return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
                child: Center(child: Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)))));
            return SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
              final s = state.items[i];
              final title = (isMr ? s['titleMr'] : null) ?? s['title'] ?? '';
              final body = (isMr ? s['bodyMr'] : null) ?? s['body'] ?? s['description'] ?? '';
              return GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.lightbulb_rounded, size: 18, color: AppColors.medium),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                ]),
                if (body.isNotEmpty) ...[const SizedBox(height: 6),
                  Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))],
              ]));
            }, childCount: state.items.length));
          }),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]),
      )),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreate(context),
        child: const Icon(Icons.add_rounded, size: 28)),
    );
  }

  void _showCreate(BuildContext ctx) {
    final cubit = ctx.read<ListCubit>(); final l = AppLocalizations.of(ctx);
    String title = '', body = '';
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 20),
          Text(l.t('suggestions.newSuggestion'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(onChanged: (v) => title = v, decoration: InputDecoration(labelText: l.t('grievances.subject'))),
          const SizedBox(height: 14),
          TextField(onChanged: (v) => body = v, maxLines: 4, decoration: InputDecoration(labelText: l.t('suggestions.yourSuggestion'))),
          const SizedBox(height: 20),
          GradientButton(label: l.t('common.submit'), onPressed: () async {
            if (title.isEmpty) return;
            try { await api.post('/suggestions', data: {'title': title, 'body': body});
              if (c.mounted) Navigator.pop(c); cubit.load(); } catch (_) {}
          }),
        ])),
      ),
    );
  }
}
