import 'package:flutter_bloc/flutter_bloc.dart';
import 'app_colors.dart';

class ThemeCubit extends Cubit<AppThemeType> {
  ThemeCubit() : super(AppThemeType.royalGold);

  void setTheme(AppThemeType type) => emit(type);

  void cycle() {
    const order = AppThemeType.values;
    final next = order[(state.index + 1) % order.length];
    emit(next);
  }
}
