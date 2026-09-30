import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ─── State ────────────────────────────────────────────────────────

class _St extends Equatable {
  final bool loading;
  final List<Map<String, dynamic>> staff;
  const _St({this.loading = false, this.staff = const []});
  @override List<Object?> get props => [loading, staff];
}

class _Cu extends Cubit<_St> {
  _Cu() : super(const _St());
  Future<void> load() async {
    emit(const _St(loading: true));
    try {
      final res = await api.get('/staff');
      final list = (res.data['staff'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      emit(_St(staff: list));
    } catch (_) {
      emit(const _St());
    }
  }
}

// ─── Screen ───────────────────────────────────────────────────────

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => _Cu()..load(), child: const _Body());
  }
}

class _Body extends StatefulWidget {
  const _Body();
  @override State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool get _isAdmin {
    final s = context.read<AuthBloc>().state;
    return s is Authenticated && s.user.role == 'ADMIN';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); context.watch<LocaleCubit>();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('staff.title')),
        actions: [
          if (_isAdmin) IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddStaff(context, l)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<_Cu>().load(),
        child: BlocBuilder<_Cu, _St>(builder: (context, state) {
          if (state.loading) return const ShimmerLoading(itemCount: 5);
          if (state.staff.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.groups, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.staff.length,
            itemBuilder: (_, i) => _StaffCard(staff: state.staff[i], l: l, isAdmin: _isAdmin),
          );
        }),
      ),
      floatingActionButton: _isAdmin ? FloatingActionButton.extended(
        onPressed: () => _showAttendanceSheet(context, l),
        icon: const Icon(Icons.checklist),
        label: Text(l.t('staff.markAttendance')),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ) : null,
    );
  }

  void _showAddStaff(BuildContext context, AppLocalizations l) {
    final nameCtl = TextEditingController();
    final mobileCtl = TextEditingController();
    final salaryCtl = TextEditingController();
    String role = 'SECURITY';
    String staffType = 'PERMANENT';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx2, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx2).viewInsets.bottom + 20),
          child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.textTertiary, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(l.t('staff.addStaff'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(controller: nameCtl, decoration: InputDecoration(labelText: l.t('staff.name'), border: const OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: mobileCtl, decoration: InputDecoration(labelText: l.t('staff.mobile'), border: const OutlineInputBorder()),
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: InputDecoration(labelText: l.t('staff.role'), border: const OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'SECURITY', child: Text('Security / Watchman')),
                  DropdownMenuItem(value: 'SWEEPER', child: Text('Sweeper / Cleaner')),
                  DropdownMenuItem(value: 'PLUMBER', child: Text('Plumber')),
                  DropdownMenuItem(value: 'ELECTRICIAN', child: Text('Electrician')),
                  DropdownMenuItem(value: 'GARDENER', child: Text('Gardener')),
                  DropdownMenuItem(value: 'CLERK', child: Text('Office Clerk')),
                  DropdownMenuItem(value: 'MANAGER', child: Text('Manager')),
                  DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                ],
                onChanged: (v) => setSheetState(() => role = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: staffType,
                decoration: InputDecoration(labelText: l.t('staff.type'), border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: 'PERMANENT', child: Text(l.t('staff.permanent'))),
                  DropdownMenuItem(value: 'CONTRACT', child: Text(l.t('staff.contract'))),
                ],
                onChanged: (v) => setSheetState(() => staffType = v!),
              ),
              const SizedBox(height: 12),
              TextField(controller: salaryCtl,
                  decoration: InputDecoration(labelText: l.t('staff.salary'), border: const OutlineInputBorder(), prefixText: '\u20B9 '),
                  keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: () async {
                  if (nameCtl.text.isEmpty || mobileCtl.text.isEmpty) return;
                  try {
                    await api.post('/staff', data: {
                      'name': nameCtl.text.trim(),
                      'mobile': mobileCtl.text.trim(),
                      'role': role,
                      'staffType': staffType,
                      'monthlySalary': double.tryParse(salaryCtl.text) ?? 0,
                      'joiningDate': DateTime.now().toIso8601String().substring(0, 10),
                    });
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                    if (mounted) context.read<_Cu>().load();
                  } catch (e) {
                    if (sheetCtx.mounted) {
                      ScaffoldMessenger.of(sheetCtx).showSnackBar(
                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                    }
                  }
                },
                child: Text(l.t('common.save')),
              )),
            ],
          )),
        ),
      ),
    );
  }

  void _showAttendanceSheet(BuildContext context, AppLocalizations l) {
    final cubit = context.read<_Cu>();
    final staff = cubit.state.staff;
    if (staff.isEmpty) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final statusMap = <String, String>{};
    for (final s in staff) {
      statusMap[s['id']] = 'PRESENT';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx2, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx2).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.textTertiary, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text('${l.t('staff.attendance')} — $today', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 12),
            Flexible(child: ListView.builder(
              shrinkWrap: true,
              itemCount: staff.length,
              itemBuilder: (_, i) {
                final s = staff[i];
                final id = s['id'] as String;
                return ListTile(
                  dense: true,
                  title: Text(s['name'] ?? '', style: const TextStyle(fontSize: 14)),
                  subtitle: Text(_roleLabel(s['role'] ?? ''), style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  trailing: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'PRESENT', label: Text('P', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: 'HALF_DAY', label: Text('H', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: 'ABSENT', label: Text('A', style: TextStyle(fontSize: 11))),
                      ButtonSegment(value: 'LEAVE', label: Text('L', style: TextStyle(fontSize: 11))),
                    ],
                    selected: {statusMap[id] ?? 'PRESENT'},
                    onSelectionChanged: (v) => setSheetState(() => statusMap[id] = v.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                );
              },
            )),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () async {
                final records = staff.map((s) => {
                  'staffId': s['id'],
                  'status': statusMap[s['id']] ?? 'PRESENT',
                }).toList();
                try {
                  await api.post('/staff/attendance/bulk', data: {'date': today, 'records': records});
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.t('staff.attendanceMarked')), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (sheetCtx.mounted) {
                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
                  }
                }
              },
              child: Text(l.t('staff.saveAttendance')),
            )),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'SECURITY': return 'Security';
      case 'SWEEPER': return 'Sweeper';
      case 'PLUMBER': return 'Plumber';
      case 'ELECTRICIAN': return 'Electrician';
      case 'GARDENER': return 'Gardener';
      case 'CLERK': return 'Office Clerk';
      case 'MANAGER': return 'Manager';
      default: return role;
    }
  }
}

class _StaffCard extends StatelessWidget {
  final Map<String, dynamic> staff;
  final AppLocalizations l;
  final bool isAdmin;
  const _StaffCard({required this.staff, required this.l, required this.isAdmin});

  IconData _roleIcon(String role) {
    switch (role) {
      case 'SECURITY': return Icons.security;
      case 'SWEEPER': return Icons.cleaning_services;
      case 'PLUMBER': return Icons.plumbing;
      case 'ELECTRICIAN': return Icons.electrical_services;
      case 'GARDENER': return Icons.nature;
      case 'CLERK': return Icons.edit_document;
      case 'MANAGER': return Icons.manage_accounts;
      default: return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = staff['name'] ?? '';
    final role = staff['role'] ?? '';
    final mobile = staff['mobile'] ?? '';
    final salary = ((staff['monthlySalary'] ?? 0) as num).toDouble();
    final type = staff['staffType'] ?? 'PERMANENT';
    final shift = '${staff['shiftStart'] ?? ''} - ${staff['shiftEnd'] ?? ''}';
    final active = staff['isActive'] != false;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          CircleAvatar(
            backgroundColor: active ? AppColors.primary.withAlpha(25) : Colors.grey.withAlpha(25),
            radius: 22,
            child: Icon(_roleIcon(role), color: active ? AppColors.primary : Colors.grey, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: type == 'PERMANENT' ? Colors.blue.withAlpha(20) : Colors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(type == 'PERMANENT' ? l.t('staff.permanent') : l.t('staff.contract'),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                        color: type == 'PERMANENT' ? Colors.blue : Colors.orange)),
              ),
            ]),
            const SizedBox(height: 3),
            Text(role, style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.phone, size: 11, color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(mobile, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              if (salary > 0) ...[
                Icon(Icons.currency_rupee, size: 11, color: AppColors.textTertiary),
                Text('${salary.toStringAsFixed(0)}/mo', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ]),
            if (shift.trim().length > 3)
              Text('Shift: $shift', style: TextStyle(fontSize: 10, color: AppColors.textTertiary)),
          ])),
        ]),
      ),
    );
  }
}
