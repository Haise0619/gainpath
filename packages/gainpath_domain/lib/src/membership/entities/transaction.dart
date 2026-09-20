import '../enums/transaction_status.dart';

class Transaction {
  final String id;
  final String type;
  final double amount;
  final DateTime date;
  final TransactionStatus status;
  const Transaction(this.id, this.type, this.amount, this.date, this.status);
}
