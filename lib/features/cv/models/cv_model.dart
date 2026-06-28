class CvModel {
  final String id;
  final String title;

  const CvModel({
    required this.id,
    required this.title,
  });

  factory CvModel.fromJson(Map<String, dynamic> json) {
    return CvModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
    };
  }
}
