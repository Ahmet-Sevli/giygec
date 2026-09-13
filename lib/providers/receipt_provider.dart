import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/receipt.dart';
import '../services/firestore_service.dart';
import 'auth_provider.dart';

final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

final userReceiptsProvider = StreamProvider<List<Receipt>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserReceipts(user.uid);
});
