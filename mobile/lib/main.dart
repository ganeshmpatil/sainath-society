import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_bloc.dart';
import 'core/auth/auth_event.dart';
import 'core/i18n/locale_cubit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  api.init();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LocaleCubit()),
        BlocProvider(create: (_) => AuthBloc()..add(const AuthCheckRequested())),
      ],
      child: const SainathSocietyApp(),
    ),
  );
}
