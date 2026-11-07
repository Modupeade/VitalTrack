import 'package:intl/intl.dart';

/// Centralized currency formatter for consistent display across the app
class CurrencyFormatter {
  // Private constructor to prevent instantiation
  CurrencyFormatter._();

  /// Default currency code for the app
  static const String defaultCurrencyCode = 'USD';

  /// Default locale for currency formatting
  static const String defaultLocale = 'en_US';

  /// Format a price amount with consistent USD formatting
  ///
  /// Examples:
  /// - formatUSD(4.99) returns "$4.99"
  /// - formatUSD(160) returns "$160.00"
  /// - formatUSD(38.99) returns "$38.99"
  static String formatUSD(double amount) {
    final formatter = NumberFormat.currency(
      locale: defaultLocale,
      symbol: '\$',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Format a price amount with currency code (for API/backend use)
  ///
  /// Examples:
  /// - formatWithCode(4.99) returns "4.99 USD"
  /// - formatWithCode(160) returns "160.00 USD"
  static String formatWithCode(double amount) {
    final formatter = NumberFormat.currency(
      locale: defaultLocale,
      symbol: '',
      decimalDigits: 2,
    );
    return '${formatter.format(amount).trim()} $defaultCurrencyCode';
  }

  /// Parse a price string to double
  /// Handles various formats: "$4.99", "4.99", "4.99 USD"
  static double? parsePrice(String price) {
    try {
      // Remove currency symbols and codes
      String cleanPrice = price
          .replaceAll('\$', '')
          .replaceAll('USD', '')
          .replaceAll(',', '')
          .trim();
      return double.parse(cleanPrice);
    } catch (e) {
      return null;
    }
  }
}

/// Pricing constants for the app
class AppPricing {
  AppPricing._();

  // Subscription pricing
  static const double monthlySubscription = 4.99;
  static const double annualSubscription = 38.99;

  // Consultation pricing
  static const double secondOpinionConsultation = 160.00;
  static const double followUpConsultation = 130.00;

  // Formatted prices for display
  static String get monthlyPrice => CurrencyFormatter.formatUSD(monthlySubscription);
  static String get annualPrice => CurrencyFormatter.formatUSD(annualSubscription);
  static String get secondOpinionPrice => CurrencyFormatter.formatUSD(secondOpinionConsultation);
  static String get followUpPrice => CurrencyFormatter.formatUSD(followUpConsultation);

  // Calculate savings
  static double get annualSavingsPercent {
    final monthlyYearlyCost = monthlySubscription * 12;
    final savings = monthlyYearlyCost - annualSubscription;
    return (savings / monthlyYearlyCost) * 100;
  }

  static String get annualSavingsText {
    return 'Save ${annualSavingsPercent.round()}%';
  }
}
