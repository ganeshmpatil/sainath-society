import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_event.dart';
import '../../core/auth/auth_state.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/gradient_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthBloc>().state;
    if (state is Authenticated) {
      _nameCtrl.text = state.user.name;
      _emailCtrl.text = state.user.email;
      _phoneCtrl.text = state.user.phone;
    }
    _nameCtrl.addListener(_onChanged);
    _emailCtrl.addListener(_onChanged);
    _phoneCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    final state = context.read<AuthBloc>().state;
    if (state is! Authenticated) return;
    final u = state.user;
    final changed = _nameCtrl.text != u.name ||
        _emailCtrl.text != u.email ||
        _phoneCtrl.text != u.phone;
    if (changed != _changed) setState(() => _changed = changed);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = context.read<AuthBloc>().state;
    if (state is! Authenticated) return;

    setState(() => _saving = true);
    try {
      final patch = <String, dynamic>{};
      if (_nameCtrl.text != state.user.name) patch['name'] = _nameCtrl.text;
      if (_emailCtrl.text != state.user.email) patch['email'] = _emailCtrl.text;
      if (_phoneCtrl.text != state.user.phone) patch['mobile'] = _phoneCtrl.text;

      if (patch.isNotEmpty) {
        await api.put('/residents/${state.user.id}', data: patch);
        // Refresh auth state to pick up updated user info
        if (mounted) {
          context.read<AuthBloc>().add(const AuthCheckRequested());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully'),
              backgroundColor: AppColors.resolved,
            ),
          );
          setState(() => _changed = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppColors.urgent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    context.watch<LocaleCubit>();

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is Authenticated ? state.user : null;

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Icon(Icons.arrow_back_ios_rounded,
                            size: 20, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                      Text(l.t('common.profile'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Avatar
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(
                          _initials(user?.name ?? ''),
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '${user?.flatNumber ?? ''} • ${user?.isAdmin == true ? l.t('common.admin') : l.t('common.member')}',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Name field
                  _label(l.t('profile.name')),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person_outline,
                          size: 20, color: AppColors.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email field
                  _label(l.t('auth.email')),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined,
                          size: 20, color: AppColors.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phone field
                  _label(l.t('auth.mobile')),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.phone_outlined,
                          size: 20, color: AppColors.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Read-only info
                  if (user != null) ...[
                    const SizedBox(height: 16),
                    _readOnlyRow(Icons.shield_outlined, l.t('profile.role'),
                        user.isAdmin ? l.t('common.admin') : l.t('common.member')),
                    if (user.designation.isNotEmpty)
                      _readOnlyRow(Icons.badge_outlined,
                          l.t('profile.designation'), user.designation),
                    _readOnlyRow(Icons.apartment_rounded,
                        l.t('profile.flat'), user.flatNumber),
                  ],

                  const SizedBox(height: 32),

                  // Save button
                  GradientButton(
                    label: l.t('common.save'),
                    isLoading: _saving,
                    onPressed: _changed ? _save : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      );

  Widget _readOnlyRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textTertiary),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textTertiary)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      );

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }
}
