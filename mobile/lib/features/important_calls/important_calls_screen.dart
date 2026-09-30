import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/shimmer_loading.dart';

// ── Cubit ──────────────────────────────────────────────────────────

class _ContactsState {
  final bool loading;
  final String? error;
  final List<Map<String, dynamic>> contacts;
  final List<Map<String, dynamic>> committee;
  const _ContactsState({this.loading = false, this.error, this.contacts = const [], this.committee = const []});
}

class _ContactsCubit extends Cubit<_ContactsState> {
  _ContactsCubit() : super(const _ContactsState());

  Future<void> load() async {
    emit(const _ContactsState(loading: true));
    try {
      final res = await api.get('/emergency-contacts');
      final data = res.data;
      final contacts = (data['contacts'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      final committee = (data['committee'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
      emit(_ContactsState(contacts: contacts, committee: committee));
    } catch (e) {
      emit(_ContactsState(error: e.toString()));
    }
  }
}

// ── Icon mapping ───────────────────────────────────────────────────

IconData _iconForName(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('police')) return Icons.local_police_rounded;
  if (lower.contains('fire')) return Icons.local_fire_department_rounded;
  if (lower.contains('ambulance') || lower.contains('medical')) return Icons.local_hospital_rounded;
  if (lower.contains('women')) return Icons.support_rounded;
  if (lower.contains('plumb')) return Icons.water_damage_rounded;
  if (lower.contains('electric')) return Icons.electrical_services_rounded;
  if (lower.contains('pest')) return Icons.pest_control_rounded;
  if (lower.contains('gas')) return Icons.local_shipping_rounded;
  if (lower.contains('watchm') || lower.contains('security')) return Icons.shield_rounded;
  return Icons.phone_rounded;
}

Color _colorForCategory(String? category) {
  switch (category) {
    case 'EMERGENCY': return const Color(0xFFEF4444);
    case 'UTILITY': return const Color(0xFF06B6D4);
    case 'COMMITTEE': return const Color(0xFF3B82F6);
    default: return const Color(0xFF64748B);
  }
}

// ── Screen ─────────────────────────────────────────────────────────

class ImportantCallsScreen extends StatelessWidget {
  const ImportantCallsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _ContactsCubit()..load(),
    child: const _View(),
  );
}

class _View extends StatelessWidget {
  const _View();

  Future<void> _makeCall(String number) async {
    if (number.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isMr = context.watch<LocaleCubit>().isMarathi;
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<_ContactsCubit>().load(),
          color: AppColors.primary,
          child: BlocBuilder<_ContactsCubit, _ContactsState>(
            builder: (context, state) {
              return CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () { if (context.canPop()) context.pop(); else context.go('/more'); },
                          child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l.t('importantCalls.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text(l.t('importantCalls.subtitle'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                        ]),
                      ]),
                    ),
                  ),

                  if (state.loading)
                    const SliverToBoxAdapter(child: ShimmerLoading()),

                  if (!state.loading && state.error != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(child: Text(l.t('common.error'), style: TextStyle(color: AppColors.textTertiary))),
                      ),
                    ),

                  // Emergency contacts
                  if (!state.loading) ..._buildSection(
                    context, l, isMr, isAdmin,
                    l.t('importantCalls.emergency'),
                    state.contacts.where((c) => c['category'] == 'EMERGENCY').toList(),
                  ),

                  // Utility contacts
                  if (!state.loading) ..._buildSection(
                    context, l, isMr, isAdmin,
                    l.t('importantCalls.utility'),
                    state.contacts.where((c) => c['category'] == 'UTILITY').toList(),
                  ),

                  // Other contacts
                  if (!state.loading) ..._buildSection(
                    context, l, isMr, isAdmin,
                    l.t('importantCalls.other'),
                    state.contacts.where((c) => c['category'] != 'EMERGENCY' && c['category'] != 'UTILITY').toList(),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: () => _showAddEdit(context, l, isMr),
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
    );
  }

  List<Widget> _buildSection(
    BuildContext context, AppLocalizations l, bool isMr, bool isAdmin,
    String title, List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) return [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.5)),
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate((ctx, i) {
          final c = items[i];
          final name = (isMr ? c['nameMr'] : null) ?? c['name'] ?? '';
          final role = (isMr ? c['roleMr'] : null) ?? c['role'] ?? '';
          final phone = c['phone'] ?? '';
          final hasPhone = phone.toString().isNotEmpty;
          final color = _colorForCategory(c['category']);
          final icon = _iconForName(c['name'] ?? '');

          return GlassCard(
            onTap: hasPhone ? () => _makeCall(phone) : null,
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                if (hasPhone)
                  Text(phone, style: TextStyle(fontSize: 13, color: AppColors.textTertiary, fontFamily: 'monospace'))
                else
                  Text(l.t('importantCalls.notConfigured'), style: TextStyle(fontSize: 12, color: AppColors.textTertiary, fontStyle: FontStyle.italic)),
                if (role.isNotEmpty) Text(role, style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ])),
              if (hasPhone)
                GestureDetector(
                  onTap: () => _makeCall(phone),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.call_rounded, size: 18, color: color),
                  ),
                ),
              if (isAdmin) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showAddEdit(context, AppLocalizations.of(context), isMr, existing: c),
                  child: Icon(Icons.edit_rounded, size: 18, color: AppColors.textTertiary),
                ),
              ],
            ]),
          );
        }, childCount: items.length),
      ),
    ];
  }

  void _showAddEdit(BuildContext ctx, AppLocalizations l, bool isMr, {Map<String, dynamic>? existing}) {
    final cubit = ctx.read<_ContactsCubit>();
    final isEdit = existing != null;

    String name = existing?['name'] ?? '';
    String nameMr = existing?['nameMr'] ?? '';
    String phone = existing?['phone'] ?? '';
    String altPhone = existing?['altPhone'] ?? '';
    String role = existing?['role'] ?? '';
    String roleMr = existing?['roleMr'] ?? '';
    String category = existing?['category'] ?? 'UTILITY';

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => StatefulBuilder(builder: (c, setState) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: Text(
              isEdit ? l.t('importantCalls.edit') : l.t('importantCalls.add'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            )),
            if (isEdit)
              GestureDetector(
                onTap: () async {
                  final id = existing['id'];
                  if (id == null) return;
                  try {
                    await api.delete('/emergency-contacts/$id');
                    if (c.mounted) Navigator.pop(c);
                    cubit.load();
                  } catch (_) {}
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.urgentBg, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.delete_rounded, size: 18, color: AppColors.urgent),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          // Category selector
          Wrap(spacing: 8, children: ['EMERGENCY', 'UTILITY', 'OTHER'].map((cat) {
            final selected = category == cat;
            final label = cat == 'EMERGENCY' ? l.t('importantCalls.emergency')
                : cat == 'UTILITY' ? l.t('importantCalls.utility')
                : l.t('importantCalls.other');
            return ChoiceChip(
              label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.textSecondary)),
              selected: selected,
              selectedColor: AppColors.primary,
              onSelected: (_) => setState(() => category = cat),
            );
          }).toList()),
          const SizedBox(height: 16),
          TextField(
            controller: TextEditingController(text: name),
            onChanged: (v) => name = v,
            decoration: InputDecoration(labelText: l.t('importantCalls.nameLabel')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: nameMr),
            onChanged: (v) => nameMr = v,
            decoration: InputDecoration(labelText: l.t('importantCalls.nameMrLabel')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: phone),
            onChanged: (v) => phone = v,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l.t('importantCalls.phoneLabel')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: altPhone),
            onChanged: (v) => altPhone = v,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l.t('importantCalls.altPhoneLabel')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: role),
            onChanged: (v) => role = v,
            decoration: InputDecoration(labelText: l.t('importantCalls.roleLabel')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: roleMr),
            onChanged: (v) => roleMr = v,
            decoration: InputDecoration(labelText: l.t('importantCalls.roleMrLabel')),
          ),
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
            Expanded(child: GradientButton(label: l.t('common.save'), onPressed: () async {
              if (name.isEmpty) return;
              final body = {
                'name': name, 'nameMr': nameMr,
                'phone': phone, 'altPhone': altPhone,
                'role': role, 'roleMr': roleMr,
                'category': category,
              };
              try {
                if (isEdit) {
                  await api.patch('/emergency-contacts/${existing['id']}', data: body);
                } else {
                  await api.post('/emergency-contacts', data: body);
                }
                if (c.mounted) Navigator.pop(c);
                cubit.load();
              } catch (_) {}
            })),
          ]),
        ])),
      )),
    );
  }
}
