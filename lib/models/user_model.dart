import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;
  final bool isFirstTime;
  final bool isPro;
  final int generationCount;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    this.isFirstTime = true,
    this.isPro = false,
    this.generationCount = 0,
    required this.createdAt,
  });

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isFirstTime,
    bool? isPro,
    int? generationCount,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isFirstTime: isFirstTime ?? this.isFirstTime,
      isPro: isPro ?? this.isPro,
      generationCount: generationCount ?? this.generationCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
      isFirstTime: json['isFirstTime'] as bool? ?? true,
      isPro: json['isPro'] as bool? ?? false,
      generationCount: json['generationCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isFirstTime': isFirstTime,
      'isPro': isPro,
      'generationCount': generationCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
