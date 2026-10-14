import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/period_model.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/models/room_model.dart';

/// Đại diện một nhóm hoặc một người thuê kèm phòng và cơ sở
class TenantItem {
  final String id;
  final String primaryName;
  final String phone;
  final String avatar;
  final String roomId;
  final String roomName;
  final String propertyId;
  final String propertyName;
  final int floor;
  final List<ResidentModel> roommates;
  final String periodId;
  final String bookingId;
  final DateTime moveInDate;
  final double deposit;
  final String status;

  bool get isGroup => roommates.length > 1;
  int get memberCount => roommates.isEmpty ? 1 : roommates.length;

  String get displayName {
    if (roommates.length > 1) {
      return roommates.map((r) => r.fullName).take(2).join(' & ');
    }
    return primaryName.isNotEmpty ? primaryName : 'Khách thuê';
  }

  const TenantItem({
    required this.id,
    required this.primaryName,
    required this.phone,
    this.avatar = '',
    required this.roomId,
    required this.roomName,
    required this.propertyId,
    required this.propertyName,
    this.floor = 1,
    this.roommates = const [],
    this.periodId = '',
    this.bookingId = '',
    required this.moveInDate,
    this.deposit = 0.0,
    this.status = 'dangO',
  });
}

/// Thống kê người thuê của chủ trọ
class TenantStats {
  final int facilityCount; // Số cơ sở
  final int activeTenantCount; // Số người đang thuê
  final int occupiedRoomCount; // Số phòng đang sử dụng

  const TenantStats({
    this.facilityCount = 0,
    this.activeTenantCount = 0,
    this.occupiedRoomCount = 0,
  });
}

class TenantRepository {
  final FirebaseFirestore _firestore;

  TenantRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Lắng nghe danh sách người thuê của chủ trọ hiện tại
  Stream<List<TenantItem>> watchHostTenants(String hostId) {
    if (hostId.isEmpty) return Stream.value([]);

    // 1. Lắng nghe rooms của chủ trọ
    return _firestore
        .collection(FirestoreCollections.hostRooms)
        .where('hostId', isEqualTo: hostId)
        .snapshots()
        .asyncMap((roomSnapshot) async {
          final hostRooms = roomSnapshot.docs
              .map(RoomModel.fromFirestore)
              .where((r) => r.status != 'deleted')
              .toList();

          if (hostRooms.isEmpty) return <TenantItem>[];

          final roomMap = {for (var r in hostRooms) r.id: r};
          final propertyIds =
              hostRooms.map((r) => r.propertyId).where((id) => id.isNotEmpty).toSet();

          // Lấy danh sách tên properties
          final propertyNameMap = <String, String>{};
          for (final pid in propertyIds) {
            try {
              final propDoc = await _firestore
                  .collection(FirestoreCollections.hostProperties)
                  .doc(pid)
                  .get();
              if (propDoc.exists) {
                final data = propDoc.data();
                propertyNameMap[pid] =
                    data?['name'] ?? data?['tenNha'] ?? data?['title'] ?? 'Nhà trọ';
              }
            } catch (_) {}
          }

          // 2. Tìm các bookings đang thuê của chủ nhà này
          final bookingsSnapshot = await _firestore
              .collection(FirestoreCollections.bookings)
              .where('hostId', isEqualTo: hostId)
              .get();

          final activeBookings = bookingsSnapshot.docs
              .map(BookingRequestModel.fromFirestore)
              .where((b) =>
                  b.status == 'dangO' ||
                  b.status == 'active' ||
                  b.status == 'approved' ||
                  b.status == 'daDuyet')
              .toList();

          // 3. Tìm các kỳ ở (periods) đang hoạt động
          final periodsSnapshot = await _firestore
              .collection(FirestoreCollections.periods)
              .where('status', isEqualTo: 'dangO')
              .get();

          final hostPeriods = periodsSnapshot.docs
              .map(PeriodModel.fromFirestore)
              .where((p) => roomMap.containsKey(p.roomId))
              .toList();

          // 4. Lấy cư dân theo từng kỳ ở
          final residentsByPeriod = <String, List<ResidentModel>>{};
          for (final period in hostPeriods) {
            final resSnap = await _firestore
                .collection(FirestoreCollections.residents)
                .where('kyThue_id', isEqualTo: period.id)
                .get();

            residentsByPeriod[period.id] =
                resSnap.docs.map(ResidentModel.fromFirestore).toList();
          }

          final items = <TenantItem>[];
          final processedRoomIds = <String>{};

          // Tổng hợp từ periods trước
          for (final period in hostPeriods) {
            final room = roomMap[period.roomId];
            if (room == null) continue;

            final periodResidents = residentsByPeriod[period.id] ?? [];
            final booking = activeBookings.cast<BookingRequestModel?>().firstWhere(
                  (b) => b?.id == period.bookingId,
                  orElse: () => null,
                );

            final propName = propertyNameMap[room.propertyId] ??
                (room.address.isNotEmpty ? room.address : 'Nhà trọ');

            final primaryName = periodResidents.isNotEmpty
                ? periodResidents.first.fullName
                : (booking?.renterName.isNotEmpty == true
                    ? booking!.renterName
                    : (room.tenantName.isNotEmpty ? room.tenantName : 'Cư dân'));

            final phone = periodResidents.isNotEmpty &&
                    periodResidents.first.phone.isNotEmpty
                ? periodResidents.first.phone
                : (booking?.renterPhone.isNotEmpty == true
                    ? booking!.renterPhone
                    : room.tenantPhone);

            items.add(TenantItem(
              id: period.id,
              primaryName: primaryName,
              phone: phone,
              avatar: periodResidents.isNotEmpty ? periodResidents.first.avatar : '',
              roomId: room.id,
              roomName: room.roomCode.isNotEmpty ? 'P.${room.roomCode}' : room.title,
              propertyId: room.propertyId,
              propertyName: propName,
              floor: room.floor > 0 ? room.floor : 1,
              roommates: periodResidents,
              periodId: period.id,
              bookingId: period.bookingId,
              moveInDate: period.startDate,
              deposit: booking?.deposit ?? room.deposit,
              status: period.status,
            ));
            processedRoomIds.add(room.id);
          }

          // Tổng hợp thêm từ activeBookings nếu chưa có period
          for (final booking in activeBookings) {
            if (processedRoomIds.contains(booking.roomId)) continue;
            final room = roomMap[booking.roomId];
            if (room == null) continue;

            final propName = propertyNameMap[room.propertyId] ??
                (room.address.isNotEmpty ? room.address : 'Nhà trọ');

            items.add(TenantItem(
              id: booking.id,
              primaryName: booking.renterName,
              phone: booking.renterPhone,
              roomId: room.id,
              roomName: room.roomCode.isNotEmpty ? 'P.${room.roomCode}' : room.title,
              propertyId: room.propertyId,
              propertyName: propName,
              floor: room.floor > 0 ? room.floor : 1,
              bookingId: booking.id,
              moveInDate: booking.moveInDate,
              deposit: booking.deposit,
              status: booking.status,
            ));
            processedRoomIds.add(room.id);
          }

          // Tổng hợp thêm từ các phòng có tenantName được gán trực tiếp
          for (final room in hostRooms) {
            if (processedRoomIds.contains(room.id)) continue;
            if (room.tenantName.trim().isNotEmpty &&
                (room.status == 'occupied' ||
                    room.status == 'daThue' ||
                    room.status == 'dangO')) {
              final propName = propertyNameMap[room.propertyId] ??
                  (room.address.isNotEmpty ? room.address : 'Nhà trọ');

              items.add(TenantItem(
                id: 'room_${room.id}',
                primaryName: room.tenantName,
                phone: room.tenantPhone,
                avatar: room.tenantAvatar,
                roomId: room.id,
                roomName:
                    room.roomCode.isNotEmpty ? 'P.${room.roomCode}' : room.title,
                propertyId: room.propertyId,
                propertyName: propName,
                floor: room.floor > 0 ? room.floor : 1,
                moveInDate: room.contractStart ?? DateTime.now(),
                deposit: room.deposit,
                status: 'dangO',
              ));
            }
          }

          return items;
        });
  }

  /// Lấy số liệu thống kê cơ sở, người đang thuê, phòng đang dùng
  Stream<TenantStats> watchTenantStats(String hostId) {
    if (hostId.isEmpty) return Stream.value(const TenantStats());

    return _firestore
        .collection(FirestoreCollections.hostRooms)
        .where('hostId', isEqualTo: hostId)
        .snapshots()
        .asyncMap((roomSnapshot) async {
          final hostRooms = roomSnapshot.docs
              .map(RoomModel.fromFirestore)
              .where((r) => r.status != 'deleted')
              .toList();

          final propSnap = await _firestore
              .collection(FirestoreCollections.hostProperties)
              .where('hostId', isEqualTo: hostId)
              .get();

          final facilityCount = propSnap.docs
              .where((d) => d.data()['status'] != 'deleted')
              .length;

          // Số phòng đang sử dụng
          final occupiedRooms = hostRooms.where((r) =>
              r.status == 'occupied' ||
              r.status == 'daThue' ||
              r.status == 'dangO' ||
              r.tenantName.isNotEmpty).length;

          // Đếm người thuê
          final bookingsSnap = await _firestore
              .collection(FirestoreCollections.bookings)
              .where('hostId', isEqualTo: hostId)
              .get();

          final activeBookingsCount = bookingsSnap.docs
              .map(BookingRequestModel.fromFirestore)
              .where((b) =>
                  b.status == 'dangO' ||
                  b.status == 'active' ||
                  b.status == 'approved' ||
                  b.status == 'daDuyet')
              .length;

          final activeTenants = occupiedRooms > activeBookingsCount
              ? occupiedRooms
              : activeBookingsCount;

          return TenantStats(
            facilityCount: facilityCount,
            activeTenantCount: activeTenants,
            occupiedRoomCount: occupiedRooms,
          );
        });
  }

  /// Thêm khách thuê mới trực tiếp vào phòng
  Future<void> addTenant({
    required String hostId,
    required String roomId,
    required String tenantName,
    required String tenantPhone,
    required double deposit,
    required DateTime moveInDate,
    int rentalMonths = 12,
  }) async {
    final batch = _firestore.batch();

    // 1. Tạo booking
    final bookingRef = _firestore.collection(FirestoreCollections.bookings).doc();
    final booking = BookingRequestModel(
      id: bookingRef.id,
      renterId: 'manual_${DateTime.now().millisecondsSinceEpoch}',
      renterName: tenantName,
      renterPhone: tenantPhone,
      roomId: roomId,
      roomTitle: 'Phòng thuê',
      roomAddress: '',
      roomPrice: 0.0,
      deposit: deposit,
      rentalMonths: rentalMonths,
      hostId: hostId,
      hostName: '',
      status: 'dangO',
      moveInDate: moveInDate,
      createdAt: DateTime.now(),
    );
    batch.set(bookingRef, booking.toMap());

    // 2. Tạo kỳ ở (period)
    final periodRef = _firestore.collection(FirestoreCollections.periods).doc();
    final period = PeriodModel(
      id: periodRef.id,
      bookingId: bookingRef.id,
      roomId: roomId,
      renterId: booking.renterId,
      startDate: moveInDate,
      status: 'dangO',
      createdAt: DateTime.now(),
    );
    batch.set(periodRef, period.toMap());

    // 3. Tạo cư dân (resident)
    final resRef = _firestore.collection(FirestoreCollections.residents).doc();
    final resident = ResidentModel(
      id: resRef.id,
      periodId: periodRef.id,
      userId: booking.renterId,
      fullName: tenantName,
      phone: tenantPhone,
      moveInDate: moveInDate,
    );
    batch.set(resRef, resident.toMap());

    // 4. Cập nhật phòng
    final roomRef =
        _firestore.collection(FirestoreCollections.hostRooms).doc(roomId);
    batch.update(roomRef, {
      'status': 'occupied',
      'tenantName': tenantName,
      'tenantPhone': tenantPhone,
      'contractStart': Timestamp.fromDate(moveInDate),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
