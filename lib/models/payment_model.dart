import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String userId;
  final String plan;
  final double amount;
  final String status;
  final String paymentMethod;
  final String transactionId;
  final DateTime createdAt;
  final DateTime expiryDate;

  const PaymentModel({
    required this.id,
    required this.userId,
    required this.plan,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    required this.transactionId,
    required this.createdAt,
    required this.expiryDate,
  });

  PaymentModel copyWith({
    String? id,
    String? userId,
    String? plan,
    double? amount,
    String? status,
    String? paymentMethod,
    String? transactionId,
    DateTime? createdAt,
    DateTime? expiryDate,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      plan: plan ?? this.plan,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionId: transactionId ?? this.transactionId,
      createdAt: createdAt ?? this.createdAt,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      plan: json['plan'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      paymentMethod: json['paymentMethod'] as String? ?? '',
      transactionId: json['transactionId'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      expiryDate: json['expiryDate'] != null
          ? (json['expiryDate'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'plan': plan,
      'amount': amount,
      'status': status,
      'paymentMethod': paymentMethod,
      'transactionId': transactionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiryDate': Timestamp.fromDate(expiryDate),
    };
  }
}
