import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<void> handleFirebaseUser(fb.User? fbUser) async {
    _userDocSubscription?.cancel();

    if (fbUser == null) {
      state = null;
      return;
    }

    // Set up real-time sync with Firestore user document
    final docRef = _db.collection('users').doc(fbUser.uid);
    _userDocSubscription = docRef.snapshots().listen((snapshot) async {
      if (snapshot.exists && snapshot.data() != null) {
        state = UserModel.fromJson(snapshot.data()!);
      } else {
        // Create new user profile if doc does not exist
        final newUser = UserModel(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          displayName: fbUser.displayName ?? 'User',
          photoUrl: fbUser.photoURL ?? '',
          isFirstTime: true,
          isPro: false,
          createdAt: DateTime.now(),
        );
        await docRef.set(newUser.toJson());
        state = newUser;
      }
    });
  }

  Future<void> completeOnboarding() async {
    final user = state;
    if (user != null) {
      await _db.collection('users').doc(user.uid).update({'isFirstTime': false});
    }
  }

  Future<void> signOut() async {
    _userDocSubscription?.cancel();
    state = null;
    await _auth.signOut();
  }

  void clear() {
    _userDocSubscription?.cancel();
    state = null;
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    super.dispose();
  }
}
