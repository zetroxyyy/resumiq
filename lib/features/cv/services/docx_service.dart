import 'dart:typed_data';
import 'package:archive/archive.dart';
import '../models/cv_model.dart';

class DocxService {
  const DocxService();

  Uint8List generateDocx(CvModel cv) {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, contentTypesXml.codeUnits));

    // 2. _rels/.rels
    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, relsXml.codeUnits));

    // 3. word/_rels/document.xml.rels
    const documentRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', documentRelsXml.length, documentRelsXml.codeUnits));

    // 4. word/styles.xml
    const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
        <w:sz w:val="22"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
      <w:sz w:val="22"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:spacing w:before="240" w:after="120"/>
    </w:pPr>
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
      <w:b/>
      <w:sz w:val="36"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:spacing w:before="180" w:after="60"/>
    </w:pPr>
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
      <w:b/>
      <w:sz w:val="28"/>
    </w:rPr>
  </w:style>
</w:styles>''';
    archive.addFile(ArchiveFile('word/styles.xml', stylesXml.length, stylesXml.codeUnits));

    // 5. word/document.xml
    final documentXml = _buildDocumentXml(cv);
    archive.addFile(ArchiveFile('word/document.xml', documentXml.length, documentXml.codeUnits));

    final encoder = ZipEncoder();
    final bytes = encoder.encode(archive);
    return Uint8List.fromList(bytes);
  }

  Uint8List generateCoverLetterDocx(CvModel cv, String text, {String? targetCompany}) {
    final archive = Archive();

    // 1. [Content_Types].xml
    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';
    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, contentTypesXml.codeUnits));

    // 2. _rels/.rels
    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, relsXml.codeUnits));

    // 3. word/_rels/document.xml.rels
    const documentRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', documentRelsXml.length, documentRelsXml.codeUnits));

    // 4. word/styles.xml
    const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
        <w:sz w:val="22"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
      <w:sz w:val="22"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:qFormat/>
    <w:pPr>
      <w:spacing w:before="240" w:after="120"/>
    </w:pPr>
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
      <w:b/>
      <w:sz w:val="36"/>
    </w:rPr>
  </w:style>
</w:styles>''';
    archive.addFile(ArchiveFile('word/styles.xml', stylesXml.length, stylesXml.codeUnits));

    // 5. word/document.xml
    final documentXml = _buildCoverLetterXml(cv, text, targetCompany: targetCompany);
    archive.addFile(ArchiveFile('word/document.xml', documentXml.length, documentXml.codeUnits));

    final encoder = ZipEncoder();
    final bytes = encoder.encode(archive);
    return Uint8List.fromList(bytes);
  }

  String _buildCoverLetterXml(CvModel cv, String text, {String? targetCompany}) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    buffer.write('<w:body>');

    final personalInfo = cv.generatedContent['personalInfo'] as Map<String, dynamic>? ?? {};
    final name = personalInfo['fullName'] as String? ?? 'Applicant';
    final email = personalInfo['email'] as String? ?? '';
    final phone = personalInfo['phone'] as String? ?? '';
    final location = personalInfo['location'] as String? ?? '';
    final linkedin = personalInfo['linkedIn'] as String? ?? '';
    final portfolio = personalInfo['portfolio'] as String? ?? '';

    // Name (Heading 1)
    buffer.write(_paragraph(name, style: 'Heading1'));

    // Contact info (Normal style)
    final contactParts = [
      if (email.isNotEmpty) email,
      if (phone.isNotEmpty) phone,
      if (location.isNotEmpty) location,
      if (linkedin.isNotEmpty) linkedin,
      if (portfolio.isNotEmpty) portfolio,
    ];
    if (contactParts.isNotEmpty) {
      buffer.write(_paragraph(contactParts.join(' | '), style: 'Normal'));
    }

    // Spacer
    buffer.write(_spacer());

    // Date
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    buffer.write('<w:p>'
        '<w:pPr><w:jc w:val="right"/></w:pPr>'
        '<w:r><w:t>${_escapeXml(dateStr)}</w:t></w:r>'
        '</w:p>');

    buffer.write(_spacer());

    // Salutation
    final salutation = targetCompany != null && targetCompany.isNotEmpty
        ? 'Dear $targetCompany Team,'
        : 'Dear Hiring Manager,';
    buffer.write(_paragraph(salutation));
    buffer.write(_spacer());

    // Body paragraphs
    final paragraphs = text.split('\n').where((p) => p.trim().isNotEmpty).toList();
    for (final p in paragraphs) {
      buffer.write(_paragraph(p));
      buffer.write(_spacer());
    }

    buffer.write(_spacer());

    // Closing
    buffer.write(_paragraph('Sincerely,'));
    buffer.write(_spacer());
    buffer.write(_compositeParagraph([
      _run(name, bold: true),
    ]));

    // Standard margins 2.54cm (1440 twips)
    buffer.write('<w:sectPr>');
    buffer.write('<w:pgSz w:w="11906" w:h="16838"/>');
    buffer.write('<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>');
    buffer.write('</w:sectPr>');

    buffer.write('</w:body>');
    buffer.write('</w:document>');
    return buffer.toString();
  }

  String _buildDocumentXml(CvModel cv) {
    final buffer = StringBuffer();
    buffer.write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');
    buffer.write('<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">');
    buffer.write('<w:body>');

    final content = cv.generatedContent;
    final personalInfo = content['personalInfo'] as Map<String, dynamic>? ?? {};
    final summary = content['summary'] as String? ?? '';
    final experiences = content['workExperience'] as List? ?? [];
    final educations = content['education'] as List? ?? [];
    final skillsMap = content['skills'] as Map<String, dynamic>? ?? {};
    final certifications = content['certifications'] as List? ?? [];
    final projects = content['projects'] as List? ?? [];
    final achievements = content['achievements'] as List? ?? [];

    final name = personalInfo['fullName'] as String? ?? 'Professional CV';
    final email = personalInfo['email'] as String? ?? '';
    final phone = personalInfo['phone'] as String? ?? '';
    final location = personalInfo['location'] as String? ?? '';
    final linkedin = personalInfo['linkedIn'] as String? ?? '';
    final portfolio = personalInfo['portfolio'] as String? ?? '';

    // Name (Heading 1)
    buffer.write(_paragraph(name, style: 'Heading1'));

    // Contact info (Normal style)
    final contactParts = [
      if (email.isNotEmpty) email,
      if (phone.isNotEmpty) phone,
      if (location.isNotEmpty) location,
      if (linkedin.isNotEmpty) linkedin,
      if (portfolio.isNotEmpty) portfolio,
    ];
    if (contactParts.isNotEmpty) {
      buffer.write(_paragraph(contactParts.join(' | '), style: 'Normal'));
    }

    // Space
    buffer.write(_spacer());

    // Summary Section
    if (summary.isNotEmpty) {
      buffer.write(_paragraph('Summary', style: 'Heading2'));
      buffer.write(_paragraph(summary, style: 'Normal'));
      buffer.write(_spacer());
    }

    // Work Experience Section
    if (experiences.isNotEmpty) {
      buffer.write(_paragraph('Work Experience', style: 'Heading2'));
      for (final exp in experiences) {
        final item = exp as Map<String, dynamic>;
        final role = item['role'] as String? ?? '';
        final company = item['company'] as String? ?? '';
        final start = item['startDate'] ?? '';
        final end = item['current'] == true ? 'Present' : item['endDate'] ?? '';
        final dateStr = '$start - $end';

        buffer.write(_compositeParagraph([
          _run('$role at $company', bold: true),
          _run('  |  ', bold: false),
          _run(dateStr, italic: true),
        ]));

        final duties = item['responsibilities'] as List? ?? [];
        for (final duty in duties) {
          buffer.write(_bullet(duty as String));
        }
        buffer.write(_spacer());
      }
    }

    // Education Section
    if (educations.isNotEmpty) {
      buffer.write(_paragraph('Education', style: 'Heading2'));
      for (final edu in educations) {
        final item = edu as Map<String, dynamic>;
        final degree = item['degree'] as String? ?? '';
        final field = item['field'] as String? ?? '';
        final school = item['institution'] as String? ?? '';
        final start = item['startDate'] ?? '';
        final end = item['endDate'] ?? '';
        final grade = item['grade'] as String? ?? '';
        final gradeStr = grade.isNotEmpty ? ' (Grade: $grade)' : '';

        buffer.write(_compositeParagraph([
          _run('$degree in $field', bold: true),
          _run(' - $school', bold: false),
          _run('  |  ', bold: false),
          _run('$start - $end$gradeStr', italic: true),
        ]));
        buffer.write(_spacer());
      }
    }

    // Skills Section
    if (skillsMap.isNotEmpty) {
      buffer.write(_paragraph('Skills', style: 'Heading2'));
      if (skillsMap['technical'] != null) {
        buffer.write(_compositeParagraph([
          _run('Technical Skills: ', bold: true),
          _run((skillsMap['technical'] as List).join(', ')),
        ]));
      }
      if (skillsMap['soft'] != null) {
        buffer.write(_compositeParagraph([
          _run('Soft Skills: ', bold: true),
          _run((skillsMap['soft'] as List).join(', ')),
        ]));
      }
      if (skillsMap['languages'] != null) {
        buffer.write(_compositeParagraph([
          _run('Languages: ', bold: true),
          _run((skillsMap['languages'] as List).join(', ')),
        ]));
      }
      buffer.write(_spacer());
    }

    // Projects Section
    if (projects.isNotEmpty) {
      buffer.write(_paragraph('Projects', style: 'Heading2'));
      for (final proj in projects) {
        final item = proj as Map<String, dynamic>;
        final name = item['name'] as String? ?? '';
        final desc = item['description'] as String? ?? '';
        final tech = item['tech'] as List? ?? [];

        buffer.write(_compositeParagraph([
          _run(name, bold: true),
          if (tech.isNotEmpty) _run(' (${tech.join(', ')})', italic: true),
        ]));
        if (desc.isNotEmpty) {
          buffer.write(_paragraph(desc));
        }
        buffer.write(_spacer());
      }
    }

    // Certifications Section
    if (certifications.isNotEmpty) {
      buffer.write(_paragraph('Certifications', style: 'Heading2'));
      for (final cert in certifications) {
        final item = cert as Map<String, dynamic>;
        final name = item['name'] as String? ?? '';
        final issuer = item['issuer'] as String? ?? '';
        final date = item['date'] as String? ?? '';

        buffer.write(_compositeParagraph([
          _run(name, bold: true),
          _run(' - $issuer ($date)'),
        ]));
      }
      buffer.write(_spacer());
    }

    // Achievements Section
    if (achievements.isNotEmpty) {
      buffer.write(_paragraph('Achievements', style: 'Heading2'));
      for (final ach in achievements) {
        buffer.write(_bullet(ach as String));
      }
      buffer.write(_spacer());
    }

    // Standard margins 2.54cm (1440 twips)
    buffer.write('<w:sectPr>');
    buffer.write('<w:pgSz w:w="11906" w:h="16838"/>');
    buffer.write('<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>');
    buffer.write('</w:sectPr>');

    buffer.write('</w:body>');
    buffer.write('</w:document>');
    return buffer.toString();
  }

  String _paragraph(String text, {String style = 'Normal'}) {
    final escaped = _escapeXml(text);
    return '<w:p>'
        '<w:pPr><w:pStyle w:val="$style"/></w:pPr>'
        '<w:r><w:t>$escaped</w:t></w:r>'
        '</w:p>';
  }

  String _compositeParagraph(List<String> runs) {
    return '<w:p>'
        '<w:pPr><w:pStyle w:val="Normal"/></w:pPr>'
        '${runs.join()}'
        '</w:p>';
  }

  String _run(String text, {bool bold = false, bool italic = false}) {
    final escaped = _escapeXml(text);
    final bTag = bold ? '<w:b/>' : '';
    final iTag = italic ? '<w:i/>' : '';
    return '<w:r>'
        '<w:rPr>$bTag$iTag</w:rPr>'
        '<w:t xml:space="preserve">$escaped</w:t>'
        '</w:r>';
  }

  String _bullet(String text) {
    final escaped = _escapeXml(text);
    return '<w:p>'
        '<w:pPr>'
        '<w:pStyle w:val="Normal"/>'
        '<w:ind w:left="720" w:hanging="360"/>'
        '</w:pPr>'
        '<w:r><w:t xml:space="preserve">•  </w:t></w:r>'
        '<w:r><w:t>$escaped</w:t></w:r>'
        '</w:p>';
  }

  String _spacer() {
    return '<w:p><w:pPr><w:spacing w:before="120" w:after="120"/></w:pPr></w:p>';
  }

  String _escapeXml(String xml) {
    return xml
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
