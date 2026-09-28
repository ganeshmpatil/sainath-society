import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/status_badge.dart';

// ─── Cubit ────────────────────────────────────────────────────────

class CalendarState {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> todos;
  const CalendarState({this.loading = false, this.error, this.todos = const []});
  CalendarState copyWith({bool? loading, String? error, List<Map<String, dynamic>>? todos}) =>
      CalendarState(loading: loading ?? this.loading, error: error, todos: todos ?? this.todos);
}

class CalendarCubit extends Cubit<CalendarState> {
  CalendarCubit() : super(const CalendarState());

  Future<void> load(int year, int month) async {
    emit(state.copyWith(loading: true));
    try {
      final res = await api.get('/committee-calendar', queryParams: {'year': '$year', 'month': '$month'});
      final list = (res.data['todos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      emit(state.copyWith(loading: false, todos: list));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }
}

// ─── Color helpers ────────────────────────────────────────────────

Color _todoColor(Map<String, dynamic> todo) {
  final status = todo['status'] ?? '';
  if (status == 'COMPLETED') return const Color(0xFF10B981);
  if (status == 'CANCELLED') return const Color(0xFF64748B);
  final dueStr = todo['dueDate'] ?? '';
  if (dueStr.isEmpty) return const Color(0xFF3B82F6);
  final due = DateTime.tryParse(dueStr);
  if (due == null) return const Color(0xFF3B82F6);
  final now = DateTime.now();
  final daysLeft = due.difference(DateTime(now.year, now.month, now.day)).inDays;
  if (daysLeft < 0) return const Color(0xFFEF4444); // overdue — red
  if (daysLeft <= 3) return const Color(0xFFF97316); // due soon — orange
  if (daysLeft <= 7) return const Color(0xFFEAB308); // this week — yellow
  return const Color(0xFF3B82F6); // future — blue
}

IconData _categoryIcon(String cat) {
  switch (cat) {
    case 'AGM': return Icons.groups_rounded;
    case 'SGM': return Icons.people_alt_rounded;
    case 'AUDIT': return Icons.fact_check_rounded;
    case 'INSURANCE': return Icons.health_and_safety_rounded;
    case 'FIRE_SAFETY': return Icons.local_fire_department_rounded;
    case 'TAX_FILING': return Icons.receipt_long_rounded;
    case 'MAINTENANCE_CONTRACT': return Icons.engineering_rounded;
    case 'ELECTION': return Icons.how_to_vote_rounded;
    case 'FESTIVAL': return Icons.celebration_rounded;
    case 'COMPLIANCE': return Icons.gavel_rounded;
    case 'LEGAL': return Icons.balance_rounded;
    default: return Icons.event_note_rounded;
  }
}

// ─── Screen ───────────────────────────────────────────────────────

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final now = DateTime.now();
      return CalendarCubit()..load(now.year, now.month);
    },
    child: const _CalendarView(),
  );
}

class _CalendarView extends StatefulWidget {
  const _CalendarView();
  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  List<Map<String, dynamic>> _todosForDay(DateTime day, List<Map<String, dynamic>> all) {
    return all.where((t) {
      final due = DateTime.tryParse(t['dueDate'] ?? '');
      if (due == null) return false;
      return due.year == day.year && due.month == day.month && due.day == day.day;
    }).toList();
  }

  List<Map<String, dynamic>> _overdueTodos(List<Map<String, dynamic>> all) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return all.where((t) {
      final status = t['status'] ?? '';
      if (status == 'COMPLETED' || status == 'CANCELLED') return false;
      final due = DateTime.tryParse(t['dueDate'] ?? '');
      if (due == null) return false;
      return due.isBefore(today);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.watch<LocaleCubit>();
    final isMr = context.read<LocaleCubit>().isMarathi;
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.role == 'ADMIN';

    return Scaffold(
      body: SafeArea(child: RefreshIndicator(
        onRefresh: () => context.read<CalendarCubit>().load(_focusedDay.year, _focusedDay.month),
        color: AppColors.primary,
        child: BlocBuilder<CalendarCubit, CalendarState>(builder: (context, state) {
          final selected = _todosForDay(_selectedDay, state.todos);
          final overdue = _overdueTodos(state.todos);

          return CustomScrollView(slivers: [
            // Header
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Row(children: [
              GestureDetector(onTap: () => context.pop(),
                  child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.t('calendar.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(l.t('calendar.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              ]),
            ]))),

            // Calendar
            SliverToBoxAdapter(child: Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: TableCalendar(
                firstDay: DateTime(2024, 1, 1),
                lastDay: DateTime(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                onFormatChanged: (fmt) => setState(() => _calendarFormat = fmt),
                onDaySelected: (selected, focused) => setState(() {
                  _selectedDay = selected;
                  _focusedDay = focused;
                }),
                onPageChanged: (focused) {
                  _focusedDay = focused;
                  context.read<CalendarCubit>().load(focused.year, focused.month);
                },
                eventLoader: (day) => _todosForDay(day, state.todos),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(color: AppColors.primary.withAlpha(60), shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  todayTextStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                  selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  defaultTextStyle: TextStyle(color: AppColors.textPrimary),
                  weekendTextStyle: TextStyle(color: AppColors.textSecondary),
                  outsideTextStyle: TextStyle(color: AppColors.textTertiary),
                  markerDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  markersMaxCount: 3,
                  markerSize: 6,
                  markerMargin: const EdgeInsets.symmetric(horizontal: 0.8),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  leftChevronIcon: Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                  rightChevronIcon: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                  weekendStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (ctx, day, events) {
                    if (events.isEmpty) return null;
                    final todos = events.cast<Map<String, dynamic>>();
                    return Row(mainAxisSize: MainAxisSize.min, children: todos.take(3).map((t) =>
                      Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 0.8),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _todoColor(t)))).toList());
                  },
                ),
              ),
            )),

            // Overdue banner
            if (overdue.isNotEmpty)
              SliverToBoxAdapter(child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444).withAlpha(60)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_rounded, size: 20, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${overdue.length} ${l.t('calendar.overdueItems')}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)))),
                ]),
              )),

            // Selected day header
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(DateFormat('d MMMM yyyy').format(_selectedDay),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            )),

            // Loading
            if (state.loading)
              const SliverToBoxAdapter(child: ShimmerLoading()),

            // Task list for selected day
            if (!state.loading && selected.isEmpty)
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(32),
                  child: Center(child: Text(l.t('calendar.noTodosForDay'), style: TextStyle(color: AppColors.textTertiary))))),

            if (!state.loading && selected.isNotEmpty)
              SliverList(delegate: SliverChildBuilderDelegate((ctx, i) {
                final t = selected[i];
                return _TodoCard(todo: t, isMr: isMr, isAdmin: isAdmin, onStatusChanged: () =>
                    context.read<CalendarCubit>().load(_focusedDay.year, _focusedDay.month));
              }, childCount: selected.length)),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ]);
        }),
      )),
      floatingActionButton: isAdmin ? FloatingActionButton(
        onPressed: () => _showAdd(context),
        child: const Icon(Icons.add_rounded, size: 28)) : null,
    );
  }

  void _showAdd(BuildContext ctx) {
    final cubit = ctx.read<CalendarCubit>();
    final l = AppLocalizations.of(ctx);
    String title = '', titleMr = '', desc = '', notes = '';
    String category = 'GENERAL', priority = 'MEDIUM';
    DateTime? dueDate;

    final categories = ['AGM', 'SGM', 'AUDIT', 'INSURANCE', 'FIRE_SAFETY', 'TAX_FILING',
      'MAINTENANCE_CONTRACT', 'ELECTION', 'FESTIVAL', 'COMPLIANCE', 'LEGAL', 'GENERAL'];

    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => StatefulBuilder(builder: (c, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 20),
          Text(l.t('calendar.addTodo'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Title
          TextField(onChanged: (v) => title = v, decoration: InputDecoration(labelText: l.t('calendar.todoTitle'))),
          const SizedBox(height: 12),
          TextField(onChanged: (v) => titleMr = v, decoration: InputDecoration(labelText: l.t('calendar.todoTitleMr'))),
          const SizedBox(height: 12),

          // Category + Priority row
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(initialValue: category, dropdownColor: AppColors.surface,
              decoration: InputDecoration(labelText: l.t('calendar.category')),
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => category = v!)),
            const SizedBox(width: 10),
            Expanded(child: DropdownButtonFormField<String>(initialValue: priority, dropdownColor: AppColors.surface,
              decoration: InputDecoration(labelText: l.t('calendar.priority')),
              items: ['LOW', 'MEDIUM', 'HIGH', 'URGENT'].map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => priority = v!)),
          ]),
          const SizedBox(height: 12),

          // Due date picker
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(context: c, initialDate: DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
              if (picked != null) setSheetState(() => dueDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textTertiary),
                const SizedBox(width: 10),
                Text(dueDate != null ? DateFormat('dd/MM/yyyy').format(dueDate!) : l.t('calendar.selectDueDate'),
                    style: TextStyle(color: dueDate != null ? AppColors.textPrimary : AppColors.textTertiary)),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Description
          TextField(onChanged: (v) => desc = v, maxLines: 2,
            decoration: InputDecoration(labelText: l.t('calendar.description'))),
          const SizedBox(height: 12),

          // Notes
          TextField(onChanged: (v) => notes = v, maxLines: 2,
            decoration: InputDecoration(labelText: l.t('calendar.notes'))),
          const SizedBox(height: 20),

          // Buttons
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
              if (title.isEmpty || dueDate == null) return;
              try {
                await api.post('/committee-calendar', data: {
                  'title': title, 'titleMr': titleMr, 'description': desc, 'notes': notes,
                  'category': category, 'priority': priority,
                  'dueDate': dueDate!.toUtc().toIso8601String(),
                });
                if (c.mounted) Navigator.pop(c);
                cubit.load(_focusedDay.year, _focusedDay.month);
              } catch (_) {}
            })),
          ]),
        ])),
      )),
    );
  }
}

// ─── Todo Card ────────────────────────────────────────────────────

class _TodoCard extends StatelessWidget {
  final Map<String, dynamic> todo;
  final bool isMr;
  final bool isAdmin;
  final VoidCallback onStatusChanged;
  const _TodoCard({required this.todo, required this.isMr, required this.isAdmin, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = (isMr ? todo['titleMr'] : null) ?? todo['title'] ?? '';
    final desc = (isMr ? todo['descriptionMr'] : null) ?? todo['description'] ?? '';
    final category = todo['category'] ?? 'GENERAL';
    final priority = todo['priority'] ?? 'MEDIUM';
    final status = todo['status'] ?? 'PENDING';
    final color = _todoColor(todo);
    final assignee = todo['assignedTo'];
    final assigneeName = assignee != null ? (assignee['name'] ?? '') : '';
    final notes = (isMr ? todo['notesMr'] : null) ?? todo['notes'] ?? '';

    final dueStr = todo['dueDate'] ?? '';
    final due = DateTime.tryParse(dueStr);
    String dueLabel = '';
    if (due != null) {
      final now = DateTime.now();
      final diff = due.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (status == 'COMPLETED') {
        dueLabel = l.t('calendar.completed');
      } else if (diff < 0) {
        dueLabel = '${l.t('calendar.overdue')} (${-diff} ${l.t('calendar.daysAgo')})';
      } else if (diff == 0) {
        dueLabel = l.t('calendar.dueToday');
      } else if (diff == 1) {
        dueLabel = l.t('calendar.dueTomorrow');
      } else {
        dueLabel = '${l.t('calendar.dueIn')} $diff ${l.t('calendar.days')}';
      }
    }

    return GlassCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10)),
          child: Icon(_categoryIcon(category), size: 20, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              decoration: status == 'COMPLETED' ? TextDecoration.lineThrough : null)),
          if (dueLabel.isNotEmpty)
            Text(dueLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
        ])),
        StatusBadge(label: priority, color: _priorityColor(priority)),
      ]),
      if (desc.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(desc, style: TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
      if (notes.isNotEmpty) ...[
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.sticky_note_2_outlined, size: 13, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Expanded(child: Text(notes, style: TextStyle(fontSize: 11, color: AppColors.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ],
      const SizedBox(height: 8),
      Row(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: AppColors.primary.withAlpha(20), borderRadius: BorderRadius.circular(6)),
          child: Text(category.replaceAll('_', ' '), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary))),
        if (assigneeName.isNotEmpty) ...[
          const SizedBox(width: 8),
          Icon(Icons.person_outline_rounded, size: 13, color: AppColors.textTertiary),
          const SizedBox(width: 3),
          Text(assigneeName, style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ],
        const Spacer(),
        if (isAdmin && status != 'COMPLETED' && status != 'CANCELLED')
          _StatusActions(todoId: todo['id'], status: status, onChanged: onStatusChanged),
      ]),
    ]));
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'URGENT': return const Color(0xFFEF4444);
      case 'HIGH': return const Color(0xFFF97316);
      case 'MEDIUM': return const Color(0xFFEAB308);
      default: return const Color(0xFF10B981);
    }
  }
}

class _StatusActions extends StatelessWidget {
  final dynamic todoId;
  final String status;
  final VoidCallback onChanged;
  const _StatusActions({required this.todoId, required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textTertiary),
      color: AppColors.surface,
      onSelected: (newStatus) async {
        try {
          await api.patch('/committee-calendar/$todoId/status', data: {'status': newStatus});
          onChanged();
        } catch (_) {}
      },
      itemBuilder: (_) {
        final items = <PopupMenuEntry<String>>[];
        if (status == 'PENDING') {
          items.add(const PopupMenuItem(value: 'IN_PROGRESS', child: Text('Start Progress')));
        }
        if (status == 'PENDING' || status == 'IN_PROGRESS') {
          items.add(const PopupMenuItem(value: 'COMPLETED', child: Text('Mark Completed')));
        }
        items.add(const PopupMenuItem(value: 'CANCELLED', child: Text('Cancel')));
        return items;
      },
    );
  }
}
