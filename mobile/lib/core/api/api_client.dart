import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class ApiClient {
  ApiClient._();
  static final instance = ApiClient._();

  late final Dio _dio;
  String? _accessToken;
  Future<bool>? _refreshFuture;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && _accessToken != null) {
          // Try refresh — use shared future to avoid concurrent refresh calls
          try {
            final refreshed = await _doRefresh();
            if (refreshed) {
              error.requestOptions.headers['Authorization'] = 'Bearer $_accessToken';
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            }
          } catch (_) {}
        }
        handler.next(error);
      },
    ));
  }

  /// Ensures only one refresh request runs at a time.
  Future<bool> _doRefresh() {
    _refreshFuture ??= _refreshToken().whenComplete(() => _refreshFuture = null);
    return _refreshFuture!;
  }

  Future<bool> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null) return false;

      final response = await Dio(BaseOptions(baseUrl: ApiConfig.baseUrl)).post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      _accessToken = response.data['accessToken'];
      if (_accessToken != null) {
        await prefs.setString('access_token', _accessToken!);
      }
      final newRefresh = response.data['refreshToken'];
      if (newRefresh != null) {
        await prefs.setString('refresh_token', newRefresh);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  String? get accessToken => _accessToken;

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) {
    return _dio.get(path, queryParameters: queryParams);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }

  Future<Response> postMultipart(String path, {required FormData data, CancelToken? cancelToken, ProgressCallback? onSendProgress}) {
    return _dio.post(path, data: data,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        options: Options(contentType: 'multipart/form-data'));
  }

  Future<Response<List<int>>> getBytes(String path) {
    return _dio.get<List<int>>(path,
        options: Options(responseType: ResponseType.bytes));
  }
}

final api = ApiClient.instance;
