import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/host/models/violation_model.dart';
import 'package:home_share/features/host/models/violation_record_model.dart';
import 'package:home_share/features/host/providers/violation_form_provider.dart';
import 'package:home_share/features/host/providers/violation_provider.dart';
import 'package:home_share/features/host/repositories/violation_repository.dart';
import 'package:home_share/features/host/screens/host_create_violation_screen.dart';
import 'package:home_share/features/host/screens/host_violation_management_screen.dart';
import 'package:home_share/features/host/widgets/violation_record_card.dart';
import 'package:home_share/features/host/widgets/violation_summary_card.dart';

void main() {
  final sampleViolation1 = ViolationModel(
    id: 'vp_rac',
    title: 'Để rác sai nơi quy định',
    defaultFine: 150000,
    category: 'Vệ sinh chung',
    iconName: 'delete_outline',
    createdAt: DateTime(2026, 10, 1),
  );

  final sampleViolation2 = ViolationModel(
    id: 'vp_on_ao',
    title: 'Ồn ào sau 23h',
    defaultFine: 200000,
    category: 'Trật tự an ninh',
    iconName: 'volume_up_outlined',
    createdAt: DateTime(2026, 10, 1),
  );

  final sampleRoom = const HostOccupiedRoomItem(
    roomId: 'room_203',
    roomCode: 'P.203',
    propertyId: 'prop_01',
    propertyName: 'KTX L2',
    periodId: 'period_01',
    tenantId: 'user_01',
    tenantName: 'Lê Hoàng Nam',
    tenantPhone: '0912345678',
  );

  final sampleRecordPending = ViolationRecordModel(
    id: 'rec_01',
    landlordId: 'host_01',
    roomId: 'room_203',
    roomCode: 'P.203',
    propertyName: 'KTX L2',
    tenantId: 'user_01',
    tenantName: 'Lê Hoàng Nam',
    tenantPhone: '0912345678',
    violationIds: const ['vp_rac'],
    violationTitles: const ['Để rác sai nơi quy định'],
    totalFine: 150000,
    paymentMethod: 'NEXT_INVOICE',
    status: 'PENDING',
    description: 'Vi phạm lần 1, để rác tại hành lang chung tầng 2.',
    createdAt: DateTime(2026, 10, 10, 10, 30),
  );

  final sampleRecordPaid = ViolationRecordModel(
    id: 'rec_02',
    landlordId: 'host_01',
    roomId: 'room_105',
    roomCode: 'P.105',
    propertyName: 'KTX L2',
    tenantId: 'user_02',
    tenantName: 'Trần Minh Tú',
    tenantPhone: '0933678910',
    violationIds: const ['vp_on_ao'],
    violationTitles: const ['Ồn ào sau 23h'],
    totalFine: 200000,
    paymentMethod: 'CASH',
    status: 'PAID',
    description: 'Bật nhạc lớn lúc 23h30',
    createdAt: DateTime(2026, 10, 8, 21, 15),
  );

  final dummyHostUser = UserProfile(
    uid: 'host_01',
    email: 'host@test.com',
    displayName: 'Chủ trọ Test',
    phoneNumber: '0901234567',
    role: 'host',
  );

  group('VP-001..VP-009: Violation Monthly Statistics & Models', () {
    test('Calculates monthly stats accurately from record list', () {
      final records = [sampleRecordPending, sampleRecordPaid];
      final stats = ViolationMonthlyStats.fromRecords(records);

      expect(stats.totalCount, 2);
      expect(stats.totalFineRecorded, 350000.0);
      expect(stats.totalPaid, 200000.0);
      expect(stats.totalPending, 150000.0);
      expect(stats.paidCount, 1);
      expect(stats.pendingCount, 1);
    });

    test('Ignores cancelled records in monthly totals', () {
      final cancelled = sampleRecordPending.copyWith(
        id: 'rec_03',
        status: 'CANCELLED',
      );
      final stats = ViolationMonthlyStats.fromRecords([
        sampleRecordPending,
        cancelled,
      ]);

      expect(stats.totalCount, 1);
      expect(stats.totalFineRecorded, 150000.0);
    });
  });

  group('BB-006..BB-025: ViolationFormNotifier Unit Tests', () {
    late ViolationFormNotifier notifier;

    setUp(() {
      notifier = ViolationFormNotifier(ViolationRepository());
    });

    test('Initial form state is pristine', () {
      expect(notifier.state.selectedRoom, isNull);
      expect(notifier.state.selectedViolations, isEmpty);
      expect(notifier.state.fineAmount, 0.0);
      expect(notifier.state.evidenceFiles, isEmpty);
      expect(notifier.state.paymentMethod, 'NEXT_INVOICE');
    });

    test('Selecting room updates state', () {
      notifier.selectRoom(sampleRoom);
      expect(notifier.state.selectedRoom?.roomCode, 'P.203');
      expect(notifier.state.selectedRoom?.tenantName, 'Lê Hoàng Nam');
    });

    test('Toggling violations recalculates total fine automatically', () {
      notifier.toggleViolation(sampleViolation1);
      expect(notifier.state.selectedViolations.length, 1);
      expect(notifier.state.fineAmount, 150000.0);

      // Add second violation
      notifier.toggleViolation(sampleViolation2);
      expect(notifier.state.selectedViolations.length, 2);
      expect(notifier.state.fineAmount, 350000.0);

      // Remove first violation
      notifier.toggleViolation(sampleViolation1);
      expect(notifier.state.selectedViolations.length, 1);
      expect(notifier.state.fineAmount, 200000.0);
    });

    test('Validation fails if room or violation is missing', () {
      expect(notifier.validate(), contains('chọn căn hộ'));

      notifier.selectRoom(sampleRoom);
      expect(notifier.validate(), contains('chọn ít nhất một hành vi'));

      notifier.toggleViolation(sampleViolation1);
      expect(notifier.validate(), isNull);
    });

    test('Switching payment method updates state', () {
      notifier.setPaymentMethod('CASH');
      expect(notifier.state.paymentMethod, 'CASH');
    });
  });

  group('Widget Tests: ViolationSummaryCard & ViolationRecordCard', () {
    testWidgets('ViolationSummaryCard renders total fine and sub-boxes',
        (tester) async {
      final stats = ViolationMonthlyStats.fromRecords([
        sampleRecordPending,
        sampleRecordPaid,
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViolationSummaryCard(
              stats: stats,
              selectedMonth: DateTime(2026, 10),
              onMonthChanged: (_) {},
              onFilterTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('TỔNG QUAN THÁNG'), findsOneWidget);
      expect(find.text('Tháng 10/2026'), findsOneWidget);
      expect(find.text('Tổng tiền phạt ghi nhận'), findsOneWidget);
      expect(find.text('350.000 đ'), findsOneWidget);
      expect(find.text('Tổng đã nộp'), findsOneWidget);
      expect(find.text('200.000 đ'), findsOneWidget);
      expect(find.text('Tổng chờ nộp'), findsOneWidget);
      expect(find.text('150.000 đ'), findsOneWidget);
    });

    testWidgets('ViolationRecordCard renders room, tenant, and action buttons',
        (tester) async {
      bool cashTapped = false;
      bool invoiceTapped = false;
      bool reminderTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ViolationRecordCard(
              record: sampleRecordPending,
              onCollectCash: () => cashTapped = true,
              onDeductInvoice: () => invoiceTapped = true,
              onSendReminder: () => reminderTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('P.203'), findsOneWidget);
      expect(find.text('Lê Hoàng Nam'), findsOneWidget);
      expect(find.text('Chờ nộp'), findsOneWidget);
      expect(find.text('Để rác sai nơi quy định'), findsOneWidget);
      expect(find.text('150.000 đ'), findsOneWidget);

      // Check Action Buttons
      expect(find.text('Trừ hóa đơn'), findsOneWidget);
      expect(find.text('Thu tiền mặt'), findsOneWidget);
      expect(find.text('Nhắc'), findsOneWidget);

      await tester.tap(find.text('Thu tiền mặt'));
      expect(cashTapped, isTrue);

      await tester.tap(find.text('Trừ hóa đơn'));
      expect(invoiceTapped, isTrue);

      await tester.tap(find.text('Nhắc'));
      expect(reminderTapped, isTrue);
    });
  });

  group('Widget Tests: HostCreateViolationScreen Layout & Interactions', () {
    testWidgets('HostCreateViolationScreen displays all 5 spec blocks',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostOccupiedRoomsProvider.overrideWith((ref) => [sampleRoom]),
            violationTypesProvider.overrideWith(
                (ref) => Stream.value([sampleViolation1, sampleViolation2])),
            userProfileProvider.overrideWith((ref) => Stream.value(dummyHostUser)),
          ],
          child: const MaterialApp(
            home: HostCreateViolationScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header
      expect(find.text('Lập biên bản vi phạm'), findsOneWidget);

      // Block 1: THÔNG TIN NGƯỜI VI PHẠM
      expect(find.text('THÔNG TIN NGƯỜI VI PHẠM'), findsOneWidget);
      expect(find.text('Căn hộ / Khách thuê vi phạm'), findsOneWidget);

      // Block 2: HÀNH VI VI PHẠM
      expect(find.text('HÀNH VI VI PHẠM'), findsOneWidget);
      expect(find.text('Để rác sai nơi quy định'), findsOneWidget);
      expect(find.text('Ồn ào sau 23h'), findsOneWidget);

      // Block 3: MỨC PHẠT & HÌNH THỨC XỬ LÝ
      expect(find.text('MỨC PHẠT & HÌNH THỨC XỬ LÝ'), findsOneWidget);
      expect(find.text('Cộng vào tiền phòng tháng sau'), findsOneWidget);
      expect(find.text('Thu tiền mặt trực tiếp'), findsOneWidget);

      // Block 4: BẰNG CHỨNG VI PHẠM
      expect(find.text('BẰNG CHỨNG VI PHẠM'), findsOneWidget);
      expect(find.text('Thêm tệp'), findsOneWidget);

      // Block 5: GHI CHÚ / MÔ TẢ VI PHẠM
      expect(find.text('GHI CHÚ / MÔ TẢ VI PHẠM'), findsOneWidget);

      // Bottom Button
      expect(find.text('Lưu biên bản vi phạm'), findsOneWidget);
    });

    testWidgets('Tapping a violation in Create screen updates fine box',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostOccupiedRoomsProvider.overrideWith((ref) => [sampleRoom]),
            violationTypesProvider.overrideWith(
                (ref) => Stream.value([sampleViolation1, sampleViolation2])),
            userProfileProvider.overrideWith((ref) => Stream.value(dummyHostUser)),
          ],
          child: const MaterialApp(
            home: HostCreateViolationScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial fine is 0
      expect(find.text('0'), findsOneWidget);

      // Tap on sampleViolation1 (150.000)
      await tester.tap(find.text('Để rác sai nơi quy định'));
      await tester.pumpAndSettle();

      expect(find.text('150.000'), findsOneWidget);
      expect(find.text('Chọn 1 lỗi'), findsOneWidget);
    });
  });

  group('Widget Tests: HostViolationManagementScreen Layout & Empty State', () {
    testWidgets('Displays Empty State when no violations exist',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostViolationRecordsStreamProvider
                .overrideWith((ref) => Stream.value([])),
            userProfileProvider.overrideWith((ref) => Stream.value(dummyHostUser)),
          ],
          child: const MaterialApp(
            home: HostViolationManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Quản lý vi phạm'), findsOneWidget);
      expect(find.text('Lập biên bản'), findsOneWidget);
      expect(find.text('Không có vi phạm nào trong tháng'), findsOneWidget);
    });

    testWidgets('Displays Violation Records when data is loaded',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hostViolationRecordsStreamProvider.overrideWith(
                (ref) => Stream.value([sampleRecordPending, sampleRecordPaid])),
            hostViolationMonthFilterProvider.overrideWith(
                () => HostViolationMonthFilterNotifier(DateTime(2026, 10))),
            userProfileProvider.overrideWith((ref) => Stream.value(dummyHostUser)),
          ],
          child: const MaterialApp(
            home: HostViolationManagementScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('P.203'), findsOneWidget);
      expect(find.text('Lê Hoàng Nam'), findsOneWidget);
      expect(find.text('P.105'), findsOneWidget);
      expect(find.text('Trần Minh Tú'), findsOneWidget);
    });
  });
}
