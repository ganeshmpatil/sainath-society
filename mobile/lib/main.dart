import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_bloc.dart';
import 'core/auth/auth_event.dart';
import 'core/i18n/locale_cubit.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/theme/theme_cubit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  api.init();

  // Initialize Firebase (wrapped in try-catch for devices without Google Play Services)
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (_) {
    // Firebase not available — app works without push notifications
  }

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LocaleCubit()),
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => AuthBloc()..add(const AuthCheckRequested())),
      ],
      child: const AanganApp(),
    ),
  );
}
