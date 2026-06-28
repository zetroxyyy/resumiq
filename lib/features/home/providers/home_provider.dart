import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cv/models/cv_model.dart';

// Stream provider for user's CVs ordered by updatedAt descending
final userCvsProvider = StreamProvider<List<CvModel>>((ref) {
  final user = ref.watch(authProvider);
  if (user == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('cvs')
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      // Ensure the id in the data maps correctly
      data['id'] = doc.id;
      return CvModel.fromJson(data);
    }).toList();
  });
});

// Service provider exposing Home actions (like deletion)
final homeProvider = Provider<HomeService>((ref) {
  return HomeService(ref);
});

class HomeService {
  final Ref _ref;

  HomeService(this._ref);

  Future<void> deleteCv(String cvId) async {
    final user = _ref.read(authProvider);
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cvs')
          .doc(cvId)
          .delete();
    }
  }
}
