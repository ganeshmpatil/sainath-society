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
        _activities = (wf['activities'] as List?)?.cast<Map<String, dynamic>>() ?? [];
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
      setState(() => _members = (res.data['residents'] as List?)?.cast<Map<String, dynamic>>() ?? []);
    } catch (_) {}
  }

  Future<void> _loadAudit() async {
    try {
      final res = await api.get('/workflows/${widget.id}/audit-log');
      if (!mounted) return;
      setState(() => _auditLogs = (res.data['logs'] as List?)?.cast<Map<String, dynamic>>() ?? []);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.watch<LocaleCubit>();
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;

    if (_loading) {
      return Scaffold(body: SafeArea(child: Center(child: CircularProgressIndicator(color: AppColors.primary))));
    }

    if (_wf == null) {
      return Scaffold(body: SafeArea(child: Center(child: Text(l.t('common.error')))));
    }

    final title = _wf!['title'] ?? '';
    final status = _wf!['status'] ?? 'DRAFT';
    final category = _wf!['category'] ?? '';
    final desc = _wf!['description'] ?? '';
    final targetDate = _wf!['targetDate'] != null ? DateTime.tryParse(_wf!['targetDate']) : null;
    final percent = _progress['percent'] ?? 0;
    final total = _progress['total'] ?? 0;
    final completed = (_progress['completed'] ?? 0) + (_progress['skipped'] ?? 0);

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
                    GestureDetector(onTap: () => context.pop(),
                        child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700), maxLines: 2)),
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
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        StatusBadge(label: status, color: _statusColor(status)),
                        const SizedBox(width: 8),
                        StatusBadge(label: category, color: AppColors.primary),
                        const Spacer(),
                        if (targetDate != null)
                          Text(DateFormat('dd MMM yyyy').format(targetDate), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      ]),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(desc, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ],
                      if (total > 0) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: ClipRRect(
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
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
                    Text(l.t('workflows.activities'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (isAdmin)
                      GestureDetector(
                        onTap: () => _showAddActivitySheet(context, l),
                        child: Row(children: [
                          Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(l.t('workflows.addActivity'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                        ]),
                      ),
                  ]),
                ),
              ),

              // Activity timeline
              if (_activities.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(padding: const EdgeInsets.all(24),
                    child: Center(child: Text(l.t('workflows.noActivities'), style: TextStyle(color: AppColors.textTertiary)))),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _ActivityTile(
                      activity: _activities[i],
                      isLast: i == _activities.length - 1,
                      isAdmin: isAdmin,
                      wfId: widget.id,
                      onRefresh: _load,
                      members: _members,
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
                      Icon(_showAudit ? Icons.expand_less : Icons.expand_more, size: 20, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Text(l.t('workflows.auditLog'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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

  Widget _buildPopupMenu(BuildContext ctx, AppLocalizations l, String status) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
      onSelected: (v) async {
        if (v == 'activate' || v == 'complete' || v == 'cancel') {
          final s = v == 'activate' ? 'ACTIVE' : v == 'complete' ? 'COMPLETED' : 'CANCELLED';
          try {
            await api.patch('/workflows/${widget.id}/status', data: {'status': s});
            _load();
          } catch (_) {}
        } else if (v == 'save_template') {
          try {
            await api.patch('/workflows/${widget.id}', data: {'is_template': true});
            if (mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(l.t('workflows.savedAsTemplate'))));
            }
          } catch (_) {}
        } else if (v == 'delete') {
          try {
            await api.delete('/workflows/${widget.id}');
            if (mounted) ctx.pop();
          } catch (_) {}
        }
      },
      itemBuilder: (_) => [
        if (status == 'DRAFT')
          PopupMenuItem(value: 'activate', child: Text(l.t('workflows.activate'))),
        if (status == 'ACTIVE')
          PopupMenuItem(value: 'complete', child: Text(l.t('workflows.markComplete'))),
        if (status != 'CANCELLED' && status != 'COMPLETED')
          PopupMenuItem(value: 'cancel', child: Text(l.t('common.cancel'))),
        PopupMenuItem(value: 'save_template', child: Text(l.t('workflows.saveAsTemplate'))),
        PopupMenuItem(value: 'delete', child: Text(l.t('common.delete'), style: TextStyle(color: AppColors.urgent))),
      ],
    );
  }

  void _showAddActivitySheet(BuildContext ctx, AppLocalizations l) {
    final titleCtrl = TextEditingController();
    final titleMrCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? dueDate;
    String? assigneeId;

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
            Text(l.t('workflows.addActivity'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: titleCtrl, decoration: InputDecoration(labelText: l.t('workflows.activityTitle'), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: titleMrCtrl, decoration: InputDecoration(labelText: l.t('workflows.activityTitleMr'), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, maxLines: 3, decoration: InputDecoration(labelText: l.t('common.description'), border: const OutlineInputBorder())),
            const SizedBox(height: 12),
            if (_members.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: l.t('workflows.assignee'), border: const OutlineInputBorder()),
                items: _members.map((m) => DropdownMenuItem(value: m['id'].toString(), child: Text(m['name'] ?? ''))).toList(),
                onChanged: (v) => assigneeId = v,
              ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(context: sheetCtx, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
                if (d != null) setSheetState(() => dueDate = d);
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: l.t('workflows.dueDate'), border: const OutlineInputBorder()),
                child: Text(dueDate != null ? DateFormat('dd MMM yyyy').format(dueDate!) : l.t('workflows.selectDate')),
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
                    await api.post('/workflows/${widget.id}/activities', data: {
                      'title': titleCtrl.text,
                      'titleMr': titleMrCtrl.text,
                      'description': descCtrl.text,
                      'dueDate': dueDate?.toIso8601String().split('T').first,
                      'assignedToMemberId': assigneeId,
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
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'ACTIVE': return const Color(0xFF3B82F6);
      case 'COMPLETED': return const Color(0xFF10B981);
      case 'CANCELLED': return const Color(0xFF64748B);
      default: return const Color(0xFFF97316);
    }
  }
}

// ─── Activity Tile (Timeline style) ──────────────────────────────

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  final bool isLast;
  final bool isAdmin;
  final String wfId;
  final VoidCallback onRefresh;
  final List<Map<String, dynamic>> members;

  const _ActivityTile({
    required this.activity,
    required this.isLast,
    required this.isAdmin,
    required this.wfId,
    required this.onRefresh,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = activity['title'] ?? '';
    final status = activity['status'] ?? 'PENDING';
    final assignee = activity['assignedTo'] as Map<String, dynamic>?;
    final dueDate = activity['dueDate'] != null ? DateTime.tryParse(activity['dueDate']) : null;
    final comments = (activity['comments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final attachments = (activity['attachments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final color = _activityStatusColor(status);

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Timeline connector
          SizedBox(
            width: 32,
            child: Column(children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withAlpha(26),
                  border: Border.all(color: color, width: 2),
                ),
                child: Center(child: Icon(
                  status == 'COMPLETED' ? Icons.check : status == 'SKIPPED' ? Icons.skip_next : status == 'IN_PROGRESS' ? Icons.play_arrow : Icons.circle,
                  size: 12, color: color,
                )),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: AppColors.border)),
            ]),
          ),
          const SizedBox(width: 10),
          // Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    decoration: status == 'COMPLETED' || status == 'SKIPPED' ? TextDecoration.lineThrough : null,
                  ))),
                  if (isAdmin) _buildStatusMenu(context, l, status),
                ]),
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  if (assignee != null) _chip(Icons.person_outline, assignee['name'] ?? '', AppColors.textTertiary),
                  if (dueDate != null) _chip(Icons.event, DateFormat('dd MMM').format(dueDate), _dueDateColor(dueDate, status)),
                  if (comments.isNotEmpty) _chip(Icons.chat_bubble_outline, '${comments.length}', AppColors.textTertiary),
                  if (attachments.isNotEmpty) _chip(Icons.attach_file, '${attachments.length}', AppColors.textTertiary),
                ]),
                // Comments preview
                if (comments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...comments.take(2).map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.subdirectory_arrow_right, size: 14, color: AppColors.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(child: RichText(text: TextSpan(
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        children: [
                          TextSpan(text: '${c['member']?['name'] ?? ''}: ', style: const TextStyle(fontWeight: FontWeight.w600)),
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
                    child: Text(l.t('workflows.addComment'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
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

  Widget _buildStatusMenu(BuildContext ctx, AppLocalizations l, String status) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz, size: 18, color: AppColors.textTertiary),
      onSelected: (v) async {
        try {
          await api.patch('/workflows/$wfId/activities/${activity['id']}/status', data: {'status': v});
          onRefresh();
        } catch (_) {}
      },
      itemBuilder: (_) => [
        if (status != 'PENDING') PopupMenuItem(value: 'PENDING', child: Text(l.t('workflows.status.pending'))),
        if (status != 'IN_PROGRESS') PopupMenuItem(value: 'IN_PROGRESS', child: Text(l.t('workflows.status.inProgress'))),
        if (status != 'COMPLETED') PopupMenuItem(value: 'COMPLETED', child: Text(l.t('workflows.status.completed'))),
        if (status != 'SKIPPED') PopupMenuItem(value: 'SKIPPED', child: Text(l.t('workflows.status.skipped'))),
      ],
    );
  }

  void _showCommentDialog(BuildContext ctx, AppLocalizations l) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: Text(l.t('workflows.addComment')),
        content: TextField(controller: ctrl, maxLines: 3, decoration: InputDecoration(hintText: l.t('workflows.commentHint'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: Text(l.t('common.cancel'))),
          TextButton(onPressed: () async {
            if (ctrl.text.isEmpty) return;
            try {
              await api.post('/workflows/$wfId/activities/${activity['id']}/comments', data: {'body': ctrl.text});
              Navigator.pop(dCtx);
              onRefresh();
            } catch (_) {}
          }, child: Text(l.t('common.save'))),
        ],
      ),
    );
  }

  Color _activityStatusColor(String s) {
    switch (s) {
      case 'IN_PROGRESS': return const Color(0xFF3B82F6);
      case 'COMPLETED': return const Color(0xFF10B981);
      case 'SKIPPED': return const Color(0xFF64748B);
      default: return const Color(0xFFF97316);
    }
  }

  Color _dueDateColor(DateTime due, String status) {
    if (status == 'COMPLETED' || status == 'SKIPPED') return AppColors.textTertiary;
    final days = due.difference(DateTime.now()).inDays;
    if (days < 0) return const Color(0xFFEF4444);
    if (days <= 3) return const Color(0xFFF97316);
    return AppColors.textTertiary;
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
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(text: TextSpan(
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            children: [
              TextSpan(text: actor?['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: ' $action'),
              if (old.isNotEmpty && nw.isNotEmpty) TextSpan(text: ': $old → $nw'),
            ],
          )),
          if (desc.isNotEmpty)
            Text(desc, style: TextStyle(fontSize: 10, color: AppColors.textTertiary), maxLines: 2),
          if (time != null)
            Text(DateFormat('dd MMM HH:mm').format(time), style: TextStyle(fontSize: 9, color: AppColors.textTertiary)),
        ])),
      ]),
    );
  }
}
