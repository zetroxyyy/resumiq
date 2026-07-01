import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/cv_model.dart';
import '../models/version_model.dart';
import '../services/ai_service.dart';

class CvInputState {
  final String rawInput;
  final String format;
  final String? jobDescription;
  final bool atsOptimized;

  const CvInputState({
    required this.rawInput,
    required this.format,
    this.jobDescription,
    this.atsOptimized = false,
  });
}

// Stores the validated user inputs for resume tailoring
final cvInputProvider = StateProvider<CvInputState?>((ref) => null);

// Model class representing generation progress/state
class CvGenerationState {
  final bool isLoading;
  final String? errorMessage;
  final String? generatedCvId;

  const CvGenerationState({
    this.isLoading = false,
    this.errorMessage,
    this.generatedCvId,
  });
}

final cvGenerationProvider = StateNotifierProvider<CvGenerationNotifier, CvGenerationState>((ref) {
  return CvGenerationNotifier(ref);
});

class CvGenerationNotifier extends StateNotifier<CvGenerationState> {
  final Ref _ref;
  final AiService _gemini = AiService();

  CvGenerationNotifier(this._ref) : super(const CvGenerationState());

  Future<void> generate(BuildContext context) async {
    final inputData = _ref.read(cvInputProvider);
    final user = _ref.read(authProvider);

    if (inputData == null || user == null) {
      state = const CvGenerationState(errorMessage: 'Missing input details or user session.');
      return;
    }

    state = const CvGenerationState(isLoading: true);

    try {
      // Generate CV content via REST API
      final generatedContent = await _gemini.generateCv(
        rawInput: inputData.rawInput,
        cvType: inputData.format,
        jobDescription: inputData.jobDescription,
        atsOptimized: inputData.atsOptimized,
      );

      final personalInfo = generatedContent['personalInfo'] as Map<String, dynamic>?;
      final fullName = personalInfo?['fullName'] as String? ?? '';
      final String cvTitle;
      if (fullName.trim().isNotEmpty) {
        cvTitle = "${fullName.trim()}'s CV";
      } else {
        cvTitle = "My CV ${DateTime.now().millisecondsSinceEpoch}";
      }

      int score = 0;
      final rawScore = generatedContent['score'];
      if (rawScore != null) {
        if (rawScore is int) score = rawScore;
        else if (rawScore is double) score = rawScore.toInt();
        else if (rawScore is String) score = int.tryParse(rawScore) ?? 0;
      }

      final scoreFeedbackList = List<String>.from(generatedContent['scoreFeedback'] as List? ?? []);

      // Persist to Firestore
      final cvRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cvs')
          .add({
        'title': cvTitle,
        'generatedContent': generatedContent,
        'template': 'clean',
        'cvType': inputData.format,
        'atsOptimized': inputData.atsOptimized,
        'score': score,
        'scoreFeedback': scoreFeedbackList,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'version': 1,
      });

      // Try to increment generationsThisMonth on the user document
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'generationsThisMonth': FieldValue.increment(1),
        });
      } catch (e) {
        debugPrint('Failed to increment generationsThisMonth: $e');
      }

      final cvId = cvRef.id;

      // Save as version 1
      await saveVersion(
        uid: user.uid,
        cvId: cvId,
        generatedContent: generatedContent,
        template: 'clean',
        changedBy: 'regenerated',
      );

      state = CvGenerationState(generatedCvId: cvId);

      if (context.mounted) {
        // Redirection on successful generation
        context.go('/cv/templates?cvId=$cvId');
      }
    } catch (e) {
      final cleanMessage = e.toString().replaceAll('Exception:', '').trim();
      state = CvGenerationState(errorMessage: cleanMessage);

      if (context.mounted) {
        // Pop GeneratingScreen and return to InputScreen
        context.go('/cv/input');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cleanMessage),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

// Single CV real-time details stream provider
final cvDetailProvider = StreamProvider.family<CvModel?, String>((ref, cvId) {
  final user = ref.watch(authProvider);
  if (user == null) {
    return Stream.value(null);
  }
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('cvs')
      .doc(cvId)
      .snapshots()
      .map((snap) => snap.exists && snap.data() != null
          ? CvModel.fromJson({...snap.data()!, 'id': snap.id})
          : null);
});

// ─── Version History ──────────────────────────────────────────────────────────

/// Streams the version history for a given CV (max 10, newest first).
final cvVersionsProvider =
    StreamProvider.family<List<VersionModel>, ({String uid, String cvId})>(
        (ref, args) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(args.uid)
      .collection('cvs')
      .doc(args.cvId)
      .collection('versions')
      .orderBy('versionNumber', descending: true)
      .limit(10)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => VersionModel.fromJson(doc.data(), doc.id))
          .toList());
});

/// Saves a snapshot of the current CV state as a new version document.
/// Called BEFORE mutating the CV document (so the snapshot captures the old state).
/// Automatically prunes to a maximum of 10 versions (oldest removed first).
Future<void> saveVersion({
  required String uid,
  required String cvId,
  required Map<String, dynamic> generatedContent,
  required String template,
  required String changedBy,
}) async {
  final versionsRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('cvs')
      .doc(cvId)
      .collection('versions');

  // Count existing versions
  final existing = await versionsRef.orderBy('versionNumber').get();
  final nextNumber = (existing.docs.isNotEmpty
          ? (existing.docs.last.data()['versionNumber'] as int? ?? 0)
          : 0) +
      1;

  // Prune oldest if we already have 10
  if (existing.docs.length >= 10) {
    final oldest = existing.docs.first;
    await versionsRef.doc(oldest.id).delete();
  }

  await versionsRef.add({
    'versionNumber': nextNumber,
    'generatedContent': generatedContent,
    'template': template,
    'changedBy': changedBy,
    'changedAt': Timestamp.now(),
  });
}

/// Restores a CV to a previous version snapshot.
Future<void> restoreVersion({
  required String uid,
  required String cvId,
  required VersionModel version,
}) async {
  final cvRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('cvs')
      .doc(cvId);

  // First snapshot the current state as a version
  final currentSnap = await cvRef.get();
  if (currentSnap.exists) {
    final data = currentSnap.data()!;
    await saveVersion(
      uid: uid,
      cvId: cvId,
      generatedContent:
          (data['generatedContent'] as Map<String, dynamic>?) ?? {},
      template: data['template'] as String? ?? '',
      changedBy: 'before_restore',
    );
  }

  int score = 0;
  final rawScore = version.generatedContent['score'];
  if (rawScore != null) {
    if (rawScore is int) score = rawScore;
    else if (rawScore is double) score = rawScore.toInt();
    else if (rawScore is String) score = int.tryParse(rawScore) ?? 0;
  }
  final scoreFeedbackList = List<String>.from(version.generatedContent['scoreFeedback'] as List? ?? []);

  // Now restore
  await cvRef.update({
    'generatedContent': version.generatedContent,
    'template': version.template,
    'score': score,
    'scoreFeedback': scoreFeedbackList,
    'version': FieldValue.increment(1),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
