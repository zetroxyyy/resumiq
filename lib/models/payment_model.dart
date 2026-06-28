import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentModel {
  final String id;
  final String userId;
  final int amount; // in paisa (NPR * 100)
  final String plan; // 'monthly' or 'yearly'
  final String status; // 'pending', 'verified', or 'rejected'
  final String? esewaTransactionId;
  final String? userGmail;
  final DateTime createdAt;
  final String? verifiedBy;
  final DateTime? verifiedAt;

  const PaymentModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.plan,
    required this.status,
    this.esewaTransactionId,
    this.userGmail,
    required this.createdAt,
    this.verifiedBy,
    this.verifiedAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      plan: json['plan'] as String? ?? 'monthly',
      status: json['status'] as String? ?? 'pending',
      esewaTransactionId: json['esewaTransactionId'] as String?,
      userGmail: json['userGmail'] as String?,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      verifiedBy: json['verifiedBy'] as String?,
      verifiedAt: json['verifiedAt'] != null
          ? (json['verifiedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'plan': plan,
      'status': status,
      'esewaTransactionId': esewaTransactionId,
      'userGmail': userGmail,
      'createdAt': Timestamp.fromDate(createdAt),
      'verifiedBy': verifiedBy,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
    };
  }
}
