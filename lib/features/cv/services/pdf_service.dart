import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/cv_model.dart';
import 'package:intl/intl.dart';

class DocumentOptions {
  final bool includePassport;
  final String? passportUrl;
  final bool includeCitizenshipFront;
  final String? citizenshipFrontUrl;
  final bool includeCitizenshipBack;
  final String? citizenshipBackUrl;
  final bool includeBodyPhoto;
  final String? bodyPhotoUrl;

  const DocumentOptions({
    this.includePassport = false,
    this.passportUrl,
    this.includeCitizenshipFront = false,
    this.citizenshipFrontUrl,
    this.includeCitizenshipBack = false,
    this.citizenshipBackUrl,
    this.includeBodyPhoto = false,
    this.bodyPhotoUrl,
  });
}

class SizeTier {
  final double nameSize, contactSize, headerSize, bodySize;
  final double lineSpacing, sectionGap, entryGap;
  const SizeTier({
    required this.nameSize,
    required this.contactSize,
    required this.headerSize,
    required this.bodySize,
    required this.lineSpacing,
    required this.sectionGap, 
    required this.entryGap,
  });
}

class PdfService {
  const PdfService();

  static const _pdfInk = PdfColor.fromInt(0xFF14141C);
  static const _pdfInkSecondary = PdfColor.fromInt(0xFF6B6B76);
  static const _pdfGold = PdfColor.fromInt(0xFFB8935B);
  static const _pdfDivider = PdfColor.fromInt(0xFFE4E1D8);
  static const _pdfWhite = PdfColor.fromInt(0xFFFFFFFF);
  static const _pdfBlack = PdfColor.fromInt(0xFF000000);

  static const _tierSpacious = SizeTier(
    nameSize: 22, contactSize: 9, headerSize: 10, bodySize: 9.5,
    lineSpacing: 1.4, sectionGap: 16, entryGap: 10);

  static const _tierStandard = SizeTier(
    nameSize: 20, contactSize: 8.5, headerSize: 9.5, bodySize: 9,
    lineSpacing: 1.3, sectionGap: 12, entryGap: 8);

  static const _tierCompact = SizeTier(
    nameSize: 18, contactSize: 8, headerSize: 9, bodySize: 8.3,
    lineSpacing: 1.2, sectionGap: 8, entryGap: 6);

  SizeTier _selectTier(int score) {
    if (score <= 12) return _tierSpacious;
    if (score <= 22) return _tierStandard;
    return _tierCompact;
  }

  int _computeDensityScore(Map<String, dynamic> data) {
    final workExp = _mapList(data['workExperience']);
    final education = _mapList(data['education']);
    final certifications = _mapList(data['certifications']);
    final projects = _mapList(data['projects']);
    final achievements = _list(data['achievements']);
    final summary = _str(data['summary']);
    
    int bulletCount = 0;
    for (final job in workExp) {
      bulletCount += _list(job['responsibilities']).length;
    }
    
    return (workExp.length * 3) 
      + bulletCount 
      + (education.length * 2) 
      + certifications.length 
      + (projects.length * 2) 
      + achievements.length 
      + (summary.length ~/ 100);
  }

  static Future<pw.ImageProvider?> downloadPhotoForPdf(String? photoUrl) async {
    if (photoUrl == null || photoUrl.trim().isEmpty) {
      debugPrint('PDF: No photo URL provided');
      return null;
    }
    
    debugPrint('PDF: Downloading photo from $photoUrl');
    
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(photoUrl));
      request.headers['Accept'] = 'image/*';
      
      final streamedResponse = await client.send(request)
        .timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);
      client.close();
      
      debugPrint('PDF: Photo response ${response.statusCode}, '
        'bytes: ${response.bodyBytes.length}');
      
      if (response.statusCode == 200 && 
          response.bodyBytes.isNotEmpty) {
        return pw.MemoryImage(response.bodyBytes);
      }
    } catch (e) {
      debugPrint('PDF: Photo download error: $e');
    }
    return null;
  }

  Future<Uint8List> generatePdf(
    CvModel cv,
    String templateName, { // Keep parameter to avoid breaking calls in preview_screen
    DocumentOptions? options,
  }) async {
    try {
      final results = await Future.wait([
        downloadPhotoForPdf(cv.photoUrl),
        options != null && options.includePassport && options.passportUrl != null
          ? downloadPhotoForPdf(options.passportUrl) 
          : Future.value(null),
        options != null && options.includeCitizenshipFront && options.citizenshipFrontUrl != null
          ? downloadPhotoForPdf(options.citizenshipFrontUrl) 
          : Future.value(null),
        options != null && options.includeCitizenshipBack && options.citizenshipBackUrl != null
          ? downloadPhotoForPdf(options.citizenshipBackUrl) 
          : Future.value(null),
        options != null && options.includeBodyPhoto && options.bodyPhotoUrl != null
          ? downloadPhotoForPdf(options.bodyPhotoUrl) 
          : Future.value(null),
      ]);

      final photoImage = results[0];
      final passportImage = results[1];
      final citFrontImage = results[2];
      final citBackImage = results[3];
      final bodyImage = results[4];

      final score = _computeDensityScore(cv.generatedContent);
      final tier = _selectTier(score);
      debugPrint('CV density score: $score, using tier: ${tier == _tierCompact ? "compact" : tier == _tierStandard ? "standard" : "spacious"}');

      final pdf = await normalTemplate(cv, photoImage: photoImage, tier: tier);

      // Appending document pages sequentially using the pre-downloaded images
      if (options != null) {
        if (options.includePassport && passportImage != null) {
          pdf.addPage(_buildDocumentPage("PASSPORT COPY", passportImage));
        }
        if (options.includeCitizenshipFront && citFrontImage != null) {
          pdf.addPage(_buildDocumentPage("CITIZENSHIP CERTIFICATE - FRONT", citFrontImage));
        }
        if (options.includeCitizenshipBack && citBackImage != null) {
          pdf.addPage(_buildDocumentPage("CITIZENSHIP CERTIFICATE - BACK", citBackImage));
        }
        if (options.includeBodyPhoto && bodyImage != null) {
          pdf.addPage(_buildDocumentPage("FULL BODY PHOTO", bodyImage));
        }
      }

      return pdf.save();
    } catch (e, stack) {
      debugPrint('PDF generation error: $e\n$stack');
      throw Exception("Some details couldn't be displayed. Try editing your CV.");
    }
  }

  pw.Page _buildDocumentPage(String label, pw.ImageProvider image) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _pdfInkSecondary,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Expanded(
              child: pw.Center(
                child: pw.Image(
                  image,
                  fit: pw.BoxFit.contain,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<pw.Document> normalTemplate(CvModel cv, {pw.ImageProvider? photoImage, required SizeTier tier}) async {
    final pdfTheme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
    );
    final pdf = pw.Document(theme: pdfTheme);
    final content = cv.generatedContent;
    final personalInfo = content['personalInfo'] is Map
        ? Map<String, dynamic>.from(content['personalInfo'] as Map)
        : <String, dynamic>{};

    // ── Page 1: Professional CV ──────────────────────────────────────────────
    final name = _str(personalInfo['fullName'], 'Applicant');
    final jobTitle = _str(personalInfo['jobTitle'] ?? personalInfo['position']);
    final email = _str(personalInfo['email']);
    final phone = _str(personalInfo['phone']).isNotEmpty
        ? _str(personalInfo['phone'])
        : _str(personalInfo['contactNo']);
    final location = _str(personalInfo['location']);
    final linkedin = _str(personalInfo['linkedIn'] ?? personalInfo['linkedin']);
    final website = _str(personalInfo['portfolio'] ?? personalInfo['website']);
    final summary = _str(content['summary']);

    final educations = _list(content['education']);
    final experiences = _list(content['workExperience']);
    final skills = content['skills'];
    final certifications = _list(content['certifications']);
    final projects = _list(content['projects']);
    final achievements = _list(content['achievements']);
    final references = _list(content['references']);

    final contactParts = [
      if (email.isNotEmpty) email,
      if (phone.isNotEmpty) phone,
      if (location.isNotEmpty) location,
      if (linkedin.isNotEmpty) linkedin,
      if (website.isNotEmpty) website,
    ];

    const ink = _pdfInk;
    const gold = _pdfGold;
    const muted = _pdfInkSecondary;
    const divider = _pdfDivider;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        build: (pw.Context context) {
          return [
            // Header row: name/title/contact + optional photo
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (name.isNotEmpty)
                        pw.Text(
                          name,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: tier.nameSize,
                            color: ink,
                          ),
                        ),
                      if (jobTitle.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          jobTitle,
                          style: pw.TextStyle(fontSize: tier.contactSize + 2, color: gold),
                        ),
                      ],
                      if (contactParts.isNotEmpty) ...[
                        pw.SizedBox(height: tier.entryGap * 0.75),
                        pw.Container(width: double.infinity, height: 0.5, color: divider),
                        pw.SizedBox(height: tier.entryGap * 0.5),
                        pw.Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          children: contactParts
                              .map((p) => pw.Text(
                                    p,
                                    style: pw.TextStyle(
                                      fontSize: tier.contactSize,
                                      color: muted,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                if (photoImage != null) ...[
                  pw.SizedBox(width: 16),
                  pw.Container(
                    width: 70,
                    height: 70,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: divider, width: 0.75),
                    ),
                    child: pw.Image(photoImage, fit: pw.BoxFit.cover),
                  ),
                ],
              ],
            ),
            pw.SizedBox(height: tier.entryGap + 4),

            // Summary
            if (summary.isNotEmpty) ...[
              _buildProfSectionHeader('PROFESSIONAL SUMMARY', ink, gold, tier: tier),
              pw.Text(
                summary,
                style: pw.TextStyle(
                  fontSize: tier.bodySize,
                  color: ink,
                  height: tier.lineSpacing,
                ),
              ),
              pw.SizedBox(height: tier.sectionGap),
            ],

            // Work Experience
            if (experiences.isNotEmpty) ...[
              _buildProfSectionHeader('WORK EXPERIENCE', ink, gold, tier: tier),
              ...experiences.map((exp) => _buildProfExpItem(exp, ink, gold, muted, tier: tier)),
              pw.SizedBox(height: tier.sectionGap - tier.entryGap),
            ],

            // Education
            if (educations.isNotEmpty) ...[
              _buildProfSectionHeader('EDUCATION', ink, gold, tier: tier),
              ...educations.map((edu) => _buildProfEduItem(edu, ink, gold, muted, tier: tier)),
              pw.SizedBox(height: tier.sectionGap - tier.entryGap),
            ],

            // Skills
            if (skills != null) ...[
              _buildProfSectionHeader('SKILLS', ink, gold, tier: tier),
              _buildProfSkills(skills, ink, muted, divider, tier: tier),
              pw.SizedBox(height: tier.sectionGap),
            ],

            // Certifications
            if (certifications.isNotEmpty) ...[
              _buildProfSectionHeader('CERTIFICATIONS', ink, gold, tier: tier),
              ...certifications.map((c) => _buildProfCertItem(c, ink, muted, tier: tier)),
              pw.SizedBox(height: tier.sectionGap - (tier.entryGap * 0.5)),
            ],

            // Projects
            if (projects.isNotEmpty) ...[
              _buildProfSectionHeader('PROJECTS', ink, gold, tier: tier),
              ...projects.map((p) => _buildProfProjectItem(p, ink, gold, muted, tier: tier)),
              pw.SizedBox(height: tier.sectionGap - tier.entryGap),
            ],

            // Achievements
            if (achievements.isNotEmpty) ...[
              _buildProfSectionHeader('ACHIEVEMENTS', ink, gold, tier: tier),
              ...achievements.map((a) => _buildProfAchievementItem(a, ink, muted, tier: tier)),
              pw.SizedBox(height: tier.sectionGap - (tier.entryGap * 0.5)),
            ],

            // References
            if (references.isNotEmpty) ...[
              _buildProfSectionHeader('REFERENCES', ink, gold, tier: tier),
              ...references.map((r) => _buildProfReferenceItem(r, ink, gold, muted, tier: tier)),
            ],
          ];
        },
      ),
    );

    // ── Page 2: Nepal Personal Info (conditional) ────────────────────────────
    if (_hasNepalInfo(personalInfo)) {
      pdf.addPage(_buildNepalInfoPage(personalInfo, skills));
    }

    return pdf;
  }

  /// Returns true if any Nepal-specific personal info fields are non-empty.
  bool _hasNepalInfo(Map<String, dynamic> info) {
    final fields = [
      info['fatherName'],
      info['motherName'],
      info['dateOfBirthBS'],
      info['sex'],
      info['maritalStatus'],
      info['citizenshipNo'],
      info['permanentAddress'],
      info['temporaryAddress'],
    ];
    return fields.any((f) => _str(f).isNotEmpty);
  }

  /// Builds a plain-styled Nepal Personal Information page.
  /// Pure white background, pure black text, Helvetica only, no accent colors.
  pw.Page _buildNepalInfoPage(Map<String, dynamic> info, dynamic skills) {
    const black = _pdfBlack;

    final languagesVal = skills is Map ? skills['languages'] : null;
    final languagesList = _list(languagesVal);
    final languagesStr = languagesList.map(_str).join(', ');

    final rows = [
      ['Full Name', info['fullName']],
      ["Father's Name", info['fatherName']],
      ["Mother's Name", info['motherName']],
      ['Date of Birth (BS)', info['dateOfBirthBS']],
      ['Sex', info['sex']],
      ['Marital Status', info['maritalStatus']],
      ['Citizenship No', info['citizenshipNo']],
      ['Permanent Address', info['permanentAddress']],
      ['Temporary Address', info['temporaryAddress']],
      if (languagesStr.isNotEmpty) ['Language Known', languagesStr],
    ].where((row) => _str(row[1]).isNotEmpty).toList();

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Text(
              'PERSONAL INFORMATION',
              style: pw.TextStyle(
                font: pw.Font.helveticaBold(),
                fontSize: 12,
                color: black,
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(width: double.infinity, height: 1, color: black),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: black, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
            },
            children: rows.map((row) {
              return pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: pw.Text(
                      _str(row[0]),
                      style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: 9,
                        color: black,
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: pw.Text(
                      _str(row[1]),
                      style: pw.TextStyle(
                        font: pw.Font.helvetica(),
                        fontSize: 9,
                        color: black,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Professional CV helper widgets ────────────────────────────────────────

  pw.Widget _buildProfSectionHeader(String title, PdfColor ink, PdfColor gold, {required SizeTier tier}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: tier.headerSize,
            letterSpacing: 1.2,
            color: ink,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Container(width: double.infinity, height: 0.75, color: gold),
        pw.SizedBox(height: tier.entryGap * 0.75),
      ],
    );
  }

  pw.Widget _buildProfExpItem(dynamic exp, PdfColor ink, PdfColor gold, PdfColor muted, {required SizeTier tier}) {
    if (exp is! Map) return pw.SizedBox.shrink();
    final company = _str(exp['company']);
    final role = _str(exp['role'] ?? exp['position'] ?? exp['title']);
    final start = _str(exp['startDate']);
    final end = _str(exp['endDate']);
    final period = [start, if (end.isNotEmpty) end].join(' - ');
    final responsibilities = _list(exp['responsibilities']);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(role.isNotEmpty ? role : company,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: tier.bodySize + 1.0, color: ink)),
            ),
            if (period.isNotEmpty)
              pw.Text(period, style: pw.TextStyle(fontSize: tier.contactSize, color: muted)),
          ],
        ),
        if (role.isNotEmpty && company.isNotEmpty)
          pw.Text(company, style: pw.TextStyle(fontSize: tier.bodySize, color: gold)),
        pw.SizedBox(height: 3),
        ...responsibilities.map((r) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('- ', style: pw.TextStyle(fontSize: tier.bodySize, color: ink)),
                  pw.Expanded(
                      child: pw.Text(_str(r),
                          style: pw.TextStyle(fontSize: tier.bodySize, color: ink, height: tier.lineSpacing))),
                ],
              ),
            )),
        pw.SizedBox(height: tier.entryGap),
      ],
    );
  }

  pw.Widget _buildProfEduItem(dynamic edu, PdfColor ink, PdfColor gold, PdfColor muted, {required SizeTier tier}) {
    if (edu is! Map) return pw.SizedBox.shrink();
    final institution = _str(edu['institution'] ?? edu['school']);
    final degree = _str(edu['degree']);
    final field = _str(edu['field'] ?? edu['fieldOfStudy']);
    final year = _str(edu['endDate'] ?? edu['startDate']);
    final grade = _str(edu['grade'] ?? edu['gpa']);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(degree.isNotEmpty ? degree : institution,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: tier.bodySize + 1.0, color: ink)),
            ),
            if (year.isNotEmpty)
              pw.Text(year, style: pw.TextStyle(fontSize: tier.contactSize, color: muted)),
          ],
        ),
        if (institution.isNotEmpty && degree.isNotEmpty)
          pw.Text(institution, style: pw.TextStyle(fontSize: tier.bodySize, color: gold)),
        if (field.isNotEmpty)
          pw.Text(field, style: pw.TextStyle(fontSize: tier.bodySize, color: muted)),
        if (grade.isNotEmpty)
          pw.Text('GPA/Grade: $grade', style: pw.TextStyle(fontSize: tier.bodySize, color: muted)),
        pw.SizedBox(height: tier.entryGap),
      ],
    );
  }

  pw.Widget _buildProfSkills(dynamic skills, PdfColor ink, PdfColor muted, PdfColor divider, {required SizeTier tier}) {
    if (skills is Map) {
      final rows = <pw.Widget>[];
      skills.forEach((key, val) {
        final items = val is List ? val.map(_str).join(', ') : _str(val);
        if (items.isEmpty) return;
        rows.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 90,
                child: pw.Text('$key:',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: tier.bodySize, color: ink)),
              ),
              pw.Expanded(
                  child: pw.Text(items,
                      style: pw.TextStyle(fontSize: tier.bodySize, color: ink, height: tier.lineSpacing))),
            ],
          ),
        ));
      });
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: rows);
    } else if (skills is List) {
      return pw.Wrap(
        spacing: 8,
        runSpacing: 4,
        children: _list(skills).map<pw.Widget>((s) {
          return pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: divider, width: 0.75),
            ),
            child: pw.Text(_str(s),
                style: pw.TextStyle(fontSize: tier.bodySize - 0.5, color: ink)),
          );
        }).toList(),
      );
    }
    return pw.SizedBox.shrink();
  }

  pw.Widget _buildProfCertItem(dynamic cert, PdfColor ink, PdfColor muted, {required SizeTier tier}) {
    String name = '';
    String issuer = '';
    String date = '';
    if (cert is Map) {
      name = _str(cert['name'] ?? cert['title']);
      issuer = _str(cert['issuer'] ?? cert['organization']);
      date = _str(cert['date'] ?? cert['year']);
    } else {
      name = _str(cert);
    }
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: tier.entryGap * 0.5),
      child: pw.Row(
        children: [
          pw.Expanded(
              child: pw.Text(name,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: tier.bodySize + 0.5, color: ink))),
          if (issuer.isNotEmpty || date.isNotEmpty)
            pw.Text([issuer, date].where((s) => s.isNotEmpty).join(', '),
                style: pw.TextStyle(fontSize: tier.contactSize, color: muted)),
        ],
      ),
    );
  }

  pw.Widget _buildProfProjectItem(dynamic proj, PdfColor ink, PdfColor gold, PdfColor muted, {required SizeTier tier}) {
    if (proj is! Map) return pw.SizedBox.shrink();
    final name = _str(proj['name'] ?? proj['title']);
    final desc = _str(proj['description']);
    final tech = proj['technologies'] ?? proj['tech'];
    final techStr = tech is List ? tech.map(_str).join(', ') : _str(tech);
    final link = _str(proj['link'] ?? proj['url']);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(name,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: tier.bodySize + 1.0, color: ink)),
        if (desc.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(desc, style: pw.TextStyle(fontSize: tier.bodySize, color: ink, height: tier.lineSpacing)),
        ],
        if (techStr.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text('Tech: $techStr',
              style: pw.TextStyle(fontSize: tier.bodySize - 0.5, color: muted)),
        ],
        if (link.isNotEmpty) ...[
          pw.SizedBox(height: 2),
          pw.Text(link, style: pw.TextStyle(fontSize: tier.bodySize - 0.5, color: gold)),
        ],
        pw.SizedBox(height: tier.entryGap),
      ],
    );
  }

  pw.Widget _buildProfAchievementItem(dynamic item, PdfColor ink, PdfColor muted, {required SizeTier tier}) {
    String title = '';
    String desc = '';
    if (item is Map) {
      title = _str(item['title'] ?? item['name']);
      desc = _str(item['description']);
    } else {
      title = _str(item);
    }
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: tier.entryGap * 0.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('- ', style: pw.TextStyle(fontSize: tier.bodySize, color: ink)),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: tier.bodySize + 0.5, color: ink)),
                if (desc.isNotEmpty)
                  pw.Text(desc,
                      style: pw.TextStyle(fontSize: tier.bodySize, color: muted, height: tier.lineSpacing)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildProfReferenceItem(dynamic ref, PdfColor ink, PdfColor gold, PdfColor muted, {required SizeTier tier}) {
    if (ref is! Map) return pw.SizedBox.shrink();
    final name = _str(ref['name']);
    final position = _str(ref['position'] ?? ref['title']);
    final company = _str(ref['company'] ?? ref['organization']);
    final contact = _str(ref['contact'] ?? ref['email'] ?? ref['phone']);
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: tier.entryGap * 0.75),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(name,
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: tier.bodySize + 0.5, color: ink)),
          if (position.isNotEmpty || company.isNotEmpty)
            pw.Text([position, company].where((s) => s.isNotEmpty).join(', '),
                style: pw.TextStyle(fontSize: tier.bodySize, color: muted)),
          if (contact.isNotEmpty)
            pw.Text(contact, style: pw.TextStyle(fontSize: tier.bodySize, color: gold)),
        ],
      ),
    );
  }

  pw.TableRow _buildTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          child: pw.Text(
            value.isNotEmpty ? value : '-',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
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



  String _sanitizeForPdf(String input) {
    if (input.isEmpty) return input;
    
    String result = input
      .replaceAll('\u2013', '-')   // en dash
      .replaceAll('\u2014', '-')   // em dash
      .replaceAll('\u2022', '-')   // bullet
      .replaceAll('\u00B7', '-')   // middle dot
      .replaceAll('\u2192', 'to') // right arrow
      .replaceAll('\u2018', "'")  // left single smart quote
      .replaceAll('\u2019', "'")  // right single smart quote
      .replaceAll('\u201C', '"')  // left double smart quote
      .replaceAll('\u201D', '"')  // right double smart quote
      .replaceAll('\u2026', '...') // ellipsis
      .replaceAll('\u25B6', '>')  // triangle
      .replaceAll('\u2192', '>'); // arrow
    
    // Strip any remaining non-ASCII-printable character that 
    // Helvetica cannot render, rather than let a tofu box appear
    result = result.replaceAll(
      RegExp(r'[^\x20-\x7E]'), '');
    
    return result;
  }

  String _str(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final s = value.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'N/A' || 
        s == 'Not mentioned' || s == 'undefined' ||
        s == 'None' || s == 'n/a') return fallback;
    return _sanitizeForPdf(s);
  }

  List<dynamic> _list(dynamic value) {
    if (value is List) {
      return value.map((e) {
        if (e is String) return _sanitizeForPdf(e);
        if (e is Map) {
          final cleanMap = <String, dynamic>{};
          e.forEach((k, v) {
            cleanMap[k.toString()] = v is String ? _sanitizeForPdf(v) : v;
          });
          return cleanMap;
        }
        return e;
      }).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is List) {
      return value.map((e) {
        if (e is Map) {
          final cleanMap = <String, dynamic>{};
          e.forEach((key, val) {
            if (val is String) {
              cleanMap[key.toString()] = _sanitizeForPdf(val);
            } else if (val is List) {
              cleanMap[key.toString()] = _list(val);
            } else if (val is Map) {
              final nestedMap = <String, dynamic>{};
              val.forEach((nk, nv) {
                nestedMap[nk.toString()] = nv is String ? _sanitizeForPdf(nv) : nv;
              });
              cleanMap[key.toString()] = nestedMap;
            } else {
              cleanMap[key.toString()] = val;
            }
          });
          return cleanMap;
        }
        return <String, dynamic>{};
      }).toList();
    }
    return [];
  }
}
