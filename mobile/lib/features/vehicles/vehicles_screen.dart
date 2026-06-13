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
import '../../shared/widgets/status_badge.dart';
import '../../shared/widgets/module_screen.dart';

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});
  @override Widget build(BuildContext context) => BlocProvider(
    create: (_) => ListCubit(endpoint: '/vehicles', listKey: 'vehicles')..load(),
    child: const _VV(),
  );
}

class _VV extends StatelessWidget {
  const _VV();
  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); context.watch<LocaleCubit>();
    return Scaffold(
      body: SafeArea(child: RefreshIndicator(
        onRefresh: () => context.read<ListCubit>().load(), color: AppColors.primary,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: Row(children: [
            GestureDetector(onTap: () => context.pop(),
                child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.t('vehicles.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text(l.t('vehicles.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            ]),
          ]))),
          BlocBuilder<ListCubit, ListData>(builder: (context, state) {
            if (state.loading) return const SliverToBoxAdapter(child: ShimmerLoading());
            if (state.items.isEmpty) return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
                child: Center(child: Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)))));
            return SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
              final v = state.items[i];
              final type = v['vehicleType'] ?? 'CAR';
              final icon = type == 'BIKE' ? Icons.two_wheeler_rounded : type == 'BICYCLE' ? Icons.pedal_bike_rounded : Icons.directions_car_rounded;
              return GlassCard(child: Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.secondary.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 22, color: AppColors.secondary)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v['registrationNo'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text([v['make'] ?? '', v['model'] ?? '', if ((v['color'] ?? '').isNotEmpty) v['color']].join(' • '),
                      style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ])),
                StatusBadge(label: type, color: AppColors.secondary),
              ]));
            }, childCount: state.items.length));
          }),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]),
      )),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAdd(context),
        child: const Icon(Icons.add_rounded, size: 28)),
    );
  }

  void _showAdd(BuildContext ctx) {
    final cubit = ctx.read<ListCubit>(); final l = AppLocalizations.of(ctx);
    String regNo = '', make = '', model = '', color = '', type = 'CAR', slot = '';
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 20),
          Text(l.t('vehicles.addVehicle'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(onChanged: (v) => regNo = v, decoration: InputDecoration(labelText: l.t('vehicles.registrationNo'))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: type, dropdownColor: AppColors.surface,
            decoration: InputDecoration(labelText: l.t('vehicles.vehicleType')),
            items: ['CAR', 'BIKE', 'BICYCLE', 'EV', 'COMMERCIAL'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => type = v!),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(onChanged: (v) => make = v, decoration: InputDecoration(labelText: l.t('vehicles.make')))),
            const SizedBox(width: 10),
            Expanded(child: TextField(onChanged: (v) => model = v, decoration: InputDecoration(labelText: l.t('vehicles.model')))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(onChanged: (v) => color = v, decoration: InputDecoration(labelText: l.t('vehicles.color')))),
            const SizedBox(width: 10),
            Expanded(child: TextField(onChanged: (v) => slot = v, decoration: InputDecoration(labelText: l.t('vehicles.parkingSlot')))),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(c),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(l.t('common.cancel')),
            )),
            const SizedBox(width: 12),
            Expanded(child: GradientButton(label: l.t('common.submit'), onPressed: () async {
              if (regNo.isEmpty) return;
              try { await api.post('/vehicles', data: {'registrationNo': regNo, 'vehicleType': type, 'make': make, 'model': model, 'color': color, 'parkingSlot': slot});
                if (c.mounted) Navigator.pop(c); cubit.load(); } catch (_) {}
            })),
          ]),
        ])),
      ),
    );
  }
}
