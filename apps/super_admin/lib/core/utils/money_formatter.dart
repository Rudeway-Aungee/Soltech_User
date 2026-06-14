import '../constants/app_constants.dart';

class MoneyFormatter {
  static String kina(dynamic value) {
    final amount = double.tryParse(value.toString()) ?? 0;
    return '${AppConstants.currencySymbol}${amount.toStringAsFixed(2)}';
  }
}