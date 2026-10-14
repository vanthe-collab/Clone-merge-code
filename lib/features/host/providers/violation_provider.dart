import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/user_provider.dart';
import '../models/violation_model.dart';
import '../models/violation_record_model.dart';
import '../repositories/violation_repository.dart';

/// Provider cung cấp repository
final violationRepositoryProvider = Provider<ViolationRepository>((ref) {
  return ViolationRepository();
});

/// Danh mục các loại vi phạm đọc từ Firestore (tự động seed nếu rỗng)
final violationTypesProvider =
    StreamProvider.autoDispose<List<ViolationModel>>((ref) {
  final repo = ref.watch(violationRepositoryProvider);
  return repo.watchViolationTypes();
});

/// Danh sách phòng đang có người ở của chủ trọ hiện tại
final hostOccupiedRoomsProvider =
    FutureProvider.autoDispose<List<HostOccupiedRoomItem>>((ref) async {
  final user = ref.watch(userProfileProvider).value;
  final hostId = user?.uid ?? '';
  if (hostId.isEmpty) return [];

  final repo = ref.watch(violationRepositoryProvider);
  return repo.getHostOccupiedRooms(hostId);
});

/// Bộ lọc tháng hiển thị (mặc định tháng & năm hiện tại)
class HostViolationMonthFilterNotifier extends Notifier<DateTime> {
  final DateTime? _initial;
  HostViolationMonthFilterNotifier([this._initial]);

  @override
  DateTime build() {
    if (_initial != null) return _initial;
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  @override
  DateTime get state => super.state;

  @override
  set state(DateTime value) => super.state = value;

  void setMonth(DateTime month) => state = month;
}

final hostViolationMonthFilterProvider =
    NotifierProvider<HostViolationMonthFilterNotifier, DateTime>(
  HostViolationMonthFilterNotifier.new,
);

/// Bộ lọc trạng thái: 'ALL', 'PENDING', 'PAID', 'ADDED_TO_INVOICE'
class HostViolationStatusFilterNotifier extends Notifier<String> {
  final String? _initial;
  HostViolationStatusFilterNotifier([this._initial]);

  @override
  String build() => _initial ?? 'ALL';

  @override
  String get state => super.state;

  @override
  set state(String value) => super.state = value;

  void setFilter(String filter) => super.state = filter;
}

final hostViolationStatusFilterProvider =
    NotifierProvider<HostViolationStatusFilterNotifier, String>(
  HostViolationStatusFilterNotifier.new,
);

/// Stream toàn bộ vi phạm của chủ trọ hiện tại
final hostViolationRecordsStreamProvider =
    StreamProvider.autoDispose<List<ViolationRecordModel>>((ref) {
  final user = ref.watch(userProfileProvider).value;
  final hostId = user?.uid ?? '';
  if (hostId.isEmpty) return Stream.value([]);

  final repo = ref.watch(violationRepositoryProvider);
  return repo.watchHostViolationRecords(hostId);
});

/// Danh sách vi phạm đã lọc theo tháng và trạng thái
final filteredViolationRecordsProvider =
    Provider.autoDispose<AsyncValue<List<ViolationRecordModel>>>((ref) {
  final recordsAsync = ref.watch(hostViolationRecordsStreamProvider);
  final selectedMonth = ref.watch(hostViolationMonthFilterProvider);
  final statusFilter = ref.watch(hostViolationStatusFilterProvider);

  return recordsAsync.whenData((records) {
    return records.where((r) {
      // 1. Lọc theo tháng
      final isSameMonth = r.createdAt.year == selectedMonth.year &&
          r.createdAt.month == selectedMonth.month;
      if (!isSameMonth) return false;

      // 2. Lọc theo trạng thái
      if (statusFilter == 'PENDING') {
        return r.isPending;
      } else if (statusFilter == 'PAID') {
        return r.isPaid;
      } else if (statusFilter == 'ADDED_TO_INVOICE') {
        return r.isAddedToInvoice;
      }
      return true;
    }).toList();
  });
});

/// Thống kê 4 chỉ số tháng (Tổng ghi nhận, Số vi phạm, Đã nộp, Chờ nộp)
final violationMonthlyStatsProvider =
    Provider.autoDispose<ViolationMonthlyStats>((ref) {
  final recordsAsync = ref.watch(hostViolationRecordsStreamProvider);
  final selectedMonth = ref.watch(hostViolationMonthFilterProvider);

  return recordsAsync.maybeWhen(
    data: (records) {
      // Lọc các bản ghi trong tháng
      final monthRecords = records.where((r) {
        return r.createdAt.year == selectedMonth.year &&
            r.createdAt.month == selectedMonth.month;
      }).toList();

      return ViolationMonthlyStats.fromRecords(monthRecords);
    },
    orElse: () => const ViolationMonthlyStats(),
  );
});
