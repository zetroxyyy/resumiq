import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  String _apiKey = '';

  Future<void> _ensureApiKey() async {
    if (_apiKey.isNotEmpty) return;

    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await rc.fetchAndActivate();
      final key = rc.getString('GEMINI_API_KEY').trim();
      debugPrint('RC key loaded, length: ${key.length}');
      if (key.isNotEmpty) {
        _apiKey = key;
        return;
      }
    } catch (e) {
      debugPrint('RC fetch error: $e');
    }

    // Try cached value
    try {
      final cached =
          FirebaseRemoteConfig.instance.getString('GEMINI_API_KEY').trim();
      if (cached.isNotEmpty) {
        _apiKey = cached;
        debugPrint('RC cached key loaded, length: ${cached.length}');
        return;
      }
    } catch (e) {
      debugPrint('RC cache error: $e');
    }

    throw Exception('AI service unavailable. Please try again later.');
  }

  Future<Map<String, dynamic>> generateCv({
    required String rawInput,
    required String cvType,
    String? jobDescription,
    bool atsOptimized = false,
  }) async {
    await _ensureApiKey();

    final atsNote = atsOptimized
        ? 'IMPORTANT: This CV must be ATS-optimized. Use only plain text, standard section names, no special characters except hyphens and bullets. Set atsOptimized: true in output.'
        : '';

    final prompt = '''
You are a world-class professional CV writer. Transform this raw information into a perfectly structured, professional CV. Think deeply. Extract all details. Use strong professional language.
$atsNote

CV Type requested: $cvType
${jobDescription != null && jobDescription.isNotEmpty ? 'Job Description (tailor CV for this): $jobDescription' : ''}

Raw Information:
$rawInput

Respond ONLY with valid JSON, no markdown, no explanation, no code fences. Use this exact structure:
{
  "personalInfo": {"fullName": "", "email": "", "phone": "", "location": "", "linkedIn": "", "portfolio": ""},
  "summary": "",
  "workExperience": [{"company": "", "role": "", "startDate": "", "endDate": "", "current": false, "responsibilities": []}],
  "education": [{"institution": "", "degree": "", "field": "", "startDate": "", "endDate": "", "grade": ""}],
  "skills": {"technical": [], "soft": [], "languages": []},
  "certifications": [{"name": "", "issuer": "", "date": "", "url": ""}],
  "projects": [{"name": "", "description": "", "tech": [], "url": ""}],
  "achievements": [],
  "references": "Available upon request",
  "cvType": "$cvType",
  "atsOptimized": ${atsOptimized.toString()},
  "score": 0,
  "scoreFeedback": []
}
Score 0-100: completeness 40%, language impact 30%, structure 30%.
scoreFeedback: 2-3 specific improvement suggestions as strings.
''';

    debugPrint('Gemini: sending request to REST API...');

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 8192,
        }
      }),
    ).timeout(const Duration(seconds: 60));

    debugPrint('Gemini: response status ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('Gemini error body: ${response.body}');
      throw Exception(
          'AI generation failed (${response.statusCode}). Please try again.');
    }

    final responseData = jsonDecode(response.body);
    String text = responseData['candidates'][0]['content']['parts'][0]['text']
        as String;

    debugPrint('Gemini: raw response length ${text.length}');

    // Strip markdown code fences if present
    text = text
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('JSON parse error: $e');
      // Try to extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch != null) {
        return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      }
      throw Exception('AI returned invalid response. Please try again.');
    }
  }

  Future<String> generateCoverLetter({
    required Map<String, dynamic> cvData,
    String? jobDescription,
    String? targetCompany,
  }) async {
    await _ensureApiKey();

    final prompt = '''
You are an expert cover letter writer. Write a professional, personalized cover letter.
The letter must be 3-4 paragraphs, under 400 words, sound human and confident.
Opening: strong hook. Middle: 2-3 specific achievements from CV. Closing: clear call to action.
${jobDescription != null ? 'Tailor to this job: $jobDescription' : ''}
${targetCompany != null ? 'Address to: $targetCompany' : ''}

CV Data: ${jsonEncode(cvData)}

Return ONLY the cover letter text. No JSON. No explanation.
''';

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {'temperature': 0.8, 'maxOutputTokens': 2048}
      }),
    ).timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception('Cover letter generation failed. Please try again.');
    }

    final data = jsonDecode(response.body);
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  Future<Map<String, dynamic>> editCv({
    required Map<String, dynamic> currentCvData,
    required String editInstruction,
  }) async {
    await _ensureApiKey();

    final prompt = '''
Apply ONLY the requested change to this CV and return the complete updated CV JSON.
Do not change anything else.
Change requested: $editInstruction
Current CV data: ${jsonEncode(currentCvData)}
Return ONLY valid JSON with the same structure. No markdown, no explanation.
''';

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {'temperature': 0.3, 'maxOutputTokens': 8192}
      }),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('CV edit failed. Please try again.');
    }

    final data = jsonDecode(response.body);
    String text =
        data['candidates'][0]['content']['parts'][0]['text'] as String;
    text = text
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (match != null) return jsonDecode(match.group(0)!) as Map<String, dynamic>;
      throw Exception('Edit failed. Please try again.');
    }
  }
}
