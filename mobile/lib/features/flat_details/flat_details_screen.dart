import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/filter_chips_row.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/module_screen.dart';

class FlatDetailsScreen extends StatelessWidget {
  const FlatDetailsScreen({super.key});
  @override Widget build(BuildContext context) => BlocProvider(
    create: (_) => ListCubit(endpoint: '/flats', listKey: 'flats')..load(),
    child: const _FV(),
  );
}

class _FV extends StatefulWidget {
  const _FV();
  @override State<_FV> createState() => _FVS();
}

class _FVS extends State<_FV> {
  int _fi = 0;
  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); context.watch<LocaleCubit>();
    return Scaffold(body: SafeArea(child: RefreshIndicator(
      onRefresh: () => context.read<ListCubit>().load(), color: AppColors.primary,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Row(children: [
          GestureDetector(onTap: () => context.pop(),
              child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.t('flatDetails.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(l.t('flatDetails.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ]),
        ]))),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(top: 12, bottom: 12), child: FilterChipsRow(
          labels: [l.t('residents.allWings'), 'A Wing', 'B Wing', 'C Wing'], selectedIndex: _fi,
          onSelected: (i) => setState(() => _fi = i)))),
        BlocBuilder<ListCubit, ListData>(builder: (context, state) {
          if (state.loading) return const SliverToBoxAdapter(child: ShimmerLoading());
          var items = state.items;
          if (_fi > 0) { final w = ['', 'A', 'B', 'C'];
            items = items.where((f) => ((f['flatNumber'] ?? '') as String).startsWith(w[_fi])).toList(); }
          if (items.isEmpty) return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
              child: Center(child: Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)))));
          return SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
            final f = items[i];
            final flat = f['flatNumber'] ?? '';
            final owner = f['ownerName'] ?? '';
            final area = f['areaSqft']?.toString() ?? '';
            final floor = f['floor']?.toString() ?? '';
            return GlassCard(child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary.withAlpha(25), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(flat, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(flat, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text([if (owner.isNotEmpty) owner, if (area.isNotEmpty) '${area} sq.ft', if (floor.isNotEmpty) 'Floor $floor'].join(' • '),
                    style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ])),
              Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary),
            ]));
          }, childCount: items.length));
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    )));
  }
}
