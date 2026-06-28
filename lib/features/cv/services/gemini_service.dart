import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/cv_model.dart';

class GeminiService {
  const GeminiService();

  Future<String> generateCv({
    required String uid,
    required String rawInput,
    required String cvType,
    String? jobDescription,
    bool atsOptimized = false,
  }) async {
    try {
      debugPrint("RemoteConfig: fetching key...");
      final remoteConfig = FirebaseRemoteConfig.instance;
      final apiKey = await _getApiKey(remoteConfig);

      debugPrint("Gemini: initializing with model gemini-1.5-pro");
      final model = GenerativeModel(
        model: 'gemini-1.5-pro',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
        systemInstruction: Content.system(
          'You are a world-class professional CV writer. Transform raw unstructured information into a perfectly structured, professional CV. '
          'Think deeply. Extract all details. Use strong professional language. '
          'Respond ONLY with valid JSON. Do NOT wrap it in markdown code fences like ```json. Do not write explanation. '
          'Follow this JSON schema format exactly:\n'
          '{\n'
          '  "personalInfo": {"fullName": "", "email": "", "phone": "", "location": "", "linkedIn": "", "portfolio": ""},\n'
          '  "summary": "",\n'
          '  "workExperience": [{"company": "", "role": "", "startDate": "", "endDate": "", "current": false, "responsibilities": []}],\n'
          '  "education": [{"institution": "", "degree": "", "field": "", "startDate": "", "endDate": "", "grade": []}],\n'
          '  "skills": {"technical": [], "soft": [], "languages": []},\n'
          '  "certifications": [{"name": "", "issuer": "", "date": "", "url": ""}],\n'
          '  "projects": [{"name": "", "description": "", "tech": [], "url": ""}],\n'
          '  "achievements": [],\n'
          '  "references": "",\n'
          '  "cvType": "",\n'
          '  "score": 85,\n'
          '  "scoreFeedback": []\n'
          '}\n'
          'Scoring criteria: completeness 40%, language impact 30%, structure 30%.'
        ),
      );

      final prompt = _buildPrompt(rawInput, cvType, jobDescription, atsOptimized: atsOptimized);

      try {
        debugPrint("Gemini: sending request...");
        final result = await _callGeminiWithRetry(
          model,
          prompt,
          uid,
          rawInput,
          cvType,
          jobDescription,
          atsOptimized: atsOptimized,
        );
        debugPrint("Gemini: response received");
        return result;
      } catch (e) {
        debugPrint("Gemini: request failed: $e");
        rethrow;
      }
    } catch (e) {
      debugPrint("generateCv error: $e");
      rethrow;
    }
  }

  String _buildPrompt(String rawInput, String cvType, String? jobDescription, {bool atsOptimized = false}) {
    final basePrompt = 'Raw Input Details:\n$rawInput\n\n'
        'Requested Format/Style: $cvType\n\n'
        '${jobDescription != null ? 'Target Job Description to optimize for:\n$jobDescription\n\n' : ''}'
        'Please parse all data, write professional summary, format experience items, list skills, score the CV out of 100, and give 2-3 feedback items.';
    if (atsOptimized) {
      return '$basePrompt\n\n'
          'IMPORTANT: This CV must be ATS-optimized. In the generatedContent, '
          'set a field \'atsOptimized: true\'. The content must use only plain text, '
          'standard section names (Work Experience, Education, Skills), '
          'and no special characters except hyphens and bullets.';
    }
    return basePrompt;
  }

  Future<String> _callGeminiWithRetry(
    GenerativeModel model,
    String prompt,
    String uid,
    String rawInput,
    String cvType,
    String? jobDescription, {
    bool atsOptimized = false,
    bool isRetry = false,
  }) async {
    final response = await model.generateContent([Content.text(prompt)]);
    var responseText = response.text ?? '';

    // Strip markdown JSON wrappers if Gemini ignored system instruction
    responseText = _cleanJsonString(responseText);

    try {
      final parsedJson = jsonDecode(responseText) as Map<String, dynamic>;

      // Save CvModel to Firestore
      final cvCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('cvs');
      final cvDocRef = cvCollection.doc();
      final cvId = cvDocRef.id;

      final now = DateTime.now();

      final cvModel = CvModel(
        id: cvId,
        userId: uid,
        title: parsedJson['personalInfo']?['fullName'] != null &&
                (parsedJson['personalInfo']?['fullName'] as String).isNotEmpty
            ? '${parsedJson['personalInfo']?['fullName']} - CV'
            : 'Gemini Professional CV',
        rawInput: rawInput,
        jobDescription: jobDescription,
        generatedContent: parsedJson,
        template: cvType,
        pdfUrl: null,
        docxUrl: null,
        shareUrl: null,
        score: parsedJson['score'] as int?,
        scoreFeedback: List<String>.from(parsedJson['scoreFeedback'] as List? ?? []),
        version: 1,
        cvType: cvType,
        atsOptimized: atsOptimized || (parsedJson['atsOptimized'] == true),
        createdAt: now,
        updatedAt: now,
      );

      // Save CV document
      await cvDocRef.set(cvModel.toJson());

      // Save initial version snapshot (version 1 = "First generated")
      await cvDocRef.collection('versions').add({
        'versionNumber': 1,
        'generatedContent': parsedJson,
        'template': cvType,
        'changedBy': 'initial',
        'changedAt': Timestamp.now(),
      });

      // Increment generations count in User Profile
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'generationsThisMonth': FieldValue.increment(1)});

      return cvId;
    } catch (e) {
      if (!isRetry) {
        // Retry once with a stricter instruction
        final strictPrompt = '$prompt\n\nIMPORTANT: return ONLY raw JSON, no backticks, no markdown code block fences.';
        return await _callGeminiWithRetry(
          model,
          strictPrompt,
          uid,
          rawInput,
          cvType,
          jobDescription,
          atsOptimized: atsOptimized,
          isRetry: true,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> editCv({
    required Map<String, dynamic> currentCvJson,
    required String transcribedText,
  }) async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    final apiKey = await _getApiKey(remoteConfig);

    // 2. Instantiate Gemini 1.5 Pro model
    final model = GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
      systemInstruction: Content.system(
        'You are a world-class professional CV editor. '
        'The user wants to make a change to their CV. Apply ONLY the requested change '
        'and return the complete updated CV JSON. Do not change anything else. '
        'Ensure the output is valid JSON matching the current CV schema structure. '
        'Do not wrap the response in markdown code blocks like ```json. Do not include any explanations.'
      ),
    );

    final prompt = 'Change requested: $transcribedText\n'
        'Current CV data: ${jsonEncode(currentCvJson)}';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      var responseText = response.text ?? '';
      responseText = _cleanJsonString(responseText);
      return jsonDecode(responseText) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Voice edit failed: ${e.toString().replaceAll('Exception:', '').trim()}');
    }
  }

  Future<String> generateCoverLetter({
    required CvModel cv,
    String? jobDescription,
    String? targetCompany,
  }) async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    final apiKey = await _getApiKey(remoteConfig);

    final model = GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: apiKey,
      systemInstruction: Content.system(
        'You are an expert cover letter writer. Write a professional, personalized '
        'cover letter based on the CV data provided. The letter must:\n'
        '- Be 3-4 paragraphs, under 400 words\n'
        '- Sound human, confident, and specific — not generic\n'
        '- Opening: hook the reader with a strong opening line\n'
        '- Middle: connect 2-3 specific achievements from CV to the role\n'
        '- Closing: clear call to action, professional sign-off\n'
        '- If a job description is provided, tailor every paragraph to it\n'
        '- If a company name is provided, address it specifically\n'
        'Return ONLY the cover letter text. No JSON. No explanation. Just the letter.'
      ),
    );

    final cvJson = jsonEncode(cv.generatedContent);
    final prompt = 'CV Data: $cvJson\n'
        'Target Company: ${targetCompany ?? "Not specified"}\n'
        'Job Description: ${jobDescription ?? "Not specified"}';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? '';
    } catch (e) {
      throw Exception('Cover letter generation failed: ${e.toString()}');
    }
  }

  Future<String> _getApiKey(FirebaseRemoteConfig remoteConfig) async {
    try {
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await remoteConfig.fetchAndActivate();
      debugPrint("RemoteConfig: key fetched successfully");
    } catch (e) {
      debugPrint("RemoteConfig: fetch failed, using cache: $e");
    }

    final rawKey = remoteConfig.getString('GEMINI_API_KEY');
    final trimmedKey = rawKey.trim();
    debugPrint("Gemini key length after trim: ${trimmedKey.length}");
    
    if (trimmedKey.isEmpty) {
      throw Exception('Gemini API key is empty. Check Remote Config.');
    }
    return trimmedKey;
  }

  String _cleanJsonString(String source) {
    var cleaned = source.trim();
    if (cleaned.startsWith('```')) {
      // Remove starting ```json or ```
      final firstLineEnd = cleaned.indexOf('\n');
      if (firstLineEnd != -1) {
        cleaned = cleaned.substring(firstLineEnd).trim();
      }
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3).trim();
    }
    return cleaned;
  }
}
