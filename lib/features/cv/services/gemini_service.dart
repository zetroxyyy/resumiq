import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/cv_model.dart';

class GeminiService {
  const GeminiService();

  Future<String> generateCv({
    required String uid,
    required String rawInput,
    required String cvType,
    String? jobDescription,
  }) async {
    // 1. Fetch API Key from Firebase Remote Config with 1-hour cache expiry
    final remoteConfig = FirebaseRemoteConfig.instance;
    try {
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 30),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await remoteConfig.fetchAndActivate();
    } catch (e) {
      // Fallback/log config fetch issue
    }

    final apiKey = remoteConfig.getString('GEMINI_API_KEY');
    if (apiKey.isEmpty) {
      throw Exception('API Key not configured. Please contact the administrator.');
    }

    // 2. Instantiate Gemini model
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

    final prompt = _buildPrompt(rawInput, cvType, jobDescription);

    try {
      return await _callGeminiWithRetry(model, prompt, uid, rawInput, cvType, jobDescription);
    } catch (e) {
      throw Exception('AI generation failed. Please try again.');
    }
  }

  String _buildPrompt(String rawInput, String cvType, String? jobDescription) {
    return 'Raw Input Details:\n$rawInput\n\n'
        'Requested Format/Style: $cvType\n\n'
        '${jobDescription != null ? 'Target Job Description to optimize for:\n$jobDescription\n\n' : ''}'
        'Please parse all data, write professional summary, format experience items, list skills, score the CV out of 100, and give 2-3 feedback items.';
  }

  Future<String> _callGeminiWithRetry(
    GenerativeModel model,
    String prompt,
    String uid,
    String rawInput,
    String cvType,
    String? jobDescription, {
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
        shareUrl: null,
        score: parsedJson['score'] as int?,
        scoreFeedback: List<String>.from(parsedJson['scoreFeedback'] as List? ?? []),
        version: 1,
        cvType: cvType,
        createdAt: now,
        updatedAt: now,
      );

      // Save CV document
      await cvDocRef.set(cvModel.toJson());

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
    // 1. Fetch API Key from Firebase Remote Config with 1-hour cache expiry
    final remoteConfig = FirebaseRemoteConfig.instance;
    try {
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 30),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await remoteConfig.fetchAndActivate();
    } catch (e) {
      // Fallback/log config fetch issue
    }

    final apiKey = remoteConfig.getString('GEMINI_API_KEY');
    if (apiKey.isEmpty) {
      throw Exception('API Key not configured. Please contact the administrator.');
    }

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

