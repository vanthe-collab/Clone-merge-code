import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/constants/firestore_collections.dart';
import 'package:home_share/data/models/checkin_model.dart';
import 'package:home_share/data/models/checkout_record_model.dart';
import 'package:home_share/data/models/handover_item_model.dart';
import 'package:home_share/data/models/period_model.dart';
import 'package:home_share/data/models/resident_model.dart';
import 'package:home_share/features/host/repositories/checkin_checkout_repository.dart';
import 'package:home_share/features/host/repositories/tenant_repository.dart';
import 'package:home_share/features/host/screens/host_checkin_checkout_screen.dart';
import 'package:home_share/features/host/screens/host_management_menu.dart';
import 'package:home_share/features/host/screens/host_tenant_management_screen.dart';
import 'package:home_share/features/host/widgets/checkin_checkout_card.dart';
import 'package:home_share/features/host/widgets/handover_item_card.dart';
import 'package:home_share/features/host/widgets/handover_meter_card.dart';
import 'package:home_share/features/host/widgets/tenant_card.dart';

void main() {
  group('1. SDS Database Mapping & Model Tests', () {
    test('FirestoreCollections contains required host management collections', () {
      expect(FirestoreCollections.periods, 'periods');
      expect(FirestoreCollections.kyO, 'periods');
      expect(FirestoreCollections.checkins, 'checkins');
      expect(FirestoreCollections.residents, 'residents');
      expect(FirestoreCollections.handoverItems, 'handover_items');
      expect(FirestoreCollections.checkoutRecords, 'checkout_records');
    });

    test('PeriodModel dual getter and toMap verification', () {
      final now = DateTime(2024, 11, 1);
      final period = PeriodModel(
        id: 'p_101',
        bookingId: 'bk_1',
        roomId: 'r_1',
        renterId: 'u_1',
        startDate: now,
        status: 'dangO',
        initialElectricityMeter: 1428.0,
        initialWaterMeter: 84.0,
        createdAt: now,
      );

      expect(period.kyOId, 'p_101');
      expect(period.donId, 'bk_1');
      expect(period.phongId, 'r_1');
      expect(period.nguoiDungId, 'u_1');
      expect(period.chiSoDienDau, 1428.0);
      expect(period.chiSoNuocDau, 84.0);
      expect(period.trangThai, 'dangO');

      final map = period.toMap();
      expect(map['kyOId'], 'p_101');
      expect(map['donId'], 'bk_1');
      expect(map['chiSoDienBanDau'], 1428.0);
    });

    test('CheckinModel dual getter and toMap verification', () {
      final now = DateTime(2024, 11, 1, 10, 30);
      final checkin = CheckinModel(
        id: 'chk_1',
        bookingId: 'bk_1',
        periodId: 'p_1',
        scannerId: 'host_1',
        scanTime: now,
        status: 'daNhanPhong',
        initialElectricityMeter: 1428.0,
        initialWaterMeter: 84.0,
        electricityRate: 3500.0,
        waterRate: 20000.0,
        isKeyHandedOver: true,
        note: 'Đã giao 2 chìa khóa',
        createdAt: now,
      );

      expect(checkin.checkinId, 'chk_1');
      expect(checkin.donId, 'bk_1');
      expect(checkin.kyOId, 'p_1');
      expect(checkin.daBanGiaoChiaKhoa, isTrue);
      expect(checkin.donGiaDien, 3500.0);
      expect(checkin.donGiaNuoc, 20000.0);
      expect(checkin.ghiChu, 'Đã giao 2 chìa khóa');
    });

    test('ResidentModel roommates and form verification', () {
      final now = DateTime(2024, 11, 1);
      final res = ResidentModel(
        id: 'res_1',
        periodId: 'p_1',
        userId: 'u_2',
        fullName: 'Hà Vy',
        phone: '0901 223 344',
        formId: 'oGhep',
        statusId: 'dangO',
        moveInDate: now,
      );

      expect(res.residentId, 'res_1');
      expect(res.hoTen, 'Hà Vy');
      expect(res.sdt, '0901 223 344');
      expect(res.hinhThuc_id, 'oGhep');
      expect(res.trangThai_id, 'dangO');
    });

    test('CheckoutRecordModel deposit refund calculation', () {
      const initialDeposit = 4800000.0;
      const deductions = 1300000.0;
      const expectedRefund = 3500000.0;

      final record = CheckoutRecordModel(
        id: 'co_1',
        periodId: 'p_1',
        roomId: 'r_1',
        renterId: 'u_1',
        checkoutTime: DateTime.now(),
        depositAmount: initialDeposit,
        deductionAmount: deductions,
        refundAmount: initialDeposit - deductions,
        status: 'daCheckout',
        note: 'Khấu trừ tiền điện nước',
      );

      expect(record.tienCoc, initialDeposit);
      expect(record.khoanKhauTru, deductions);
      expect(record.tienHoan, expectedRefund);
      expect(record.trangThai, 'daCheckout');
    });

    test('HandoverItemModel toggle and condition', () {
      const item = HandoverItemModel(
        id: 'ac_1',
        periodId: 'p_1',
        itemName: 'Điều hòa Daikin Inverter 1.5HP',
        description: 'Làm lạnh sâu',
        condition: 'Đạt chuẩn',
        isChecked: true,
      );

      expect(item.tenHangMuc, 'Điều hòa Daikin Inverter 1.5HP');
      expect(item.daKiemTra, isTrue);

      final toggled = item.copyWith(isChecked: false);
      expect(toggled.daKiemTra, isFalse);
    });
  });

  group('2. Widget Render & Viewport (390–430px) Tests', () {
    testWidgets('TenantCard renders single and group roommates correctly',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final singleTenant = TenantItem(
        id: 't_1',
        primaryName: 'Lê Hoàng Nam',
        phone: '0912 345 678',
        roomId: 'r_203',
        roomName: 'P.203',
        propertyId: 'prop_1',
        propertyName: 'KTX mini L2',
        moveInDate: DateTime.now(),
      );

      final groupTenant = TenantItem(
        id: 't_2',
        primaryName: 'Hà Vy',
        phone: '0901 223 344',
        roomId: 'r_302',
        roomName: 'P.302',
        propertyId: 'prop_2',
        propertyName: 'SkyHome',
        roommates: [
          ResidentModel(
            id: 'r_1',
            periodId: 'p_2',
            userId: 'u_1',
            fullName: 'Hà Vy',
            moveInDate: DateTime.now(),
          ),
          ResidentModel(
            id: 'r_2',
            periodId: 'p_2',
            userId: 'u_2',
            fullName: 'Đức Anh',
            moveInDate: DateTime.now(),
          ),
        ],
        moveInDate: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TenantCard(tenant: singleTenant),
                TenantCard(tenant: groupTenant),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Lê Hoàng Nam'), findsOneWidget);
      expect(find.text('0912 345 678'), findsOneWidget);
      expect(find.text('Hà Vy & Đức Anh'), findsOneWidget);
      expect(find.text('2 người'), findsOneWidget);
      expect(find.text('Gọi'), findsNWidgets(2));
      expect(find.text('SMS'), findsNWidgets(2));
    });

    testWidgets('CheckinCheckoutCard displays pending and completed states',
        (tester) async {
      tester.view.physicalSize = const Size(430 * 2, 932 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final pendingItem = CheckinCheckoutItem(
        id: 'chk_1',
        bookingId: 'bk_1',
        roomId: 'r_204',
        roomCode: '204',
        renterId: 'u_1',
        renterName: 'Đỗ Hoàng Long',
        propertyName: 'Nhà Đặng Văn Bi',
        floor: 2,
        deposit: 4800000.0,
        expectedDate: DateTime(2024, 11, 30),
        status: 'Đang ở',
        isCompleted: false,
      );

      final completedItem = CheckinCheckoutItem(
        id: 'chk_2',
        bookingId: 'bk_2',
        roomId: 'r_105',
        roomCode: '105',
        renterId: 'u_2',
        renterName: 'Trần Thị Mai',
        propertyName: 'Ký túc xá L2',
        floor: 1,
        deposit: 3500000.0,
        expectedDate: DateTime(2024, 11, 15),
        status: 'Đã Check-out',
        isCompleted: true,
        completedTime: DateTime(2024, 11, 15, 10, 30),
        refundedDeposit: 3500000.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  CheckinCheckoutCard(
                    item: pendingItem,
                    isCheckinTab: false,
                    onAction: () {},
                  ),
                  CheckinCheckoutCard(
                    item: completedItem,
                    isCheckinTab: false,
                    onAction: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('204'), findsOneWidget);
      expect(find.text('Đỗ Hoàng Long'), findsOneWidget);
      expect(find.text('Check-out'), findsOneWidget);

      expect(find.text('105'), findsOneWidget);
      expect(find.text('Trần Thị Mai'), findsOneWidget);
      expect(find.text('Đã Check-out'), findsOneWidget);
    });

    testWidgets('HandoverMeterCard and HandoverItemCard render without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final elecCtrl = TextEditingController(text: '1428');
      var itemToggled = false;
      const sampleItem = HandoverItemModel(
        id: 'item_1',
        periodId: 'p_1',
        itemName: 'Bình nóng lạnh Ariston 20L',
        description: 'Chống giật ELCB an toàn',
        isChecked: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                HandoverMeterCard(
                  title: 'Chỉ số điện ban đầu (kWh)',
                  unit: 'kWh',
                  rate: 3500.0,
                  controller: elecCtrl,
                  isElectricity: true,
                ),
                HandoverItemCard(
                  item: sampleItem,
                  onToggle: (val) {
                    itemToggled = val;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Chỉ số điện ban đầu (kWh)'), findsOneWidget);
      expect(find.text('1428'), findsOneWidget);
      expect(find.text('kWh'), findsOneWidget);
      expect(find.text('Bình nóng lạnh Ariston 20L'), findsOneWidget);

      // Tap toggle
      await tester.tap(find.byType(Switch));
      expect(itemToggled, isFalse);
    });

    testWidgets('HostManagementMenu renders 3 options with current highlighted',
        (tester) async {
      HostManagementSection? selectedSection;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HostManagementMenu(
              currentSection: HostManagementSection.tenants,
              onSelect: (sec) {
                selectedSection = sec;
              },
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('Quản lý người thuê'), findsOneWidget);
      expect(find.text('Quản lý Check in/Check out'), findsOneWidget);
      expect(find.text('Quản lý vi phạm & Phí phạt'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Quản lý Check in/Check out'));
      expect(selectedSection, HostManagementSection.checkinCheckout);
    });

    testWidgets('HostTenantManagementScreen renders header and stats',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 2, 844 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HostTenantManagementScreen(),
          ),
        ),
      );

      expect(find.text('Quản lý cư dân & người thuê'), findsOneWidget);
      expect(find.text('Hồ sơ khách thuê & hợp đồng'), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);
    });

    testWidgets('HostCheckinCheckoutScreen renders QR banner and segmented tabs',
        (tester) async {
      tester.view.physicalSize = const Size(414 * 2, 896 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HostCheckinCheckoutScreen(),
          ),
        ),
      );

      expect(find.text('Quản lý Check in & Check Out'), findsOneWidget);
      expect(find.text('Quét mã'), findsOneWidget);
      expect(find.text('Check-in'), findsOneWidget);
      expect(find.text('Check-out'), findsOneWidget);
    });
  });
}
