import 'dart:io';
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

class PdfService {
  const PdfService();

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
    bool isPro = false,
    DocumentOptions? options,
  }) async {
    final pw.ImageProvider? photoImage = await downloadPhotoForPdf(cv.photoUrl);

    final pdf = await normalTemplate(cv, photoImage: photoImage, isPro: isPro);

    // Appending document pages if enabled
    if (options != null) {
      if (options.includePassport && options.passportUrl != null && options.passportUrl!.isNotEmpty) {
        final img = await downloadPhotoForPdf(options.passportUrl);
        if (img != null) {
          pdf.addPage(_buildDocumentPage("PASSPORT COPY", img));
        }
      }
      if (options.includeCitizenshipFront && options.citizenshipFrontUrl != null && options.citizenshipFrontUrl!.isNotEmpty) {
        final img = await downloadPhotoForPdf(options.citizenshipFrontUrl);
        if (img != null) {
          pdf.addPage(_buildDocumentPage("CITIZENSHIP CERTIFICATE - FRONT", img));
        }
      }
      if (options.includeCitizenshipBack && options.citizenshipBackUrl != null && options.citizenshipBackUrl!.isNotEmpty) {
        final img = await downloadPhotoForPdf(options.citizenshipBackUrl);
        if (img != null) {
          pdf.addPage(_buildDocumentPage("CITIZENSHIP CERTIFICATE - BACK", img));
        }
      }
      if (options.includeBodyPhoto && options.bodyPhotoUrl != null && options.bodyPhotoUrl!.isNotEmpty) {
        final img = await downloadPhotoForPdf(options.bodyPhotoUrl);
        if (img != null) {
          pdf.addPage(_buildDocumentPage("FULL BODY PHOTO", img));
        }
      }
    }

    return pdf.save();
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
                color: PdfColors.grey700,
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

  Future<pw.Document> normalTemplate(CvModel cv, {pw.ImageProvider? photoImage, bool isPro = false}) async {
    final pdf = pw.Document();
    final content = cv.generatedContent;
    final personalInfo = content['personalInfo'] as Map<String, dynamic>? ?? {};
    
    final name = _str(personalInfo['fullName'], 'PERSONAL INFORMATION CV').toUpperCase();
    final fatherName = _str(personalInfo['fatherName']);
    final motherName = _str(personalInfo['motherName']);
    
    final dobBS = _str(personalInfo['dateOfBirthBS']);
    final dobAD = _str(personalInfo['dateOfBirthAD'] ?? personalInfo['dateOfBirth']);
    final dobText = [
      if (dobBS.isNotEmpty) "$dobBS BS",
      if (dobAD.isNotEmpty) "$dobAD AD",
    ].join(' / ');

    final permanentAddress = _str(personalInfo['permanentAddress']);
    final temporaryAddress = _str(personalInfo['temporaryAddress']);
    
    final skillsMap = content['skills'] as Map<String, dynamic>? ?? {};
    final languagesList = skillsMap['languages'] as List? ?? [];
    final languagesKnown = languagesList.map((e) => _str(e)).where((e) => e.isNotEmpty).join(', ');

    final sex = _str(personalInfo['sex']);
    final maritalStatus = _str(personalInfo['maritalStatus']);
    final citizenshipNo = _str(personalInfo['citizenshipNo']);
    final contactNo = _str(personalInfo['phone'] ?? personalInfo['contactNo']);
    final email = _str(personalInfo['email']);

    final educations = content['education'] as List? ?? [];
    final experiences = content['workExperience'] as List? ?? [];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Centered Header
            pw.Center(
              child: pw.Text(
                name,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 12),

            // Info Table and Photo Box Row
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Table(
                    border: pw.TableBorder.symmetric(
                      inside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                    ),
                    children: [
                      _buildTableRow("Father's Name", fatherName),
                      _buildTableRow("Mother's Name", motherName),
                      _buildTableRow("Date of Birth", dobText),
                      _buildTableRow("Permanent Address", permanentAddress),
                      _buildTableRow("Temporary Address", temporaryAddress),
                      _buildTableRow("Language Known", languagesKnown),
                      _buildTableRow("Sex", sex),
                      _buildTableRow("Marital Status", maritalStatus),
                      _buildTableRow("Nationality", "Nepali"),
                      _buildTableRow("Citizenship No", citizenshipNo),
                      _buildTableRow("Contact No", contactNo),
                      _buildTableRow("Email", email),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Container(
                  width: 99,
                  height: 127,
                  decoration: pw.BoxDecoration(
                    border: photoImage == null 
                        ? pw.Border.all(color: PdfColors.grey400, style: pw.BorderStyle.dashed)
                        : null,
                  ),
                  child: photoImage != null
                      ? pw.Image(photoImage, fit: pw.BoxFit.cover)
                      : pw.Center(
                          child: pw.Text(
                            "Photo\n(3.5x4.5 cm)",
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 8),
                          ),
                        ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Education Section
            if (educations.isNotEmpty) ...[
              pw.Text(
                "Education Qualification",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.black),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text("Passout Year", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text("Qualification / Institute", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text("Percentage / GPA", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      ),
                    ],
                  ),
                  ...educations.map((edu) {
                    final year = _str(edu['endDate'] ?? edu['startDate']);
                    final qual = [
                      if (_str(edu['degree']).isNotEmpty) _str(edu['degree']),
                      if (_str(edu['field']).isNotEmpty) "in ${_str(edu['field'])}",
                      if (_str(edu['institution']).isNotEmpty) "- ${_str(edu['institution'])}"
                    ].join(' ');
                    final grade = _str(edu['grade']);
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(year, style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(qual, style: const pw.TextStyle(fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(grade, style: const pw.TextStyle(fontSize: 10)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // Work Experience Section
            if (experiences.isNotEmpty) ...[
              pw.Text(
                "Work Experience",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.black),
              ),
              pw.SizedBox(height: 8),
              ...experiences.map((exp) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "${_str(exp['role'])} at ${_str(exp['company'])}",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                    ),
                    pw.Text(
                      "${_str(exp['startDate'])} to ${_str(exp['endDate'])}",
                      style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 9),
                    ),
                    pw.SizedBox(height: 4),
                    ...((exp['responsibilities'] as List? ?? []).map((resp) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 10, bottom: 2),
                        child: pw.Bullet(
                          text: _str(resp),
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      );
                    })),
                    pw.SizedBox(height: 10),
                  ],
                );
              }),
            ],
          ];
        },
      ),
    );

    return pdf;
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

  Future<Uint8List> generateCoverLetterPdf(CvModel cv, String text, {String? targetCompany}) async {
    final pdf = pw.Document();
    final personalInfo = cv.generatedContent['personalInfo'] as Map<String, dynamic>? ?? {};
    final name = _str(personalInfo['fullName'], 'Applicant');
    final email = _str(personalInfo['email']);
    final phone = _str(personalInfo['phone']);
    final location = _str(personalInfo['location']);
    final linkedin = _str(personalInfo['linkedIn']);
    final portfolio = _str(personalInfo['portfolio']);

    final primaryColor = PdfColor.fromInt(0xFF2C3E50);

    final formattedDate = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    final contactRow = [
      if (email.isNotEmpty) email,
      if (phone.isNotEmpty) phone,
      if (location.isNotEmpty) location,
    ].join(' | ');

    final socialRow = [
      if (linkedin.isNotEmpty) linkedin,
      if (portfolio.isNotEmpty) portfolio,
    ].join(' | ');

    final paragraphs = text.split('\n').where((p) => p.trim().isNotEmpty).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(56),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(height: 4, color: primaryColor),
              pw.SizedBox(height: 12),
              pw.Text(
                name,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(contactRow, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              if (socialRow.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(socialRow, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColors.grey300, thickness: 1),
              pw.SizedBox(height: 16),
              pw.Align(
                alignment: pw.Alignment.topRight,
                child: pw.Text(
                  formattedDate,
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                targetCompany != null && targetCompany.isNotEmpty
                    ? 'Dear $targetCompany Team,'
                    : 'Dear Hiring Manager,',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 16),
              ...paragraphs.map((p) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Text(
                    p,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  )),
              pw.SizedBox(height: 20),
              pw.Text('Sincerely,', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 16),
              pw.Text(
                name,
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<String> saveCoverLetterPdfToDevice(Uint8List bytes, String fullName) async {
    final cleanName = fullName.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = '${cleanName}_CoverLetter_$timestamp.pdf';

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$filename';
    final file = File(path);
    await file.writeAsBytes(bytes);
    return path;
  }

  String _str(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;
    final s = value.toString().trim();
    if (s.isEmpty || s == 'null' || s == 'N/A' || 
        s == 'Not mentioned' || s == 'undefined' ||
        s == 'None' || s == 'n/a') return fallback;
    return s;
  }
}
