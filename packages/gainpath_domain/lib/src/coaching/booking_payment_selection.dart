import 'booking_payment.dart';
import 'booking_payment_methods.dart';

class BookingPaymentChoice {
  const BookingPaymentChoice(this.category, this.code, this.name, this.iconKey);
  final String category, code, name, iconKey;
  String get categoryLabel => switch (category) {
        'fpx' => 'Online Banking',
        'ewallet' => 'E-Wallet',
        _ => 'Card'
      };
  factory BookingPaymentChoice.fromJson(Map<String, dynamic> json) {
    final match =
        bookingPaymentChoices.where((m) => m.code == json['code']).firstOrNull;
    if (match == null ||
        match.category != json['category'] ||
        match.name != json['name'] ||
        match.iconKey != json['iconKey']) {
      throw const FormatException('Invalid payment choice');
    }
    return match;
  }
}

/// Display preferences only; the hosted provider determines the actual rail.
const bookingPaymentChoices = <BookingPaymentChoice>[
  BookingPaymentChoice('fpx', 'maybank2u', 'Maybank2u', 'maybank'),
  BookingPaymentChoice('fpx', 'cimbclicks', 'CIMB Clicks', 'cimb'),
  BookingPaymentChoice('fpx', 'publicbank', 'Public Bank', 'public_bank'),
  BookingPaymentChoice('fpx', 'rhb', 'RHB', 'rhb'),
  BookingPaymentChoice('fpx', 'hongleong', 'Hong Leong Bank', 'hong_leong'),
  BookingPaymentChoice('fpx', 'bankislam', 'Bank Islam', 'bank_islam'),
  BookingPaymentChoice('fpx', 'ambank', 'AmBank', 'ambank'),
  BookingPaymentChoice('fpx', 'bsn', 'BSN', 'bsn'),
  BookingPaymentChoice('fpx', 'affin', 'Affin Bank', 'affin'),
  BookingPaymentChoice('fpx', 'alliance', 'Alliance Bank', 'alliance'),
  BookingPaymentChoice('ewallet', 'tng', 'Touch ’n Go eWallet', 'tng'),
  BookingPaymentChoice('ewallet', 'grabpay', 'GrabPay', 'grabpay'),
  BookingPaymentChoice('ewallet', 'shopeepay', 'ShopeePay', 'shopeepay'),
  BookingPaymentChoice(
      'card', 'visa_mastercard', 'Visa / Mastercard', 'visa_mastercard'),
];

class SelectedBookingPaymentMethod {
  const SelectedBookingPaymentMethod(
      {required this.choice, required this.selectedAt});
  final BookingPaymentChoice choice;
  final int selectedAt;
  String get code => choice.code;
  Map<String, dynamic> toJson() => {
        'selectedPaymentMethodCategory': choice.category,
        'selectedPaymentMethodCode': choice.code,
        'selectedPaymentMethodLabel': choice.name,
        'selectedPaymentMethodIconKey': choice.iconKey,
        'selectedAt': selectedAt
      };
  static SelectedBookingPaymentMethod? fromPaymentJson(
      Map<String, dynamic> json) {
    const keys = [
      'selectedPaymentMethodCategory',
      'selectedPaymentMethodCode',
      'selectedPaymentMethodLabel',
      'selectedPaymentMethodIconKey',
      'selectedAt'
    ];
    if (!keys.any(json.containsKey)) return null;
    final choice = BookingPaymentChoice.fromJson({
      'category': json[keys[0]],
      'code': json[keys[1]],
      'name': json[keys[2]],
      'iconKey': json[keys[3]]
    });
    if (json['selectedAt'] is! int || (json['selectedAt'] as int) < 1) {
      throw const FormatException('Invalid payment selection time');
    }
    return SelectedBookingPaymentMethod(
        choice: choice, selectedAt: json['selectedAt'] as int);
  }
}

/// Additive capability; older gateway selections and invoices stay compatible.
abstract interface class BookingPaymentSelectionRepository {
  Future<BookingPaymentMethods> loadPaymentSelections(String bookingId);
  Future<BookingPaymentView> createWithSelectedPaymentMethod(String bookingId,
      {required String selectedPaymentMethodCode,
      String? quoteToken,
      bool usePremiumVoucher = false});
}
