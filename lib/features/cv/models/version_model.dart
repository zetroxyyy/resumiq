import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a point-in-time snapshot of a CV, stored as a subcollection
/// under /users/{uid}/cvs/{cvId}/versions/{versionId}/
class VersionModel {
  final String id;
  final int versionNumber;
  final Map<String, dynamic> generatedContent;
  final String template;
  final String changedBy; // "manual_edit" | "voice_edit" | "regenerated" | "initial"
  final DateTime changedAt;

  const VersionModel({
    required this.id,
    required this.versionNumber,
    required this.generatedContent,
    required this.template,
    required this.changedBy,
    required this.changedAt,
  });

  factory VersionModel.fromJson(Map<String, dynamic> json, String id) {
    return VersionModel(
      id: id,
      versionNumber: json['versionNumber'] as int? ?? 1,
      generatedContent:
          (json['generatedContent'] as Map<String, dynamic>?) ?? {},
      template: json['template'] as String? ?? '',
      changedBy: json['changedBy'] as String? ?? 'manual_edit',
      changedAt: json['changedAt'] != null
          ? (json['changedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'versionNumber': versionNumber,
      'generatedContent': generatedContent,
      'template': template,
      'changedBy': changedBy,
      'changedAt': Timestamp.fromDate(changedAt),
    };
  }
}
