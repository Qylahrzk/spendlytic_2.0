class CurrencyService {
  static final Map<String, double> _conversionRates = {
    'MYR (RM)': 1.0,
    'USD (\$)': 0.21,
    'EUR (€)': 0.19,
    'JPY (¥)': 32.5,
  };

  static Map<String, double> get conversionRates => _conversionRates;

  static double convert({
    required double amountInMYR,
    required String targetCurrency,
  }) {
    final rate = _conversionRates[targetCurrency] ?? 1.0;
    return amountInMYR * rate;
  }

  double convertAmount(double amountInMYR, String targetCurrency) {
    switch (targetCurrency) {
      case 'USD (\$)':
        return amountInMYR * 0.21;
      case 'EUR (€)':
        return amountInMYR * 0.19;
      case 'JPY (¥)':
        return amountInMYR * 32.5;
      default:
        return amountInMYR;
    }
  }

  static String getSymbol(String currency) {
    switch (currency) {
      case 'USD (\$)':
        return '\$';
      case 'EUR (€)':
        return '€';
      case 'JPY (¥)':
        return '¥';
      default:
        return 'RM';
    }
  }
}
