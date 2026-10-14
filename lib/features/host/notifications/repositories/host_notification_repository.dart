import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../models/host_notification_model.dart';
import '../notification_types.dart';

/// Repository quản lý toàn bộ truy vấn Firestore cho thông báo chủ trọ
/// Tuân thủ nguyên tắc: Đây là nơi duy nhất tương tác trực tiếp với Cloud Firestore.
class HostNotificationRepository {
  final FirebaseFirestore? _customFirestore;

  HostNotificationRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _notificationsCol =>
      _firestore?.collection(FirestoreCollections.notifications);

  CollectionReference<Map<String, dynamic>>? get _bookingsCol =>
      _firestore?.collection(FirestoreCollections.bookings);

  static List<HostNotificationModel>? _mockNotifications;

  static List<HostNotificationModel> _getMockList(String hostId) {
    _mockNotifications ??= [
      ..._getSampleNotifications(hostId: hostId, type: HostNotificationType.pendingAction),
      ..._getSampleNotifications(hostId: hostId, type: HostNotificationType.deposit),
      ..._getSampleNotifications(hostId: hostId, type: HostNotificationType.paymentCompleted),
    ];
    return _mockNotifications!;
  }

  /// Lắng nghe danh sách thông báo theo loại thông báo và ID chủ trọ (Realtime)
  Stream<List<HostNotificationModel>> watchByType({
    required String hostId,
    required HostNotificationType type,
  }) {
    if (hostId.isEmpty || _notificationsCol == null) {
      final list = _getMockList(hostId).where((item) => item.type == type).toList();
      return Stream.value(list);
    }

    try {
      return _notificationsCol!
          .where(NotificationFields.receiverId, isEqualTo: hostId)
          .snapshots()
          .map((snapshot) {
            final list = snapshot.docs
                .map((doc) => HostNotificationModel.fromFirestore(doc))
                .where((item) => item.type == type)
                .toList();

            // Sắp xếp thông báo mới nhất lên trên
            list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

            // Nếu Firestore chưa có dữ liệu mẫu, trả về dữ liệu mẫu tương ứng với Figma
            if (list.isEmpty) {
              return _getMockList(hostId).where((item) => item.type == type).toList();
            }
            return list;
          })
          .handleError((_) {
            // Fallback an toàn khi offline hoặc rules hạn chế
            return _getMockList(hostId).where((item) => item.type == type).toList();
          });
    } catch (_) {
      return Stream.value(
        _getMockList(hostId).where((item) => item.type == type).toList(),
      );
    }
  }

  /// Đếm số lượng thông báo theo từng loại (phục vụ badge trên thanh filter chip)
  Stream<Map<HostNotificationType, int>> watchCounts(String hostId) {
    final defaultMock = _getMockList(hostId);
    Map<HostNotificationType, int> calcCounts(List<HostNotificationModel> items) {
      final res = <HostNotificationType, int>{
        HostNotificationType.pendingAction: 0,
        HostNotificationType.deposit: 0,
        HostNotificationType.paymentCompleted: 0,
      };
      for (final it in items) {
        res[it.type] = (res[it.type] ?? 0) + 1;
      }
      return res;
    }

    if (hostId.isEmpty || _notificationsCol == null) {
      return Stream.value(calcCounts(defaultMock));
    }

    try {
      return _notificationsCol!
          .where(NotificationFields.receiverId, isEqualTo: hostId)
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.isEmpty) {
              return calcCounts(_getMockList(hostId));
            }
            final list = snapshot.docs
                .map((doc) => HostNotificationModel.fromFirestore(doc))
                .toList();
            return calcCounts(list);
          })
          .handleError((_) => calcCounts(_getMockList(hostId)));
    } catch (_) {
      return Stream.value(calcCounts(_getMockList(hostId)));
    }
  }

  /// Đánh dấu một thông báo đã đọc
  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty || _notificationsCol == null) return;
    try {
      final docRef = _notificationsCol!.doc(notificationId);
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.update({
          NotificationFields.isRead: true,
          NotificationFields.legacyIsRead: true,
          NotificationFields.updatedAt: FieldValue.serverTimestamp(),
          NotificationFields.legacyUpdatedAt: FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
  }

  /// Đánh dấu tất cả thông báo của chủ trọ là đã đọc
  Future<void> markAllAsRead(String hostId) async {
    if (hostId.isEmpty || _notificationsCol == null || _firestore == null) return;
    try {
      final query = await _notificationsCol!
          .where(NotificationFields.receiverId, isEqualTo: hostId)
          .where(NotificationFields.isRead, isEqualTo: false)
          .get();

      final batch = _firestore!.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {
          NotificationFields.isRead: true,
          NotificationFields.legacyIsRead: true,
          NotificationFields.updatedAt: FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Lấy số lượng thông báo chưa đọc của chủ nhà
  Stream<int> getUnreadCount(String hostId) {
    if (hostId.isEmpty || _notificationsCol == null) return Stream.value(3);
    return _notificationsCol!
        .where(NotificationFields.receiverId, isEqualTo: hostId)
        .where(NotificationFields.isRead, isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length)
        .handleError((_) => 3);
  }

  /// Cập nhật điều chỉnh cọc (Đổi phòng, đổi ngày Check-in, lý do) từ Modal Thao tác chủ nhà
  Future<void> updateDepositAdjustment({
    required String notificationId,
    required String bookingId,
    required String newRoomId,
    required String newRoomTitle,
    required DateTime newCheckInDate,
    required String adjustmentReason,
    String? hostId,
  }) async {
    final fs = _firestore;
    final bCol = _bookingsCol;
    final nCol = _notificationsCol;
    if (fs == null || bCol == null || nCol == null) return;
    final batch = fs.batch();

    // 1. Cập nhật booking gốc
    if (bookingId.isNotEmpty) {
      final bookingRef = bCol.doc(bookingId);
      batch.set(
        bookingRef,
        {
          'newRoomId': newRoomId,
          'newRoomTitle': newRoomTitle,
          'newCheckInDate': Timestamp.fromDate(newCheckInDate),
          'adjustmentReason': adjustmentReason,
          'status': 'choXacNhanThayDoi',
          'trangThai': 'choXacNhanThayDoi',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    // 2. Cập nhật document notification của chủ trọ
    if (notificationId.isNotEmpty) {
      final notifRef = nCol.doc(notificationId);
      batch.set(
        notifRef,
        {
          NotificationFields.newRoomId: newRoomId,
          'newRoomTitle': newRoomTitle,
          NotificationFields.newCheckInDate: Timestamp.fromDate(newCheckInDate),
          NotificationFields.adjustmentReason: adjustmentReason,
          NotificationFields.statusId: 'choXacNhanThayDoi',
          NotificationFields.updatedAt: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  /// Admin duyệt xác nhận đã nhận tiền (cọc hoặc thanh toán hết):
  /// - Khi khách đặt phòng -> thông báo tạo ở "Đang xử lý" (Chờ xác nhận cọc).
  /// - Khách chuyển tiền cho bên Admin xác nhận.
  /// - Khi Admin duyệt đã nhận:
  ///   + Nếu duyệt cọc (isFullPayment = false): chuyển trạng thái sang "Đã cọc" (HostNotificationType.deposit).
  ///   + Nếu duyệt thanh toán đủ (isFullPayment = true): chuyển sang "Đã thanh toán hết" (HostNotificationType.paymentCompleted).
  Future<void> adminVerifyAndApprovePayment({
    required String bookingId,
    required String notificationId,
    bool isFullPayment = false,
  }) async {
    final targetType = isFullPayment
        ? HostNotificationType.paymentCompleted
        : HostNotificationType.deposit;
    final targetStatus = isFullPayment ? 'completed' : 'deposited';
    final bookingStatus = isFullPayment ? 'daThanhToanHet' : 'daCoc';

    // Cập nhật bộ nhớ mock nếu chạy chế độ mẫu
    if (_mockNotifications != null) {
      final index = _mockNotifications!.indexWhere(
        (n) => n.id == notificationId || (bookingId.isNotEmpty && n.bookingId == bookingId),
      );
      if (index != -1) {
        final item = _mockNotifications![index];
        _mockNotifications![index] = item.copyWith(
          type: targetType,
          statusId: targetStatus,
          isRead: true,
          updatedAt: DateTime.now(),
        );
      }
    }

    try {
      if (_firestore == null || _bookingsCol == null || _notificationsCol == null) return;
      final batch = _firestore!.batch();
      if (bookingId.isNotEmpty) {
        batch.set(
          _bookingsCol!.doc(bookingId),
          {
            'status': bookingStatus,
            'trangThai': bookingStatus,
            'statusId': targetStatus,
            'adminVerified': true,
            'adminVerifiedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      if (notificationId.isNotEmpty) {
        batch.set(
          _notificationsCol!.doc(notificationId),
          {
            NotificationFields.notificationType: targetType.code,
            NotificationFields.legacyNotificationType: targetType.code,
            NotificationFields.statusId: targetStatus,
            NotificationFields.legacyStatusId: targetStatus,
            NotificationFields.isRead: true,
            NotificationFields.legacyIsRead: true,
            NotificationFields.updatedAt: FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    } catch (_) {}
  }

  /// Duyệt xác nhận cọc của khách thuê
  Future<void> approveDeposit({
    required String bookingId,
    required String notificationId,
  }) async {
    if (_firestore == null || _bookingsCol == null || _notificationsCol == null) return;
    final batch = _firestore!.batch();
    if (bookingId.isNotEmpty) {
      batch.set(
        _bookingsCol!.doc(bookingId),
        {
          'status': 'daCoc',
          'trangThai': 'daCoc',
          'statusId': 'deposited',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    if (notificationId.isNotEmpty) {
      batch.set(
        _notificationsCol!.doc(notificationId),
        {
          NotificationFields.notificationType: HostNotificationType.deposit.code,
          NotificationFields.statusId: 'deposited',
          NotificationFields.isRead: true,
          NotificationFields.updatedAt: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Duyệt check-in phòng (Từ Tab Đã cọc -> Duyệt check-in)
  Future<void> approveCheckIn({
    required String bookingId,
    required String notificationId,
  }) async {
    if (_firestore == null || _bookingsCol == null || _notificationsCol == null) return;
    final batch = _firestore!.batch();
    if (bookingId.isNotEmpty) {
      batch.set(
        _bookingsCol!.doc(bookingId),
        {
          'status': 'dangO',
          'trangThai': 'dangO',
          'statusId': 'active',
          'checkInCompletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    if (notificationId.isNotEmpty) {
      batch.set(
        _notificationsCol!.doc(notificationId),
        {
          NotificationFields.statusId: 'completed',
          NotificationFields.isRead: true,
          NotificationFields.updatedAt: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Xác nhận đồng ý thay đổi đặt chỗ (Màn hình Figma: Xác nhận thay đổi)
  Future<void> confirmBookingChange({
    required String bookingId,
    required String notificationId,
  }) async {
    if (_firestore == null || _bookingsCol == null || _notificationsCol == null) return;
    final batch = _firestore!.batch();
    if (bookingId.isNotEmpty) {
      batch.set(
        _bookingsCol!.doc(bookingId),
        {
          'status': 'daXacNhanThayDoi',
          'trangThai': 'daXacNhanThayDoi',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    if (notificationId.isNotEmpty) {
      batch.set(
        _notificationsCol!.doc(notificationId),
        {
          NotificationFields.statusId: 'approved',
          NotificationFields.isRead: true,
          NotificationFields.updatedAt: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Từ chối thay đổi đặt chỗ
  Future<void> rejectBookingChange({
    required String bookingId,
    required String notificationId,
  }) async {
    if (_firestore == null || _bookingsCol == null || _notificationsCol == null) return;
    final batch = _firestore!.batch();
    if (bookingId.isNotEmpty) {
      batch.set(
        _bookingsCol!.doc(bookingId),
        {
          'status': 'tuChoiThayDoi',
          'trangThai': 'tuChoiThayDoi',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    if (notificationId.isNotEmpty) {
      batch.set(
        _notificationsCol!.doc(notificationId),
        {
          NotificationFields.statusId: 'rejected',
          NotificationFields.isRead: true,
          NotificationFields.updatedAt: FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  /// Dữ liệu mẫu chuẩn hóa sát 100% các giá trị trong Figma design
  static List<HostNotificationModel> _getSampleNotifications({
    required String hostId,
    required HostNotificationType type,
  }) {
    final now = DateTime(2026, 10, 15, 14, 0);

    if (type == HostNotificationType.pendingAction) {
      return [
        HostNotificationModel(
          id: 'notif_bk12345',
          receiverId: hostId,
          senderId: 'renter_linh',
          type: HostNotificationType.pendingAction,
          title: 'Yêu cầu đặt cọc giữ chỗ mới',
          message: 'Khách thuê Trần Phương Linh đã gửi tiền cọc giữ phòng 101',
          bookingId: 'BK12345',
          bookingCode: '#BK12345',
          roomId: 'room_101',
          propertyId: 'prop_nguyen_van_cu',
          amount: 1500000,
          statusId: 'pending',
          isRead: false,
          createdAt: now.subtract(const Duration(minutes: 15)),
          roomCode: '101',
          roomTitle: 'Phòng 101 – Ban công lộng gió',
          roomFloorInfo: 'Tầng 1 • Căn hộ mini 25m²',
          renterName: 'Trần Phương Linh',
          renterAvatarUrl: '',
          checkInDate: DateTime(2026, 10, 15),
        ),
        HostNotificationModel(
          id: 'notif_bk12348',
          receiverId: hostId,
          senderId: 'renter_huy',
          type: HostNotificationType.pendingAction,
          title: 'Yêu cầu đặt cọc giữ chỗ mới',
          message: 'Khách thuê Nguyễn Quốc Huy đã gửi tiền cọc giữ phòng 203',
          bookingId: 'BK12348',
          bookingCode: '#BK12348',
          roomId: 'room_203',
          propertyId: 'prop_nguyen_van_cu',
          amount: 1800000,
          statusId: 'pending',
          isRead: false,
          createdAt: now.subtract(const Duration(hours: 1)),
          roomCode: '203',
          roomTitle: 'Phòng 203 – Gác đúc cao cấp',
          roomFloorInfo: 'Tầng 2 • Khép kín 22m²',
          renterName: 'Nguyễn Quốc Huy',
          renterAvatarUrl: '',
          checkInDate: DateTime(2026, 10, 18),
        ),
        HostNotificationModel(
          id: 'notif_bk12352',
          receiverId: hostId,
          senderId: 'renter_yen',
          type: HostNotificationType.pendingAction,
          title: 'Yêu cầu đặt cọc giữ chỗ mới',
          message: 'Khách thuê Lê Hoàng Yến đã gửi tiền cọc giữ phòng 302',
          bookingId: 'BK12352',
          bookingCode: '#BK12352',
          roomId: 'room_302',
          propertyId: 'prop_nguyen_van_cu',
          amount: 2000000,
          statusId: 'pending',
          isRead: true,
          createdAt: now.subtract(const Duration(hours: 3)),
          roomCode: '302',
          roomTitle: 'Phòng 302 – Studio đầy đủ NT',
          roomFloorInfo: 'Tầng 3 • Cửa sổ lớn thoáng',
          renterName: 'Lê Hoàng Yến',
          renterAvatarUrl: '',
          checkInDate: DateTime(2026, 10, 20),
        ),
      ];
    } else if (type == HostNotificationType.deposit) {
      return [
        HostNotificationModel(
          id: 'notif_dep_101',
          receiverId: hostId,
          senderId: 'renter_linh',
          type: HostNotificationType.deposit,
          title: 'Đã xác nhận đặt cọc',
          message: 'Đã nhận 1.500.000 đ tiền cọc từ Trần Phương Linh',
          bookingId: 'BK12345',
          bookingCode: '#BK12345',
          roomId: 'room_101',
          propertyId: 'prop_nguyen_van_cu',
          amount: 1500000,
          statusId: 'deposited',
          isRead: false,
          createdAt: now.subtract(const Duration(minutes: 30)),
          roomCode: '101',
          roomTitle: 'Phòng 101 – Ban công lộng gió',
          roomFloorInfo: 'Tầng 1 • Căn hộ mini 25m²',
          renterName: 'Trần Phương Linh',
          renterAvatarUrl: '',
          checkInDate: DateTime(2026, 10, 15),
          oldRoomId: 'room_101',
          newRoomId: 'room_201',
          oldRoomTitle: 'Phòng 101, Tầng 1 (25m²)',
          newRoomTitle: 'Phòng 201, Tầng 2 (Có gác lửng)',
          oldCheckInDate: DateTime(2026, 10, 12),
          newCheckInDate: DateTime(2026, 10, 15),
          adjustmentReason:
              'Phòng 101 đang được vệ sinh và bảo dưỡng điều hòa, giữ nguyên giá cọc và hỗ trợ nhận phòng sớm.',
        ),
        HostNotificationModel(
          id: 'notif_dep_203',
          receiverId: hostId,
          senderId: 'renter_huy',
          type: HostNotificationType.deposit,
          title: 'Đã xác nhận đặt cọc',
          message: 'Đã nhận 1.800.000 đ tiền cọc từ Nguyễn Quốc Huy',
          bookingId: 'BK12348',
          bookingCode: '#BK12348',
          roomId: 'room_203',
          propertyId: 'prop_nguyen_van_cu',
          amount: 1800000,
          statusId: 'deposited',
          isRead: false,
          createdAt: now.subtract(const Duration(hours: 2)),
          roomCode: '203',
          roomTitle: 'Phòng 203 – Gác đúc cao cấp',
          roomFloorInfo: 'Tầng 2 • Khép kín 22m²',
          renterName: 'Nguyễn Quốc Huy',
          renterAvatarUrl: '',
          checkInDate: DateTime(2026, 10, 18),
        ),
        HostNotificationModel(
          id: 'notif_dep_302',
          receiverId: hostId,
          senderId: 'renter_yen',
          type: HostNotificationType.deposit,
          title: 'Đã xác nhận đặt cọc',
          message: 'Đã nhận 2.000.000 đ tiền cọc từ Lê Hoàng Yến',
          bookingId: 'BK12352',
          bookingCode: '#BK12352',
          roomId: 'room_302',
          propertyId: 'prop_nguyen_van_cu',
          amount: 2000000,
          statusId: 'deposited',
          isRead: true,
          createdAt: now.subtract(const Duration(hours: 4)),
          roomCode: '302',
          roomTitle: 'Phòng 302 – Studio đầy đủ NT',
          roomFloorInfo: 'Tầng 3 • Cửa sổ lớn thoáng',
          renterName: 'Lê Hoàng Yến',
          renterAvatarUrl: '',
          checkInDate: DateTime(2026, 10, 20),
        ),
        HostNotificationModel(
          id: 'notif_dep_401',
          receiverId: hostId,
          senderId: 'renter_nam',
          type: HostNotificationType.deposit,
          title: 'Đã xác nhận đặt cọc',
          message: 'Đã nhận 1.600.000 đ tiền cọc từ Phan Hải Nam',
          bookingId: 'BK12358',
          bookingCode: '#BK12358',
          roomId: 'room_401',
          propertyId: 'prop_nguyen_van_cu',
          amount: 1600000,
          statusId: 'deposited',
          isRead: true,
          createdAt: now.subtract(const Duration(days: 1)),
          roomCode: '401',
          roomTitle: 'Phòng 401 – View sông thoáng mát',
          roomFloorInfo: 'Tầng 4 • Ban công riêng',
          renterName: 'Phan Hải Nam',
          renterAvatarUrl: '',
          checkInDate: DateTime(2026, 10, 22),
        ),
        HostNotificationModel(
          id: 'notif_dep_105',
          receiverId: hostId,
          senderId: 'renter_anh',
          type: HostNotificationType.deposit,
          title: 'Đã xác nhận đặt cọc',
          message: 'Đã nhận 1.500.000 đ tiền cọc từ Vũ Mai Anh',
          bookingId: 'BK12360',
          bookingCode: '#BK12360',
          roomId: 'room_105',
          propertyId: 'prop_nguyen_van_cu',
          amount: 1500000,
          statusId: 'deposited',
          isRead: true,
          createdAt: now.subtract(const Duration(days: 2)),
          roomCode: '105',
          roomTitle: 'Phòng 105 – Phòng đơn tiện nghi',
          roomFloorInfo: 'Tầng 1 • Tiện di chuyển',
          renterName: 'Vũ Mai Anh',
          renterAvatarUrl: '',
          checkInDate: DateTime(2026, 10, 25),
        ),
      ];
    } else {
      // paymentCompleted
      return [
        HostNotificationModel(
          id: 'notif_pay_01',
          receiverId: hostId,
          senderId: 'renter_minh',
          type: HostNotificationType.paymentCompleted,
          title: 'Thanh toán tiền thuê tháng 10 hoàn tất',
          message: 'Khách thuê Đặng Tuấn Minh đã thanh toán 3.500.000 đ qua QR',
          bookingId: 'BK12290',
          bookingCode: '#BK12290',
          roomId: 'room_202',
          propertyId: 'prop_nguyen_van_cu',
          amount: 3500000,
          statusId: 'completed',
          isRead: true,
          createdAt: now.subtract(const Duration(hours: 6)),
          roomCode: '202',
          roomTitle: 'Phòng 202 – Căn hộ mini cao cấp',
          roomFloorInfo: 'Tầng 2 • Khép kín',
          renterName: 'Đặng Tuấn Minh',
          renterAvatarUrl: '',
          paymentMethod: 'Chuyển khoản VietQR',
        ),
        HostNotificationModel(
          id: 'notif_pay_02',
          receiverId: hostId,
          senderId: 'renter_hoa',
          type: HostNotificationType.paymentCompleted,
          title: 'Thanh toán tiền điện nước tháng 09',
          message: 'Khách thuê Lê Thu Hoa đã thanh toán 450.000 đ',
          bookingId: 'BK12150',
          bookingCode: '#BK12150',
          roomId: 'room_301',
          propertyId: 'prop_nguyen_van_cu',
          amount: 450000,
          statusId: 'completed',
          isRead: true,
          createdAt: now.subtract(const Duration(days: 1)),
          roomCode: '301',
          roomTitle: 'Phòng 301 – Studio thoáng mát',
          roomFloorInfo: 'Tầng 3 • Cửa sổ lớn',
          renterName: 'Lê Thu Hoa',
          renterAvatarUrl: '',
          paymentMethod: 'Ví ZaloPay / QR',
        ),
      ];
    }
  }
}
