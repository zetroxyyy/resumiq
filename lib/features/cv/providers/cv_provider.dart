import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/cv_model.dart';
import '../services/gemini_service.dart';

class CvInputState {
  final String rawInput;
  final String format;
  final String? jobDescription;

  const CvInputState({
    required this.rawInput,
    required this.format,
    this.jobDescription,
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
  final GeminiService _gemini = const GeminiService();

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
      final cvId = await _gemini.generateCv(
        uid: user.uid,
        rawInput: inputData.rawInput,
        cvType: inputData.format,
        jobDescription: inputData.jobDescription,
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
