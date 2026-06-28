import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String formatCurrency(num amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_NP',
      symbol: 'Rs. ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  static String formatDate(DateTime date) {
    return DateFormat.yMMMd().format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat.jm().format(date);
  }

  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} at ${formatTime(date)}';
  }
}
