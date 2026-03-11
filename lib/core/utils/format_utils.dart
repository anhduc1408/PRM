import 'package:intl/intl.dart';

class FormatUtils {
  FormatUtils._();

  static final _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  static final _numberFormat = NumberFormat('#,###', 'vi_VN');

  static String formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  static String formatNumber(num value) {
    return _numberFormat.format(value);
  }

  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy', 'vi').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('HH:mm dd/MM/yyyy', 'vi').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm', 'vi').format(date);
  }

  static String formatShortDate(DateTime date) {
    return DateFormat('dd/MM', 'vi').format(date);
  }

  static String formatDayOfWeek(DateTime date) {
    const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return days[date.weekday - 1];
  }

  static String formatMonth(DateTime date) {
    return DateFormat('MM/yyyy', 'vi').format(date);
  }
}
