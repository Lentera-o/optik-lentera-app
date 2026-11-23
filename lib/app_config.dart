/// Konfigurasi koneksi backend OPTIK LENTERA.
class AppConfig {
  AppConfig._();

  static const String appsScriptUrl =
      'https://script.google.com/macros/s/AKfycbxmsqzBvZyF36NernbNuG9nV3EC3BbuoBENuu868_ORjwzONT_W_AzNF-os99Q9Org/exec';

  // App access key is injected by the release workflow; no Google login UI.
  static const String appApiKey = String.fromEnvironment('OL_APP_API_KEY');

  static const Duration apiTimeout = Duration(seconds: 90);
}
