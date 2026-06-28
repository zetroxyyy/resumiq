import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String photoUrl;
  final String tier; // 'free' or 'pro'
  final String? tierGrantedBy; // 'payment', 'admin', or null
  final DateTime? tierExpiresAt;
  final int generationsThisMonth;
  final DateTime generationResetDate;
  final DateTime createdAt;
  final bool isFirstTime;

  const UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.photoUrl,
    this.tier = 'free',
    this.tierGrantedBy,
    this.tierExpiresAt,
    this.generationsThisMonth = 0,
    required this.generationResetDate,
    required this.createdAt,
    this.isFirstTime = true,
  });

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? photoUrl,
    String? tier,
    String? tierGrantedBy,
    DateTime? tierExpiresAt,
    int? generationsThisMonth,
    DateTime? generationResetDate,
    DateTime? createdAt,
    bool? isFirstTime,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      tier: tier ?? this.tier,
      tierGrantedBy: tierGrantedBy ?? this.tierGrantedBy,
      tierExpiresAt: tierExpiresAt ?? this.tierExpiresAt,
      generationsThisMonth: generationsThisMonth ?? this.generationsThisMonth,
      generationResetDate: generationResetDate ?? this.generationResetDate,
      createdAt: createdAt ?? this.createdAt,
      isFirstTime: isFirstTime ?? this.isFirstTime,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
      tier: json['tier'] as String? ?? 'free',
      tierGrantedBy: json['tierGrantedBy'] as String?,
      tierExpiresAt: json['tierExpiresAt'] != null
          ? (json['tierExpiresAt'] as Timestamp).toDate()
          : null,
      generationsThisMonth: json['generationsThisMonth'] as int? ?? 0,
      generationResetDate: json['generationResetDate'] != null
          ? (json['generationResetDate'] as Timestamp).toDate()
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      isFirstTime: json['isFirstTime'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'tier': tier,
      'tierGrantedBy': tierGrantedBy,
      'tierExpiresAt': tierExpiresAt != null ? Timestamp.fromDate(tierExpiresAt!) : null,
      'generationsThisMonth': generationsThisMonth,
      'generationResetDate': Timestamp.fromDate(generationResetDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'isFirstTime': isFirstTime,
    };
  }

  bool get isPro => tier == 'pro';
}
