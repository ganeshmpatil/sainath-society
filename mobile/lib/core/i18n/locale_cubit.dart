import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(const Locale('en'));

  bool get isMarathi => state.languageCode == 'mr';

  void setLocale(Locale locale) => emit(locale);

  void toggle() {
    emit(isMarathi ? const Locale('en') : const Locale('mr'));
  }
}
