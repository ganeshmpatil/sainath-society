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
  const _WFListState(
      {this.loading = false, this.error, this.workflows = const []});
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
      final list = (res.data['workflows'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
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
          onRefresh: () =>
              context.read<_WFListCubit>().load(status: _filters[_fi]),
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () {
                        if (context.canPop())
                          context.pop();
                        else
                          context.go('/more');
                      },
                      child: Icon(Icons.arrow_back_ios_rounded,
                          size: 20, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.t('workflows.title'),
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                            Text(l.t('workflows.subtitle'),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textTertiary)),
                          ]),
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
                      context
                          .read<_WFListCubit>()
                          .load(status: _filters[i]);
                    },
                  ),
                ),
              ),

              // List
              BlocBuilder<_WFListCubit, _WFListState>(
                builder: (context, state) {
                  if (state.loading) {
                    return const SliverToBoxAdapter(child: ShimmerLoading());
                  }
                  if (state.workflows.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                            child: Text(l.t('workflows.noWorkflows'),
                                style: TextStyle(
                                    color: AppColors.textTertiary))),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) =>
                          _WorkflowCard(wf: state.workflows[i]),
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
              onPressed: () => _showNewWorkflowSheet(context, l),
              backgroundColor: AppColors.primary,
              child:
                  const Icon(Icons.add_rounded, size: 28, color: Colors.white),
            )
          : null,
    );
  }

  // ─── New Workflow — choose template or blank ─────────────────

  void _showNewWorkflowSheet(BuildContext ctx, AppLocalizations l) {
    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (sheetCtx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.t('workflows.create'),
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Template option
          _OptionTile(
            icon: Icons.auto_awesome_rounded,
            color: const Color(0xFF8B5CF6),
            title: l.t('workflows.fromTemplate'),
            subtitle: '7 ready-made templates',
            onTap: () {
              Navigator.pop(sheetCtx);
              _showTemplatePicker(ctx, l);
            },
          ),
          const SizedBox(height: 10),

          // Blank workflow
          _OptionTile(
            icon: Icons.edit_note_rounded,
            color: AppColors.primary,
            title: l.t('workflows.blankWorkflow'),
            subtitle: 'Start from scratch',
            onTap: () {
              Navigator.pop(sheetCtx);
              _showCreateSheet(ctx, l);
            },
          ),
          const SizedBox(height: 16),
        ]),
      ),
      ),
    );
  }

  // ─── Template Picker ──────────────────────────────────────────

  void _showTemplatePicker(BuildContext ctx, AppLocalizations l) async {
    try {
      final res = await api.get('/workflows/templates');
      final templates = (res.data['templates'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      if (!ctx.mounted) return;

      showDialog(
        context: ctx,
        barrierDismissible: true,
        builder: (sheetCtx) => Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(children: [
                Row(children: [
                  Text(l.t('workflows.templates'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  // Seed templates button
                  GestureDetector(
                    onTap: () async {
                      try {
                        await api.post('/workflows/seed-templates', data: {});
                        if (sheetCtx.mounted) {
                          Navigator.pop(sheetCtx);
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text(l.t('workflows.seeded'))));
                          _showTemplatePicker(ctx, l);
                        }
                      } catch (_) {}
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.download_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(l.t('workflows.seedTemplates'),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
              ]),
            ),
            Flexible(
              child: templates.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 48, color: AppColors.textTertiary),
                            const SizedBox(height: 12),
                            Text(l.t('workflows.noTemplates'),
                                style:
                                    TextStyle(color: AppColors.textTertiary)),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () async {
                                try {
                                  await api.post('/workflows/seed-templates',
                                      data: {});
                                  if (sheetCtx.mounted) {
                                    Navigator.pop(sheetCtx);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                l.t('workflows.seeded'))));
                                    _showTemplatePicker(ctx, l);
                                  }
                                } catch (_) {}
                              },
                              icon: Icon(Icons.download_rounded,
                                  size: 18, color: AppColors.primary),
                              label: Text(l.t('workflows.seedTemplates'),
                                  style: TextStyle(color: AppColors.primary)),
                            ),
                          ],
                        ),
                      ))
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: templates.length,
                      itemBuilder: (_, i) => _TemplateCard(
                        tmpl: templates[i],
                        onUse: () {
                          Navigator.pop(sheetCtx);
                          _instantiateTemplate(ctx, l, templates[i]);
                        },
                      ),
                    ),
            ),
          ]),
        ),
      );
    } catch (_) {}
  }

  void _instantiateTemplate(
      BuildContext ctx, AppLocalizations l, Map<String, dynamic> tmpl) {
    final titleCtrl =
        TextEditingController(text: '${tmpl['title']} ${DateTime.now().year}');
    DateTime? targetDate;

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (sheetCtx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: StatefulBuilder(
          builder: (sheetCtx, setSheetState) => SingleChildScrollView(
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.t('workflows.useTemplate'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                          '${(tmpl['activities'] as List?)?.length ?? 0} ${l.t('workflows.templateActivities')}',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textTertiary)),
                      const SizedBox(height: 16),
                      TextField(
                          controller: titleCtrl,
                          decoration: InputDecoration(
                              labelText: l.t('workflows.titleLabel'),
                              border: const OutlineInputBorder())),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final d = await showDatePicker(
                              context: sheetCtx,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 730)));
                          if (d != null) setSheetState(() => targetDate = d);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                              labelText: l.t('workflows.targetDate'),
                              border: const OutlineInputBorder()),
                          child: Text(
                              targetDate != null
                                  ? DateFormat('dd MMM yyyy')
                                      .format(targetDate!)
                                  : l.t('workflows.selectDate'),
                              style: TextStyle(
                                  color: targetDate != null
                                      ? null
                                      : AppColors.textTertiary)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () => Navigator.pop(sheetCtx),
                                child: Text(l.t('common.cancel')))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: GradientButton(
                          label: l.t('workflows.useTemplate'),
                          onPressed: () async {
                            if (titleCtrl.text.isEmpty) return;
                            try {
                              await api.post(
                                  '/workflows/${tmpl['id']}/instantiate',
                                  data: {
                                    'title': titleCtrl.text,
                                    'titleMr': tmpl['titleMr'] ?? '',
                                    'targetDate': targetDate
                                        ?.toIso8601String()
                                        .split('T')
                                        .first,
                                  });
                              if (ctx.mounted) {
                                Navigator.pop(sheetCtx);
                                ctx
                                    .read<_WFListCubit>()
                                    .load(status: _filters[_fi]);
                              }
                            } catch (_) {}
                          },
                        )),
                      ]),
                    ]),
            ),
          )),
        ),
    );
  }

  // ─── Blank Workflow ─────────────────────────────────────────────

  void _showCreateSheet(BuildContext ctx, AppLocalizations l) {
    final titleCtrl = TextEditingController();
    final titleMrCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'GENERAL';
    DateTime? targetDate;

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (sheetCtx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
          return Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(l.t('workflows.create'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                        labelText: l.t('workflows.titleLabel'),
                        border: const OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: titleMrCtrl,
                    decoration: InputDecoration(
                        labelText: l.t('workflows.titleMrLabel'),
                        border: const OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                        labelText: l.t('workflows.description'),
                        border: const OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(
                      labelText: l.t('workflows.category'),
                      border: const OutlineInputBorder()),
                  items: [
                    'GENERAL',
                    'AGM',
                    'SGM',
                    'FESTIVAL',
                    'REPAIR',
                    'COMPLIANCE',
                    'ELECTION'
                  ]
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setSheetState(() => category = v ?? 'GENERAL'),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                        context: sheetCtx,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 730)));
                    if (d != null) setSheetState(() => targetDate = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: l.t('workflows.targetDate'),
                        border: const OutlineInputBorder()),
                    child: Text(
                        targetDate != null
                            ? DateFormat('dd MMM yyyy').format(targetDate!)
                            : l.t('workflows.selectDate')),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: Text(l.t('common.cancel')))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: GradientButton(
                    label: l.t('common.save'),
                    onPressed: () async {
                      if (titleCtrl.text.isEmpty) return;
                      try {
                        await api.post('/workflows', data: {
                          'title': titleCtrl.text,
                          'titleMr': titleMrCtrl.text,
                          'description': descCtrl.text,
                          'category': category,
                          'targetDate': targetDate
                              ?.toIso8601String()
                              .split('T')
                              .first,
                        });
                        if (ctx.mounted) {
                          Navigator.pop(sheetCtx);
                          ctx
                              .read<_WFListCubit>()
                              .load(status: _filters[_fi]);
                        }
                      } catch (_) {}
                    },
                  )),
                ]),
              ])),
          );
        }),
        ),
    );
  }
}

// ─── Option Tile (for new workflow chooser) ─────────────────────

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _OptionTile(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(50)),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textTertiary)),
              ])),
          Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
        ]),
      ),
    );
  }
}

// ─── Template Card ──────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final Map<String, dynamic> tmpl;
  final VoidCallback onUse;
  const _TemplateCard({required this.tmpl, required this.onUse});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;
    final title = (isMr ? tmpl['titleMr'] : null) ?? tmpl['title'] ?? '';
    final desc =
        (isMr ? tmpl['descriptionMr'] : null) ?? tmpl['description'] ?? '';
    final category = tmpl['category'] ?? 'GENERAL';
    final activities =
        (tmpl['activities'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final catColor = _categoryColor(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: catColor.withAlpha(12),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child:
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: catColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(_categoryIcon(category),
                  size: 20, color: catColor),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  if (desc.isNotEmpty)
                    Text(desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textTertiary)),
                ])),
          ]),
        ),

        // Activity preview chips
        if (activities.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              ...activities.take(5).map((a) {
                final compType = a['componentType'] ?? 'CUSTOM';
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _componentColor(compType).withAlpha(15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _componentColor(compType).withAlpha(40)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_componentIcon(compType),
                        size: 12, color: _componentColor(compType)),
                    const SizedBox(width: 4),
                    Text(
                        (isMr ? a['titleMr'] : null) ?? a['title'] ?? '',
                        style: TextStyle(
                            fontSize: 10,
                            color: _componentColor(compType))),
                  ]),
                );
              }),
              if (activities.length > 5)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('+${activities.length - 5}',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textTertiary)),
                ),
            ]),
          ),

        // Use button
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Row(children: [
            Text(
                '${activities.length} ${l.t('workflows.templateActivities')}',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textTertiary)),
            const Spacer(),
            GestureDetector(
              onTap: onUse,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(l.t('workflows.useTemplate'),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'AGM':
        return const Color(0xFF3B82F6);
      case 'SGM':
        return const Color(0xFF8B5CF6);
      case 'FESTIVAL':
        return const Color(0xFFEC4899);
      case 'REPAIR':
        return const Color(0xFFF59E0B);
      case 'COMPLIANCE':
        return const Color(0xFF10B981);
      case 'ELECTION':
        return const Color(0xFF06B6D4);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'AGM':
        return Icons.groups_rounded;
      case 'SGM':
        return Icons.people_alt_rounded;
      case 'FESTIVAL':
        return Icons.celebration_rounded;
      case 'REPAIR':
        return Icons.build_rounded;
      case 'COMPLIANCE':
        return Icons.gavel_rounded;
      case 'ELECTION':
        return Icons.how_to_vote_rounded;
      default:
        return Icons.account_tree_rounded;
    }
  }
}

// ─── Workflow Card ────────────────────────────────────────────────

class _WorkflowCard extends StatelessWidget {
  final Map<String, dynamic> wf;
  const _WorkflowCard({required this.wf});

  @override
  Widget build(BuildContext context) {
    final isMr = context.watch<LocaleCubit>().isMarathi;
    final title = (isMr ? wf['titleMr'] : null) ?? wf['title'] ?? '';
    final category = wf['category'] ?? 'GENERAL';
    final status = wf['status'] ?? 'DRAFT';
    final progress = wf['progress'] as Map<String, dynamic>? ?? {};
    final percent = progress['percent'] ?? 0;
    final total = progress['total'] ?? 0;
    final completed =
        (progress['completed'] ?? 0) + (progress['skipped'] ?? 0);
    final targetDate = wf['targetDate'] != null
        ? DateTime.tryParse(wf['targetDate'])
        : null;

    final statusColor = _statusColor(status);

    return GlassCard(
      onTap: () => context.push('/workflows/${wf['id']}'),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: statusColor.withAlpha(26),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(_categoryIcon(category),
                size: 20, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                    [
                      category,
                      if (targetDate != null)
                        DateFormat('dd MMM').format(targetDate)
                    ].join(' · '),
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textTertiary)),
              ])),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: statusColor.withAlpha(26),
                borderRadius: BorderRadius.circular(6)),
            child: Text(status,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
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
            Text('$completed/$total',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ]),
        ],
      ]),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'ACTIVE':
        return const Color(0xFF3B82F6);
      case 'COMPLETED':
        return const Color(0xFF10B981);
      case 'CANCELLED':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFFF97316);
    }
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'AGM':
        return Icons.groups_rounded;
      case 'SGM':
        return Icons.people_alt_rounded;
      case 'FESTIVAL':
        return Icons.celebration_rounded;
      case 'REPAIR':
        return Icons.build_rounded;
      case 'COMPLIANCE':
        return Icons.gavel_rounded;
      case 'ELECTION':
        return Icons.how_to_vote_rounded;
      default:
        return Icons.account_tree_rounded;
    }
  }
}

// ─── Component helpers (shared) ─────────────────────────────────

IconData _componentIcon(String type) {
  switch (type) {
    case 'SCHEDULE_MEETING':
      return Icons.event_rounded;
    case 'SHARE_MINUTES':
      return Icons.description_rounded;
    case 'UPLOAD_DOCUMENT':
      return Icons.upload_file_rounded;
    case 'ISSUE_CHEQUE':
      return Icons.payments_rounded;
    case 'UPLOAD_INVOICE':
      return Icons.receipt_long_rounded;
    case 'SEND_NOTICE':
      return Icons.campaign_rounded;
    case 'COLLECT_APPROVAL':
      return Icons.how_to_vote_rounded;
    default:
      return Icons.task_alt_rounded;
  }
}

Color _componentColor(String type) {
  switch (type) {
    case 'SCHEDULE_MEETING':
      return const Color(0xFF3B82F6);
    case 'SHARE_MINUTES':
      return const Color(0xFF8B5CF6);
    case 'UPLOAD_DOCUMENT':
      return const Color(0xFF10B981);
    case 'ISSUE_CHEQUE':
      return const Color(0xFFF59E0B);
    case 'UPLOAD_INVOICE':
      return const Color(0xFFEF4444);
    case 'SEND_NOTICE':
      return const Color(0xFFEC4899);
    case 'COLLECT_APPROVAL':
      return const Color(0xFF06B6D4);
    default:
      return const Color(0xFF64748B);
  }
}
