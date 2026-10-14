import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/handover_repository.dart';

final handoverRepositoryProvider = Provider<HandoverRepository>((ref) {
  return HandoverRepository();
});

/// Tham số tải ngữ cảnh bàn giao
class HandoverParams {
  final String bookingId;
  final String roomId;

  const HandoverParams({required this.bookingId, required this.roomId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HandoverParams &&
          runtimeType == other.runtimeType &&
          bookingId == other.bookingId &&
          roomId == other.roomId;

  @override
  int get hashCode => bookingId.hashCode ^ roomId.hashCode;
}

/// Provider tải dữ liệu bàn giao theo phòng & booking
final handoverContextProvider = FutureProvider.autoDispose
    .family<HandoverRoomContext, HandoverParams>((ref, params) {
  final repo = ref.watch(handoverRepositoryProvider);
  return repo.getHandoverContext(
    bookingId: params.bookingId,
    roomId: params.roomId,
  );
});
