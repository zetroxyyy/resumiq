import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/user_model.dart';
import '../../../models/payment_model.dart';

final totalUsersProvider = FutureProvider<int>((ref) async {
  final snap = await FirebaseFirestore.instance.collection('users').get();
  return snap.docs.length;
});

final proUsersCountProvider = FutureProvider<int>((ref) async {
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .where('tier', isEqualTo: 'pro')
      .get();
  return snap.docs.length;
});

final totalGenerationsProvider = FutureProvider<int>((ref) async {
  final snap = await FirebaseFirestore.instance.collection('users').get();
  int total = 0;
  for (var doc in snap.docs) {
    final data = doc.data();
    final gens = data['generationsThisMonth'] as int? ?? 0;
    total += gens;
  }
  return total;
});

final allUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  final snap = await FirebaseFirestore.instance.collection('users').get();
  return snap.docs
      .map((doc) => UserModel.fromJson({...doc.data(), 'uid': doc.id}))
      .toList();
});

final pendingPaymentsProvider = StreamProvider<List<PaymentModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('payments')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => PaymentModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList());
});

final allPaymentsProvider = StreamProvider<List<PaymentModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('payments')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => PaymentModel.fromJson({...doc.data(), 'id': doc.id}))
          .toList());
});
