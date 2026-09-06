enum BookingStatus {
  pending('Pending'),
  confirmed('Confirmed'),
  completed('Completed'),
  cancelled('Cancelled');

  const BookingStatus(this.label);
  final String label;

  static BookingStatus fromLabel(String label) =>
      values.firstWhere((v) => v.label == label);
}
