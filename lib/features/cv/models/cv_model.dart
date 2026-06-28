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
  final String? docxUrl;
  final String? shareUrl;
  final int? score;
  final List<String> scoreFeedback;
  final int version;
  final String cvType;
  final bool atsOptimized;
  final String? coverLetter;
  final String? coverLetterPdfUrl;
  final String? coverLetterDocxUrl;
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
    this.docxUrl,
    this.shareUrl,
    this.score,
    this.scoreFeedback = const [],
    this.version = 1,
    required this.cvType,
    this.atsOptimized = false,
    this.coverLetter,
    this.coverLetterPdfUrl,
    this.coverLetterDocxUrl,
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
      docxUrl: json['docxUrl'] as String?,
      shareUrl: json['shareUrl'] as String?,
      score: json['score'] as int?,
      scoreFeedback: List<String>.from(json['scoreFeedback'] as List? ?? []),
      version: json['version'] as int? ?? 1,
      cvType: json['cvType'] as String? ?? 'professional',
      atsOptimized: json['atsOptimized'] as bool? ?? false,
      coverLetter: json['coverLetter'] as String?,
      coverLetterPdfUrl: json['coverLetterPdfUrl'] as String?,
      coverLetterDocxUrl: json['coverLetterDocxUrl'] as String?,
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
      'docxUrl': docxUrl,
      'shareUrl': shareUrl,
      'score': score,
      'scoreFeedback': scoreFeedback,
      'version': version,
      'cvType': cvType,
      'atsOptimized': atsOptimized,
      'coverLetter': coverLetter,
      'coverLetterPdfUrl': coverLetterPdfUrl,
      'coverLetterDocxUrl': coverLetterDocxUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CvModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? rawInput,
    String? jobDescription,
    Map<String, dynamic>? generatedContent,
    String? template,
    String? pdfUrl,
    String? docxUrl,
    String? shareUrl,
    int? score,
    List<String>? scoreFeedback,
    int? version,
    String? cvType,
    bool? atsOptimized,
    String? coverLetter,
    String? coverLetterPdfUrl,
    String? coverLetterDocxUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CvModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      rawInput: rawInput ?? this.rawInput,
      jobDescription: jobDescription ?? this.jobDescription,
      generatedContent: generatedContent ?? this.generatedContent,
      template: template ?? this.template,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      docxUrl: docxUrl ?? this.docxUrl,
      shareUrl: shareUrl ?? this.shareUrl,
      score: score ?? this.score,
      scoreFeedback: scoreFeedback ?? this.scoreFeedback,
      version: version ?? this.version,
      cvType: cvType ?? this.cvType,
      atsOptimized: atsOptimized ?? this.atsOptimized,
      coverLetter: coverLetter ?? this.coverLetter,
      coverLetterPdfUrl: coverLetterPdfUrl ?? this.coverLetterPdfUrl,
      coverLetterDocxUrl: coverLetterDocxUrl ?? this.coverLetterDocxUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
