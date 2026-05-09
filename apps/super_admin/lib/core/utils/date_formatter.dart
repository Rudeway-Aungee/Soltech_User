class DateFormatter {
  static String fromMilliseconds(dynamic value) {
    final int? milliseconds = int.tryParse(value.toString());

    if (milliseconds == null || milliseconds <= 0) {
      return 'Not available';
    }

    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);

    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}