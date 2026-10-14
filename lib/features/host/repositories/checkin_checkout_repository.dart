import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/checkout_record_model.dart';
import '../../../data/models/period_model.dart';
import '../../../data/models/room_model.dart';

/// Mục cần xử lý Check-in hoặc Check-out
class CheckinCheckoutItem {
  final String id;
  final String bookingId;
  final String periodId;
  final String roomId;
  final String roomCode;
  final String renterId;
  final String renterName;
  final String renterPhone;
  final String propertyName;
  final int floor;
  final double deposit;
  final DateTime expectedDate; // Ngày vào (check-in) hoặc Ngày dự kiến trả (check-out)
  final String status; // 'choNhanPhong', 'dangO', 'daCheckout', 'daNhanPhong'
  final bool isCompleted;
  final DateTime? completedTime;
  final double? refundedDeposit;

  const CheckinCheckoutItem({
    required this.id,
    required this.bookingId,
    this.periodId = '',
    required this.roomId,
    required this.roomCode,
    required this.renterId,
    required this.renterName,
    this.renterPhone = '',
    required this.propertyName,
    this.floor = 1,
    required this.deposit,
    required this.expectedDate,
    required this.status,
    this.isCompleted = false,
    this.completedTime,
    this.refundedDeposit,
  });
}

class CheckinCheckoutRepository {
  final FirebaseFirestore _firestore;

  CheckinCheckoutRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Lắng nghe danh sách phòng cần Check-in của chủ trọ
  Stream<List<CheckinCheckoutItem>> watchCheckinItems(String hostId) {
    if (hostId.isEmpty) return Stream.value([]);

    return _firestore
        .collection(FirestoreCollections.hostRooms)
        .where('hostId', isEqualTo: hostId)
        .snapshots()
        .asyncMap((roomSnap) async {
          final hostRooms = roomSnap.docs
              .map(RoomModel.fromFirestore)
              .where((r) => r.status != 'deleted')
              .toList();

          if (hostRooms.isEmpty) return <CheckinCheckoutItem>[];
          final roomMap = {for (var r in hostRooms) r.id: r};

          // Tìm tên properties
          final propertyNames = await _getPropertyNames(hostRooms);

          // 1. Bookings chờ nhận phòng (chờ duyệt hoặc đã duyệt nhưng chưa sang 'dangO')
          final bookingsSnap = await _firestore
              .collection(FirestoreCollections.bookings)
              .where('hostId', isEqualTo: hostId)
              .get();

          final items = <CheckinCheckoutItem>[];

          for (final doc in bookingsSnap.docs) {
            final booking = BookingRequestModel.fromFirestore(doc);
            final room = roomMap[booking.roomId];
            if (room == null) continue;

            final isPending = booking.status == 'pending' ||
                booking.status == 'choDuyet' ||
                booking.status == 'approved' ||
                booking.status == 'daDuyet' ||
                booking.status == 'choNhanPhong';

            final isDone = booking.status == 'dangO' ||
                booking.status == 'active';

            final propName = propertyNames[room.propertyId] ??
                (room.address.isNotEmpty ? room.address : 'Nhà trọ');

            if (isPending) {
              items.add(CheckinCheckoutItem(
                id: booking.id,
                bookingId: booking.id,
                roomId: room.id,
                roomCode: room.roomCode.isNotEmpty ? room.roomCode : room.title,
                renterId: booking.renterId,
                renterName: booking.renterName,
                renterPhone: booking.renterPhone,
                propertyName: propName,
                floor: room.floor > 0 ? room.floor : 1,
                deposit: booking.deposit > 0 ? booking.deposit : room.deposit,
                expectedDate: booking.moveInDate,
                status: 'Chờ nhận phòng',
                isCompleted: false,
              ));
            } else if (isDone) {
              items.add(CheckinCheckoutItem(
                id: booking.id,
                bookingId: booking.id,
                roomId: room.id,
                roomCode: room.roomCode.isNotEmpty ? room.roomCode : room.title,
                renterId: booking.renterId,
                renterName: booking.renterName,
                renterPhone: booking.renterPhone,
                propertyName: propName,
                floor: room.floor > 0 ? room.floor : 1,
                deposit: booking.deposit > 0 ? booking.deposit : room.deposit,
                expectedDate: booking.moveInDate,
                status: 'Đã nhận phòng',
                isCompleted: true,
                completedTime: booking.acceptedDate ?? booking.createdAt,
                refundedDeposit: booking.deposit,
              ));
            }
          }

          return items;
        });
  }

  /// Lắng nghe danh sách phòng cần Check-out & Đã check-out của chủ trọ
  Stream<List<CheckinCheckoutItem>> watchCheckoutItems(String hostId) {
    if (hostId.isEmpty) return Stream.value([]);

    return _firestore
        .collection(FirestoreCollections.hostRooms)
        .where('hostId', isEqualTo: hostId)
        .snapshots()
        .asyncMap((roomSnap) async {
          final hostRooms = roomSnap.docs
              .map(RoomModel.fromFirestore)
              .where((r) => r.status != 'deleted')
              .toList();

          if (hostRooms.isEmpty) return <CheckinCheckoutItem>[];
          final roomMap = {for (var r in hostRooms) r.id: r};
          final propertyNames = await _getPropertyNames(hostRooms);

          final items = <CheckinCheckoutItem>[];

          // 1. Các kỳ ở đang ở (dangO) -> Danh sách cần xử lý Check-out
          final periodsSnap = await _firestore
              .collection(FirestoreCollections.periods)
              .where('status', isEqualTo: 'dangO')
              .get();

          for (final doc in periodsSnap.docs) {
            final period = PeriodModel.fromFirestore(doc);
            final room = roomMap[period.roomId];
            if (room == null) continue;

            final propName = propertyNames[room.propertyId] ??
                (room.address.isNotEmpty ? room.address : 'Nhà trọ');

            // Tính ngày dự kiến trả phòng (1 năm sau ngày bắt đầu hoặc contractEnd)
            final expectedOut = room.contractEnd ??
                period.endDate ??
                period.startDate.add(const Duration(days: 365));

            items.add(CheckinCheckoutItem(
              id: period.id,
              bookingId: period.bookingId,
              periodId: period.id,
              roomId: room.id,
              roomCode: room.roomCode.isNotEmpty ? room.roomCode : room.title,
              renterId: period.renterId,
              renterName: room.tenantName.isNotEmpty
                  ? room.tenantName
                  : 'Khách thuê',
              renterPhone: room.tenantPhone,
              propertyName: propName,
              floor: room.floor > 0 ? room.floor : 1,
              deposit: room.deposit > 0 ? room.deposit : 4800000.0,
              expectedDate: expectedOut,
              status: 'Đang ở',
              isCompleted: false,
            ));
          }

          // 2. Các phòng có trạng thái occupied nhưng chưa có period
          for (final room in hostRooms) {
            final alreadyInList = items.any((i) => i.roomId == room.id);
            if (!alreadyInList &&
                room.tenantName.isNotEmpty &&
                (room.status == 'occupied' ||
                    room.status == 'daThue' ||
                    room.status == 'dangO')) {
              final propName = propertyNames[room.propertyId] ??
                  (room.address.isNotEmpty ? room.address : 'Nhà trọ');

              final expectedOut = room.contractEnd ??
                  (room.contractStart?.add(const Duration(days: 365)) ??
                      DateTime.now().add(const Duration(days: 30)));

              items.add(CheckinCheckoutItem(
                id: 'room_${room.id}',
                bookingId: room.contractId,
                roomId: room.id,
                roomCode: room.roomCode.isNotEmpty ? room.roomCode : room.title,
                renterId: '',
                renterName: room.tenantName,
                renterPhone: room.tenantPhone,
                propertyName: propName,
                floor: room.floor > 0 ? room.floor : 1,
                deposit: room.deposit > 0 ? room.deposit : 4800000.0,
                expectedDate: expectedOut,
                status: 'Đang ở',
                isCompleted: false,
              ));
            }
          }

          // 3. Các biên bản trả phòng (checkout_records) đã hoàn tất
          final checkoutRecordsSnap = await _firestore
              .collection(FirestoreCollections.checkoutRecords)
              .get();

          for (final doc in checkoutRecordsSnap.docs) {
            final record = CheckoutRecordModel.fromFirestore(doc);
            final room = roomMap[record.roomId];
            // Hiển thị nếu thuộc phòng của chủ nhà này
            if (room != null) {
              final propName = propertyNames[room.propertyId] ??
                  (room.address.isNotEmpty ? room.address : 'Nhà trọ');

              items.add(CheckinCheckoutItem(
                id: record.id,
                bookingId: '',
                periodId: record.periodId,
                roomId: record.roomId,
                roomCode: room.roomCode.isNotEmpty ? room.roomCode : room.title,
                renterId: record.renterId,
                renterName: 'Trần Thị Mai', // Hoặc đọc profile
                propertyName: propName,
                floor: room.floor > 0 ? room.floor : 1,
                deposit: record.depositAmount,
                expectedDate: record.checkoutTime,
                status: 'Đã Check-out',
                isCompleted: true,
                completedTime: record.checkoutTime,
                refundedDeposit: record.refundAmount,
              ));
            }
          }

          return items;
        });
  }

  /// Thực hiện Check-out và Hoàn cọc
  Future<void> performCheckout({
    required String roomId,
    required String periodId,
    required String renterId,
    required double initialDeposit,
    required double deductionAmount,
    required String note,
  }) async {
    final batch = _firestore.batch();
    final refundAmount = (initialDeposit - deductionAmount).clamp(0.0, double.infinity);

    // 1. Tạo checkout_record
    final recordRef =
        _firestore.collection(FirestoreCollections.checkoutRecords).doc();
    final record = CheckoutRecordModel(
      id: recordRef.id,
      periodId: periodId,
      roomId: roomId,
      renterId: renterId,
      checkoutTime: DateTime.now(),
      depositAmount: initialDeposit,
      deductionAmount: deductionAmount,
      refundAmount: refundAmount,
      status: 'daCheckout',
      note: note,
    );
    batch.set(recordRef, record.toMap());

    // 2. Cập nhật period sang daKetThuc
    if (periodId.isNotEmpty && !periodId.startsWith('room_')) {
      final periodRef =
          _firestore.collection(FirestoreCollections.periods).doc(periodId);
      batch.update(periodRef, {
        'status': 'daKetThuc',
        'trangThai': 'daKetThuc',
        'endDate': FieldValue.serverTimestamp(),
        'ngayKetThuc': FieldValue.serverTimestamp(),
        'ketThucLuc': FieldValue.serverTimestamp(),
      });

      // Cập nhật cư dân trong period
      final resSnap = await _firestore
          .collection(FirestoreCollections.residents)
          .where('kyThue_id', isEqualTo: periodId)
          .get();
      for (final d in resSnap.docs) {
        batch.update(d.reference, {
          'statusId': 'daRoi',
          'trangThai_id': 'daRoi',
          'moveOutDate': FieldValue.serverTimestamp(),
          'ngayRoi': FieldValue.serverTimestamp(),
        });
      }
    }

    // 3. Cập nhật phòng host_rooms sang available / còn phòng
    final roomRef =
        _firestore.collection(FirestoreCollections.hostRooms).doc(roomId);
    batch.update(roomRef, {
      'status': 'available',
      'tenantName': '',
      'tenantPhone': '',
      'tenantAvatar': '',
      'contractId': '',
      'contractStart': null,
      'contractEnd': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<Map<String, String>> _getPropertyNames(List<RoomModel> rooms) async {
    final map = <String, String>{};
    final propIds = rooms
        .map((r) => r.propertyId)
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final pid in propIds) {
      try {
        final doc = await _firestore
            .collection(FirestoreCollections.hostProperties)
            .doc(pid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          map[pid] = data?['name'] ?? data?['tenNha'] ?? data?['title'] ?? 'Nhà trọ';
        }
      } catch (_) {}
    }
    return map;
  }
}
