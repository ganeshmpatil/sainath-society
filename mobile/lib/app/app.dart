import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/auth/auth_bloc.dart';
import '../core/i18n/app_localizations.dart';
import '../core/i18n/locale_cubit.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_cubit.dart';
import 'router.dart';
import 'theme.dart';

class SainathSocietyApp extends StatelessWidget {
  const SainathSocietyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleCubit>().state;
    final themeType = context.watch<ThemeCubit>().state;
    final authBloc = context.read<AuthBloc>();

    // Sync static palette so widgets using AppColors.xxx get the right colors
    AppColors.applyTheme(themeType);

    return MaterialApp.router(
      title: 'Sainath Society',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forType(themeType),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: buildRouter(authBloc),
    );
  }
}
