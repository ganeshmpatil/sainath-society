import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/status_badge.dart';

class MeetingDetailScreen extends StatefulWidget {
  final String id;
  const MeetingDetailScreen({super.key, required this.id});

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  Map<String, dynamic>? _meeting;
  bool _loading = true;
  String? _error;
  bool _editingMinutes = false;
  final _minutesCtrl = TextEditingController();

  // For action item creation
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadMembers();
  }

  @override
  void dispose() {
    _minutesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await api.get('/meetings/${widget.id}');
      setState(() {
        _meeting = res.data;
        _minutesCtrl.text = _meeting?['minutesOfMeeting'] ?? '';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMembers() async {
    try {
      final res = await api.get('/residents');
      final list =
          (res.data['residents'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      setState(() => _members = list);
    } catch (_) {}
  }

  bool get _isMinutesLocked => _meeting?['minutesLockedAt'] != null;

  Future<void> _saveMinutes({bool lock = false}) async {
    final l = AppLocalizations.of(context);
    try {
      await api.post('/meetings/${widget.id}/minutes', data: {
        'minutes': _minutesCtrl.text,
        'minutesMr': '',
        'lock': lock,
      });
      setState(() => _editingMinutes = false);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.t('meetings.saveMinutes'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.t('common.error')}: $e')),
        );
      }
    }
  }

  void _showAddActionItemSheet() {
    final l = AppLocalizations.of(context);
    String title = '', description = '';
    String? selectedMemberId;
    DateTime? dueDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(l.t('meetings.addActionItem'),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextField(
                  onChanged: (v) => title = v,
                  decoration:
                      InputDecoration(labelText: l.t('grievances.subject')),
                ),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (v) => description = v,
                  maxLines: 2,
                  decoration: InputDecoration(
                      labelText: l.t('grievances.description')),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedMemberId,
                  dropdownColor: AppColors.surface,
                  isExpanded: true,
                  decoration:
                      InputDecoration(labelText: l.t('meetings.assignee')),
                  hint: Text(l.t('meetings.selectMember'),
                      style: const TextStyle(fontSize: 13)),
                  items: _members
                      .map((m) => DropdownMenuItem(
                          value: m['id']?.toString(),
                          child: Text(
                              '${m['name']} (${m['flat']?['flatNumber'] ?? ''})',
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) =>
                      setSheetState(() => selectedMemberId = v),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate:
                          DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setSheetState(() => dueDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withAlpha(40)),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        dueDate != null
                            ? '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}'
                            : l.t('tasks.dueDate'),
                        style: TextStyle(
                            fontSize: 13,
                            color: dueDate != null
                                ? AppColors.textPrimary
                                : AppColors.textTertiary),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(l.t('common.cancel')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GradientButton(
                        label: l.t('common.submit'),
                        onPressed: () async {
                          if (title.isEmpty || selectedMemberId == null) return;
                          try {
                            final data = <String, dynamic>{
                              'title': title,
                              'description': description,
                              'ownerMemberId': selectedMemberId,
                            };
                            if (dueDate != null) {
                              data['dueDate'] =
                                  dueDate!.toUtc().toIso8601String();
                            }
                            await api.post(
                                '/meetings/${widget.id}/action-items',
                                data: data);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _load();
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                    content:
                                        Text('${l.t('common.error')}: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const ShimmerLoading()
            : _error != null
                ? Center(
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: TextStyle(color: AppColors.urgent)),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: _load,
                          child: Text(l.t('common.retry'))),
                    ],
                  ))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    child: CustomScrollView(
                      slivers: [
                        // Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => context.pop(),
                                  child: Icon(
                                      Icons.arrow_back_ios_rounded,
                                      size: 20,
                                      color: AppColors.textSecondary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(l.t('meetings.detail'),
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_meeting != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // Meeting info
                                  _buildMeetingInfo(l, isMr),
                                  const Divider(height: 32),

                                  // Minutes of Meeting
                                  _buildMinutesSection(l, isAdmin),
                                  const Divider(height: 32),

                                  // Action Items
                                  _buildActionItems(l, isMr, isAdmin),

                                  const SizedBox(height: 60),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildMeetingInfo(AppLocalizations l, bool isMr) {
    final m = _meeting!;
    final title =
        (isMr && (m['titleMr'] ?? '').toString().isNotEmpty)
            ? m['titleMr']
            : m['title'] ?? '';
    final type = m['meetingType'] ?? 'COMMITTEE';
    final status = m['status'] ?? 'PLANNED';
    final date = m['scheduledAt'] ?? '';
    final location = m['location'] ?? '';
    final agenda =
        (isMr && (m['agendaMr'] ?? '').toString().isNotEmpty)
            ? m['agendaMr']
            : m['agenda'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type + Status badges
        Row(
          children: [
            StatusBadge(label: type, color: AppColors.primary),
            const SizedBox(width: 6),
            StatusBadge.status(status),
            if (_isMinutesLocked) ...[
              const SizedBox(width: 6),
              Icon(Icons.lock_rounded,
                  size: 14, color: AppColors.resolved),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Title
        Text(title,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, height: 1.3)),
        const SizedBox(height: 8),

        // Date + Location
        Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(_fmtDateTime(date),
                style: TextStyle(
                    fontSize: 12, color: AppColors.textTertiary)),
          ],
        ),
        if (location.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(location,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textTertiary)),
            ],
          ),
        ],

        // Agenda
        if (agenda.toString().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l.t('meetings.agenda'),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SelectableText(agenda.toString(),
              style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.textSecondary)),
        ],
      ],
    );
  }

  Widget _buildMinutesSection(AppLocalizations l, bool isAdmin) {
    final minutes = _meeting?['minutesOfMeeting'] ?? '';
    final hasMinutes = minutes.toString().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description_outlined,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(l.t('meetings.minutesOfMeeting'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (isAdmin && !_isMinutesLocked && !_editingMinutes)
              GestureDetector(
                onTap: () => setState(() => _editingMinutes = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(l.t('meetings.editMinutes'),
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            if (_isMinutesLocked)
              Row(
                children: [
                  Icon(Icons.lock_rounded,
                      size: 12, color: AppColors.resolved),
                  const SizedBox(width: 4),
                  Text(l.t('meetings.minutesLocked'),
                      style: TextStyle(
                          fontSize: 11, color: AppColors.resolved)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (_editingMinutes) ...[
          TextField(
            controller: _minutesCtrl,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: l.t('meetings.minutesPlaceholder'),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _editingMinutes = false),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(l.t('common.cancel')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GradientButton(
                  label: l.t('meetings.saveMinutes'),
                  onPressed: () => _saveMinutes(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasMinutes)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showLockConfirm(),
                icon: Icon(Icons.lock_rounded,
                    size: 16, color: AppColors.urgent),
                label: Text(l.t('meetings.lockMinutes'),
                    style: TextStyle(color: AppColors.urgent)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: AppColors.urgent.withAlpha(60)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ] else if (hasMinutes) ...[
          // Display minutes as formatted text - each line is a point
          ..._buildMinutesPoints(minutes.toString()),
        ] else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(8),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.primary.withAlpha(30)),
            ),
            child: Column(
              children: [
                Icon(Icons.edit_note_rounded,
                    size: 32, color: AppColors.textTertiary),
                const SizedBox(height: 8),
                Text(l.t('meetings.noMinutes'),
                    style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary)),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _buildMinutesPoints(String minutes) {
    final lines = minutes
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    return lines.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final line = entry.value.trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Text('$idx',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SelectableText(line,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _showLockConfirm() {
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.t('meetings.lockMinutes')),
        content: Text(
            'Once locked, minutes cannot be edited. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.t('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveMinutes(lock: true);
            },
            child: Text(l.t('common.yes'),
                style: TextStyle(color: AppColors.urgent)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItems(
      AppLocalizations l, bool isMr, bool isAdmin) {
    final items = (_meeting?['actionItems'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.checklist_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(l.t('meetings.actionItems'),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (isAdmin)
              GestureDetector(
                onTap: _showAddActionItemSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(l.t('common.new'),
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(l.t('meetings.noActionItems'),
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary)),
            ),
          )
        else
          ...items.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final item = entry.value;
            return _buildActionItemCard(item, idx, l);
          }),
      ],
    );
  }

  Widget _buildActionItemCard(
      Map<String, dynamic> item, int idx, AppLocalizations l) {
    final title = item['title'] ?? '';
    final desc = item['description'] ?? '';
    final status = item['status'] ?? 'OPEN';
    final ownerName = item['owner']?['name'] ?? '';
    final dueDate = item['dueDate'] ?? '';

    final statusColor = _actionStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text('#$idx',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              StatusBadge(label: status, color: statusColor),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(desc,
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline_rounded,
                  size: 14, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(ownerName,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textTertiary)),
              if (dueDate.isNotEmpty) ...[
                const SizedBox(width: 12),
                Icon(Icons.calendar_today_rounded,
                    size: 12, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(_fmtDate(dueDate),
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textTertiary)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _actionStatusColor(String status) {
    switch (status) {
      case 'OPEN':
        return AppColors.open;
      case 'IN_PROGRESS':
        return AppColors.secondary;
      case 'DONE':
        return AppColors.resolved;
      case 'BLOCKED':
        return AppColors.urgent;
      case 'DROPPED':
        return AppColors.textTertiary;
      default:
        return AppColors.primary;
    }
  }

  String _fmtDateTime(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '';
    }
  }
}
