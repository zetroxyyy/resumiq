import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/cv_model.dart';

class PdfService {
  const PdfService();

  Future<Uint8List> generatePdf(CvModel cv, String templateName) async {
    final nameNormalized = templateName.toLowerCase().trim();

    if (nameNormalized == 'professional') {
      return _generateProfessional(cv);
    } else if (nameNormalized == 'simple') {
      return _generateSimple(cv);
    } else if (nameNormalized == 'basic') {
      return _generateBasic(cv);
    } else if (nameNormalized == 'modern') {
      return _generateModern(cv);
    } else if (nameNormalized == 'europass') {
      return _generateEuropass(cv);
    } else if (nameNormalized == 'executive') {
      return _generateExecutive(cv);
    } else if (nameNormalized == 'nepal special' || nameNormalized == 'nepal-special') {
      return _generateNepalSpecial(cv);
    } else {
      return _generateClean(cv);
    }
  }

  Future<String> savePdfToDevice(Uint8List bytes, String fullName) async {
    final cleanName = fullName.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '${cleanName}_CV_$timestamp.pdf';

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$filename';
    final file = File(path);
    await file.writeAsBytes(bytes);

    return path;
  }

  // ==========================================
  // TEMPLATE 1: CLEAN (Default)
  // ==========================================
  Future<Uint8List> _generateClean(CvModel cv) async {
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

            // Skills Section
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

    return pdf.save();
  }

  // ==========================================
  // TEMPLATE 2: PROFESSIONAL
  // ==========================================
  Future<Uint8List> _generateProfessional(CvModel cv) async {
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

    return pdf.save();
  }

  // ==========================================
  // TEMPLATE 3: SIMPLE
  // ==========================================
  Future<Uint8List> _generateSimple(CvModel cv) async {
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(56), // 2cm margin is ~56pt
        build: (pw.Context context) {
          return [
            // Center Name
            pw.Center(
              child: pw.Text(
                name,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            // Contact info centered single line
            pw.Center(
              child: pw.Text(
                contactInfo,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.black,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            // Thin black horizontal rule
            pw.Container(
              height: 0.8,
              color: PdfColors.black,
            ),
            pw.SizedBox(height: 16),

            // Summary
            if (summary.isNotEmpty) ...[
              _buildSimpleHeader('SUMMARY'),
              pw.SizedBox(height: 6),
              pw.Text(
                summary,
                style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.3),
              ),
              pw.SizedBox(height: 16),
            ],

            // Experience
            if (experiences.isNotEmpty) ...[
              _buildSimpleHeader('EXPERIENCE'),
              pw.SizedBox(height: 6),
              ...experiences.map((exp) {
                final item = exp as Map<String, dynamic>;
                final duties = item['responsibilities'] as List? ?? [];
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${item['role']} - ${item['company']}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                          ),
                          pw.Text(
                            '${item['startDate'] ?? ''} - ${item['current'] == true ? 'Present' : item['endDate'] ?? ''}',
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      ...duties.map((duty) => pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('- ', style: const pw.TextStyle(fontSize: 9)),
                                pw.Expanded(
                                  child: pw.Text(
                                    duty as String,
                                    style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.2),
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

            // Education
            if (educations.isNotEmpty) ...[
              _buildSimpleHeader('EDUCATION'),
              pw.SizedBox(height: 6),
              ...educations.map((edu) {
                final item = edu as Map<String, dynamic>;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${item['degree']} in ${item['field']} - ${item['institution']}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                      ),
                      pw.Text(
                        '${item['startDate'] ?? ''} - ${item['endDate'] ?? ''}',
                        style: const pw.TextStyle(fontSize: 8.5),
                      ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 16),
            ],

            // Skills (comma-separated inline text)
            if (skillsMap.isNotEmpty) ...[
              _buildSimpleHeader('SKILLS'),
              pw.SizedBox(height: 6),
              pw.Text(
                [
                  if (skillsMap['technical'] != null) (skillsMap['technical'] as List).join(', '),
                  if (skillsMap['soft'] != null) (skillsMap['soft'] as List).join(', '),
                  if (skillsMap['languages'] != null) (skillsMap['languages'] as List).join(', '),
                ].where((s) => s.isNotEmpty).join(', '),
                style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.3),
              ),
              pw.SizedBox(height: 16),
            ],

            // Projects
            if (projects.isNotEmpty) ...[
              _buildSimpleHeader('PROJECTS'),
              pw.SizedBox(height: 6),
              ...projects.map((proj) {
                final item = proj as Map<String, dynamic>;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item['name'] as String? ?? '',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                      ),
                      if (item['description'] != null)
                        pw.Text(
                          item['description'] as String,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 16),
            ],

            // Certifications
            if (certifications.isNotEmpty) ...[
              _buildSimpleHeader('CERTIFICATIONS'),
              pw.SizedBox(height: 6),
              ...certifications.map((cert) {
                final item = cert as Map<String, dynamic>;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Text(
                    '${item['name']} - ${item['issuer']} (${item['date'] ?? ''})',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                );
              }),
              pw.SizedBox(height: 16),
            ],

            // Achievements
            if (achievements.isNotEmpty) ...[
              _buildSimpleHeader('ACHIEVEMENTS'),
              pw.SizedBox(height: 6),
              ...achievements.map((ach) => pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                    child: pw.Row(
                      children: [
                        pw.Text('- ', style: const pw.TextStyle(fontSize: 9)),
                        pw.Expanded(child: pw.Text(ach as String, style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 16),
            ],

            // References
            if (references.isNotEmpty) ...[
              _buildSimpleHeader('REFERENCES'),
              pw.SizedBox(height: 6),
              pw.Text(
                references,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSimpleHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Container(
          height: 0.5,
          color: PdfColors.black,
        ),
      ],
    );
  }

  // ==========================================
  // TEMPLATE 4: BASIC
  // ==========================================
  Future<Uint8List> _generateBasic(CvModel cv) async {
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(56),
        build: (pw.Context context) {
          return [
            // Name left-aligned
            pw.Text(
              name,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 2),
            // Contact info left-aligned
            pw.Text(
              contactInfo,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 16),

            // Summary
            if (summary.isNotEmpty) ...[
              _buildBasicHeader('SUMMARY'),
              pw.SizedBox(height: 6),
              pw.Text(
                summary,
                style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 1.3),
              ),
              pw.SizedBox(height: 16),
            ],

            // Experience
            if (experiences.isNotEmpty) ...[
              _buildBasicHeader('WORK EXPERIENCE'),
              pw.SizedBox(height: 6),
              ...experiences.map((exp) {
                final item = exp as Map<String, dynamic>;
                final duties = item['responsibilities'] as List? ?? [];
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            item['company'] as String? ?? '',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                          ),
                          pw.Text(
                            '${item['startDate'] ?? ''} - ${item['current'] == true ? 'Present' : item['endDate'] ?? ''}',
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                        ],
                      ),
                      pw.Text(
                        item['role'] as String? ?? '',
                        style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 9),
                      ),
                      pw.SizedBox(height: 4),
                      ...duties.map((duty) => pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('• ', style: const pw.TextStyle(fontSize: 9)),
                                pw.Expanded(
                                  child: pw.Text(
                                    duty as String,
                                    style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.2),
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

            // Education
            if (educations.isNotEmpty) ...[
              _buildBasicHeader('EDUCATION'),
              pw.SizedBox(height: 6),
              ...educations.map((edu) {
                final item = edu as Map<String, dynamic>;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            item['institution'] as String? ?? '',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                          ),
                          pw.Text(
                            '${item['startDate'] ?? ''} - ${item['endDate'] ?? ''}',
                            style: const pw.TextStyle(fontSize: 8.5),
                          ),
                        ],
                      ),
                      pw.Text(
                        '${item['degree']} in ${item['field']}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 16),
            ],

            // Skills
            if (skillsMap.isNotEmpty) ...[
              _buildBasicHeader('SKILLS'),
              pw.SizedBox(height: 6),
              ..._buildBasicSkillsList(skillsMap),
              pw.SizedBox(height: 16),
            ],

            // Projects
            if (projects.isNotEmpty) ...[
              _buildBasicHeader('PROJECTS'),
              pw.SizedBox(height: 6),
              ...projects.map((proj) {
                final item = proj as Map<String, dynamic>;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        item['name'] as String? ?? '',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                      ),
                      if (item['description'] != null)
                        pw.Text(
                          item['description'] as String,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 16),
            ],

            // Certifications
            if (certifications.isNotEmpty) ...[
              _buildBasicHeader('CERTIFICATIONS'),
              pw.SizedBox(height: 6),
              ...certifications.map((cert) {
                final item = cert as Map<String, dynamic>;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Text(
                    '• ${item['name']} - ${item['issuer']} (${item['date'] ?? ''})',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                );
              }),
              pw.SizedBox(height: 16),
            ],

            // Achievements
            if (achievements.isNotEmpty) ...[
              _buildBasicHeader('ACHIEVEMENTS'),
              pw.SizedBox(height: 6),
              ...achievements.map((ach) => pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                    child: pw.Row(
                      children: [
                        pw.Text('• ', style: const pw.TextStyle(fontSize: 9)),
                        pw.Expanded(child: pw.Text(ach as String, style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                  )),
              pw.SizedBox(height: 16),
            ],

            // References
            if (references.isNotEmpty) ...[
              _buildBasicHeader('REFERENCES'),
              pw.SizedBox(height: 6),
              pw.Text(
                references,
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildBasicHeader(String title) {
    return pw.Container(
      width: double.infinity,
      color: PdfColors.grey300,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
      ),
    );
  }

  List<pw.Widget> _buildBasicSkillsList(Map<String, dynamic> skillsMap) {
    final List<pw.Widget> items = [];
    if (skillsMap['technical'] != null) {
      items.add(pw.Text('• Technical: ${(skillsMap['technical'] as List).join(', ')}', style: const pw.TextStyle(fontSize: 9)));
    }
    if (skillsMap['soft'] != null) {
      items.add(pw.Text('• Soft Skills: ${(skillsMap['soft'] as List).join(', ')}', style: const pw.TextStyle(fontSize: 9)));
    }
    if (skillsMap['languages'] != null) {
      items.add(pw.Text('• Languages: ${(skillsMap['languages'] as List).join(', ')}', style: const pw.TextStyle(fontSize: 9)));
    }
    return items;
  }

  // ==========================================
  // TEMPLATE 5: MODERN
  // ==========================================
  Future<Uint8List> _generateModern(CvModel cv) async {
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

    final primaryColor = PdfColor.fromHex('#6C63FF');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0),
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(0),
          buildBackground: (pw.Context context) {
            // Draw left gray sidebar background
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 140, // ~16% A4 width
                    color: PdfColors.grey100,
                  ),
                  pw.Expanded(
                    child: pw.Container(color: PdfColors.white),
                  ),
                ],
              ),
            );
          },
        ),
        build: (pw.Context context) {
          return [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left Column (Sidebar Contact/Name)
                pw.Container(
                  width: 140,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 24),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Rotated/Stacked Name at top of sidebar
                      pw.Text(
                        name,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      // Accent line
                      pw.Container(
                        height: 2,
                        width: 40,
                        color: primaryColor,
                      ),
                      pw.SizedBox(height: 16),
                      // Stacked Contact Info
                      if (email.isNotEmpty) ...[
                        pw.Text('✉ Email', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text(email, style: const pw.TextStyle(fontSize: 7.5)),
                        pw.SizedBox(height: 8),
                      ],
                      if (phone.isNotEmpty) ...[
                        pw.Text('☎ Phone', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text(phone, style: const pw.TextStyle(fontSize: 7.5)),
                        pw.SizedBox(height: 8),
                      ],
                      if (location.isNotEmpty) ...[
                        pw.Text('📍 Location', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text(location, style: const pw.TextStyle(fontSize: 7.5)),
                        pw.SizedBox(height: 8),
                      ],
                      if (linkedin.isNotEmpty) ...[
                        pw.Text('🔗 LinkedIn', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text(linkedin.replaceFirst(RegExp(r'https?://(www\.)?'), ''), style: const pw.TextStyle(fontSize: 7)),
                        pw.SizedBox(height: 8),
                      ],
                      if (portfolio.isNotEmpty) ...[
                        pw.Text('💻 Portfolio', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text(portfolio.replaceFirst(RegExp(r'https?://(www\.)?'), ''), style: const pw.TextStyle(fontSize: 7)),
                      ],
                    ],
                  ),
                ),
                // Right Column (Main content area)
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(24),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Summary
                        if (summary.isNotEmpty) ...[
                          _buildModernSectionHeader('SUMMARY', primaryColor),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            summary,
                            style: const pw.TextStyle(fontSize: 9.5, lineSpacing: 1.3),
                          ),
                          pw.SizedBox(height: 20),
                        ],

                        // Experience (with timeline vertical line)
                        if (experiences.isNotEmpty) ...[
                          _buildModernSectionHeader('EXPERIENCE', primaryColor),
                          pw.SizedBox(height: 8),
                          ...experiences.map((exp) {
                            final item = exp as Map<String, dynamic>;
                            final duties = item['responsibilities'] as List? ?? [];
                            return pw.Container(
                              decoration: pw.BoxDecoration(
                                border: pw.Border(
                                  left: pw.BorderSide(color: primaryColor, width: 1.5),
                                ),
                              ),
                              padding: const pw.EdgeInsets.only(left: 12, bottom: 12),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    item['role'] as String? ?? '',
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                                  ),
                                  pw.Text(
                                    '${item['company']} | ${item['startDate'] ?? ''} - ${item['current'] == true ? 'Present' : item['endDate'] ?? ''}',
                                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                                  ),
                                  pw.SizedBox(height: 4),
                                  ...duties.map((duty) => pw.Padding(
                                        padding: const pw.EdgeInsets.only(bottom: 2),
                                        child: pw.Row(
                                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                                          children: [
                                            pw.Text('• ', style: pw.TextStyle(fontSize: 8, color: primaryColor)),
                                            pw.Expanded(child: pw.Text(duty as String, style: const pw.TextStyle(fontSize: 8.5))),
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            );
                          }),
                          pw.SizedBox(height: 16),
                        ],

                        // Education
                        if (educations.isNotEmpty) ...[
                          _buildModernSectionHeader('EDUCATION', primaryColor),
                          pw.SizedBox(height: 8),
                          ...educations.map((edu) {
                            final item = edu as Map<String, dynamic>;
                            return pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 8),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(
                                    '${item['degree']} in ${item['field']}',
                                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                                  ),
                                  pw.Text('${item['institution']} (${item['startDate'] ?? ''} - ${item['endDate'] ?? ''})', style: const pw.TextStyle(fontSize: 8.5)),
                                ],
                              ),
                            );
                          }),
                          pw.SizedBox(height: 16),
                        ],

                        // Skills (Pills-styled)
                        if (skillsMap.isNotEmpty) ...[
                          _buildModernSectionHeader('SKILLS', primaryColor),
                          pw.SizedBox(height: 8),
                          pw.Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ...[
                                if (skillsMap['technical'] != null) ...(skillsMap['technical'] as List),
                                if (skillsMap['soft'] != null) ...(skillsMap['soft'] as List),
                                if (skillsMap['languages'] != null) ...(skillsMap['languages'] as List),
                              ].map((skill) => pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: pw.BoxDecoration(
                                      border: pw.Border.all(color: primaryColor, width: 1),
                                      borderRadius: pw.BorderRadius.circular(8),
                                    ),
                                    child: pw.Text(skill as String, style: const pw.TextStyle(fontSize: 8)),
                                  )),
                            ],
                          ),
                          pw.SizedBox(height: 16),
                        ],

                        // Projects
                        if (projects.isNotEmpty) ...[
                          _buildModernSectionHeader('PROJECTS', primaryColor),
                          pw.SizedBox(height: 8),
                          ...projects.map((proj) {
                            final item = proj as Map<String, dynamic>;
                            return pw.Padding(
                              padding: const pw.EdgeInsets.only(bottom: 8),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(item['name'] as String? ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                                  if (item['description'] != null) pw.Text(item['description'] as String, style: const pw.TextStyle(fontSize: 8.5)),
                                ],
                              ),
                            );
                          }),
                          pw.SizedBox(height: 16),
                        ],

                        // Certifications
                        if (certifications.isNotEmpty) ...[
                          _buildModernSectionHeader('CERTIFICATIONS', primaryColor),
                          pw.SizedBox(height: 8),
                          ...certifications.map((cert) {
                            final item = cert as Map<String, dynamic>;
                            return pw.Text('• ${item['name']} - ${item['issuer']}', style: const pw.TextStyle(fontSize: 8.5));
                          }),
                          pw.SizedBox(height: 16),
                        ],

                        // Achievements
                        if (achievements.isNotEmpty) ...[
                          _buildModernSectionHeader('ACHIEVEMENTS', primaryColor),
                          pw.SizedBox(height: 8),
                          ...achievements.map((ach) => pw.Text('• $ach', style: const pw.TextStyle(fontSize: 8.5))),
                          pw.SizedBox(height: 16),
                        ],

                        // References
                        if (references.isNotEmpty) ...[
                          _buildModernSectionHeader('REFERENCES', primaryColor),
                          pw.SizedBox(height: 8),
                          pw.Text(references, style: const pw.TextStyle(fontSize: 8.5)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildModernSectionHeader(String title, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Container(height: 1, color: PdfColor(color.red, color.green, color.blue, 0.3)),
      ],
    );
  }

  // ==========================================
  // TEMPLATE 6: EUROPASS
  // ==========================================
  Future<Uint8List> _generateEuropass(CvModel cv) async {
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

    final name = personalInfo['fullName'] as String? ?? 'Curriculum Vitae';
    final email = personalInfo['email'] as String? ?? '';
    final phone = personalInfo['phone'] as String? ?? '';
    final location = personalInfo['location'] as String? ?? '';
    final linkedin = personalInfo['linkedIn'] as String? ?? '';
    final portfolio = personalInfo['portfolio'] as String? ?? '';

    final europassBlue = PdfColor.fromHex('#004494');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(42), // ~1.5cm margins
        build: (pw.Context context) {
          return [
            // Europass Header Band
            pw.Container(
              color: europassBlue,
              padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('europass', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.Text('Curriculum Vitae', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.white)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Labeled Two-Column Layouts

            // 1. Personal Information
            _buildEuropassHeader('Personal information'),
            _buildEuropassRow('First name / Surname', name, europassBlue),
            if (location.isNotEmpty) _buildEuropassRow('Address', location, europassBlue),
            if (phone.isNotEmpty) _buildEuropassRow('Telephone', phone, europassBlue),
            if (email.isNotEmpty) _buildEuropassRow('Email', email, europassBlue),
            _buildEuropassRow('Nationality', 'Nepali', europassBlue),
            if (linkedin.isNotEmpty) _buildEuropassRow('LinkedIn', linkedin, europassBlue),
            if (portfolio.isNotEmpty) _buildEuropassRow('Portfolio', portfolio, europassBlue),
            pw.SizedBox(height: 16),

            // 2. Summary
            if (summary.isNotEmpty) ...[
              _buildEuropassHeader('Work summary'),
              _buildEuropassRow('Objective', summary, europassBlue),
              pw.SizedBox(height: 16),
            ],

            // 3. Work Experience
            if (experiences.isNotEmpty) ...[
              _buildEuropassHeader('Work experience'),
              ...experiences.map((exp) {
                final item = exp as Map<String, dynamic>;
                final duties = item['responsibilities'] as List? ?? [];
                final details = pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item['role'] as String? ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                    pw.Text(item['company'] as String? ?? '', style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 4),
                    ...duties.map((duty) => pw.Text('• $duty', style: const pw.TextStyle(fontSize: 8.5))),
                  ],
                );

                return _buildEuropassRow(
                  '${item['startDate'] ?? ''} - ${item['current'] == true ? 'Present' : item['endDate'] ?? ''}',
                  details,
                  europassBlue,
                );
              }),
              pw.SizedBox(height: 16),
            ],

            // 4. Education
            if (educations.isNotEmpty) ...[
              _buildEuropassHeader('Education and training'),
              ...educations.map((edu) {
                final item = edu as Map<String, dynamic>;
                final details = pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${item['degree']} in ${item['field']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.Text(item['institution'] as String? ?? '', style: const pw.TextStyle(fontSize: 9)),
                  ],
                );

                return _buildEuropassRow(
                  '${item['startDate'] ?? ''} - ${item['endDate'] ?? ''}',
                  details,
                  europassBlue,
                );
              }),
              pw.SizedBox(height: 16),
            ],

            // 5. Personal Skills
            if (skillsMap.isNotEmpty) ...[
              _buildEuropassHeader('Personal skills'),
              if (skillsMap['languages'] != null)
                _buildEuropassRow('Mother tongue(s)', (skillsMap['languages'] as List).firstOrNull as String? ?? 'Nepali', europassBlue),
              if (skillsMap['technical'] != null)
                _buildEuropassRow('Digital skills', (skillsMap['technical'] as List).join(', '), europassBlue),
              if (skillsMap['soft'] != null)
                _buildEuropassRow('Other skills', (skillsMap['soft'] as List).join(', '), europassBlue),
              pw.SizedBox(height: 16),
            ],

            // 6. Projects
            if (projects.isNotEmpty) ...[
              _buildEuropassHeader('Projects'),
              ...projects.map((proj) {
                final item = proj as Map<String, dynamic>;
                final detail = pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(item['name'] as String? ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5)),
                    if (item['description'] != null) pw.Text(item['description'] as String, style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                );
                return _buildEuropassRow('Project detail', detail, europassBlue);
              }),
              pw.SizedBox(height: 16),
            ],

            // 7. Certifications
            if (certifications.isNotEmpty) ...[
              _buildEuropassHeader('Certifications'),
              ...certifications.map((cert) {
                final item = cert as Map<String, dynamic>;
                return _buildEuropassRow(
                  item['date'] as String? ?? 'Awarded',
                  '${item['name']} - ${item['issuer']}',
                  europassBlue,
                );
              }),
              pw.SizedBox(height: 16),
            ],

            // 8. Achievements
            if (achievements.isNotEmpty) ...[
              _buildEuropassHeader('Achievements'),
              _buildEuropassRow('Personal milestones', achievements.join('\n'), europassBlue),
              pw.SizedBox(height: 16),
            ],

            // 9. References
            if (references.isNotEmpty) ...[
              _buildEuropassHeader('References'),
              _buildEuropassRow('Endorsements', references, europassBlue),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildEuropassHeader(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
      ),
    );
  }

  pw.Widget _buildEuropassRow(String label, dynamic value, PdfColor labelColor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 8.5, color: labelColor, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            flex: 5,
            child: value is pw.Widget
                ? value
                : pw.Text(
                    value as String,
                    style: const pw.TextStyle(fontSize: 9),
                  ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TEMPLATE 7: EXECUTIVE
  // ==========================================
  Future<Uint8List> _generateExecutive(CvModel cv) async {
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

    final navy = PdfColor.fromHex('#1B2A4A');
    final gold = PdfColor.fromHex('#C9A84C');
    final darkGray = PdfColor.fromHex('#2C2C2C');

    final contactInfo = [
      if (email.isNotEmpty) email,
      if (phone.isNotEmpty) phone,
      if (location.isNotEmpty) location,
      if (linkedin.isNotEmpty) linkedin,
      if (portfolio.isNotEmpty) portfolio,
    ].join(' · ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(56),
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(56),
          buildBackground: (pw.Context context) {
            // Off-white/cream page background
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Container(color: PdfColor.fromHex('#FAFAF7')),
            );
          },
        ),
        build: (pw.Context context) {
          return [
            // Center Name
            pw.Center(
              child: pw.Text(
                name,
                style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: navy),
              ),
            ),
            pw.SizedBox(height: 6),
            // Gold line centered, 40% width
            pw.Center(
              child: pw.Container(
                height: 2,
                width: 200,
                color: gold,
              ),
            ),
            pw.SizedBox(height: 6),
            // Tagline / summary subtitle
            if (summary.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  summary.split('.').first, // First sentence of summary as tagline
                  style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: navy),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            pw.SizedBox(height: 8),
            // Contact row centered
            pw.Center(
              child: pw.Text(
                contactInfo,
                style: pw.TextStyle(fontSize: 8.5, color: darkGray),
              ),
            ),
            pw.SizedBox(height: 8),
            // Gold line full-width
            pw.Container(height: 1, color: gold),
            pw.SizedBox(height: 16),

            // Summary
            if (summary.isNotEmpty) ...[
              _buildExecutiveHeader('SUMMARY', navy, gold),
              pw.SizedBox(height: 8),
              pw.Text(
                summary,
                style: pw.TextStyle(fontSize: 9.5, color: darkGray, lineSpacing: 1.4),
              ),
              pw.SizedBox(height: 20),
            ],

            // Work Experience
            if (experiences.isNotEmpty) ...[
              _buildExecutiveHeader('WORK EXPERIENCE', navy, gold),
              pw.SizedBox(height: 8),
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
                          pw.Text(item['role'] as String? ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5, color: navy)),
                          pw.Text(
                            '${item['company']}  |  ${item['startDate'] ?? ''} - ${item['current'] == true ? 'Present' : item['endDate'] ?? ''}',
                            style: pw.TextStyle(fontSize: 9, color: darkGray),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      ...duties.map((duty) => pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8, bottom: 2),
                            child: pw.Row(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('► ', style: pw.TextStyle(fontSize: 7, color: gold)),
                                pw.Expanded(child: pw.Text(duty as String, style: pw.TextStyle(fontSize: 9, color: darkGray))),
                              ],
                            ),
                          )),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 16),
            ],

            // Education
            if (educations.isNotEmpty) ...[
              _buildExecutiveHeader('EDUCATION', navy, gold),
              pw.SizedBox(height: 8),
              ...educations.map((edu) {
                final item = edu as Map<String, dynamic>;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${item['degree']} in ${item['field']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: navy)),
                      pw.Text('${item['institution']} (${item['startDate'] ?? ''} - ${item['endDate'] ?? ''})', style: pw.TextStyle(fontSize: 9, color: darkGray)),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 16),
            ],

            // Skills (2-columns)
            if (skillsMap.isNotEmpty) ...[
              _buildExecutiveHeader('CORE COMPETENCIES', navy, gold),
              pw.SizedBox(height: 8),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (skillsMap['technical'] != null)
                          ...(skillsMap['technical'] as List).map((s) => pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 3),
                                child: pw.Text('► $s', style: pw.TextStyle(fontSize: 9, color: darkGray)),
                              )),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (skillsMap['soft'] != null)
                          ...(skillsMap['soft'] as List).map((s) => pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 3),
                                child: pw.Text('► $s', style: pw.TextStyle(fontSize: 9, color: darkGray)),
                              )),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // Projects
            if (projects.isNotEmpty) ...[
              _buildExecutiveHeader('KEY PROJECTS', navy, gold),
              pw.SizedBox(height: 8),
              ...projects.map((proj) {
                final item = proj as Map<String, dynamic>;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(item['name'] as String? ?? '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: navy)),
                      if (item['description'] != null) pw.Text(item['description'] as String, style: pw.TextStyle(fontSize: 9, color: darkGray)),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 16),
            ],

            // Certifications
            if (certifications.isNotEmpty) ...[
              _buildExecutiveHeader('CERTIFICATIONS', navy, gold),
              pw.SizedBox(height: 8),
              ...certifications.map((cert) {
                final item = cert as Map<String, dynamic>;
                return pw.Text('► ${item['name']} - ${item['issuer']}', style: pw.TextStyle(fontSize: 9, color: darkGray));
              }),
              pw.SizedBox(height: 16),
            ],

            // Achievements
            if (achievements.isNotEmpty) ...[
              _buildExecutiveHeader('ACHIEVEMENTS', navy, gold),
              pw.SizedBox(height: 8),
              ...achievements.map((ach) => pw.Text('► $ach', style: pw.TextStyle(fontSize: 9, color: darkGray))),
              pw.SizedBox(height: 16),
            ],

            // References
            if (references.isNotEmpty) ...[
              _buildExecutiveHeader('REFERENCES', navy, gold),
              pw.SizedBox(height: 8),
              pw.Text(references, style: pw.TextStyle(fontSize: 9, color: darkGray)),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildExecutiveHeader(String title, PdfColor navy, PdfColor gold) {
    return pw.Row(
      children: [
        // Gold left accent bar
        pw.Container(
          width: 4,
          height: 14,
          color: gold,
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: navy),
        ),
      ],
    );
  }

  // ==========================================
  // TEMPLATE 8: NEPAL SPECIAL
  // ==========================================
  Future<Uint8List> _generateNepalSpecial(CvModel cv) async {
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

    final name = personalInfo['fullName'] as String? ?? 'Nepal Special CV';
    final email = personalInfo['email'] as String? ?? '';
    final phone = personalInfo['phone'] as String? ?? '';
    final location = personalInfo['location'] as String? ?? '';

    final redColor = PdfColor.fromHex('#DC143C');
    final blueColor = PdfColor.fromHex('#003893');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(42),
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(42),
          buildBackground: (pw.Context context) {
            // Flag colors thin top and bottom border borders
            return pw.Stack(
              children: [
                pw.Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: pw.Column(
                    children: [
                      pw.Container(height: 4, color: redColor),
                      pw.Container(height: 2, color: blueColor),
                    ],
                  ),
                ),
                pw.Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: pw.Container(height: 4, color: redColor),
                ),
              ],
            );
          },
        ),
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 12),
            // Header Content
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        name,
                        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: blueColor),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Nationality: Nepali', style: const pw.TextStyle(fontSize: 9.5)),
                      if (email.isNotEmpty) pw.Text('Email: $email', style: const pw.TextStyle(fontSize: 9.5)),
                      if (phone.isNotEmpty) pw.Text('Phone: $phone', style: const pw.TextStyle(fontSize: 9.5)),
                    ],
                  ),
                ),
                // Passport Photo Box
                pw.Container(
                  width: 99.2, // ~3.5cm (1cm = 28.35pt)
                  height: 127.5, // ~4.5cm
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey700, width: 1, style: pw.BorderStyle.dashed),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Passport Size\nPhoto',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            // Objective
            if (summary.isNotEmpty) ...[
              _buildNepalHeader('OBJECTIVE', redColor),
              pw.SizedBox(height: 6),
              pw.Text(summary, style: const pw.TextStyle(fontSize: 9.5)),
              pw.SizedBox(height: 16),
            ],

            // Personal Particulars Table
            _buildNepalHeader('PERSONAL PARTICULARS', redColor),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
              children: [
                _buildNepalTableRow('Full Name', name),
                _buildNepalTableRow('Date of Birth', 'Nepal Citizen'),
                _buildNepalTableRow('Gender', 'Male/Female'),
                _buildNepalTableRow('Nationality', 'Nepali'),
                _buildNepalTableRow('Passport Number', personalInfo['passportNo'] as String? ?? '------------------'),
                _buildNepalTableRow('Current Address', location.isNotEmpty ? location : 'Nepal Address'),
                _buildNepalTableRow('Permanent Address', 'Nepal Address'),
              ],
            ),
            pw.SizedBox(height: 16),

            // Work Experience
            if (experiences.isNotEmpty) ...[
              _buildNepalHeader('PROFESSIONAL EXPERIENCE', redColor),
              pw.SizedBox(height: 6),
              ...experiences.map((exp) {
                final item = exp as Map<String, dynamic>;
                final duties = item['responsibilities'] as List? ?? [];
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${item['role']} - ${item['company']} (${item['startDate'] ?? ''} - ${item['current'] == true ? 'Present' : item['endDate'] ?? ''})',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
                      ),
                      pw.SizedBox(height: 4),
                      ...duties.map((duty) => pw.Text('• $duty', style: const pw.TextStyle(fontSize: 9))),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 16),
            ],

            // Education
            if (educations.isNotEmpty) ...[
              _buildNepalHeader('EDUCATION BACKGROUND', redColor),
              pw.SizedBox(height: 6),
              ...educations.map((edu) {
                final item = edu as Map<String, dynamic>;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Text(
                    '• ${item['degree']} in ${item['field']} from ${item['institution']} (${item['startDate'] ?? ''} - ${item['endDate'] ?? ''})',
                    style: const pw.TextStyle(fontSize: 9.5),
                  ),
                );
              }),
              pw.SizedBox(height: 16),
            ],

            // Skills (separated technical/languages)
            if (skillsMap.isNotEmpty) ...[
              _buildNepalHeader('KEY SKILLS & COMPETENCIES', redColor),
              pw.SizedBox(height: 6),
              if (skillsMap['technical'] != null) ...[
                pw.Text('Technical Skills:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text((skillsMap['technical'] as List).join(', '), style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 4),
              ],
              if (skillsMap['languages'] != null) ...[
                pw.Text('Language Skills:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text((skillsMap['languages'] as List).join(', '), style: const pw.TextStyle(fontSize: 9)),
              ],
              pw.SizedBox(height: 16),
            ],

            // Declaration Block
            _buildNepalHeader('DECLARATION', redColor),
            pw.SizedBox(height: 6),
            pw.Text(
              'I hereby declare that all information provided above is true and correct to the best of my knowledge.',
              style: const pw.TextStyle(fontSize: 9.5),
            ),
            pw.SizedBox(height: 32),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Date: ________________', style: const pw.TextStyle(fontSize: 9.5)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('________________________', style: const pw.TextStyle(fontSize: 9.5)),
                    pw.SizedBox(height: 4),
                    pw.Text('Signature of Applicant', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildNepalHeader(String title, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: color),
        ),
        pw.SizedBox(height: 2),
        pw.Container(height: 1, color: color),
      ],
    );
  }

  pw.TableRow _buildNepalTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    );
  }

  // ==========================================
  // SHARED HELPERS
  // ==========================================
  pw.Widget _buildSectionTitle(String title, {required String themeColor}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 12,
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
            fontSize: 11,
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
