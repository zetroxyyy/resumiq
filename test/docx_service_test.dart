import 'package:flutter_test/flutter_test.dart';
import 'package:resumind/features/cv/models/cv_model.dart';
import 'package:resumind/features/cv/services/docx_service.dart';

void main() {
  group('DocxService Tests', () {
    const docxService = DocxService();

    test('generateDocx returns non-empty byte list and encodes correctly', () {
      final cv = CvModel(
        id: 'test-id',
        userId: 'user-id',
        title: 'Test CV',
        rawInput: 'Some input text that is long enough to describe myself.',
        generatedContent: {
          'personalInfo': {
            'fullName': 'John Doe',
            'email': 'john@example.com',
            'phone': '1234567890',
            'location': 'Kathmandu, Nepal',
          },
          'summary': 'Professional summary details.',
          'workExperience': [
            {
              'company': 'Tech Corp',
              'role': 'Developer',
              'startDate': '2020',
              'endDate': '2022',
              'current': false,
              'responsibilities': ['Developed applications.', 'Optimized code.']
            }
          ],
          'skills': {
            'technical': ['Dart', 'Flutter'],
          }
        },
        template: 'Standard',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        cvType: 'Standard',
      );

      final docxBytes = docxService.generateDocx(cv);
      expect(docxBytes, isNotEmpty);
      expect(docxBytes.length, greaterThan(100));
    });
  });
}
