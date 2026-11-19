/// Konfigurasi koneksi backend OPTIK LENTERA.
class AppConfig {
  AppConfig._();

  static const String appsScriptUrl =
      'https://script.google.com/macros/s/AKfycbz6LykoZH9w3LM9elrD5qRhDrEpPWfiK2vb1WYrAD9b-m1NIwLMfkph82EOFRrSZY4/exec';

  // App access key is injected by the release workflow; no Google login UI.
  static const String appApiKey = String.fromEnvironment('OL_APP_API_KEY');

  // Retained only so the unused legacy auth helper still compiles.
  static const String googleWebClientId = '';

  static const Duration apiTimeout = Duration(seconds: 25);
}
