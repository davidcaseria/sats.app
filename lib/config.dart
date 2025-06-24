class AppConfig {
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.satsapp.link');
  static const String _linkBaseUrl = String.fromEnvironment('LINK_BASE_URL', defaultValue: 'https://satsapp.link');

  static String get apiBaseUrl => _apiBaseUrl;
  static String get linkBaseUrl => _linkBaseUrl;
}
