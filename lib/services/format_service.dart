import 'package:intl/intl.dart';

class FormatService {
  static final _decimalFormat = NumberFormat('#,##0.0', 'en_US');
  static final _integerFormat = NumberFormat('#,##0', 'en_US');
  static final _currencyFormat = NumberFormat.currency(
    symbol: '₦',
    decimalDigits: 0,
  );

  /// Formats a number with one decimal place and thousand separators.
  /// Example: 1234.5 -> 1,234.5
  static String formatDecimal(double? value) {
    if (value == null) return '0.0';
    return _decimalFormat.format(value);
  }

  /// Formats an integer with thousand separators.
  /// Example: 1234 -> 1,234
  static String formatInteger(num? value) {
    if (value == null) return '0';
    return _integerFormat.format(value);
  }

  /// Formats a value as currency (Naira).
  /// Example: 1234 -> ₦1,234
  static String formatCurrency(num? value) {
    if (value == null) return '₦0';
    return _currencyFormat.format(value);
  }
}
