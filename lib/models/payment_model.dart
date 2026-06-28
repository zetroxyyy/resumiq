import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String userId;
  final int amount; // in paisa (NPR * 100)
  final String plan; // 'monthly' or 'yearly'
  final String status; // 'pending', 'completed', or 'failed'
  final String? khaltiToken;
  final String? khaltiTransactionId;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.plan,
    required this.status,
    this.khaltiToken,
    this.khaltiTransactionId,
    required this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      plan: json['plan'] as String? ?? 'monthly',
      status: json['status'] as String? ?? 'pending',
      khaltiToken: json['khaltiToken'] as String?,
      khaltiTransactionId: json['khaltiTransactionId'] as String?,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'plan': plan,
      'status': status,
      'khaltiToken': khaltiToken,
      'khaltiTransactionId': khaltiTransactionId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
