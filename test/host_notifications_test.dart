import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/constants/firestore_collections.dart';
import 'package:home_share/features/host/notifications/models/host_notification_model.dart';
import 'package:home_share/features/host/notifications/notification_types.dart';
import 'package:home_share/features/host/notifications/providers/host_notification_provider.dart';
import 'package:home_share/features/host/notifications/screens/host_booking_change_confirmation_screen.dart';
import 'package:home_share/features/host/notifications/screens/host_notifications_screen.dart';
import 'package:home_share/features/host/notifications/widgets/notification_card.dart';

void main() {
  group('Host Notifications Module Tests', () {
    test('HostNotificationType Enum mapping and aliases', () {
      expect(HostNotificationType.deposit.code, 'deposit');
      expect(HostNotificationType.deposit.label, 'Đã cọc');

      expect(HostNotificationType.pendingAction.code, 'pendingAction');
      expect(HostNotificationType.pendingAction.label, 'Đang xử lý');

      expect(HostNotificationType.paymentCompleted.code, 'paymentCompleted');
      expect(HostNotificationType.paymentCompleted.label, 'Đã thanh toán hết');

      expect(HostNotificationTypeX.fromString('deposit'), HostNotificationType.deposit);
      expect(HostNotificationTypeX.fromString('thongbaotiencoc'), HostNotificationType.deposit);
      expect(HostNotificationTypeX.fromString('paymentCompleted'), HostNotificationType.paymentCompleted);
      expect(HostNotificationTypeX.fromString('thanhtoan'), HostNotificationType.paymentCompleted);
      expect(HostNotificationTypeX.fromString('pendingAction'), HostNotificationType.pendingAction);
      expect(HostNotificationTypeX.fromString(null), HostNotificationType.pendingAction);
    });

    test('HostNotificationModel serialization with English and Vietnamese keys', () {
      final now = DateTime(2026, 10, 15, 10, 0);
      final model = HostNotificationModel(
        id: 'notif_001',
        receiverId: 'host_123',
        senderId: 'renter_456',
        type: HostNotificationType.deposit,
        title: 'Xác nhận cọc',
        message: 'Đã nhận tiền cọc',
        bookingId: 'BK12345',
        bookingCode: '#BK12345',
        roomId: 'room_101',
        propertyId: 'prop_01',
        amount: 1500000,
        statusId: 'deposited',
        isRead: false,
        createdAt: now,
        roomCode: '101',
        roomTitle: 'Phòng 101 – Ban công lộng gió',
        roomFloorInfo: 'Tầng 1 • Căn hộ mini 25m²',
        renterName: 'Trần Phương Linh',
        checkInDate: DateTime(2026, 10, 15),
      );

      final map = model.toMap();
      expect(map[NotificationFields.notificationId], 'notif_001');
      expect(map[NotificationFields.legacyNotificationId], 'notif_001');
      expect(map[NotificationFields.receiverId], 'host_123');
      expect(map[NotificationFields.legacyReceiverId], 'host_123');
      expect(map[NotificationFields.notificationType], 'deposit');
      expect(map[NotificationFields.amount], 1500000);
      expect(map[NotificationFields.legacyAmount], 1500000);

      // Deserialization
      final fromData = HostNotificationModel.fromMap(map, 'notif_001');
      expect(fromData.id, 'notif_001');
      expect(fromData.receiverId, 'host_123');
      expect(fromData.senderId, 'renter_456');
      expect(fromData.type, HostNotificationType.deposit);
      expect(fromData.amount, 1500000);
      expect(fromData.displayBookingCode, '#BK12345');
      expect(fromData.displayRoomCode, '101');
      expect(fromData.renterName, 'Trần Phương Linh');
    });

    test('HostNotificationModel from Vietnamese legacy map', () {
      final legacyMap = {
        'thongBaoId': 'notif_leg_01',
        'nguoiNhanId': 'chuNha_01',
        'nguoiGuiId': 'khach_01',
        'loaiThongBao': 'thong_bao_tien_coc',
        'tieuDe': 'Thông báo tiền cọc',
        'noiDung': 'Khách đặt cọc',
        'donId': 'BK99999',
        'phongId': 'phong_203',
        'soTien': 1800000,
        'trangThai_id': 'choXacNhan',
        'daDoc': false,
        'tenNguoiO': 'Nguyễn Quốc Huy',
        'tenPhong': 'Phòng 203 – Gác đúc cao cấp',
        'roomCode': '203',
      };

      final parsed = HostNotificationModel.fromMap(legacyMap, 'notif_leg_01');
      expect(parsed.id, 'notif_leg_01');
      expect(parsed.receiverId, 'chuNha_01');
      expect(parsed.senderId, 'khach_01');
      expect(parsed.type, HostNotificationType.deposit);
      expect(parsed.amount, 1800000);
      expect(parsed.renterName, 'Nguyễn Quốc Huy');
      expect(parsed.displayRoomCode, '203');
    });

    test('FirestoreCollections contains notifications and payments', () {
      expect(FirestoreCollections.notifications, 'notifications');
      expect(FirestoreCollections.payments, 'payments');
    });

    testWidgets('HostNotificationsScreen renders search bar and filter chips',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostNotificationCountsProvider.overrideWith((ref) => Stream.value({
                  HostNotificationType.pendingAction: 3,
                  HostNotificationType.deposit: 5,
                  HostNotificationType.paymentCompleted: 2,
                })),
            hostNotificationsProvider.overrideWith((ref, type) => Stream.value([
                  HostNotificationModel(
                    id: 'mock_1',
                    receiverId: 'host_01',
                    type: HostNotificationType.pendingAction,
                    title: 'Yêu cầu đặt cọc giữ chỗ mới',
                    bookingId: 'BK12345',
                    bookingCode: '#BK12345',
                    roomCode: '101',
                    roomTitle: 'Phòng 101 – Ban công lộng gió',
                    roomFloorInfo: 'Tầng 1 • Căn hộ mini 25m²',
                    renterName: 'Trần Phương Linh',
                    amount: 1500000,
                    createdAt: DateTime(2026, 10, 15),
                    checkInDate: DateTime(2026, 10, 15),
                  ),
                ])),
          ],
          child: const MaterialApp(
            home: HostNotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thông báo'), findsOneWidget);
      expect(find.text('Tìm kiếm theo mã booking...'), findsOneWidget);
      expect(find.text('Đang xử lý'), findsOneWidget);
      expect(find.text('Đã cọc'), findsOneWidget);
      expect(find.text('Đã thanh toán hết'), findsOneWidget);
      expect(find.text('Đang ở'), findsNothing);
      expect(find.text('Phòng 101 – Ban công lộng gió'), findsOneWidget);
    });

    testWidgets('NotificationCard renders correctly for pendingAction and deposit',
        (tester) async {
      final sample = HostNotificationModel(
        id: 'test_card_01',
        receiverId: 'host_01',
        type: HostNotificationType.pendingAction,
        title: 'Yêu cầu đặt cọc giữ chỗ mới',
        bookingId: 'BK12345',
        bookingCode: '#BK12345',
        roomCode: '101',
        roomTitle: 'Phòng 101 – Ban công lộng gió',
        roomFloorInfo: 'Tầng 1 • Căn hộ mini 25m²',
        renterName: 'Trần Phương Linh',
        amount: 1500000,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        checkInDate: DateTime(2026, 10, 15),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: NotificationCard(
                notification: sample,
                currentTabType: HostNotificationType.pendingAction,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('101'), findsOneWidget);
      expect(find.text('Phòng 101 – Ban công lộng gió'), findsOneWidget);
      expect(find.text('#BK12345'), findsOneWidget);
      expect(find.text('Trần Phương Linh'), findsOneWidget);
      expect(find.text('Chờ xác nhận cọc'), findsOneWidget);

      // Bấm vào thẻ ở tab pendingAction không mở màn hình "Xác nhận thay đổi"
      await tester.tap(find.text('#BK12345'));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận thay đổi'), findsNothing);
    });

    testWidgets('HostBookingChangeConfirmationScreen renders Figma Image 1 layout',
        (tester) async {
      final sample = HostNotificationModel(
        id: 'test_conf_01',
        receiverId: 'host_01',
        type: HostNotificationType.pendingAction,
        title: 'Thay đổi thông tin',
        bookingId: 'BK12345',
        bookingCode: '#BK12345',
        roomCode: '101',
        amount: 1500000,
        createdAt: DateTime.now(),
        oldRoomTitle: 'Phòng 101, Tầng 1 (25m²)',
        newRoomTitle: 'Phòng 201, Tầng 2 (Có gác lửng)',
        oldCheckInDate: DateTime(2026, 10, 12),
        newCheckInDate: DateTime(2026, 10, 15),
        adjustmentReason:
            'Phòng 101 đang được vệ sinh và bảo dưỡng điều hòa, giữ nguyên giá cọc và hỗ trợ nhận phòng sớm.',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: HostBookingChangeConfirmationScreen(notification: sample),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận thay đổi'), findsOneWidget);
      expect(find.text('Mã đơn đặt chỗ: #BK12345'), findsOneWidget);
      expect(find.text('Thông báo từ Chủ nhà'), findsOneWidget);
      expect(find.text('Chú Ba Linh Trung'), findsOneWidget);
      expect(find.text('Chi tiết thay đổi đặt chỗ'), findsOneWidget);
      expect(find.text('1. CĂN PHÒNG ĐĂNG KÝ'), findsOneWidget);
      expect(find.text('2. NGÀY NHẬN PHÒNG (CHECK-IN)'), findsOneWidget);
      expect(find.text('Giữ nguyên giá cọc'), findsOneWidget);
      expect(find.text('Từ chối'), findsOneWidget);
      expect(find.text('Xác nhận đồng ý'), findsOneWidget);
    });
  });
}
