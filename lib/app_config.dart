/// Konfigurasi koneksi backend OPTIK LENTERA.
class AppConfig {
  AppConfig._();

  static const String appsScriptUrl =
      'https://script.google.com/macros/s/AKfycbz6LykoZH9w3LM9elrD5qRhDrEpPWfiK2vb1WYrAD9b-m1NIwLMfkph82EOFRrSZY4/exec';

  // Set with --dart-define=OL_GOOGLE_WEB_CLIENT_ID=<OAuth Web client ID>.
  static const String googleWebClientId =
      String.fromEnvironment('OL_GOOGLE_WEB_CLIENT_ID');

  static const Duration apiTimeout = Duration(seconds: 25);
}
