import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/cv_model.dart';

class PdfService {
  const PdfService();

  Future<Uint8List> generatePdf(CvModel cv, String templateName) async {
    final pdf = pw.Document();

    final content = cv.generatedContent;
    final personalInfo = content['personalInfo'] as Map<String, dynamic>? ?? {};
    final summary = content['summary'] as String? ?? '';
    final experiences = content['workExperience'] as List? ?? [];
    final educations = content['education'] as List? ?? [];
    final skillsMap = content['skills'] as Map<String, dynamic>? ?? {};
    final certifications = content['certifications'] as List? ?? [];
    final projects = content['projects'] as List? ?? [];
    final achievements = content['achievements'] as List? ?? [];
    final references = content['references'] as String? ?? '';

    final name = personalInfo['fullName'] as String? ?? 'Professional CV';
    final email = personalInfo['email'] as String? ?? '';
    final phone = personalInfo['phone'] as String? ?? '';
    final location = personalInfo['location'] as String? ?? '';
    final linkedin = personalInfo['linkedIn'] as String? ?? '';
    final portfolio = personalInfo['portfolio'] as String? ?? '';

    final contactInfo = [
      if (email.isNotEmpty) email,
      if (phone.isNotEmpty) phone,
      if (location.isNotEmpty) location,
      if (linkedin.isNotEmpty) linkedin,
      if (portfolio.isNotEmpty) portfolio,
    ].join(' | ');

    if (templateName.toLowerCase() == 'professional') {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0), // Full band header needs 0 margin at page level
          build: (pw.Context context) {
            return [
              // Header Band
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(24),
                color: PdfColor.fromHex('#6C63FF'),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      name,
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      contactInfo,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Body (Two Columns)
              pw.Padding(
                padding: const pw.EdgeInsets.all(24),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Left Column (Narrower)
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Skills Section
                          if (skillsMap.isNotEmpty) ...[
                            _buildSectionTitle('SKILLS', themeColor: '#6C63FF'),
                            pw.SizedBox(height: 8),
                            ..._buildSkillsSubsections(skillsMap),
                            pw.SizedBox(height: 16),
                          ],
                          // Education Section
                          if (educations.isNotEmpty) ...[
                            _buildSectionTitle('EDUCATION', themeColor: '#6C63FF'),
                            pw.SizedBox(height: 8),
                            ...educations.map((edu) {
                              final item = edu as Map<String, dynamic>;
                              return pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 12),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      item['degree'] as String? ?? '',
                                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                                    ),
                                    pw.Text(
                                      item['institution'] as String? ?? '',
                                      style: const pw.TextStyle(fontSize: 9),
                                    ),
                                    pw.Text(
                                      '${item['startDate'] ?? ''} - ${item['endDate'] ?? ''}',
                                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                                    ),
                                    if (item['grade'] != null && (item['grade'] as String).isNotEmpty)
                                      pw.Text(
                                        'Grade: ${item['grade']}',
                                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                                      ),
                                  ],
                                ),
                              );
                            }),
                            pw.SizedBox(height: 16),
                          ],
                          // Certifications Section
                          if (certifications.isNotEmpty) ...[
                            _buildSectionTitle('CERTIFICATIONS', themeColor: '#6C63FF'),
                            pw.SizedBox(height: 8),
                            ...certifications.map((cert) {
                              final item = cert as Map<String, dynamic>;
                              return pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 8),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      item['name'] as String? ?? '',
                                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                                    ),
                                    pw.Text(
                                      '${item['issuer'] ?? ''} (${item['date'] ?? ''})',
                                      style: const pw.TextStyle(fontSize: 9),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 24),
                    // Right Column (Wider)
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // Summary
                          if (summary.isNotEmpty) ...[
                            _buildSectionTitle('SUMMARY', themeColor: '#6C63FF'),
                            pw.SizedBox(height: 8),
                            pw.Text(
                              summary,
                              style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.3),
                            ),
                            pw.SizedBox(height: 20),
                          ],
                          // Experience
                          if (experiences.isNotEmpty) ...[
                            _buildSectionTitle('EXPERIENCE', themeColor: '#6C63FF'),
                            pw.SizedBox(height: 8),
                            ...experiences.map((exp) {
                              final item = exp as Map<String, dynamic>;
                              final duties = item['responsibilities'] as List? ?? [];
                              return pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 16),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Row(
                                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                      children: [
                                        pw.Text(
                                          item['role'] as String? ?? '',
                                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                                        ),
                                        pw.Text(
                                          '${item['startDate'] ?? ''} - ${item['current'] == true ? 'Present' : item['endDate'] ?? ''}',
                                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                                        ),
                                      ],
                                    ),
                                    pw.Text(
                                      item['company'] as String? ?? '',
                                      style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#6C63FF')),
                                    ),
                                    pw.SizedBox(height: 6),
                                    ...duties.map((duty) => pw.Padding(
                                          padding: const pw.EdgeInsets.only(left: 8, bottom: 3),
                                          child: pw.Row(
                                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                                            children: [
                                              pw.Text('• ', style: const pw.TextStyle(fontSize: 10)),
                                              pw.Expanded(
                                                child: pw.Text(
                                                  duty as String,
                                                  style: const pw.TextStyle(fontSize: 9.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              );
                            }),
                            pw.SizedBox(height: 16),
                          ],
                          // Projects Section
                          if (projects.isNotEmpty) ...[
                            _buildSectionTitle('PROJECTS', themeColor: '#6C63FF'),
                            pw.SizedBox(height: 8),
                            ...projects.map((proj) {
                              final item = proj as Map<String, dynamic>;
                              return pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 12),
                                child: pw.Column(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      item['name'] as String? ?? '',
                                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                                    ),
                                    if (item['description'] != null)
                                      pw.Text(
                                        item['description'] as String,
                                        style: const pw.TextStyle(fontSize: 9.5),
                                      ),
                                    if (item['tech'] != null)
                                      pw.Text(
                                        'Technologies: ${(item['tech'] as List).join(', ')}',
                                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                                      ),
                                  ],
                                ),
                              );
                            }),
                            pw.SizedBox(height: 16),
                          ],
                          // Achievements Section
                          if (achievements.isNotEmpty) ...[
                            _buildSectionTitle('ACHIEVEMENTS', themeColor: '#6C63FF'),
                            pw.SizedBox(height: 8),
                            ...achievements.map((ach) => pw.Padding(
                                  padding: const pw.EdgeInsets.only(left: 8, bottom: 4),
                                  child: pw.Row(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text('• ', style: const pw.TextStyle(fontSize: 10)),
                                      pw.Expanded(
                                        child: pw.Text(
                                          ach as String,
                                          style: const pw.TextStyle(fontSize: 9.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                            pw.SizedBox(height: 16),
                          ],
                          // References
                          if (references.isNotEmpty) ...[
                            _buildSectionTitle('REFERENCES', themeColor: '#6C63FF'),
                            pw.SizedBox(height: 8),
                            pw.Text(
                              references,
                              style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );
    } else {
      // Default: CLEAN TEMPLATE
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context context) {
            return [
              // Header
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    name,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1A1A2E'),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    contactInfo,
                    style: const pw.TextStyle(
                      fontSize: 9.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey300, thickness: 1.0),
              pw.SizedBox(height: 12),

              // Summary Section
              if (summary.isNotEmpty) ...[
                _buildCleanHeader('PROFESSIONAL SUMMARY'),
                pw.SizedBox(height: 6),
                pw.Text(
                  summary,
                  style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.2),
                ),
                pw.SizedBox(height: 16),
              ],

              // Experience Section
              if (experiences.isNotEmpty) ...[
                _buildCleanHeader('WORK EXPERIENCE'),
                pw.SizedBox(height: 6),
                ...experiences.map((exp) {
                  final item = exp as Map<String, dynamic>;
                  final duties = item['responsibilities'] as List? ?? [];
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 14),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              '${item['role']} at ${item['company']}',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5),
                            ),
                            pw.Text(
                              '${item['startDate'] ?? ''} - ${item['current'] == true ? 'Present' : item['endDate'] ?? ''}',
                              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        ...duties.map((duty) => pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 8, bottom: 3),
                              child: pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('• ', style: const pw.TextStyle(fontSize: 10)),
                                  pw.Expanded(
                                    child: pw.Text(
                                      duty as String,
                                      style: const pw.TextStyle(fontSize: 9.5),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  );
                }),
                pw.SizedBox(height: 16),
              ],

              // Education Section
              if (educations.isNotEmpty) ...[
                _buildCleanHeader('EDUCATION'),
                pw.SizedBox(height: 6),
                ...educations.map((edu) {
                  final item = edu as Map<String, dynamic>;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                '${item['degree']} in ${item['field']}',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                              ),
                              pw.Text(
                                item['institution'] as String? ?? '',
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text(
                              '${item['startDate'] ?? ''} - ${item['endDate'] ?? ''}',
                              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                            ),
                            if (item['grade'] != null && (item['grade'] as String).isNotEmpty)
                              pw.Text(
                                'Grade: ${item['grade']}',
                                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                pw.SizedBox(height: 16),
              ],

              // Skills Section (Two Columns)
              if (skillsMap.isNotEmpty) ...[
                _buildCleanHeader('SKILLS'),
                pw.SizedBox(height: 6),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (skillsMap['technical'] != null) ...[
                            pw.Text('Technical:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                            pw.Text((skillsMap['technical'] as List).join(', '), style: const pw.TextStyle(fontSize: 9)),
                            pw.SizedBox(height: 8),
                          ],
                          if (skillsMap['languages'] != null) ...[
                            pw.Text('Languages:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                            pw.Text((skillsMap['languages'] as List).join(', '), style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 24),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (skillsMap['soft'] != null) ...[
                            pw.Text('Soft Skills:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                            pw.Text((skillsMap['soft'] as List).join(', '), style: const pw.TextStyle(fontSize: 9)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
              ],

              // Projects Section
              if (projects.isNotEmpty) ...[
                _buildCleanHeader('PROJECTS'),
                pw.SizedBox(height: 6),
                ...projects.map((proj) {
                  final item = proj as Map<String, dynamic>;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          item['name'] as String? ?? '',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                        ),
                        if (item['description'] != null)
                          pw.Text(
                            item['description'] as String,
                            style: const pw.TextStyle(fontSize: 9.5),
                          ),
                        if (item['tech'] != null)
                          pw.Text(
                            'Technologies: ${(item['tech'] as List).join(', ')}',
                            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                          ),
                      ],
                    ),
                  );
                }),
                pw.SizedBox(height: 16),
              ],

              // Certifications Section
              if (certifications.isNotEmpty) ...[
                _buildCleanHeader('CERTIFICATIONS'),
                pw.SizedBox(height: 6),
                ...certifications.map((cert) {
                  final item = cert as Map<String, dynamic>;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          item['name'] as String? ?? '',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                        ),
                        pw.Text(
                          '${item['issuer'] ?? ''} (${item['date'] ?? ''})',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  );
                }),
                pw.SizedBox(height: 16),
              ],

              // Achievements Section
              if (achievements.isNotEmpty) ...[
                _buildCleanHeader('ACHIEVEMENTS'),
                pw.SizedBox(height: 6),
                ...achievements.map((ach) => pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 8, bottom: 4),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('• ', style: const pw.TextStyle(fontSize: 10)),
                          pw.Expanded(
                            child: pw.Text(
                              ach as String,
                              style: const pw.TextStyle(fontSize: 9.5),
                            ),
                          ),
                        ],
                      ),
                    )),
                pw.SizedBox(height: 16),
              ],

              // References
              if (references.isNotEmpty) ...[
                _buildCleanHeader('REFERENCES'),
                pw.SizedBox(height: 6),
                pw.Text(
                  references,
                  style: pw.TextStyle(fontSize: 9.5, fontStyle: pw.FontStyle.italic),
                ),
              ],
            ];
          },
        ),
      );
    }

    return pdf.save();
  }

  Future<String> savePdfToDevice(Uint8List bytes, String fullName) async {
    final cleanName = fullName.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '${cleanName}_CV_$timestamp.pdf';

    // In cross-platform mobile apps we use path_provider's getApplicationDocumentsDirectory
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$filename';
    final file = File(path);
    await file.writeAsBytes(bytes);

    return path;
  }

  pw.Widget _buildSectionTitle(String title, {required String themeColor}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex(themeColor),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          height: 1.5,
          color: PdfColor.fromHex(themeColor),
        ),
      ],
    );
  }

  pw.Widget _buildCleanHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#1A1A2E'),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Divider(color: PdfColors.grey300, thickness: 0.8),
      ],
    );
  }

  List<pw.Widget> _buildSkillsSubsections(Map<String, dynamic> skillsMap) {
    final List<pw.Widget> items = [];
    if (skillsMap['technical'] != null) {
      items.add(pw.Text('Technical:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)));
      items.add(pw.Text((skillsMap['technical'] as List).join(', '), style: const pw.TextStyle(fontSize: 9)));
      items.add(pw.SizedBox(height: 6));
    }
    if (skillsMap['soft'] != null) {
      items.add(pw.Text('Soft Skills:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)));
      items.add(pw.Text((skillsMap['soft'] as List).join(', '), style: const pw.TextStyle(fontSize: 9)));
      items.add(pw.SizedBox(height: 6));
    }
    if (skillsMap['languages'] != null) {
      items.add(pw.Text('Languages:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)));
      items.add(pw.Text((skillsMap['languages'] as List).join(', '), style: const pw.TextStyle(fontSize: 9)));
    }
    return items;
  }
}
