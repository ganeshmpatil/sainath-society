import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_bloc.dart';
import '../core/i18n/app_localizations.dart';
import '../core/i18n/locale_cubit.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/theme_cubit.dart';
import 'router.dart';
import 'theme.dart';

class AanganApp extends StatefulWidget {
  const AanganApp({super.key});

  @override
  State<AanganApp> createState() => _AanganAppState();
}

class _AanganAppState extends State<AanganApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(context.read<AuthBloc>());
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleCubit>().state;
    final themeType = context.watch<ThemeCubit>().state;

    // Sync static palette so widgets using AppColors.xxx get the right colors
    AppColors.applyTheme(themeType);

    return MaterialApp.router(
      title: 'Aangan',
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
      routerConfig: _router,
    );
  }
}
