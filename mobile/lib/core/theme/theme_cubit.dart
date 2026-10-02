import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';

class ThemeCubit extends Cubit<AppThemeType> {
  ThemeCubit() : super(AppThemeType.freshEmerald) {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_theme');
    if (saved != null) {
      final type = AppThemeType.values.where((t) => t.name == saved).firstOrNull;
      if (type != null) emit(type);
    }
  }

  void setTheme(AppThemeType type) async {
    emit(type);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', type.name);
  }

  void cycle() {
    const order = AppThemeType.values;
    final next = order[(state.index + 1) % order.length];
    setTheme(next);
  }
}
