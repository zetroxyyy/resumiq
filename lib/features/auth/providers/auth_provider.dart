import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/user_model.dart';

// Provides Stream of Firebase auth state changes
final firebaseAuthProvider = Provider<fb.FirebaseAuth>((ref) {
  return fb.FirebaseAuth.instance;
});

final authStateChangesProvider = StreamProvider<fb.User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

// Main auth provider managing custom UserModel? state
final authProvider = StateNotifierProvider<AuthNotifier, UserModel?>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final notifier = AuthNotifier(firebaseAuth);

  // Sync with Firebase User changes
  final sub = ref.listen<AsyncValue<fb.User?>>(authStateChangesProvider, (prev, next) {
    next.when(
      data: (fbUser) => notifier.handleFirebaseUser(fbUser),
      error: (_, __) => notifier.clear(),
      loading: () {},
    );
  });

  ref.onDispose(() {
    sub.close();
  });

  return notifier;
});

class AuthNotifier extends StateNotifier<UserModel?> {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  AuthNotifier(this._auth) : super(null) {
    // Initial fetch if already logged in at startup
    handleFirebaseUser(_auth.currentUser);
  }

  bool get isAdmin => state?.email == AppConstants.adminEmail;

  Future<void> handleFirebaseUser(fb.User? fbUser) async {
    _userDocSubscription?.cancel();

    if (fbUser == null) {
      state = null;
      return;
      // Do not try to sync database if the user is null
    }

    // Set up real-time sync with Firestore user document
    final docRef = _db.collection('users').doc(fbUser.uid);
    _userDocSubscription = docRef.snapshots().listen((snapshot) async {
      if (snapshot.exists && snapshot.data() != null) {
        UserModel userModel = UserModel.fromJson(snapshot.data()!);

        // On every sign-in / data read: check if generationResetDate is a past month
        final now = DateTime.now();
        final reset = userModel.generationResetDate;
        if (now.year > reset.year || (now.year == reset.year && now.month > reset.month)) {
          final newResetDate = DateTime(now.year, now.month, 1);
          await docRef.update({
            'generationsThisMonth': 0,
            'generationResetDate': Timestamp.fromDate(newResetDate),
          });
          return;
        }

        state = userModel;
      } else {
        // Create new user profile if doc does not exist
        final now = DateTime.now();
        final resetDate = DateTime(now.year, now.month, 1);
        final newUser = UserModel(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          name: fbUser.displayName ?? 'User',
          photoUrl: fbUser.photoURL ?? '',
          tier: 'free',
          tierGrantedBy: null,
          tierExpiresAt: null,
          generationsThisMonth: 0,
          generationResetDate: resetDate,
          createdAt: now,
          isFirstTime: true,
        );
        await docRef.set(newUser.toJson());
        state = newUser;
      }
    }, onError: (e) {
      // Stream error handling
    });
  }

  Future<void> completeOnboarding() async {
    final user = state;
    if (user != null) {
      await _db.collection('users').doc(user.uid).update({'isFirstTime': false});
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        // Sign-in cancelled by user
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final fb.OAuthCredential credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
    } catch (e) {
      throw Exception(_getCleanErrorMessage(e));
    }
  }

  // Developer preview/anonymous login to support platforms without Google Sign-In setup
  Future<void> signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
    } catch (e) {
      throw Exception(_getCleanErrorMessage(e));
    }
  }

  Future<void> signOut() async {
    _userDocSubscription?.cancel();
    state = null;
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  void clear() {
    _userDocSubscription?.cancel();
    state = null;
  }

  String _getCleanErrorMessage(dynamic e) {
    final message = e.toString();
    if (message.contains('network-request-failed')) {
      return 'Network connection error. Please check your internet connection and try again.';
    } else if (message.contains('invalid-credential')) {
      return 'Invalid credentials. Please sign in again.';
    } else if (message.contains('user-disabled')) {
      return 'This user account has been disabled.';
    } else if (message.contains('sign_in_canceled')) {
      return 'Sign in was cancelled.';
    }
    return 'Authentication failed: ${message.replaceAll('Exception:', '').trim()}';
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    super.dispose();
  }
}
