import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class AiService {
  static const String _baseUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.1-70b-versatile';

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

    final prompt = '''Take a deep breath and work through this step by step.
Quality matters more than speed. Write every bullet point as if the candidate's job offer depends on it.

You are a senior professional CV writer with 20 years of experience 
helping candidates land jobs at top companies. You have written 
thousands of CVs across all industries. Your CVs are known for 
being precise, impactful, and tailored.

Your task: Transform the raw information below into a world-class 
professional CV. Take your time to think deeply about every detail.

STRICT RULES YOU MUST FOLLOW:
1. Every bullet point under work experience must start with a 
   strong action verb (Developed, Led, Managed, Increased, Built, 
   Designed, Implemented, Achieved, Delivered, Created, etc.)
2. Quantify achievements wherever possible. If the person says 
   "worked on a team", write "Collaborated with cross-functional 
   team of X members". If they say "improved performance", write 
   "Improved system performance by an estimated 30%".
3. The professional summary must be 3-4 sentences. It must mention 
   years of experience, key skills, and career goal. It must be 
   written in third person (e.g. "Experienced software developer...")
4. Never use the words "responsible for" or "worked on" — replace 
   with specific action verbs.
5. If information is missing (like exact dates), use reasonable 
   professional estimates. Never leave fields empty if you can 
   infer from context.
6. Skills must be specific. Not "programming" but "Python 3.x, 
   Django REST Framework". Not "communication" but "Cross-functional 
   team collaboration".
7. If the person mentions any project, expand it into a proper 
   project description with technologies used and impact.
8. Education section must include the degree type, field, 
   institution, and years clearly.
9. The CV must read like it was written by the person themselves 
   at their absolute best — not like an AI summarized their notes.
10. Score honestly. A CV with missing work experience should score 
    50-60. A complete CV with good detail should score 75-85. 
    A perfect CV with quantified achievements scores 90+.
11. The work experience section is the most important part. 
    Every responsibility must show IMPACT, not just activity.
    BAD: 'Developed mobile applications'
    GOOD: 'Delivered 4 Flutter mobile applications for clients 
    across fintech and e-commerce sectors, maintaining 99.2% 
    crash-free session rate'
12. The summary must mention the person by name in the first 
    sentence and end with what they are looking for career-wise.
13. If the person provides very little information, ask yourself:
    What would a great candidate in this role have achieved? 
    Use realistic, believable estimates. Never make up companies 
    or schools — only embellish achievements and responsibilities.
14. Every CV must have at least 3 bullet points per job, 
    minimum 2 skills categories, and a complete education entry.
15. Do not add sections that have zero data. If there are no 
    projects mentioned, leave the projects array empty — 
    do not invent projects.
16. The "atsOptimized" field in the JSON response must be explicitly 
    set to true if ATS-optimized, and false otherwise.

CV Type requested: $cvType
${jobDescription != null && jobDescription.isNotEmpty ? '''
JOB DESCRIPTION TO TAILOR FOR:
$jobDescription
Make every section of the CV speak directly to this job. 
Use keywords from the job description naturally.''' : ''}
$atsNote

RAW INFORMATION FROM USER:
$rawInput

Respond ONLY with valid JSON. No markdown. No explanation. 
No text before or after the JSON. Just the JSON object.

Required JSON structure:
{
  "personalInfo": {
    "fullName": "Full name here",
    "email": "email@example.com", 
    "phone": "+977-XXXXXXXXXX",
    "location": "City, Country",
    "linkedIn": "",
    "portfolio": ""
  },
  "summary": "3-4 sentence professional summary in third person",
  "workExperience": [
    {
      "company": "Company Name",
      "role": "Job Title",
      "startDate": "Month Year",
      "endDate": "Month Year or Present",
      "current": false,
      "responsibilities": [
        "Action verb + specific achievement with context",
        "Action verb + specific achievement with context",
        "Action verb + specific achievement with context"
      ]
    }
  ],
  "education": [
    {
      "institution": "University/School Name",
      "degree": "Bachelor of / Master of / etc",
      "field": "Field of Study",
      "startDate": "Year",
      "endDate": "Year",
      "grade": "GPA or percentage if mentioned"
    }
  ],
  "skills": {
    "technical": ["Specific Skill 1", "Specific Skill 2"],
    "soft": ["Leadership", "Team Collaboration"],
    "languages": ["English (Fluent)", "Nepali (Native)"]
  },
  "certifications": [],
  "projects": [
    {
      "name": "Project Name",
      "description": "What it does, your role, and impact",
      "tech": ["Tech1", "Tech2"],
      "url": ""
    }
  ],
  "achievements": ["Specific achievement 1", "Specific achievement 2"],
  "references": "Available upon request",
  "cvType": "$cvType",
  "atsOptimized": ${atsOptimized.toString()},
  "score": 0,
  "scoreFeedback": [
    "Specific suggestion 1",
    "Specific suggestion 2", 
    "Specific suggestion 3"
  ]
}
''';

    final text = await _callGroq(prompt, temperature: 0.2, maxTokens: 6000);

    String cleaned = text
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    try {
      final map = jsonDecode(cleaned) as Map<String, dynamic>;
      map['atsOptimized'] = map['atsOptimized'] == true;
      return map;
    } catch (e) {
      debugPrint('JSON parse error: $e\nRaw: $cleaned');
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (match != null) {
        final map = jsonDecode(match.group(0)!) as Map<String, dynamic>;
        map['atsOptimized'] = map['atsOptimized'] == true;
        return map;
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
