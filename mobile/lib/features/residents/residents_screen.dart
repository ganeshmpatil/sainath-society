import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/filter_chips_row.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/module_screen.dart';

class ResidentsScreen extends StatelessWidget {
  const ResidentsScreen({super.key});
  @override Widget build(BuildContext context) => BlocProvider(
    create: (_) => ListCubit(endpoint: '/residents', listKey: 'residents')..load(),
    child: const _RV(),
  );
}

class _RV extends StatefulWidget {
  const _RV();
  @override State<_RV> createState() => _RVS();
}

class _RVS extends State<_RV> {
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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.t('residents.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            BlocBuilder<ListCubit, ListData>(builder: (_, s) => Text('${s.count} ${l.t('residents.members')}',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary))),
          ])),
        ]))),
        SliverToBoxAdapter(child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: TextField(decoration: InputDecoration(hintText: l.t('residents.searchHint'),
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textTertiary),
            border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none)),
        )),
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(bottom: 12), child: FilterChipsRow(
          labels: [l.t('residents.allWings'), 'A', 'B', 'C', 'D', 'E', 'E1', 'F'], selectedIndex: _fi,
          onSelected: (i) => setState(() => _fi = i)))),
        BlocBuilder<ListCubit, ListData>(builder: (context, state) {
          if (state.loading) return const SliverToBoxAdapter(child: ShimmerLoading());
          var items = state.items;
          if (_fi > 0) { final w = ['', 'A', 'B', 'C', 'D', 'E', 'E1', 'F'];
            items = items.where((r) {
              final wing = r['flat']?['wing']?['name'] ?? '';
              return wing == w[_fi];
            }).toList(); }
          if (items.isEmpty) return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
              child: Center(child: Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)))));
          return SliverList(delegate: SliverChildBuilderDelegate((ctx, i) => _RC(r: items[i]), childCount: items.length));
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    )));
  }
}

class _RC extends StatelessWidget {
  final Map<String, dynamic> r;
  const _RC({required this.r});
  @override Widget build(BuildContext context) {
    final name = r['name'] ?? ''; final flat = r['flat']?['flatNumber'] ?? '';
    final role = r['role'] ?? 'MEMBER'; final desg = r['designation'] ?? '';
    final i = _init(name);
    final cs = [[AppColors.primary, AppColors.secondary], [AppColors.open, AppColors.primary],
      [AppColors.secondary, AppColors.resolved], [AppColors.high, AppColors.medium]];
    final cp = cs[name.hashCode.abs() % cs.length];
    return GlassCard(child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(gradient: LinearGradient(colors: cp), borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(i, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text([flat, role == 'ADMIN' ? 'Admin' : 'Owner', if (desg.isNotEmpty) desg].join(' • '),
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ])),
      GestureDetector(
        onTap: () {
          final phone = r['phone'] ?? '';
          if (phone.isNotEmpty) {
            launchUrl(Uri.parse('tel:$phone'));
          }
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(26),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.phone_outlined, size: 18, color: AppColors.primary),
        ),
      ),
    ]));
  }
  String _init(String n) { final p = n.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    if (p.isNotEmpty && p[0].isNotEmpty) return p[0][0].toUpperCase(); return '?'; }
}
