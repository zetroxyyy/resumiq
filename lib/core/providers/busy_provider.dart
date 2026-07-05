import 'package:flutter_riverpod/flutter_riverpod.dart';

final busyProvider = StateProvider<bool>((ref) => false);
final busyReasonProvider = StateProvider<String?>((ref) => null);
