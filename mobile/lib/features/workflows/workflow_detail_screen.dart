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
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/status_badge.dart';

// ─── Screen ──────────────────────────────────────────────────────

class WorkflowDetailScreen extends StatefulWidget {
  final String id;
  const WorkflowDetailScreen({super.key, required this.id});
  @override
  State<WorkflowDetailScreen> createState() => _WorkflowDetailScreenState();
}

class _WorkflowDetailScreenState extends State<WorkflowDetailScreen> {
  Map<String, dynamic>? _wf;
  Map<String, dynamic> _progress = {};
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _auditLogs = [];
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;
  bool _showAudit = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadMembers();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await api.get('/workflows/${widget.id}');
      if (!mounted) return;
      final wf = res.data['workflow'] as Map<String, dynamic>? ?? {};
      setState(() {
        _wf = wf;
        _progress = res.data['progress'] as Map<String, dynamic>? ?? {};
        _activities =
            (wf['activities'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMembers() async {
    try {
      final res = await api.get('/residents');
      if (!mounted) return;
      setState(() => _members =
          (res.data['residents'] as List?)?.cast<Map<String, dynamic>>() ?? []);
    } catch (_) {}
  }

  Future<void> _loadAudit() async {
    try {
      final res = await api.get('/workflows/${widget.id}/audit-log');
      if (!mounted) return;
      setState(() => _auditLogs =
          (res.data['logs'] as List?)?.cast<Map<String, dynamic>>() ?? []);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;

    if (_loading) {
      return Scaffold(
          body: SafeArea(
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary))));
    }

    if (_wf == null) {
      return Scaffold(
          body: SafeArea(child: Center(child: Text(l.t('common.error')))));
    }

    final title = (isMr ? _wf!['titleMr'] : null) ?? _wf!['title'] ?? '';
    final status = _wf!['status'] ?? 'DRAFT';
    final category = _wf!['category'] ?? '';
    final desc =
        (isMr ? _wf!['descriptionMr'] : null) ?? _wf!['description'] ?? '';
    final targetDate =
        _wf!['targetDate'] != null ? DateTime.tryParse(_wf!['targetDate']) : null;
    final percent = _progress['percent'] ?? 0;
    final total = _progress['total'] ?? 0;
    final completed =
        (_progress['completed'] ?? 0) + (_progress['skipped'] ?? 0);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
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
                            size: 20, color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700),
                            maxLines: 2)),
                    if (isAdmin) _buildPopupMenu(context, l, status),
                  ]),
                ),
              ),

              // Info card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            StatusBadge(
                                label: status, color: _statusColor(status)),
                            const SizedBox(width: 8),
                            StatusBadge(
                                label: category, color: AppColors.primary),
                            const Spacer(),
                            if (targetDate != null)
                              Text(
                                  DateFormat('dd MMM yyyy')
                                      .format(targetDate),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary)),
                          ]),
                          if (desc.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(desc,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary)),
                          ],
                          if (total > 0) ...[
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                  child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: percent / 100,
                                  backgroundColor: AppColors.border,
                                  color: _statusColor(status),
                                  minHeight: 8,
                                ),
                              )),
                              const SizedBox(width: 10),
                              Text('$completed/$total ($percent%)',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary)),
                            ]),
                          ],
                        ]),
                  ),
                ),
              ),

              // Activities header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(children: [
                    Text(l.t('workflows.activities'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (isAdmin)
                      GestureDetector(
                        onTap: () => _showComponentPalette(context, l),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.add_rounded,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(l.t('workflows.addActivity'),
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary)),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ),

              // Activity timeline with component cards
              if (_activities.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                          child: Text(l.t('workflows.noActivities'),
                              style: TextStyle(
                                  color: AppColors.textTertiary)))),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _ComponentActivityTile(
                      activity: _activities[i],
                      isLast: i == _activities.length - 1,
                      isAdmin: isAdmin,
                      wfId: widget.id,
                      onRefresh: _load,
                      members: _members,
                      isMr: isMr,
                    ),
                    childCount: _activities.length,
                  ),
                ),

              // Audit log toggle
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: GestureDetector(
                    onTap: () {
                      if (!_showAudit && _auditLogs.isEmpty) _loadAudit();
                      setState(() => _showAudit = !_showAudit);
                    },
                    child: Row(children: [
                      Icon(
                          _showAudit
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 20,
                          color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(l.t('workflows.auditLog'),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ]),
                  ),
                ),
              ),

              if (_showAudit)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _AuditTile(log: _auditLogs[i]),
                    childCount: _auditLogs.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPopupMenu(
      BuildContext ctx, AppLocalizations l, String status) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
      onSelected: (v) async {
        if (v == 'activate' || v == 'complete' || v == 'cancel') {
          final s = v == 'activate'
              ? 'ACTIVE'
              : v == 'complete'
                  ? 'COMPLETED'
                  : 'CANCELLED';
          try {
            await api.patch('/workflows/${widget.id}/status',
                data: {'status': s});
            _load();
          } catch (_) {}
        } else if (v == 'save_template') {
          try {
            await api.patch('/workflows/${widget.id}',
                data: {'is_template': true});
            if (mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(l.t('workflows.savedAsTemplate'))));
            }
          } catch (_) {}
        } else if (v == 'delete') {
          try {
            await api.delete('/workflows/${widget.id}');
            if (mounted) {
              if (ctx.canPop()) ctx.pop(); else ctx.go('/more');
            }
          } catch (_) {}
        }
      },
      itemBuilder: (_) => [
        if (status == 'DRAFT')
          PopupMenuItem(
              value: 'activate', child: Text(l.t('workflows.activate'))),
        if (status == 'ACTIVE')
          PopupMenuItem(
              value: 'complete',
              child: Text(l.t('workflows.markComplete'))),
        if (status != 'CANCELLED' && status != 'COMPLETED')
          PopupMenuItem(
              value: 'cancel', child: Text(l.t('common.cancel'))),
        PopupMenuItem(
            value: 'save_template',
            child: Text(l.t('workflows.saveAsTemplate'))),
        PopupMenuItem(
            value: 'delete',
            child: Text(l.t('common.delete'),
                style: TextStyle(color: AppColors.urgent))),
      ],
    );
  }

  // ─── Component Palette ────────────────────────────────────────

  void _showComponentPalette(BuildContext ctx, AppLocalizations l) {
    final components = [
      {
        'type': 'SCHEDULE_MEETING',
        'label': l.t('workflows.component.scheduleMeeting'),
        'icon': Icons.event_rounded,
        'color': const Color(0xFF3B82F6),
      },
      {
        'type': 'SHARE_MINUTES',
        'label': l.t('workflows.component.shareMinutes'),
        'icon': Icons.description_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'type': 'UPLOAD_DOCUMENT',
        'label': l.t('workflows.component.uploadDocument'),
        'icon': Icons.upload_file_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'type': 'ISSUE_CHEQUE',
        'label': l.t('workflows.component.issueCheque'),
        'icon': Icons.payments_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'type': 'UPLOAD_INVOICE',
        'label': l.t('workflows.component.uploadInvoice'),
        'icon': Icons.receipt_long_rounded,
        'color': const Color(0xFFEF4444),
      },
      {
        'type': 'SEND_NOTICE',
        'label': l.t('workflows.component.sendNotice'),
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFFEC4899),
      },
      {
        'type': 'COLLECT_APPROVAL',
        'label': l.t('workflows.component.collectApproval'),
        'icon': Icons.how_to_vote_rounded,
        'color': const Color(0xFF06B6D4),
      },
      {
        'type': 'CUSTOM',
        'label': l.t('workflows.component.custom'),
        'icon': Icons.task_alt_rounded,
        'color': const Color(0xFF64748B),
      },
    ];

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (sheetCtx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.t('workflows.pickComponent'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: components.length,
            itemBuilder: (_, i) {
              final c = components[i];
              final color = c['color'] as Color;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showAddActivitySheet(
                    ctx,
                    l,
                    componentType: c['type'] as String,
                    defaultTitle: c['label'] as String,
                  );
                },
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: color.withAlpha(50)),
                        ),
                        child: Icon(c['icon'] as IconData,
                            size: 24, color: color),
                      ),
                      const SizedBox(height: 6),
                      Text(c['label'] as String,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary)),
                    ]),
              );
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
      ),
    );
  }

  // ─── Add Activity Sheet ────────────────────────────────────────

  void _showAddActivitySheet(BuildContext ctx, AppLocalizations l,
      {String componentType = 'CUSTOM', String defaultTitle = ''}) {
    final titleCtrl = TextEditingController(text: defaultTitle);
    final titleMrCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? dueDate;
    String? assigneeId;

    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (sheetCtx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
          final compColor = _compColor(componentType);
          return Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Component type badge
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: compColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_compIcon(componentType),
                        size: 20, color: compColor),
                  ),
                  const SizedBox(width: 10),
                  Text(l.t('workflows.addActivity'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 16),
                TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                        labelText: l.t('workflows.activityTitle'),
                        border: const OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: titleMrCtrl,
                    decoration: InputDecoration(
                        labelText: l.t('workflows.activityTitleMr'),
                        border: const OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                        labelText: l.t('workflows.description'),
                        border: const OutlineInputBorder())),
                const SizedBox(height: 12),
                if (_members.isNotEmpty)
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                        labelText: l.t('workflows.assignee'),
                        border: const OutlineInputBorder()),
                    items: _members
                        .map((m) => DropdownMenuItem(
                            value: m['id'].toString(),
                            child: Text(m['name'] ?? '')))
                        .toList(),
                    onChanged: (v) => assigneeId = v,
                  ),
                if (_members.isNotEmpty) const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                        context: sheetCtx,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 730)));
                    if (d != null) setSheetState(() => dueDate = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: l.t('workflows.dueDate'),
                        border: const OutlineInputBorder()),
                    child: Text(
                        dueDate != null
                            ? DateFormat('dd MMM yyyy').format(dueDate!)
                            : l.t('workflows.selectDate'),
                        style: TextStyle(
                            color: dueDate != null
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
                    label: l.t('common.save'),
                    onPressed: () async {
                      if (titleCtrl.text.isEmpty) return;
                      try {
                        await api.post(
                            '/workflows/${widget.id}/activities',
                            data: {
                              'title': titleCtrl.text,
                              'titleMr': titleMrCtrl.text,
                              'description': descCtrl.text,
                              'dueDate': dueDate
                                  ?.toIso8601String()
                                  .split('T')
                                  .first,
                              'assignedToMemberId': assigneeId,
                              'componentType': componentType,
                            });
                        if (ctx.mounted) {
                          Navigator.pop(sheetCtx);
                          _load();
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

  IconData _compIcon(String type) {
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

  Color _compColor(String type) {
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
}

// ─── Component-typed Activity Tile ──────────────────────────────

class _ComponentActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  final bool isLast;
  final bool isAdmin;
  final String wfId;
  final VoidCallback onRefresh;
  final List<Map<String, dynamic>> members;
  final bool isMr;

  const _ComponentActivityTile({
    required this.activity,
    required this.isLast,
    required this.isAdmin,
    required this.wfId,
    required this.onRefresh,
    required this.members,
    required this.isMr,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title =
        (isMr ? activity['titleMr'] : null) ?? activity['title'] ?? '';
    final desc = (isMr ? activity['descriptionMr'] : null) ??
        activity['description'] ??
        '';
    final status = activity['status'] ?? 'PENDING';
    final compType = activity['componentType'] ?? 'CUSTOM';
    final assignee = activity['assignedTo'] as Map<String, dynamic>?;
    final dueDate = activity['dueDate'] != null
        ? DateTime.tryParse(activity['dueDate'])
        : null;
    final comments =
        (activity['comments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final attachments =
        (activity['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final compColor = _componentColor(compType);
    final statusColor = _activityStatusColor(status);
    final isDone = status == 'COMPLETED' || status == 'SKIPPED';

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Timeline connector with component icon
          SizedBox(
            width: 36,
            child: Column(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDone
                      ? statusColor.withAlpha(20)
                      : compColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDone ? statusColor : compColor, width: 1.5),
                ),
                child: Icon(
                  isDone
                      ? (status == 'COMPLETED'
                          ? Icons.check_rounded
                          : Icons.skip_next_rounded)
                      : _componentIcon(compType),
                  size: 16,
                  color: isDone ? statusColor : compColor,
                ),
              ),
              if (!isLast)
                Expanded(
                    child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: AppColors.border)),
            ]),
          ),
          const SizedBox(width: 10),
          // Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDone
                        ? statusColor.withAlpha(40)
                        : compColor.withAlpha(40)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row with component badge + status menu
                    Row(children: [
                      // Component type chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: compColor.withAlpha(15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                            _componentLabel(compType),
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: compColor)),
                      ),
                      const Spacer(),
                      // Status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(status,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: statusColor)),
                      ),
                      if (isAdmin) _buildStatusMenu(context, l, status),
                    ]),
                    const SizedBox(height: 6),
                    Text(title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          color: isDone
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                        )),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textTertiary)),
                    ],
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      if (assignee != null)
                        _chip(Icons.person_outline, assignee['name'] ?? '',
                            AppColors.textTertiary),
                      if (dueDate != null)
                        _chip(
                            Icons.event,
                            DateFormat('dd MMM').format(dueDate),
                            _dueDateColor(dueDate, status)),
                      if (comments.isNotEmpty)
                        _chip(Icons.chat_bubble_outline,
                            '${comments.length}', AppColors.textTertiary),
                      if (attachments.isNotEmpty)
                        _chip(Icons.attach_file, '${attachments.length}',
                            AppColors.textTertiary),
                    ]),
                    // Comments preview
                    if (comments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ...comments.take(2).map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.subdirectory_arrow_right,
                                      size: 14,
                                      color: AppColors.textTertiary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                      child: RichText(
                                          text: TextSpan(
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary),
                                    children: [
                                      TextSpan(
                                          text:
                                              '${c['member']?['name'] ?? ''}: ',
                                          style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w600)),
                                      TextSpan(text: c['body'] ?? ''),
                                    ],
                                  ))),
                                ]),
                          )),
                    ],
                    // Add comment button
                    if (isAdmin) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => _showCommentDialog(context, l),
                        child: Text(l.t('workflows.addComment'),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                    ],
                  ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 2),
      Text(text, style: TextStyle(fontSize: 10, color: color)),
    ]);
  }

  Widget _buildStatusMenu(
      BuildContext ctx, AppLocalizations l, String status) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz, size: 18, color: AppColors.textTertiary),
      onSelected: (v) async {
        try {
          await api.patch(
              '/workflows/$wfId/activities/${activity['id']}/status',
              data: {'status': v});
          onRefresh();
        } catch (_) {}
      },
      itemBuilder: (_) => [
        if (status != 'PENDING')
          PopupMenuItem(
              value: 'PENDING',
              child: Text(l.t('workflows.status.pending'))),
        if (status != 'IN_PROGRESS')
          PopupMenuItem(
              value: 'IN_PROGRESS',
              child: Text(l.t('workflows.status.inProgress'))),
        if (status != 'COMPLETED')
          PopupMenuItem(
              value: 'COMPLETED',
              child: Text(l.t('workflows.status.completed'))),
        if (status != 'SKIPPED')
          PopupMenuItem(
              value: 'SKIPPED',
              child: Text(l.t('workflows.status.skipped'))),
      ],
    );
  }

  void _showCommentDialog(BuildContext ctx, AppLocalizations l) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Text(l.t('workflows.addComment')),
        content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration:
                InputDecoration(hintText: l.t('workflows.commentHint'))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: Text(l.t('common.cancel'))),
          TextButton(
              onPressed: () async {
                if (ctrl.text.isEmpty) return;
                try {
                  await api.post(
                      '/workflows/$wfId/activities/${activity['id']}/comments',
                      data: {'body': ctrl.text});
                  Navigator.pop(dCtx);
                  onRefresh();
                } catch (_) {}
              },
              child: Text(l.t('common.save'))),
        ],
      ),
    );
  }

  String _componentLabel(String type) {
    switch (type) {
      case 'SCHEDULE_MEETING':
        return 'Meeting';
      case 'SHARE_MINUTES':
        return 'Minutes';
      case 'UPLOAD_DOCUMENT':
        return 'Document';
      case 'ISSUE_CHEQUE':
        return 'Payment';
      case 'UPLOAD_INVOICE':
        return 'Invoice';
      case 'SEND_NOTICE':
        return 'Notice';
      case 'COLLECT_APPROVAL':
        return 'Approval';
      default:
        return 'Task';
    }
  }

  Color _activityStatusColor(String s) {
    switch (s) {
      case 'IN_PROGRESS':
        return const Color(0xFF3B82F6);
      case 'COMPLETED':
        return const Color(0xFF10B981);
      case 'SKIPPED':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFFF97316);
    }
  }

  Color _dueDateColor(DateTime due, String status) {
    if (status == 'COMPLETED' || status == 'SKIPPED') {
      return AppColors.textTertiary;
    }
    final days = due.difference(DateTime.now()).inDays;
    if (days < 0) return const Color(0xFFEF4444);
    if (days <= 3) return const Color(0xFFF97316);
    return AppColors.textTertiary;
  }
}

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

// ─── Audit Tile ──────────────────────────────────────────────────

class _AuditTile extends StatelessWidget {
  final Map<String, dynamic> log;
  const _AuditTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final action = log['action'] ?? '';
    final actor = log['actor'] as Map<String, dynamic>?;
    final desc = log['description'] ?? '';
    final old = log['oldValue'] ?? '';
    final nw = log['newValue'] ?? '';
    final time = DateTime.tryParse(log['createdAt'] ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.circle, size: 6, color: AppColors.textTertiary),
        const SizedBox(width: 8),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              RichText(
                  text: TextSpan(
                style:
                    TextStyle(fontSize: 11, color: AppColors.textSecondary),
                children: [
                  TextSpan(
                      text: actor?['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: ' $action'),
                  if (old.isNotEmpty && nw.isNotEmpty)
                    TextSpan(text: ': $old → $nw'),
                ],
              )),
              if (desc.isNotEmpty)
                Text(desc,
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textTertiary),
                    maxLines: 2),
              if (time != null)
                Text(DateFormat('dd MMM HH:mm').format(time),
                    style: TextStyle(
                        fontSize: 9, color: AppColors.textTertiary)),
            ])),
      ]),
    );
  }
}
