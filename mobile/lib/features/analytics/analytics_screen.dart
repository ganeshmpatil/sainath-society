import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ── State & Cubit ─────────────────────────────────────────────

class _St {
  final bool loading;
  final String? error;
  final Map<String, dynamic> financial;
  final List<Map<String, dynamic>> collection;
  final Map<String, dynamic> grievances;
  final Map<String, dynamic> occupancy;
  final List<Map<String, dynamic>> vehicles;
  final List<Map<String, dynamic>> visitors;
  const _St({
    this.loading = false,
    this.error,
    this.financial = const {},
    this.collection = const [],
    this.grievances = const {},
    this.occupancy = const {},
    this.vehicles = const [],
    this.visitors = const [],
  });
}

class _Cu extends Cubit<_St> {
  _Cu() : super(const _St());

  Future<void> load() async {
    emit(const _St(loading: true));
    try {
      final results = await Future.wait([
        api.get('/analytics/financial-summary'),
        api.get('/analytics/collection-efficiency'),
        api.get('/analytics/grievance-trends'),
        api.get('/analytics/occupancy'),
        api.get('/analytics/vehicle-stats'),
        api.get('/analytics/visitor-trends'),
      ]);

      final financial = results[0].data is Map<String, dynamic>
          ? results[0].data as Map<String, dynamic>
          : <String, dynamic>{};
      final collection = (results[1].data['data'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      final grievances = results[2].data is Map<String, dynamic>
          ? results[2].data as Map<String, dynamic>
          : <String, dynamic>{};
      final occupancy = results[3].data is Map<String, dynamic>
          ? results[3].data as Map<String, dynamic>
          : <String, dynamic>{};
      final vehicles = (results[4].data['data'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];
      final visitors = (results[5].data['data'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];

      emit(_St(
        financial: financial,
        collection: collection,
        grievances: grievances,
        occupancy: occupancy,
        vehicles: vehicles,
        visitors: visitors,
      ));
    } catch (e) {
      emit(_St(error: e.toString()));
    }
  }
}

// ── Screen ────────────────────────────────────────────────────

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;
    if (!isAdmin) {
      final l = AppLocalizations.of(context);
      return Scaffold(
        body: Center(
          child: Text(l.t('common.comingSoon'),
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    return BlocProvider(
      create: (_) => _Cu()..load(),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.watch<LocaleCubit>();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<_Cu>().load(),
          color: AppColors.primary,
          child: BlocBuilder<_Cu, _St>(
            builder: (context, state) {
              if (state.loading) {
                return const ShimmerLoading();
              }
              if (state.error != null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48, color: AppColors.urgent),
                      const SizedBox(height: 12),
                      Text(l.t('common.error'),
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.read<_Cu>().load(),
                        child: Text(l.t('common.retry')),
                      ),
                    ],
                  ),
                );
              }
              return CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).maybePop(),
                          child: Icon(Icons.arrow_back_ios_rounded,
                              size: 20, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.t('analytics.title'),
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  state.financial['financialYearStart'] != null
                                      ? 'FY ${state.financial['financialYearStart']}'
                                      : '',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textTertiary)),
                            ]),
                      ]),
                    ),
                  ),

                  // Financial Summary
                  SliverToBoxAdapter(
                      child: _SectionCard(
                    title: l.t('analytics.financialSummary'),
                    icon: Icons.account_balance_wallet_rounded,
                    child: Row(children: [
                      _FinStatTile(
                        label: l.t('analytics.totalIncome'),
                        value: state.financial['totalIncome'] ?? 0,
                        color: const Color(0xFF10B981),
                        icon: Icons.trending_up_rounded,
                      ),
                      _FinStatTile(
                        label: l.t('analytics.totalExpense'),
                        value: state.financial['totalExpense'] ?? 0,
                        color: const Color(0xFFF97316),
                        icon: Icons.trending_down_rounded,
                      ),
                      _FinStatTile(
                        label: l.t('analytics.outstanding'),
                        value: state.financial['outstanding'] ?? 0,
                        color: AppColors.urgent,
                        icon: Icons.warning_amber_rounded,
                      ),
                    ]),
                  )),

                  // Collection Efficiency
                  SliverToBoxAdapter(
                      child: _SectionCard(
                    title: l.t('analytics.collectionEfficiency'),
                    icon: Icons.bar_chart_rounded,
                    child: state.collection.isEmpty
                        ? _NoData(l)
                        : _CollectionBarChart(
                            data: state.collection.length > 6
                                ? state.collection
                                    .sublist(state.collection.length - 6)
                                : state.collection),
                  )),

                  // Grievance Trends
                  SliverToBoxAdapter(
                      child: _SectionCard(
                    title: l.t('analytics.grievanceTrends'),
                    icon: Icons.forum_rounded,
                    child: _GrievanceSummary(
                        data: state.grievances, l: l),
                  )),

                  // Occupancy
                  SliverToBoxAdapter(
                      child: _SectionCard(
                    title: l.t('analytics.occupancy'),
                    icon: Icons.home_rounded,
                    child: _OccupancyTiles(data: state.occupancy, l: l),
                  )),

                  // Vehicle Stats
                  SliverToBoxAdapter(
                      child: _SectionCard(
                    title: l.t('analytics.vehicleStats'),
                    icon: Icons.directions_car_rounded,
                    child: state.vehicles.isEmpty
                        ? _NoData(l)
                        : _VehicleBars(data: state.vehicles),
                  )),

                  // Visitor Trends (last 7 days)
                  SliverToBoxAdapter(
                      child: _SectionCard(
                    title: l.t('analytics.visitorTrends'),
                    icon: Icons.people_outline_rounded,
                    child: () {
                      final last7 = state.visitors.length > 7
                          ? state.visitors
                              .sublist(state.visitors.length - 7)
                          : state.visitors;
                      return last7.isEmpty
                          ? _NoData(l)
                          : _VisitorBarChart(data: last7);
                    }(),
                  )),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Section Card wrapper ───────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(8)),
                    child:
                        Icon(icon, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 14),
                child,
              ]),
        ),
      ),
    );
  }
}

// ── No data placeholder ────────────────────────────────────────

class _NoData extends StatelessWidget {
  final AppLocalizations l;
  const _NoData(this.l);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(l.t('analytics.noData'),
            style: TextStyle(
                fontSize: 13, color: AppColors.textTertiary)),
      ),
    );
  }
}

// ── Financial stat tile ────────────────────────────────────────

class _FinStatTile extends StatelessWidget {
  final String label;
  final dynamic value;
  final Color color;
  final IconData icon;
  const _FinStatTile(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  String _fmt(dynamic v) {
    final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    if (d >= 100000) return '₹${(d / 100000).toStringAsFixed(1)}L';
    if (d >= 1000) return '₹${(d / 1000).toStringAsFixed(1)}K';
    return '₹${d.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withAlpha(60))),
        child: Column(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(_fmt(value),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color)),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: AppColors.textTertiary)),
        ]),
      ),
    );
  }
}

// ── Collection bar chart ───────────────────────────────────────

class _CollectionBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _CollectionBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((row) {
          final pct = (row['percentage'] is num)
              ? (row['percentage'] as num).toDouble()
              : 0.0;
          final month = _shortMonth(row['month'] as String? ?? '');
          final barH = (pct / 100.0) * 80.0;
          final color = pct >= 80
              ? const Color(0xFF10B981)
              : pct >= 50
                  ? const Color(0xFFF59E0B)
                  : AppColors.urgent;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${pct.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 8, color: color)),
                    const SizedBox(height: 2),
                    Container(
                      height: max(barH, 4),
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: 4),
                    Text(month,
                        style: TextStyle(
                            fontSize: 8,
                            color: AppColors.textTertiary)),
                  ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _shortMonth(String yyyyMm) {
    if (yyyyMm.length < 7) return yyyyMm;
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = int.tryParse(yyyyMm.substring(5)) ?? 0;
    return (m >= 1 && m <= 12) ? months[m] : yyyyMm.substring(5);
  }
}

// ── Grievance summary ──────────────────────────────────────────

class _GrievanceSummary extends StatelessWidget {
  final Map<String, dynamic> data;
  final AppLocalizations l;
  const _GrievanceSummary({required this.data, required this.l});

  @override
  Widget build(BuildContext context) {
    final summary = data['summary'] is Map<String, dynamic>
        ? data['summary'] as Map<String, dynamic>
        : <String, dynamic>{};
    final open = summary['open'] ?? 0;
    final inProgress = summary['inProgress'] ?? 0;
    final resolved = summary['resolved'] ?? 0;
    final avgDays = (summary['avgResolutionDays'] is num)
        ? (summary['avgResolutionDays'] as num).toDouble()
        : 0.0;

    return Column(children: [
      Row(children: [
        _GrievanceChip(
            label: 'Open', count: open, color: AppColors.urgent),
        const SizedBox(width: 8),
        _GrievanceChip(
            label: 'In Progress',
            count: inProgress,
            color: const Color(0xFF3B82F6)),
        const SizedBox(width: 8),
        _GrievanceChip(
            label: 'Resolved',
            count: resolved,
            color: const Color(0xFF10B981)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Icon(Icons.timer_outlined, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Text(
          '${l.t('analytics.avgResolution')}: ${avgDays.toStringAsFixed(1)} ${l.t('analytics.days')}',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ]),
    ]);
  }
}

class _GrievanceChip extends StatelessWidget {
  final String label;
  final dynamic count;
  final Color color;
  const _GrievanceChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(children: [
          Text('$count',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color)),
          Text(label,
              style: TextStyle(fontSize: 9, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ── Occupancy tiles ────────────────────────────────────────────

class _OccupancyTiles extends StatelessWidget {
  final Map<String, dynamic> data;
  final AppLocalizations l;
  const _OccupancyTiles({required this.data, required this.l});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _OccupancyTile(
        label: l.t('analytics.ownerOccupied'),
        count: data['ownerOccupied'] ?? 0,
        color: const Color(0xFF10B981),
        icon: Icons.person_rounded,
      ),
      const SizedBox(width: 8),
      _OccupancyTile(
        label: l.t('analytics.tenantOccupied'),
        count: data['tenantOccupied'] ?? 0,
        color: const Color(0xFF3B82F6),
        icon: Icons.home_work_rounded,
      ),
      const SizedBox(width: 8),
      _OccupancyTile(
        label: l.t('analytics.vacant'),
        count: data['vacant'] ?? 0,
        color: AppColors.textTertiary,
        icon: Icons.door_back_door_rounded,
      ),
    ]);
  }
}

class _OccupancyTile extends StatelessWidget {
  final String label;
  final dynamic count;
  final Color color;
  final IconData icon;
  const _OccupancyTile(
      {required this.label,
      required this.count,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text('$count',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 9,
                  color: AppColors.textTertiary)),
        ]),
      ),
    );
  }
}

// ── Vehicle horizontal bars ────────────────────────────────────

class _VehicleBars extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _VehicleBars({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxCount = data.fold<int>(
        0,
        (m, r) =>
            max(m, (r['count'] is num ? (r['count'] as num).toInt() : 0)));
    return Column(
      children: data.map((row) {
        final type = row['vehicleType'] as String? ?? '';
        final count =
            (row['count'] is num) ? (row['count'] as num).toInt() : 0;
        final ratio = maxCount > 0 ? count / maxCount : 0.0;
        final color = _typeColor(type);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(
              width: 80,
              child: Text(
                _typeLabel(type),
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(children: [
                Container(
                    height: 18,
                    decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(4))),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4))),
                ),
              ]),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 24,
              child: Text('$count',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ),
          ]),
        );
      }).toList(),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'CAR': return const Color(0xFF3B82F6);
      case 'BIKE': return const Color(0xFF10B981);
      case 'BICYCLE': return const Color(0xFF8B5CF6);
      case 'EV': return const Color(0xFF06B6D4);
      case 'COMMERCIAL': return const Color(0xFFF59E0B);
      default: return const Color(0xFF64748B);
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'CAR': return 'Car';
      case 'BIKE': return 'Bike';
      case 'BICYCLE': return 'Bicycle';
      case 'EV': return 'EV';
      case 'COMMERCIAL': return 'Commercial';
      default: return type;
    }
  }
}

// ── Visitor bar chart ──────────────────────────────────────────

class _VisitorBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _VisitorBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxTotal = data.fold<int>(
        0,
        (m, r) =>
            max(m, (r['total'] is num ? (r['total'] as num).toInt() : 0)));
    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((row) {
          final total =
              (row['total'] is num) ? (row['total'] as num).toInt() : 0;
          final barH =
              maxTotal > 0 ? (total / maxTotal) * 80.0 : 0.0;
          final day = _shortDay(row['day'] as String? ?? '');
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('$total',
                        style: TextStyle(
                            fontSize: 8,
                            color: AppColors.primary)),
                    const SizedBox(height: 2),
                    Container(
                      height: max(barH, 4),
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: 4),
                    Text(day,
                        style: TextStyle(
                            fontSize: 8,
                            color: AppColors.textTertiary)),
                  ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _shortDay(String yyyyMmDd) {
    if (yyyyMmDd.length < 10) return yyyyMmDd;
    return yyyyMmDd.substring(8); // day digits
  }
}
