import 'package:cloud_firestore/cloud_firestore.dart';

class CvModel {
  final String id;
  final String userId;
  final String title;
  final String rawInput;
  final String? jobDescription;
  final Map<String, dynamic> generatedContent;
  final String template;
  final String? pdfUrl;
  final String? shareUrl;
  final int? score;
  final List<String> scoreFeedback;
  final int version;
  final String cvType;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CvModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.rawInput,
    this.jobDescription,
    required this.generatedContent,
    required this.template,
    this.pdfUrl,
    this.shareUrl,
    this.score,
    this.scoreFeedback = const [],
    this.version = 1,
    required this.cvType,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CvModel.fromJson(Map<String, dynamic> json) {
    return CvModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      rawInput: json['rawInput'] as String? ?? '',
      jobDescription: json['jobDescription'] as String?,
      generatedContent: (json['generatedContent'] as Map<String, dynamic>?) ?? {},
      template: json['template'] as String? ?? '',
      pdfUrl: json['pdfUrl'] as String?,
      shareUrl: json['shareUrl'] as String?,
      score: json['score'] as int?,
      scoreFeedback: List<String>.from(json['scoreFeedback'] as List? ?? []),
      version: json['version'] as int? ?? 1,
      cvType: json['cvType'] as String? ?? 'professional',
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'rawInput': rawInput,
      'jobDescription': jobDescription,
      'generatedContent': generatedContent,
      'template': template,
      'pdfUrl': pdfUrl,
      'shareUrl': shareUrl,
      'score': score,
      'scoreFeedback': scoreFeedback,
      'version': version,
      'cvType': cvType,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
