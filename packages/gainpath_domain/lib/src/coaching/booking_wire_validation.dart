/// Internal validation shared by the transport-independent booking contracts.
const bookingMaximumMillis = 8639999996400000;
const bookingSlotMillis = 1800000;

Never invalidBookingData() => throw const FormatException(
    'Unsupported booking data. Refresh or request authorized review.');

void bookingShape(Map<String, dynamic> data, List<String> required,
    [List<String> optional = const []]) {
  if (required.any((key) => !data.containsKey(key)) ||
      data.keys
          .any((key) => !required.contains(key) && !optional.contains(key))) {
    invalidBookingData();
  }
}

void bookingVersion(dynamic value) {
  if (value is! int || value != 1) {
    invalidBookingData();
  }
}

String bookingId(dynamic value) {
  if (value is! String || !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value)) {
    invalidBookingData();
  }
  return value;
}

int bookingInt(dynamic value, {int min = 1, int max = bookingMaximumMillis}) {
  if (value is! int || value < min || value > max) {
    invalidBookingData();
  }
  return value;
}

int bookingDuration(dynamic value) {
  if (value is! int || (value != 30 && value != 60)) {
    invalidBookingData();
  }
  return value;
}

String bookingText(dynamic value, {int max = 100, bool multiline = false}) {
  final pattern = multiline
      ? RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]')
      : RegExp(r'[\x00-\x1F\x7F]');
  if (value is! String ||
      value.trim().isEmpty ||
      value.length > max ||
      pattern.hasMatch(value)) {
    invalidBookingData();
  }
  return value;
}

String bookingTimeZone(dynamic value) {
  final zone = bookingText(value);
  if (!RegExp(r'^[A-Za-z][A-Za-z0-9_+\-]*(/[A-Za-z0-9_+\-]+)*$')
      .hasMatch(zone)) {
    invalidBookingData();
  }
  return zone;
}

String bookingDate(dynamic value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    invalidBookingData();
  }
  final date = DateTime.tryParse('${value}T00:00:00Z');
  if (date == null || date.toIso8601String().substring(0, 10) != value) {
    invalidBookingData();
  }
  return value;
}

Map<String, dynamic> bookingMap(dynamic value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    invalidBookingData();
  }
  return Map<String, dynamic>.from(value);
}

List<T> bookingList<T>(dynamic value, T Function(dynamic) parse,
    {required int max}) {
  if (value is! List || value.length > max) {
    invalidBookingData();
  }
  return List<T>.unmodifiable(value.map(parse));
}

void bookingInterval(int start, int end, int duration) {
  bookingInt(start);
  bookingInt(end);
  bookingDuration(duration);
  if (start % bookingSlotMillis != 0 || end - start != duration * 60000) {
    invalidBookingData();
  }
}
