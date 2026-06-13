import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_bloc.dart';
import '../../core/auth/auth_event.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/gradient_button.dart';

class ChangePasswordScreen extends StatefulWidget {
  /// When true, the user was forced here after login (must_change_password).
  /// Back navigation is disabled and they must set a new password.
  final bool forced;

  const ChangePasswordScreen({super.key, this.forced = false});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);

    if (_currentCtrl.text.isEmpty || _newCtrl.text.isEmpty || _confirmCtrl.text.isEmpty) {
      _snack(l.t('changePassword.allFieldsRequired'));
      return;
    }
    if (_newCtrl.text.length < 8) {
      _snack(l.t('changePassword.minLength'));
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      _snack(l.t('changePassword.mismatch'));
      return;
    }
    if (_newCtrl.text == _currentCtrl.text) {
      _snack(l.t('changePassword.sameAsOld'));
      return;
    }

    setState(() => _saving = true);
    try {
      await api.put('/auth/password', data: {
        'currentPassword': _currentCtrl.text,
        'newPassword': _newCtrl.text,
      });

      if (!mounted) return;

      _snack(l.t('changePassword.success'), isError: false);

      if (widget.forced) {
        // Re-login to get fresh token without mustChangePassword flag
        context.read<AuthBloc>().add(const AuthCheckRequested());
        // Small delay for snackbar visibility then navigate home
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) context.go('/');
      } else {
        context.pop();
      }
    } catch (e) {
      String message = l.t('common.error');
      if (e is DioException && e.response?.data is Map) {
        message = (e.response!.data as Map)['error']?.toString() ?? message;
      }
      _snack(message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.urgent : AppColors.resolved,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    if (!widget.forced)
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Icon(Icons.arrow_back_ios_rounded,
                            size: 20, color: AppColors.textSecondary),
                      ),
                    if (!widget.forced) const SizedBox(width: 12),
                    Text(l.t('changePassword.title'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),

                if (widget.forced) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.urgentBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.urgent.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.urgent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.t('changePassword.forcedMessage'),
                            style: const TextStyle(fontSize: 12, color: AppColors.urgent),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 16),

                // Current password
                _label(l.t('changePassword.currentPassword')),
                const SizedBox(height: 6),
                _passwordField(
                  controller: _currentCtrl,
                  obscure: _obscureCurrent,
                  onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  hint: l.t('changePassword.enterCurrent'),
                ),
                const SizedBox(height: 20),

                // New password
                _label(l.t('changePassword.newPassword')),
                const SizedBox(height: 6),
                _passwordField(
                  controller: _newCtrl,
                  obscure: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                  hint: l.t('changePassword.enterNew'),
                ),
                const SizedBox(height: 20),

                // Confirm password
                _label(l.t('changePassword.confirmPassword')),
                const SizedBox(height: 6),
                _passwordField(
                  controller: _confirmCtrl,
                  obscure: _obscureConfirm,
                  onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  hint: l.t('changePassword.enterConfirm'),
                ),
                const SizedBox(height: 32),

                GradientButton(
                  label: l.t('changePassword.submit'),
                  isLoading: _saving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
      );

  Widget _passwordField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppColors.textTertiary),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            size: 20,
            color: AppColors.textTertiary,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
