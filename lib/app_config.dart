/// Konfigurasi koneksi backend OPTIK LENTERA.
class AppConfig {
  AppConfig._();

  static const String appsScriptUrl =
      'https://script.google.com/macros/s/AKfycbxmsqzBvZyF36NernbNuG9nV3EC3BbuoBENuu868_ORjwzONT_W_AzNF-os99Q9Org/exec';

  static const Duration apiTimeout = Duration(seconds: 25);

  /// Inject at build time with --dart-define=OL_API_TOKEN=... .
  static const String apiToken = String.fromEnvironment('OL_API_TOKEN');
  static bool get apiConfigured => apiToken.isNotEmpty;
}
