import 'dart:typed_data';
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
import '../../shared/widgets/filter_chips_row.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/module_screen.dart';

// ─── Photo cache ──────────────────────────────────────────────────
// Simple in-memory cache so photos aren't re-fetched on every scroll/rebuild.
final Map<String, Uint8List?> _photoCache = {};
final Set<String> _photoLoading = {};

Future<Uint8List?> _loadPhoto(String memberId) async {
  if (_photoCache.containsKey(memberId)) return _photoCache[memberId];
  if (_photoLoading.contains(memberId)) return null;
  _photoLoading.add(memberId);
  try {
    final res = await api.getBytes('/residents/$memberId/photo');
    final bytes = Uint8List.fromList(res.data ?? []);
    _photoCache[memberId] = bytes.isNotEmpty ? bytes : null;
  } catch (_) {
    _photoCache[memberId] = null;
  }
  _photoLoading.remove(memberId);
  return _photoCache[memberId];
}

// ─── Screen ───────────────────────────────────────────────────────

class ResidentsScreen extends StatelessWidget {
  const ResidentsScreen({super.key});
  @override Widget build(BuildContext context) => BlocProvider(
    create: (_) => ListCubit(endpoint: '/residents', listKey: 'residents')..load(),
    child: const _RV(),
  );
}

class _RV extends StatefulWidget {
  const _RV();
  @override State<_RV> createState() => _RVS();
}

class _RVS extends State<_RV> {
  int _fi = 0;
  String _search = '';
  @override Widget build(BuildContext context) {
    final l = AppLocalizations.of(context); context.watch<LocaleCubit>();
    final authState = context.watch<AuthBloc>().state;
    final isAdmin = authState is Authenticated && authState.user.isAdmin;
    return Scaffold(
      floatingActionButton: isAdmin ? FloatingActionButton(
        onPressed: () => _showAddResident(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add_rounded, color: Colors.white),
      ) : null,
      body: SafeArea(child: RefreshIndicator(
      onRefresh: () { _photoCache.clear(); return context.read<ListCubit>().load(); },
      color: AppColors.primary,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 4), child: Row(children: [
          GestureDetector(onTap: () { if (context.canPop()) context.pop(); else context.go('/more'); },
              child: Icon(Icons.arrow_back_ios_rounded, size: 20, color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.t('residents.title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            BlocBuilder<ListCubit, ListData>(builder: (_, s) => Text('${s.count} ${l.t('residents.members')}',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary))),
          ])),
        ]))),
        SliverToBoxAdapter(child: Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: TextField(
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            decoration: InputDecoration(hintText: l.t('residents.searchHint'),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textTertiary),
              border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none)),
        )),
        BlocBuilder<ListCubit, ListData>(builder: (context, state) {
          if (state.loading) return const SliverToBoxAdapter(child: ShimmerLoading());
          // Extract unique wings from data
          final wingSet = <String>{};
          for (final r in state.items) {
            final w = r['flat']?['wing']?['name'] ?? '';
            if (w.toString().isNotEmpty) wingSet.add(w.toString());
          }
          final wings = wingSet.toList()..sort();
          final labels = [l.t('residents.allWings'), ...wings];
          if (_fi >= labels.length) _fi = 0;
          return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.only(bottom: 12), child: FilterChipsRow(
            labels: labels, selectedIndex: _fi,
            onSelected: (i) => setState(() => _fi = i))));
        }),
        BlocBuilder<ListCubit, ListData>(builder: (context, state) {
          if (state.loading) return const SliverToBoxAdapter(child: ShimmerLoading());
          final wingSet = <String>{};
          for (final r in state.items) {
            final w = r['flat']?['wing']?['name'] ?? '';
            if (w.toString().isNotEmpty) wingSet.add(w.toString());
          }
          final wings = wingSet.toList()..sort();
          var items = state.items;
          if (_fi > 0 && _fi <= wings.length) {
            final selectedWing = wings[_fi - 1];
            items = items.where((r) {
              final wing = r['flat']?['wing']?['name'] ?? '';
              return wing == selectedWing;
            }).toList(); }
          if (_search.isNotEmpty) {
            items = items.where((r) {
              final name = (r['name'] ?? '').toString().toLowerCase();
              final flat = (r['flat']?['flatNumber'] ?? '').toString().toLowerCase();
              return name.contains(_search) || flat.contains(_search);
            }).toList();
          }
          if (items.isEmpty) return SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(40),
              child: Center(child: Text(l.t('common.noRecords'), style: TextStyle(color: AppColors.textTertiary)))));
          return SliverList(delegate: SliverChildBuilderDelegate((ctx, i) => _RC(r: items[i]), childCount: items.length));
        }),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    )));
  }

  void _showAddResident(BuildContext ctx) {
    final l = AppLocalizations.of(ctx);
    final cubit = ctx.read<ListCubit>();
    showDialog(
      context: ctx,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: _AddResidentForm(l: l, onSaved: () {
          _photoCache.clear();
          cubit.load();
        }),
      ),
    );
  }
}

// ─── Resident Card ────────────────────────────────────────────────

class _RC extends StatelessWidget {
  final Map<String, dynamic> r;
  const _RC({required this.r});
  @override Widget build(BuildContext context) {
    final name = r['name'] ?? ''; final flat = r['flat']?['flatNumber'] ?? '';
    final role = r['role'] ?? 'MEMBER'; final desg = r['designation'] ?? '';
    final hasPhoto = r['hasPhoto'] == true;
    final memberId = r['id'] ?? '';

    return GlassCard(child: Row(children: [
      _PhotoAvatar(name: name, memberId: memberId, hasPhoto: hasPhoto),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text([flat, role == 'ADMIN' ? 'Admin' : 'Owner', if (desg.isNotEmpty) desg].join(' • '),
            style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
      ])),
      GestureDetector(
        onTap: () {
          final phone = r['mobile'] ?? '';
          if (phone.isNotEmpty) launchUrl(Uri.parse('tel:$phone'));
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(26),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.phone_outlined, size: 18, color: AppColors.primary),
        ),
      ),
    ]));
  }
}

// ─── Add Resident Form ───────────────────────────────────────────

class _AddResidentForm extends StatefulWidget {
  final AppLocalizations l;
  final VoidCallback onSaved;
  const _AddResidentForm({required this.l, required this.onSaved});
  @override State<_AddResidentForm> createState() => _AddResidentFormState();
}

class _AddResidentFormState extends State<_AddResidentForm> {
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _wingCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _flatNoCtrl = TextEditingController();
  String _role = 'MEMBER';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _designationCtrl.dispose();
    _wingCtrl.dispose();
    _floorCtrl.dispose();
    _flatNoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    if (name.isEmpty || mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.l.t('common.error'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': name,
        'mobile': mobile,
        'role': _role,
      };
      if (_emailCtrl.text.trim().isNotEmpty) body['email'] = _emailCtrl.text.trim();
      if (_designationCtrl.text.trim().isNotEmpty) body['designation'] = _designationCtrl.text.trim();
      // Build flat number from wing + flat no (e.g. "A-101")
      final wing = _wingCtrl.text.trim();
      final flatNo = _flatNoCtrl.text.trim();
      if (flatNo.isNotEmpty) {
        body['flatNo'] = wing.isNotEmpty ? '$wing-$flatNo' : flatNo;
      }
      await api.post('/residents', data: body);
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.l.t('residents.addSuccess'))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.l.t('common.error')}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.t('residents.addResident'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        _field(l.t('residents.name'), _nameCtrl, Icons.person_rounded),
        const SizedBox(height: 12),
        _field(l.t('residents.mobile'), _mobileCtrl, Icons.phone_rounded, keyboard: TextInputType.phone),
        const SizedBox(height: 12),
        _field(l.t('residents.email'), _emailCtrl, Icons.email_rounded, keyboard: TextInputType.emailAddress, required: false),
        const SizedBox(height: 12),
        // Wing, Floor, Flat Number row
        Row(children: [
          Expanded(child: _field(l.t('residents.wing'), _wingCtrl, Icons.apartment_rounded, required: false)),
          const SizedBox(width: 8),
          Expanded(child: _field(l.t('residents.floor'), _floorCtrl, Icons.layers_rounded, keyboard: TextInputType.number, required: false)),
          const SizedBox(width: 8),
          Expanded(child: _field(l.t('residents.flatNumber'), _flatNoCtrl, Icons.home_rounded, required: false)),
        ]),
        const SizedBox(height: 12),
        // Role
        Text(l.t('residents.role'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Row(children: [
          _roleChip('MEMBER', l.t('residents.roleMember')),
          const SizedBox(width: 8),
          _roleChip('ADMIN', l.t('residents.roleAdmin')),
        ]),
        const SizedBox(height: 12),
        if (_role == 'ADMIN')
          _field(l.t('residents.designation'), _designationCtrl, Icons.badge_rounded, required: false),
        if (_role == 'ADMIN')
          const SizedBox(height: 12),
        // Save button
        SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _saving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(l.t('residents.addResident'), style: const TextStyle(fontWeight: FontWeight.w600)),
        )),
      ])),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, {TextInputType? keyboard, bool required = true}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textTertiary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
  }

  Widget _roleChip(String value, String label) {
    final selected = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(20) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: selected ? AppColors.primary : AppColors.textSecondary,
        )),
      ),
    );
  }
}

// ─── Instagram-style Photo Avatar ─────────────────────────────────

class _PhotoAvatar extends StatefulWidget {
  final String name;
  final String memberId;
  final bool hasPhoto;
  const _PhotoAvatar({required this.name, required this.memberId, required this.hasPhoto});
  @override State<_PhotoAvatar> createState() => _PhotoAvatarState();
}

class _PhotoAvatarState extends State<_PhotoAvatar> {
  Uint8List? _photo;

  @override
  void initState() {
    super.initState();
    if (widget.hasPhoto) _fetchPhoto();
  }

  void _fetchPhoto() async {
    final bytes = await _loadPhoto(widget.memberId);
    if (mounted) setState(() => _photo = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(widget.name);
    final gradientColors = _gradientFor(widget.name);

    // If has photo and loaded, show Instagram-style ring
    if (widget.hasPhoto && _photo != null) {
      return Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 1.5),
          ),
          child: ClipOval(
            child: Image.memory(_photo!, fit: BoxFit.cover, width: 42, height: 42),
          ),
        ),
      );
    }

    // Fallback: gradient initials (existing style, now circular)
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        shape: BoxShape.circle,
      ),
      child: Center(child: Text(initials,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))),
    );
  }

  List<Color> _gradientFor(String name) {
    final sets = [
      [AppColors.primary, AppColors.secondary],
      [AppColors.open, AppColors.primary],
      [AppColors.secondary, AppColors.resolved],
      [AppColors.high, AppColors.medium],
    ];
    return sets[name.hashCode.abs() % sets.length];
  }

  String _initials(String n) {
    final p = n.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    if (p.isNotEmpty && p[0].isNotEmpty) return p[0][0].toUpperCase();
    return '?';
  }
}
