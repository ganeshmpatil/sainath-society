/// Backend connection settings. Mirrors the website's `VITE_API_URL` default.
/// Override at build time with: `--dart-define=API_BASE_URL=...`.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://sainath-society.onrender.com/api/v1',
  );
}
