import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheck);
    on<AuthLoginRequested>(_onLogin);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onCheck(AuthCheckRequested event, Emitter<AuthState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      emit(const Unauthenticated());
      return;
    }

    api.setAccessToken(token);
    try {
      final response = await api.get('/auth/me');
      final user = UserInfo.fromJson(response.data);
      emit(Authenticated(user: user, accessToken: token));
    } catch (_) {
      await prefs.remove('access_token');
      api.setAccessToken(null);
      emit(const Unauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    try {
      final response = await api.post('/auth/login', data: {
        'email': event.email,
        'password': event.password,
      });

      final token = response.data['accessToken'] as String;
      final user = UserInfo.fromJson(response.data['user']);

      api.setAccessToken(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);

      emit(Authenticated(user: user, accessToken: token));
    } catch (e) {
      String message = 'Login failed';
      if (e is DioException && e.response?.data is Map) {
        message = (e.response!.data as Map)['error']?.toString() ?? message;
      }
      emit(AuthError(message));
      emit(const Unauthenticated());
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    try {
      await api.post('/auth/logout');
    } catch (_) {}

    api.setAccessToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    emit(const Unauthenticated());
  }
}
