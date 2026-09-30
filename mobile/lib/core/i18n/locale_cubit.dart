import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(const Locale('en')) {
    _loadSaved();
  }

  bool get isMarathi => state.languageCode == 'mr';

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_locale');
    if (saved != null) emit(Locale(saved));
  }

  void setLocale(Locale locale) async {
    emit(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale.languageCode);
  }

  void toggle() {
    setLocale(isMarathi ? const Locale('en') : const Locale('mr'));
  }
}
