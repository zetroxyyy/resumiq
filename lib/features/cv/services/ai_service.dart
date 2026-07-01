import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class AiService {
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  String _apiKey = '';

  Future<void> _ensureApiKey() async {
    if (_apiKey.isNotEmpty) return;

    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 15),
        minimumFetchInterval: Duration.zero,
      ));
      await rc.fetchAndActivate();
      final key = rc.getString('GROQ_API_KEY').trim();
      debugPrint('Groq key loaded, length: ${key.length}');
      if (key.isNotEmpty) {
        _apiKey = key;
        return;
      }
    } catch (e) {
      debugPrint('RC fetch error: $e');
    }

    try {
      final cached =
          FirebaseRemoteConfig.instance.getString('GROQ_API_KEY').trim();
      if (cached.isNotEmpty) {
        _apiKey = cached;
        return;
      }
    } catch (e) {
      debugPrint('RC cache error: $e');
    }

    throw Exception('AI service unavailable. Please try again later.');
  }

  Future<String> _callGroq(
    String prompt, {
    double temperature = 0.7,
    int maxTokens = 8192,
  }) async {
    await _ensureApiKey();

    debugPrint('Groq: sending request...');

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': temperature,
        'max_tokens': maxTokens,
      }),
    ).timeout(const Duration(seconds: 60));

    debugPrint('Groq: response status ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('Groq error: ${response.body}');
      throw Exception(
          'AI generation failed. Please try again.\n${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  Future<Map<String, dynamic>> generateCv({
    required String rawInput,
    required String cvType,
    String? jobDescription,
    bool atsOptimized = false,
  }) async {
    final atsNote = atsOptimized
        ? 'IMPORTANT: ATS-optimized CV required. Plain text only, standard section names, no special characters except hyphens and bullets. Set atsOptimized: true in output.'
        : '';

    final prompt = '''
You are a world-class professional CV writer. Transform this raw information into a perfectly structured, professional CV. Think deeply. Extract all details. Use strong professional language.
$atsNote

CV Type: $cvType
${jobDescription != null && jobDescription.isNotEmpty ? 'Job Description (tailor for this): $jobDescription' : ''}

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
scoreFeedback: 2-3 specific improvement suggestions.
Return ONLY the JSON object. Nothing else.
''';

    final text = await _callGroq(prompt);

    String cleaned = text
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('JSON parse error: $e\nRaw: $cleaned');
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (match != null) {
        return jsonDecode(match.group(0)!) as Map<String, dynamic>;
      }
      throw Exception('AI returned invalid response. Please try again.');
    }
  }

  Future<String> generateCoverLetter({
    required Map<String, dynamic> cvData,
    String? jobDescription,
    String? targetCompany,
  }) async {
    final prompt = '''
You are an expert cover letter writer. Write a professional, personalized cover letter based on this CV.
3-4 paragraphs, under 400 words. Sound human, confident, specific.
Opening: strong hook. Middle: 2-3 specific achievements. Closing: clear call to action.
${jobDescription != null ? 'Job Description: $jobDescription' : ''}
${targetCompany != null ? 'Target Company: $targetCompany' : ''}

CV Data: ${jsonEncode(cvData)}

Return ONLY the cover letter text. No explanation.
''';

    return await _callGroq(prompt, temperature: 0.8, maxTokens: 2048);
  }

  Future<Map<String, dynamic>> editCv({
    required Map<String, dynamic> currentCvData,
    required String editInstruction,
  }) async {
    final prompt = '''
Apply ONLY the requested change to this CV and return the complete updated CV JSON.
Do not change anything else.
Change requested: $editInstruction
Current CV: ${jsonEncode(currentCvData)}
Return ONLY valid JSON with the same structure. No markdown, no explanation.
''';

    final text = await _callGroq(prompt, temperature: 0.3);

    String cleaned = text
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (match != null) {
        return jsonDecode(match.group(0)!) as Map<String, dynamic>;
      }
      throw Exception('Edit failed. Please try again.');
    }
  }
}
