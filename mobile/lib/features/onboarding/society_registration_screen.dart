import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/gradient_button.dart';
import '../../shared/widgets/language_toggle.dart';

class SocietyRegistrationScreen extends StatefulWidget {
  const SocietyRegistrationScreen({super.key});

  @override
  State<SocietyRegistrationScreen> createState() =>
      _SocietyRegistrationScreenState();
}

class _SocietyRegistrationScreenState
    extends State<SocietyRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _societyName = TextEditingController();
  final _societyNameMr = TextEditingController();
  final _regNumber = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _pinCode = TextEditingController();
  final _totalWings = TextEditingController();
  final _totalFlats = TextEditingController();
  final _requesterName = TextEditingController();
  final _requesterPhone = TextEditingController();
  final _requesterEmail = TextEditingController();
  final _requesterDesignation = TextEditingController();

  bool _submitting = false;
  bool _submitted = false;
  String? _requestNo;

  @override
  void dispose() {
    _societyName.dispose();
    _societyNameMr.dispose();
    _regNumber.dispose();
    _address.dispose();
    _city.dispose();
    _pinCode.dispose();
    _totalWings.dispose();
    _totalFlats.dispose();
    _requesterName.dispose();
    _requesterPhone.dispose();
    _requesterEmail.dispose();
    _requesterDesignation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final response = await api.post('/platform/onboarding/submit', data: {
        'societyName': _societyName.text.trim(),
        'societyNameMr': _societyNameMr.text.trim(),
        'registrationNumber': _regNumber.text.trim(),
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'pinCode': _pinCode.text.trim(),
        'totalWings': int.tryParse(_totalWings.text) ?? 0,
        'totalFlats': int.tryParse(_totalFlats.text) ?? 0,
        'requesterName': _requesterName.text.trim(),
        'requesterPhone': _requesterPhone.text.trim(),
        'requesterEmail': _requesterEmail.text.trim(),
        'requesterDesignation': _requesterDesignation.text.trim(),
      });

      setState(() {
        _submitted = true;
        _requestNo = response.data['requestNo'] ?? '';
      });
    } catch (e) {
      String message = 'Submission failed';
      if (e is DioException && e.response?.data is Map) {
        message = (e.response!.data as Map)['error']?.toString() ?? message;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.urgent),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    if (_submitted) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.resolvedBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.check_circle_rounded,
                        size: 40, color: AppColors.resolved),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l.t('onboarding.submitted'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.t('onboarding.submittedDesc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_requestNo != null && _requestNo!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${l.t('onboarding.requestNo')}: $_requestNo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  GradientButton(
                    label: l.t('onboarding.backToLogin'),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        l.t('onboarding.title'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const LanguageToggle(),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  l.t('onboarding.subtitle'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Society Info ───
                      _sectionHeader(l.t('onboarding.societyInfo')),
                      const SizedBox(height: 8),
                      _field(
                        controller: _societyName,
                        label: l.t('onboarding.societyName'),
                        hint: 'Aangan CHS Ltd.',
                        validator: _required,
                      ),
                      _field(
                        controller: _societyNameMr,
                        label: l.t('onboarding.societyNameMr'),
                        hint: 'न्यू साईनाथ सहकारी गृहनिर्माण संस्था',
                      ),
                      _field(
                        controller: _regNumber,
                        label: l.t('onboarding.regNumber'),
                        hint: 'BOM/HSG/1234',
                        validator: _required,
                      ),
                      _field(
                        controller: _address,
                        label: l.t('onboarding.address'),
                        hint: 'Plot 45, Bhandup (W)',
                        maxLines: 2,
                        validator: _required,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              controller: _city,
                              label: l.t('onboarding.city'),
                              hint: 'Mumbai',
                              validator: _required,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              controller: _pinCode,
                              label: l.t('onboarding.pinCode'),
                              hint: '400078',
                              keyboard: TextInputType.number,
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return l.t('common.required');
                                }
                                if (v.length != 6) {
                                  return l.t('onboarding.invalidPin');
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              controller: _totalWings,
                              label: l.t('onboarding.totalWings'),
                              hint: '7',
                              keyboard: TextInputType.number,
                              validator: _requiredNumber,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              controller: _totalFlats,
                              label: l.t('onboarding.totalFlats'),
                              hint: '87',
                              keyboard: TextInputType.number,
                              validator: _requiredNumber,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      // ─── Requester Info ───
                      _sectionHeader(l.t('onboarding.requesterInfo')),
                      const SizedBox(height: 8),
                      _field(
                        controller: _requesterName,
                        label: l.t('onboarding.requesterName'),
                        hint: 'Ganesh Patil',
                        validator: _required,
                      ),
                      _field(
                        controller: _requesterDesignation,
                        label: l.t('onboarding.requesterDesignation'),
                        hint: 'Chairman / Secretary',
                      ),
                      _field(
                        controller: _requesterPhone,
                        label: l.t('onboarding.requesterPhone'),
                        hint: '9876543210',
                        keyboard: TextInputType.phone,
                        validator: _required,
                      ),
                      _field(
                        controller: _requesterEmail,
                        label: l.t('onboarding.requesterEmail'),
                        hint: 'chairman@society.com',
                        keyboard: TextInputType.emailAddress,
                        validator: _required,
                      ),

                      const SizedBox(height: 24),
                      GradientButton(
                        label: l.t('onboarding.submitRequest'),
                        isLoading: _submitting,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboard,
            validator: validator,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }

  String? _required(String? v) {
    if (v == null || v.trim().isEmpty) {
      return AppLocalizations.of(context).t('common.required');
    }
    return null;
  }

  String? _requiredNumber(String? v) {
    if (v == null || v.trim().isEmpty) {
      return AppLocalizations.of(context).t('common.required');
    }
    final n = int.tryParse(v);
    if (n == null || n <= 0) {
      return AppLocalizations.of(context).t('onboarding.invalidNumber');
    }
    return null;
  }
}
