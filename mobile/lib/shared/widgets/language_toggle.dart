import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/i18n/locale_cubit.dart';
import '../../core/theme/app_colors.dart';

class LanguageToggle extends StatelessWidget {
  final bool compact;
  const LanguageToggle({super.key, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<LocaleCubit>();
    final isMarathi = cubit.isMarathi;

    return GestureDetector(
      onTap: () => cubit.toggle(),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chip('EN', !isMarathi),
            _chip('MR', isMarathi),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool active) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        gradient: active ? AppColors.primaryGradient : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : AppColors.textTertiary,
        ),
      ),
    );
  }
}
