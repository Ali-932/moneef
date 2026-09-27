class AppSettings {
  const AppSettings({
    required this.currencyCode,
    required this.language,
    required this.isNotificationEnabled,
    required this.isDarkMode,
    required this.exchangeRateApiKey,
  });

  final String currencyCode;
  final String language;
  final bool isNotificationEnabled;
  final bool isDarkMode;
  final String exchangeRateApiKey;

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      currencyCode: json['currency_code'] as String? ?? 'USD',
      language: json['language'] as String? ?? 'en',
      isNotificationEnabled: json['is_notification_enabled'] as bool? ?? false,
      isDarkMode: json['is_dark_mode'] as bool? ?? false,
      exchangeRateApiKey: json['exchange_rate_api_key'] as String? ?? '',
    );
  }
}
