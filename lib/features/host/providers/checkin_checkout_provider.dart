import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/checkin_checkout_repository.dart';
import 'host_management_provider.dart';

final checkinCheckoutRepositoryProvider =
    Provider<CheckinCheckoutRepository>((ref) {
  return CheckinCheckoutRepository();
});

/// Stream danh sách các phòng trong luồng Check-in của chủ trọ
final hostCheckinItemsProvider =
    StreamProvider<List<CheckinCheckoutItem>>((ref) {
  final uid = ref.watch(hostSessionProvider).value;
  if (uid == null || uid.isEmpty) return Stream.value([]);
  return ref.watch(checkinCheckoutRepositoryProvider).watchCheckinItems(uid);
});

/// Stream danh sách các phòng trong luồng Check-out của chủ trọ
final hostCheckoutItemsProvider =
    StreamProvider<List<CheckinCheckoutItem>>((ref) {
  final uid = ref.watch(hostSessionProvider).value;
  if (uid == null || uid.isEmpty) return Stream.value([]);
  return ref.watch(checkinCheckoutRepositoryProvider).watchCheckoutItems(uid);
});
