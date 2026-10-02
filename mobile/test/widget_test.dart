// Smoke test: the app boots and lands on the login screen (unauthenticated).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:aangan/app/app.dart';
import 'package:aangan/core/auth/auth_bloc.dart';
import 'package:aangan/core/i18n/locale_cubit.dart';

void main() {
  testWidgets('boots to login when unauthenticated', (tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => LocaleCubit()),
          BlocProvider(create: (_) => AuthBloc()),
        ],
        child: const AanganApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(TextField), findsWidgets);
  });
}
