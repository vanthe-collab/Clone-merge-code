import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/checkin_model.dart';
import '../../../data/models/handover_item_model.dart';
import '../../../data/models/period_model.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/models/room_model.dart';

/// Dữ liệu tổng hợp để hiển thị màn hình Bàn giao & Chốt chỉ số
class HandoverRoomContext {
  final String bookingId;
  final String roomId;
  final String roomCode;
  final String propertyName;
  final String address;
  final String renterId;
  final String renterName;
  final String renterPhone;
  final String renterAvatar;
  final bool isVerified;
  final double deposit;
  final int rentalMonths;
  final double electricityRate;
  final double waterRate;
  final double initialElectricityMeter;
  final double initialWaterMeter;
  final List<HandoverItemModel> items;

  const HandoverRoomContext({
    required this.bookingId,
    required this.roomId,
    required this.roomCode,
    required this.propertyName,
    required this.address,
    required this.renterId,
    required this.renterName,
    this.renterPhone = '',
    this.renterAvatar = '',
    this.isVerified = true,
    required this.deposit,
    this.rentalMonths = 12,
    this.electricityRate = 3500.0,
    this.waterRate = 20000.0,
    this.initialElectricityMeter = 1428.0,
    this.initialWaterMeter = 84.0,
    this.items = const [],
  });
}

class HandoverRepository {
  final FirebaseFirestore _firestore;

  HandoverRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Tải thông tin phòng, đơn đặt phòng và danh mục thiết bị bàn giao
  Future<HandoverRoomContext> getHandoverContext({
    required String bookingId,
    required String roomId,
  }) async {
    // 1. Đọc phòng
    RoomModel? room;
    if (roomId.isNotEmpty) {
      final roomDoc = await _firestore
          .collection(FirestoreCollections.hostRooms)
          .doc(roomId)
          .get();
      if (roomDoc.exists) {
        room = RoomModel.fromFirestore(roomDoc);
      }
    }

    // 2. Đọc booking nếu có
    BookingRequestModel? booking;
    if (bookingId.isNotEmpty) {
      final bookingDoc = await _firestore
          .collection(FirestoreCollections.bookings)
          .doc(bookingId)
          .get();
      if (bookingDoc.exists) {
        booking = BookingRequestModel.fromFirestore(bookingDoc);
      }
    }

    // 3. Tên property
    var propertyName = 'Nhà Đặng Văn Bi';
    var propertyAddress = room?.address ?? 'Nhà Đặng Văn Bi, TP. Thủ Đức';
    if (room != null && room.propertyId.isNotEmpty) {
      try {
        final propDoc = await _firestore
            .collection(FirestoreCollections.hostProperties)
            .doc(room.propertyId)
            .get();
        if (propDoc.exists) {
          final data = propDoc.data();
          propertyName = data?['name'] ?? data?['tenNha'] ?? propertyName;
          propertyAddress = data?['address'] ?? data?['diaChi'] ?? propertyAddress;
        }
      } catch (_) {}
    }

    // 4. Lấy danh sách thiết bị từ Firestore hoặc khởi tạo danh sách tiêu chuẩn
    var items = <HandoverItemModel>[];
    if (roomId.isNotEmpty) {
      final itemSnap = await _firestore
          .collection(FirestoreCollections.handoverItems)
          .where('roomId', isEqualTo: roomId)
          .get();

      if (itemSnap.docs.isNotEmpty) {
        items = itemSnap.docs.map(HandoverItemModel.fromFirestore).toList();
      }
    }

    if (items.isEmpty) {
      // Mẫu trang thiết bị tiêu chuẩn theo thiết kế Figma/PNG
      items = [
        const HandoverItemModel(
          id: 'item_ac',
          periodId: '',
          itemName: 'Điều hòa Daikin Inverter 1.5HP',
          description: 'Làm lạnh sâu, kèm 01 remote zin hoạt động tốt',
          condition: 'Đạt chuẩn',
          isChecked: true,
        ),
        const HandoverItemModel(
          id: 'item_heater',
          periodId: '',
          itemName: 'Bình nóng lạnh Ariston 20L',
          description: 'Chống giật ELCB an toàn, đủ van xả áp',
          condition: 'Đạt chuẩn',
          isChecked: true,
        ),
        const HandoverItemModel(
          id: 'item_bed',
          periodId: '',
          itemName: 'Giường, nệm & tủ quần áo',
          description: 'Gỗ công nghiệp An Cường mới 98%, nệm bọc ga mới',
          condition: 'Đạt chuẩn',
          isChecked: true,
        ),
        const HandoverItemModel(
          id: 'item_key',
          periodId: '',
          itemName: 'Khóa từ & 02 chìa khóa cơ',
          description: 'Thẻ từ mở cổng chính và 02 chìa phòng nguyên vẹn',
          condition: 'Đạt chuẩn',
          isChecked: true,
        ),
      ];
    }

    final roomCode = room?.roomCode.isNotEmpty == true
        ? room!.roomCode
        : (room?.title.isNotEmpty == true ? room!.title : '204');

    final renterName = booking?.renterName.isNotEmpty == true
        ? booking!.renterName
        : (room?.tenantName.isNotEmpty == true ? room!.tenantName : 'Đỗ Hoàng Long');

    final renterPhone = booking?.renterPhone.isNotEmpty == true
        ? booking!.renterPhone
        : (room?.tenantPhone.isNotEmpty == true ? room!.tenantPhone : '0912 345 678');

    final deposit = (booking != null && booking.deposit > 0)
        ? booking.deposit
        : ((room != null && room.deposit > 0) ? room.deposit : 4800000.0);

    return HandoverRoomContext(
      bookingId: bookingId,
      roomId: roomId,
      roomCode: roomCode,
      propertyName: propertyName,
      address: propertyAddress,
      renterId: booking?.renterId ?? 'renter_hl',
      renterName: renterName,
      renterPhone: renterPhone,
      renterAvatar: room?.tenantAvatar ?? '',
      isVerified: true,
      deposit: deposit,
      rentalMonths: booking?.rentalMonths ?? 12,
      electricityRate: room?.electricityRate ?? 3500.0,
      waterRate: room?.waterRate ?? 20000.0,
      initialElectricityMeter: 1428.0,
      initialWaterMeter: 84.0,
      items: items,
    );
  }

  /// Xác nhận bàn giao phòng & Chốt chỉ số
  Future<void> confirmHandover({
    required String bookingId,
    required String roomId,
    required String renterId,
    required String renterName,
    required String renterPhone,
    required String hostId,
    required double electricityMeter,
    required double electricityRate,
    required double waterMeter,
    required double waterRate,
    required bool isKeyHandedOver,
    required String note,
    required List<HandoverItemModel> items,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();

    // 1. Tạo hoặc lấy Period
    final periodRef = _firestore.collection(FirestoreCollections.periods).doc();
    final periodId = periodRef.id;

    final period = PeriodModel(
      id: periodId,
      bookingId: bookingId,
      roomId: roomId,
      renterId: renterId,
      startDate: now,
      status: 'dangO',
      isKeyHandedOver: isKeyHandedOver,
      handoverNote: note,
      initialElectricityMeter: electricityMeter,
      initialWaterMeter: waterMeter,
      createdAt: now,
    );
    batch.set(periodRef, period.toMap());

    // 2. Tạo Phiếu nhận phòng (checkin)
    final checkinRef =
        _firestore.collection(FirestoreCollections.checkins).doc();
    final checkin = CheckinModel(
      id: checkinRef.id,
      bookingId: bookingId,
      periodId: periodId,
      scannerId: hostId,
      scanTime: now,
      status: 'daNhanPhong',
      initialElectricityMeter: electricityMeter,
      initialWaterMeter: waterMeter,
      electricityRate: electricityRate,
      waterRate: waterRate,
      isKeyHandedOver: isKeyHandedOver,
      note: note,
      createdAt: now,
    );
    batch.set(checkinRef, checkin.toMap());

    // 3. Tạo cư dân (resident)
    final residentRef =
        _firestore.collection(FirestoreCollections.residents).doc();
    final resident = ResidentModel(
      id: residentRef.id,
      periodId: periodId,
      userId: renterId,
      fullName: renterName,
      phone: renterPhone,
      formId: 'chinh',
      statusId: 'dangO',
      moveInDate: now,
    );
    batch.set(residentRef, resident.toMap());

    // 4. Lưu từng hạng mục bàn giao (handover_items)
    for (final item in items) {
      final itemRef =
          _firestore.collection(FirestoreCollections.handoverItems).doc();
      final itemData = item
          .copyWith(id: itemRef.id, periodId: periodId)
          .toMap();
      itemData['roomId'] = roomId;
      batch.set(itemRef, itemData);
    }

    // 5. Cập nhật booking sang trạng thái dangO nếu có
    if (bookingId.isNotEmpty) {
      final bookingRef =
          _firestore.collection(FirestoreCollections.bookings).doc(bookingId);
      batch.update(bookingRef, {
        'status': 'dangO',
        'trangThai': 'dangO',
        'trangThaiDon_id': 'dangO',
        'acceptedDate': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 6. Cập nhật host_rooms sang occupied
    if (roomId.isNotEmpty) {
      final roomRef =
          _firestore.collection(FirestoreCollections.hostRooms).doc(roomId);
      batch.update(roomRef, {
        'status': 'occupied',
        'tenantName': renterName,
        'tenantPhone': renterPhone,
        'contractId': periodId,
        'contractStart': Timestamp.fromDate(now),
        'electricityRate': electricityRate,
        'waterRate': waterRate,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}
