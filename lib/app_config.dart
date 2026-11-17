/// Konfigurasi koneksi backend OPTIK LENTERA.
class AppConfig {
  AppConfig._();

  static const String appsScriptUrl =
      'https://script.google.com/macros/s/AKfycbz6LykoZH9w3LM9elrD5qRhDrEpPWfiK2vb1WYrAD9b-m1NIwLMfkph82EOFRrSZY4/exec';

  static const Duration apiTimeout = Duration(seconds: 25);

  /// Inject at build time with --dart-define=OL_API_TOKEN=... .
  static const String apiToken = String.fromEnvironment('OL_API_TOKEN');
  static bool get apiConfigured => apiToken.isNotEmpty;
}
