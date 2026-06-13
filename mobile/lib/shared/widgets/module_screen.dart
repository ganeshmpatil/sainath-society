import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import 'filter_chips_row.dart';
import 'shimmer_loading.dart';

/// Generic list state for simple modules.
class ListData extends Equatable {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> items;
  final int count;

  const ListData({
    this.loading = false,
    this.error,
    this.items = const [],
    this.count = 0,
  });

  @override
  List<Object?> get props => [loading, error, items, count];
}

/// Generic cubit for modules that just load a list from an endpoint.
class ListCubit extends Cubit<ListData> {
  final String endpoint;
  final String listKey;

  ListCubit({required this.endpoint, required this.listKey})
      : super(const ListData());

  Future<void> load([Map<String, dynamic>? params]) async {
    emit(const ListData(loading: true));
    try {
      final res = await api.get(endpoint, queryParams: params);
      final data = res.data;
      final list = (data[listKey] as List?)?.cast<Map<String, dynamic>>() ?? [];
      emit(ListData(items: list, count: data['count'] ?? list.length));
    } catch (e) {
      emit(ListData(error: e.toString()));
    }
  }
}

/// Generic module list screen builder.
class ModuleListScreen extends StatelessWidget {
  final String titleKey;
  final String subtitleKey;
  final String endpoint;
  final String listKey;
  final Widget Function(BuildContext, Map<String, dynamic>, bool isMr) itemBuilder;
  final List<String>? filterLabels;
  final List<String>? filterValues;
  final String? filterParam;
  final VoidCallback? onFabPressed;
  final IconData? fabIcon;

  const ModuleListScreen({
    super.key,
    required this.titleKey,
    required this.subtitleKey,
    required this.endpoint,
    required this.listKey,
    required this.itemBuilder,
    this.filterLabels,
    this.filterValues,
    this.filterParam,
    this.onFabPressed,
    this.fabIcon,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ListCubit(endpoint: endpoint, listKey: listKey)..load(),
      child: _View(
        titleKey: titleKey,
        subtitleKey: subtitleKey,
        itemBuilder: itemBuilder,
        filterLabels: filterLabels,
        filterValues: filterValues,
        filterParam: filterParam,
        onFabPressed: onFabPressed,
        fabIcon: fabIcon,
      ),
    );
  }
}

class _View extends StatefulWidget {
  final String titleKey;
  final String subtitleKey;
  final Widget Function(BuildContext, Map<String, dynamic>, bool) itemBuilder;
  final List<String>? filterLabels;
  final List<String>? filterValues;
  final String? filterParam;
  final VoidCallback? onFabPressed;
  final IconData? fabIcon;

  const _View({
    required this.titleKey,
    required this.subtitleKey,
    required this.itemBuilder,
    this.filterLabels,
    this.filterValues,
    this.filterParam,
    this.onFabPressed,
    this.fabIcon,
  });

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  int _filterIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<ListCubit>().load(),
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.t(widget.titleKey),
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                            Text(l.t(widget.subtitleKey),
                                style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.filterLabels != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    child: FilterChipsRow(
                      labels: widget.filterLabels!.map((k) => l.t(k)).toList(),
                      selectedIndex: _filterIndex,
                      onSelected: (i) {
                        setState(() => _filterIndex = i);
                        final vals = widget.filterValues;
                        if (vals != null && widget.filterParam != null) {
                          final params = vals[i].isEmpty
                              ? null
                              : <String, dynamic>{widget.filterParam!: vals[i]};
                          context.read<ListCubit>().load(params);
                        }
                      },
                    ),
                  ),
                ),
              BlocBuilder<ListCubit, ListData>(
                builder: (context, state) {
                  if (state.loading) {
                    return const SliverToBoxAdapter(child: ShimmerLoading());
                  }
                  if (state.items.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(child: Text(l.t('common.noRecords'),
                            style: TextStyle(color: AppColors.textTertiary))),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => widget.itemBuilder(ctx, state.items[i], isMr),
                      childCount: state.items.length,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: widget.onFabPressed != null
          ? FloatingActionButton(
              onPressed: widget.onFabPressed,
              child: Icon(widget.fabIcon ?? Icons.add_rounded, size: 28),
            )
          : null,
    );
  }
}
