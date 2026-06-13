import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/gradient_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 0;
  final _flat = TextEditingController();
  final _mobile = TextEditingController();
  final _otp = TextEditingController();

  @override
  void dispose() {
    _flat.dispose();
    _mobile.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_step > 0) {
                        setState(() => _step--);
                      } else {
                        context.go('/login');
                      }
                    },
                    child: Icon(Icons.arrow_back_ios_rounded,
                        color: AppColors.textSecondary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(l.t('common.register'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: i <= _step ? AppColors.primaryGradient : null,
                        color: i > _step ? AppColors.border : null,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              if (_step == 0) ...[
                Text(l.t('register.verifyMembership'),
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                _label(l.t('register.wingTower')),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(hintText: l.t('register.selectWing')),
                  items: ['A', 'B', 'C', 'D', 'E', 'E1', 'F']
                      .map((w) => DropdownMenuItem(value: w, child: Text('Wing $w')))
                      .toList(),
                  onChanged: (_) {},
                  dropdownColor: AppColors.surface,
                ),
                const SizedBox(height: 16),
                _label(l.t('flatDetails.flatNumber')),
                const SizedBox(height: 6),
                TextField(
                  controller: _flat,
                  decoration: const InputDecoration(hintText: 'e.g. A-101'),
                ),
                const SizedBox(height: 16),
                _label(l.t('auth.mobile')),
                const SizedBox(height: 6),
                TextField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '+91 XXXXX XXXXX',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20, color: AppColors.textTertiary),
                  ),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: l.t('register.sendOtp'),
                  onPressed: () => setState(() => _step = 1),
                ),
              ],
              if (_step == 1) ...[
                Text(l.t('register.enterOtp'),
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                _label('OTP'),
                const SizedBox(height: 6),
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(hintText: '- - - - - -'),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: l.t('register.verifyOtp'),
                  onPressed: () => setState(() => _step = 2),
                ),
              ],
              if (_step == 2) ...[
                Text(l.t('register.setPassword'),
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                _label(l.t('auth.email')),
                const SizedBox(height: 6),
                const TextField(
                  decoration: InputDecoration(hintText: 'your.email@example.com'),
                ),
                const SizedBox(height: 16),
                _label(l.t('auth.password')),
                const SizedBox(height: 6),
                const TextField(
                  obscureText: true,
                  decoration: InputDecoration(hintText: 'Min 8 characters'),
                ),
                const SizedBox(height: 24),
                GradientButton(
                  label: l.t('auth.createAccount'),
                  onPressed: () => context.go('/login'),
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  l.t('register.flatNotListed'),
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary, height: 1.6),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l.t('auth.haveAccount'),
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: Text(l.t('auth.loginHere'),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
      );
}
