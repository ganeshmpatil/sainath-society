import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/filter_chips_row.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ─── State & Cubit ───────────────────────────────────────────────

class _WFListState {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> workflows;
  const _WFListState({this.loading = false, this.error, this.workflows = const []});
}

class _WFListCubit extends Cubit<_WFListState> {
  _WFListCubit() : super(const _WFListState());

  Future<void> load({String status = '', bool isTemplate = false}) async {
    emit(const _WFListState(loading: true));
    try {
      final params = <String, dynamic>{};
      if (status.isNotEmpty) params['status'] = status;
      if (isTemplate) params['is_template'] = 'true';
      final res = await api.get('/workflows', queryParams: params);
      final list = (res.data['workflows'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      emit(_WFListState(workflows: list));
    } catch (e) {
      emit(_WFListState(error: e.toString()));
    }
  }
}

// ─── Screen ──────────────────────────────────────────────────────

class WorkflowListScreen extends StatelessWidget {
  const WorkflowListScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _WFListCubit()..load(),
    child: const _WFListView(),
  );
}

class _WFListView extends StatefulWidget {
  const _WFListView();
  @override
  State<_WFListView> createState() => _WFListViewState();
}

class _WFListViewState extends State<_WFListView> {
  int _fi = 0;
  final _filters = ['', 'ACTIVE', 'COMPLETED', 'DRAFT'];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.watch<LocaleCubit>();
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<_WFListCubit>().load(status: _filters[_fi]),
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.t('workflows.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(l.t('workflows.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      ]),
                    ),
                    if (isAdmin)
                      GestureDetector(
                        onTap: () => _showTemplates(context, l),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(26),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                        ),
                      ),
                  ]),
                ),
              ),

              // Filters
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: FilterChipsRow(
                    labels: [
                      l.t('common.all'),
                      l.t('workflows.active'),
                      l.t('workflows.completed'),
                      l.t('workflows.draft'),
                    ],
                    selectedIndex: _fi,
                    onSelected: (i) {
                      setState(() => _fi = i);
                      context.read<_WFListCubit>().load(status: _filters[i]);
                    },
                  ),
                ),
              ),

              // List
              BlocBuilder<_WFListCubit, _WFListState>(
                builder: (context, state) {
                  if (state.loading) return const SliverToBoxAdapter(child: ShimmerLoading());
                  if (state.workflows.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(child: Text(l.t('workflows.noWorkflows'),
                            style: TextStyle(color: AppColors.textTertiary))),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _WorkflowCard(wf: state.workflows[i]),
                      childCount: state.workflows.length,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showCreateSheet(context, l),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
            )
          : null,
    );
  }

  void _showCreateSheet(BuildContext ctx, AppLocalizations l) {
    final titleCtrl = TextEditingController();
    final titleMrCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'GENERAL';
    DateTime? targetDate;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(builder: (sheetCtx, setSheetState) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(sheetCtx).viewInsets.bottom + 16),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(l.t('workflows.create'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: titleCtrl, decoration: InputDecoration(labelText: l.t('workflows.titleLabel'), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: titleMrCtrl, decoration: InputDecoration(labelText: l.t('workflows.titleMrLabel'), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 3, decoration: InputDecoration(labelText: l.t('common.description'), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: InputDecoration(labelText: l.t('workflows.category'), border: const OutlineInputBorder()),
              items: ['GENERAL', 'AGM', 'SGM', 'FESTIVAL', 'REPAIR', 'COMPLIANCE', 'ELECTION']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setSheetState(() => category = v ?? 'GENERAL'),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(context: sheetCtx, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
                if (d != null) setSheetState(() => targetDate = d);
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: l.t('workflows.targetDate'), border: const OutlineInputBorder()),
                child: Text(targetDate != null ? DateFormat('dd MMM yyyy').format(targetDate!) : l.t('workflows.selectDate')),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(sheetCtx), child: Text(l.t('common.cancel')))),
              const SizedBox(width: 12),
              Expanded(child: GradientButton(
                label: l.t('common.save'),
                onPressed: () async {
                  if (titleCtrl.text.isEmpty) return;
                  try {
                    await api.post('/workflows', data: {
                      'title': titleCtrl.text,
                      'titleMr': titleMrCtrl.text,
                      'description': descCtrl.text,
                      'category': category,
                      'targetDate': targetDate?.toIso8601String().split('T').first,
                    });
                    if (ctx.mounted) {
                      Navigator.pop(sheetCtx);
                      ctx.read<_WFListCubit>().load(status: _filters[_fi]);
                    }
                  } catch (_) {}
                },
              )),
            ]),
          ])),
        );
      }),
    );
  }

  void _showTemplates(BuildContext ctx, AppLocalizations l) async {
    try {
      final res = await api.get('/workflows/templates');
      final templates = (res.data['templates'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (!ctx.mounted) return;
      showModalBottomSheet(
        context: ctx,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheetCtx) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(l.t('workflows.templates'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (templates.isEmpty)
              Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(l.t('workflows.noTemplates'), style: TextStyle(color: AppColors.textTertiary))))
            else
              ...templates.map((t) => ListTile(
                title: Text(t['title'] ?? ''),
                subtitle: Text('${(t['activities'] as List?)?.length ?? 0} ${l.t('workflows.activities')}'),
                trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textTertiary),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  try {
                    await api.post('/workflows/${t['id']}/instantiate', data: {
                      'title': '${t['title']} ${DateTime.now().year}',
                      'titleMr': t['titleMr'] ?? '',
                    });
                    if (ctx.mounted) ctx.read<_WFListCubit>().load(status: _filters[_fi]);
                  } catch (_) {}
                },
              )),
          ]),
        ),
      );
    } catch (_) {}
  }
}

// ─── Workflow Card ────────────────────────────────────────────────

class _WorkflowCard extends StatelessWidget {
  final Map<String, dynamic> wf;
  const _WorkflowCard({required this.wf});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = wf['title'] ?? '';
    final category = wf['category'] ?? 'GENERAL';
    final status = wf['status'] ?? 'DRAFT';
    final progress = wf['progress'] as Map<String, dynamic>? ?? {};
    final percent = progress['percent'] ?? 0;
    final total = progress['total'] ?? 0;
    final completed = (progress['completed'] ?? 0) + (progress['skipped'] ?? 0);
    final targetDate = wf['targetDate'] != null ? DateTime.tryParse(wf['targetDate']) : null;

    final statusColor = _statusColor(status);

    return GlassCard(
      onTap: () => context.push('/workflows/${wf['id']}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: statusColor.withAlpha(26), borderRadius: BorderRadius.circular(10)),
            child: Icon(_categoryIcon(category), size: 20, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text([category, if (targetDate != null) DateFormat('dd MMM').format(targetDate)].join(' · '),
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withAlpha(26), borderRadius: BorderRadius.circular(6)),
            child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
          ),
        ]),
        if (total > 0) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  backgroundColor: AppColors.border,
                  color: statusColor,
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('$completed/$total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ]),
        ],
      ]),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'ACTIVE': return const Color(0xFF3B82F6);
      case 'COMPLETED': return const Color(0xFF10B981);
      case 'CANCELLED': return const Color(0xFF64748B);
      default: return const Color(0xFFF97316); // DRAFT
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'AGM': return Icons.groups_rounded;
      case 'SGM': return Icons.people_alt_rounded;
      case 'FESTIVAL': return Icons.celebration_rounded;
      case 'REPAIR': return Icons.build_rounded;
      case 'COMPLIANCE': return Icons.gavel_rounded;
      case 'ELECTION': return Icons.how_to_vote_rounded;
      default: return Icons.account_tree_rounded;
    }
  }
}
