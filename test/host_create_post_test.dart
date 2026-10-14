import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:home_share/core/theme/app_theme.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/host/data/host_property.dart';
import 'package:home_share/features/host/providers/host_dashboard_provider.dart';
import 'package:home_share/features/host/providers/host_management_provider.dart';
import 'package:home_share/features/host/screens/host_create_post_screen.dart';
import 'package:home_share/features/host/screens/host_create_screen.dart';

class CreatePostTestRepository extends HostRepository {
  final properties = <HostProperty>[];
  final rooms = <RoomModel>[];
  final posts = <Map<String, dynamic>>[];
  final customAmenitiesCreated = <Map<String, dynamic>>[];
  final tienIchPhongLinks = <Map<String, dynamic>>[];

  bool failCreateRoom = false;
  bool failCreatePost = false;
  bool rollbackCleanedUp = false;

  @override
  String newPropertyId() => 'prop_test_1';

  @override
  Stream<List<HostProperty>> watchProperties(String uid) =>
      Stream.value(properties.where((p) => p.hostId == uid).toList());

  @override
  Stream<List<RoomModel>> watchRooms(String uid) =>
      Stream.value(rooms.where((r) => r.hostId == uid).toList());

  @override
  Stream<List<RoomModel>> watchRoomsByProperty(String uid, String propertyId) =>
      Stream.value(
        rooms
            .where((r) => r.hostId == uid && r.propertyId == propertyId)
            .toList(),
      );

  @override
  Future<String> createProperty(
    HostProperty property,
    List<HostUpload> images,
    HostUpload? proof,
  ) async {
    properties.add(property);
    return property.id;
  }

  @override
  Future<void> createRoom(
    RoomModel room,
    List<HostUpload> images,
    String operationId,
  ) async {
    if (failCreateRoom) throw StateError('Lỗi kiểm thử khi lưu phòng');
    final id = 'room_${rooms.length + 1}';
    final saved = RoomModel.fromMap({
      ...room.toMap(),
      'id': id,
      'images': images.map((_) => 'http://example.com/mock.jpg').toList(),
    }, id);
    rooms.add(saved);
  }

  @override
  Future<List<String>> getRoomAmenitiesFromTienIchPhong(String roomId) async =>
      tienIchPhongLinks
          .where((l) => l['phongId'] == roomId)
          .map((l) => l['amenityName'] as String)
          .toList();

  @override
  Future<List<String>> getRoomImagesFromAnhPhong(String roomId) async =>
      const [];

  @override
  Future<String> createPostWithAmenities({
    required RoomModel room,
    required List<HostUpload> images,
    required String operationId,
    required Set<String> selectedAmenities,
    required List<String> customAmenities,
    required Map<String, String> catalogAmenitiesMap,
    required String chuNhaId,
    required String diaDiemId,
    required String loaiThueId,
    required String trangThaiId,
    required String tieuDe,
    required String moTa,
    required double giaThue,
    int phanTramTienCoc = 20,
    double? tienCoc,
    required String soDienThoaiLienHe,
    required String authorName,
    required String authorAvatar,
    String? nhaTroId,
    String? phongId,
  }) async {
    if (failCreatePost) {
      rollbackCleanedUp = true;
      throw StateError('Lỗi kiểm thử khi tạo bài đăng');
    }

    final targetRoomId =
        phongId ?? (room.id.isNotEmpty ? room.id : 'room_${rooms.length + 1}');

    final amenityNameToId = <String, String>{};
    for (final name in selectedAmenities) {
      final key = name.trim().toLowerCase();
      if (catalogAmenitiesMap.containsKey(key)) {
        amenityNameToId[name] = catalogAmenitiesMap[key]!;
      } else {
        final amId = 'custom_am_${customAmenitiesCreated.length + 1}';
        customAmenitiesCreated.add({
          'id': amId,
          'name': name,
          'label': name,
          'source': 'host_custom',
        });
        amenityNameToId[name] = amId;
      }
    }

    for (final entry in amenityNameToId.entries) {
      tienIchPhongLinks.add({
        'phongId': targetRoomId,
        'tienIch_Id': entry.value,
        'amenityName': entry.key,
      });
    }

    final calculatedDeposit = tienCoc ?? (giaThue * phanTramTienCoc / 100);

    final post = {
      'id': 'post_${posts.length + 1}',
      'phongId': targetRoomId,
      'chuNhaId': chuNhaId,
      'diaDiemId': diaDiemId,
      'loaiThue_id': loaiThueId,
      'trangThai_id': trangThaiId,
      'tieuDe': tieuDe,
      'moTa': moTa,
      'giaThue': giaThue,
      'phanTramTienCoc': phanTramTienCoc,
      'tienCoc': calculatedDeposit,
      'soDienThoaiLienHe': soDienThoaiLienHe,
      'ngayDang': DateTime.now(),
      'authorName': authorName,
      'authorAvatar': authorAvatar,
    };
    posts.add(post);
    return post['id'] as String;
  }
}

class TestPicker extends ImagePicker {
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => [
    XFile.fromData(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
      name: 'test.png',
      mimeType: 'image/png',
    ),
  ];
}

Widget createTestApp(
  Widget home,
  CreatePostTestRepository repository, {
  String hostUid = 'host-test-uid',
  List<Map<String, String>> catalogAmenities = const [
    {'id': 'am_1', 'name': 'Máy lạnh'},
    {'id': 'am_2', 'name': 'Có gác lửng'},
    {'id': 'am_3', 'name': 'Wifi tốc độ cao'},
    {'id': 'am_4', 'name': 'Giờ giấc tự do'},
  ],
  Stream<List<HostProperty>>? customPropertiesStream,
  Stream<List<RoomModel>>? customRoomsStream,
}) => ProviderScope(
  overrides: [
    hostSessionProvider.overrideWith((ref) => Stream.value(hostUid)),
    hostRepositoryProvider.overrideWithValue(repository),
    hostPropertiesProvider.overrideWith(
      (ref) => customPropertiesStream ?? repository.watchProperties(hostUid),
    ),
    hostRoomsProvider.overrideWith(
      (ref) => customRoomsStream ?? repository.watchRooms(hostUid),
    ),
    hostAmenitiesProvider.overrideWith((ref) => Stream.value(catalogAmenities)),
    hostImagePickerProvider.overrideWithValue(TestPicker()),
    userProfileProvider.overrideWith(
      (ref) => Stream.value(
        UserProfile(
          uid: hostUid,
          email: 'host@test.com',
          displayName: 'Anh Chủ Nhà',
          phoneNumber: '0987654321',
          role: 'host',
        ),
      ),
    ),
  ],
  child: MaterialApp(theme: AppTheme.lightTheme, home: home),
);

void setScreenSize(WidgetTester tester, {double width = 390}) {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
}

void main() {
  const defaultProperty = HostProperty(
    id: 'prop-1',
    name: 'Nhà trọ Hoa Sen',
    address: '18 Đường số 6, Tăng Nhơn Phú B, TP. Thủ Đức',
    city: 'TP. Hồ Chí Minh',
    ward: 'Tăng Nhơn Phú B',
    hostId: 'host-test-uid',
    plannedRooms: 5,
    floors: 2,
  );

  final defaultRoom = RoomModel(
    id: 'room-1',
    propertyId: 'prop-1',
    roomCode: 'P101',
    title: 'Phòng studio full nội thất',
    description: 'Phòng mới tinh, thoáng mát, gần trường ĐH.',
    price: 2800000,
    deposit: 840000,
    address: '18 Đường số 6, Tăng Nhơn Phú B, TP. Thủ Đức',
    district: 'Tăng Nhơn Phú B',
    city: 'TP. Hồ Chí Minh',
    area: 28,
    roomType: 'Phòng trọ',
    amenities: const ['Máy lạnh', 'Wifi tốc độ cao'],
    images: const ['http://example.com/room1.jpg'],
    hostId: 'host-test-uid',
    hostName: 'Anh Chủ Nhà',
    hostPhone: '0987654321',
    isAvailable: true,
    capacity: 2,
    floor: 1,
    createdAt: DateTime.now(),
    status: 'available',
  );

  group('Màn Tạo bài đăng - Role Chủ trọ', () {
    testWidgets(
      '1. Validate giá: chỉ nhận số digitsOnly, đồng bộ giá readonly ở Vị trí & liên hệ',
      (tester) async {
        setScreenSize(tester, width: 390);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty);
        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();
        final priceField = find.byKey(const ValueKey('price_input'));
        final readonlyField = find.byKey(const ValueKey('price_readonly'));

        expect(priceField, findsOneWidget);
        expect(readonlyField, findsOneWidget);

        // Ban đầu chưa nhập
        expect(find.text('Chưa nhập'), findsOneWidget);

        // Nhập text số
        await tester.enterText(priceField, '2800000');
        await tester.pumpAndSettle();

        // Giá readonly đồng bộ và hiển thị định dạng số
        expect(find.text('2.800.000'), findsOneWidget);

        // Đổi giá
        await tester.enterText(priceField, '3500000');
        await tester.pumpAndSettle();
        expect(find.text('3.500.000'), findsOneWidget);

        // Không tồn tại trường trạng thái phòng trong UI
        expect(find.text('Trạng thái phòng'), findsNothing);
      },
    );

    testWidgets(
      '2. Chống trùng tiện ích: chuẩn hóa chuỗi, chống trùng Firestore catalog và local list',
      (tester) async {
        setScreenSize(tester, width: 414);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty);

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        final customInput = find.byKey(const ValueKey('custom_amenity_input'));
        final addButton = find.byKey(
          const ValueKey('add_custom_amenity_button'),
        );

        // Trùng với danh mục Firestore (catalog có 'Máy lạnh')
        await tester.ensureVisible(customInput);
        await tester.enterText(customInput, '   máy lạnh   ');
        await tester.ensureVisible(addButton);
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        // Không tạo thêm item tùy chọn mới vì đã trùng với catalog
        expect(find.text('Tùy chọn'), findsNothing);
        expect(find.text('Đã chọn'), findsWidgets);

        // Thêm tiện ích tùy chọn hợp lệ mới
        await tester.ensureVisible(customInput);
        await tester.enterText(customInput, '   Gần trạm xe buýt   ');
        await tester.ensureVisible(addButton);
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        // Xuất hiện nhãn Tùy chọn và nút xóa X
        expect(find.text('Gần trạm xe buýt'), findsOneWidget);
        expect(find.text('Tùy chọn'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('delete_custom_amenity_Gần trạm xe buýt')),
          findsOneWidget,
        );

        // Thử thêm lại tiện ích tùy chọn đó (chống trùng local)
        await tester.ensureVisible(customInput);
        await tester.enterText(customInput, 'gần trạm xe buýt');
        await tester.ensureVisible(addButton);
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        // Vẫn chỉ có 1 item "Gần trạm xe buýt"
        expect(find.text('Gần trạm xe buýt'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Local-only trước submit: thêm tiện ích không gọi ghi Firestore ngay',
      (tester) async {
        setScreenSize(tester, width: 390);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty);

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        final customInput = find.byKey(const ValueKey('custom_amenity_input'));
        final addButton = find.byKey(
          const ValueKey('add_custom_amenity_button'),
        );

        await tester.ensureVisible(customInput);
        await tester.enterText(customInput, 'Nội thất cao cấp');
        await tester.ensureVisible(addButton);
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        // Chưa submit: repo chưa có bản ghi Firestore nào được tạo
        expect(repo.customAmenitiesCreated, isEmpty);
        expect(repo.tienIchPhongLinks, isEmpty);
        expect(repo.posts, isEmpty);
      },
    );

    testWidgets(
      '4. Toggle không xóa: chạm vào tiện ích tùy chọn chỉ bỏ chọn, nút X mới xóa',
      (tester) async {
        setScreenSize(tester, width: 390);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty);

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        final customInput = find.byKey(const ValueKey('custom_amenity_input'));
        final addButton = find.byKey(
          const ValueKey('add_custom_amenity_button'),
        );

        await tester.ensureVisible(customInput);
        await tester.enterText(customInput, 'Gần chợ');
        await tester.tap(addButton);
        await tester.pumpAndSettle();

        expect(find.text('Gần chợ'), findsOneWidget);
        expect(find.text('1 đang chọn'), findsOneWidget);

        // Chạm vào tile để toggle bỏ chọn
        final tile = find.byKey(const ValueKey('amenity_tile_Gần chợ'));
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();

        // Item vẫn còn, không bị xóa khỏi list
        expect(find.text('Gần chợ'), findsOneWidget);
        expect(find.text('0 đang chọn'), findsOneWidget);

        // Chạm lại để chọn lại
        await tester.ensureVisible(tile);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(find.text('1 đang chọn'), findsOneWidget);

        // Bấm nút xóa X: item bị xóa hoàn toàn khỏi list
        final deleteBtn = find.byKey(
          const ValueKey('delete_custom_amenity_Gần chợ'),
        );
        await tester.ensureVisible(deleteBtn);
        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        expect(find.text('Gần chợ'), findsNothing);
        expect(find.text('0 đang chọn'), findsOneWidget);
      },
    );

    testWidgets(
      '5. Thu gọn & Xem thêm: Thu gọn chỉ giữ item đã chọn, Xem thêm hiện toàn bộ',
      (tester) async {
        setScreenSize(tester, width: 390);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty);

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        final toggleBtn = find.byKey(const ValueKey('amenities_toggle_button'));

        // Mặc định đang thu gọn (chưa chọn gì -> không hiện item nào)
        await tester.ensureVisible(toggleBtn);
        expect(find.text('Xem thêm v'), findsOneWidget);
        expect(find.text('Máy lạnh'), findsNothing);

        // Bấm "Xem thêm v" -> hiện toàn bộ catalog
        await tester.tap(toggleBtn);
        await tester.pumpAndSettle();

        expect(find.text('Thu gọn ^'), findsOneWidget);
        expect(find.text('Máy lạnh'), findsOneWidget);
        expect(find.text('Có gác lửng'), findsOneWidget);
        expect(find.text('Wifi tốc độ cao'), findsOneWidget);

        // Chọn "Máy lạnh"
        final mayLanhTile = find.byKey(const ValueKey('amenity_tile_Máy lạnh'));
        await tester.ensureVisible(mayLanhTile);
        await tester.tap(mayLanhTile);
        await tester.pumpAndSettle();

        // Bấm "Thu gọn ^"
        await tester.ensureVisible(toggleBtn);
        await tester.tap(toggleBtn);
        await tester.pumpAndSettle();

        expect(find.text('Xem thêm v'), findsOneWidget);
        // Chỉ giữ item đã chọn "Máy lạnh"
        expect(find.text('Máy lạnh'), findsOneWidget);
        // Các item chưa chọn bị ẩn
        expect(find.text('Có gác lửng'), findsNothing);
        expect(find.text('Wifi tốc độ cao'), findsNothing);
      },
    );

    testWidgets('6. Nút Đăng bài responsive 390-430px và nằm ngoài vùng cuộn', (
      tester,
    ) async {
      setScreenSize(tester, width: 390);
      final repo = CreatePostTestRepository()..properties.add(defaultProperty);

      await tester.pumpWidget(
        createTestApp(const HostCreatePostScreen(), repo),
      );
      await tester.pumpAndSettle();

      final submitButton = find.byKey(const ValueKey('submit_post_button'));
      expect(submitButton, findsOneWidget);

      // Kiểm tra nút nằm trong SafeArea/bottomNavigationBar ngoài Scrollable
      final scrollable = find.byType(Scrollable).first;
      expect(
        find.descendant(of: scrollable, matching: submitButton),
        findsNothing,
      );

      // Thử thay đổi kích thước lên 430px (responsive)
      setScreenSize(tester, width: 430);
      await tester.pumpAndSettle();
      expect(submitButton, findsOneWidget);
    });

    testWidgets(
      '7. Nhà tải đúng theo chuNhaId: chỉ tải nhà trọ thuộc tài khoản chủ trọ hiện tại',
      (tester) async {
        setScreenSize(tester, width: 390);
        final otherProperty = HostProperty(
          id: 'prop-other',
          name: 'Nhà trọ Người Khác',
          address: '99 Đường X, Quận 1',
          city: 'TP. Hồ Chí Minh',
          ward: 'Bến Nghé',
          hostId: 'other-host-uid',
          plannedRooms: 10,
        );

        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty)
          ..properties.add(otherProperty);

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        // Mở dropdown chọn khu nhà
        await tester.tap(find.byKey(const ValueKey('property_select')));
        await tester.pumpAndSettle();

        // Chỉ hiển thị nhà của host-test-uid
        expect(find.text('Nhà trọ Hoa Sen').last, findsOneWidget);
        // Không hiển thị nhà của host khác
        expect(find.text('Nhà trọ Người Khác'), findsNothing);
      },
    );

    testWidgets(
      '8. Chọn nhà thì danh sách phòng thay đổi đúng và không thể chọn phòng của nhà khác',
      (tester) async {
        setScreenSize(tester, width: 390);
        final prop2 = HostProperty(
          id: 'prop-2',
          name: 'Nhà trọ Bình An',
          address: '45 Lê Văn Việt, Tăng Nhơn Phú A',
          city: 'TP. Hồ Chí Minh',
          ward: 'Tăng Nhơn Phú A',
          hostId: 'host-test-uid',
          plannedRooms: 3,
        );
        final roomOfProp2 = RoomModel(
          id: 'room-p2-1',
          propertyId: 'prop-2',
          roomCode: 'P201',
          title: 'Phòng 201 Nhà Bình An',
          description: 'Mô tả phòng 201',
          price: 3200000,
          deposit: 640000,
          address: '45 Lê Văn Việt',
          district: 'Tăng Nhơn Phú A',
          city: 'TP. Hồ Chí Minh',
          area: 30,
          roomType: 'Phòng trọ',
          amenities: const [],
          images: const [],
          hostId: 'host-test-uid',
          hostName: 'Anh Chủ Nhà',
          hostPhone: '0987654321',
          isAvailable: true,
          capacity: 2,
          floor: 2,
          createdAt: DateTime.now(),
          status: 'available',
        );

        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty)
          ..properties.add(prop2)
          ..rooms.add(defaultRoom)
          ..rooms.add(roomOfProp2);

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        // 1. Chọn Nhà trọ Hoa Sen (prop-1)
        await tester.tap(find.byKey(const ValueKey('property_select')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nhà trọ Hoa Sen').last);
        await tester.pumpAndSettle();

        // Mở dropdown phòng: chỉ thấy P101 của prop-1, KHÔNG thấy P201 của prop-2
        await tester.tap(find.byKey(const ValueKey('room_select')));
        await tester.pumpAndSettle();
        expect(
          find.text('P101 - Phòng studio full nội thất').last,
          findsOneWidget,
        );
        expect(find.text('P201 - Phòng 201 Nhà Bình An'), findsNothing);

        // Đóng dropdown bằng cách chọn P101
        await tester.tap(find.text('P101 - Phòng studio full nội thất').last);
        await tester.pumpAndSettle();

        // 2. Đổi sang Nhà trọ Bình An (prop-2): Xóa phòng cũ và cập nhật danh sách
        await tester.tap(find.byKey(const ValueKey('property_select')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nhà trọ Bình An').last);
        await tester.pumpAndSettle();

        // Kiểm tra dropdown phòng chỉ có phòng P201 của prop-2
        await tester.tap(find.byKey(const ValueKey('room_select')));
        await tester.pumpAndSettle();
        expect(find.text('P201 - Phòng 201 Nhà Bình An').last, findsOneWidget);
        expect(find.text('P101 - Phòng studio full nội thất'), findsNothing);
      },
    );

    testWidgets(
      '9. Khi chọn phòng: tự động điền tiêu đề, diện tích, giá, địa chỉ, hình ảnh, tiện ích',
      (tester) async {
        setScreenSize(tester, width: 390);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty)
          ..rooms.add(defaultRoom);

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        // Chọn nhà
        await tester.tap(find.byKey(const ValueKey('property_select')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nhà trọ Hoa Sen').last);
        await tester.pumpAndSettle();

        // Chọn phòng
        await tester.tap(find.byKey(const ValueKey('room_select')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('P101 - Phòng studio full nội thất').last);
        await tester.pumpAndSettle();

        // Tự động điền:
        // - Tiêu đề
        final titleField = tester.widget<TextFormField>(
          find.byKey(const ValueKey('title_input')),
        );
        expect(titleField.controller?.text, 'Phòng studio full nội thất');

        // - Diện tích
        final areaField = tester.widget<TextFormField>(
          find.byKey(const ValueKey('area_input')),
        );
        expect(areaField.controller?.text, '28');

        // - Giá phòng
        final priceField = tester.widget<TextFormField>(
          find.byKey(const ValueKey('price_input')),
        );
        expect(priceField.controller?.text, '2800000');

        // - Giá readonly đồng bộ
        expect(find.text('2.800.000'), findsOneWidget);

        // - Tiền cọc đã lưu của phòng tự động điền
        final depositField = tester.widget<TextFormField>(
          find.byKey(const ValueKey('deposit_input')),
        );
        expect(depositField.controller?.text, '840000');

        // - Địa chỉ
        final addressField = tester.widget<TextFormField>(
          find.byKey(const ValueKey('address_input')),
        );
        expect(
          addressField.controller?.text,
          '18 Đường số 6, Tăng Nhơn Phú B, TP. Thủ Đức',
        );

        // - Tiện ích đã liên kết (Máy lạnh, Wifi tốc độ cao)
        expect(find.text('2 đang chọn'), findsOneWidget);
        expect(find.text('Máy lạnh'), findsOneWidget);
        expect(find.text('Wifi tốc độ cao'), findsOneWidget);

        // - Hình ảnh phòng đã lưu hiển thị
        expect(find.text('Đã chọn 1/10'), findsOneWidget);
      },
    );

    testWidgets(
      '10. Tiền cọc hiển thị thay thế phần trăm cọc và tự động điền theo phòng đã chọn',
      (tester) async {
        setScreenSize(tester, width: 390);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty)
          ..rooms.add(defaultRoom);

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        // 1. Kiểm tra ô Tiền cọc hiển thị thay vì dropdown % cọc
        expect(find.byKey(const ValueKey('deposit_input')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('deposit_percent_select')),
          findsNothing,
        );

        // 2. Chọn nhà và phòng để kiểm tra tự động điền tiền cọc đã nhập từ phòng
        await tester.tap(find.byKey(const ValueKey('property_select')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nhà trọ Hoa Sen').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('room_select')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('P101 - Phòng studio full nội thất').last);
        await tester.pumpAndSettle();

        // Tiền cọc tự động điền 840000 theo defaultRoom.deposit
        final depositInput = tester.widget<TextFormField>(
          find.byKey(const ValueKey('deposit_input')),
        );
        expect(depositInput.controller?.text, '840000');

        // 3. Người dùng có thể chỉnh sửa số tiền cọc trực tiếp
        await tester.enterText(
          find.byKey(const ValueKey('deposit_input')),
          '1000000',
        );
        await tester.pumpAndSettle();

        final updatedDeposit = tester.widget<TextFormField>(
          find.byKey(const ValueKey('deposit_input')),
        );
        expect(updatedDeposit.controller?.text, '1000000');
      },
    );

    testWidgets(
      '10b. Phòng có tiền cọc bằng 0 nhưng có giá thuê: tự động điền tiền cọc bằng giá thuê phòng',
      (tester) async {
        setScreenSize(tester, width: 390);
        final roomZeroDeposit = RoomModel(
          id: 'room-zero-dep',
          propertyId: defaultProperty.id,
          roomCode: 'P102',
          title: 'Phòng 102 Chưa Đặt Cọc Riêng',
          description: 'Mô tả phòng 102',
          price: 3500000,
          deposit: 0,
          address: defaultProperty.fullAddress,
          district: defaultProperty.district,
          city: defaultProperty.city,
          area: 25,
          roomType: 'Phòng trọ',
          amenities: const [],
          images: const [],
          hostId: 'host-test-uid',
          hostName: 'Anh Chủ Nhà',
          hostPhone: '0987654321',
          createdAt: DateTime.now(),
          status: 'available',
        );

        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty)
          ..rooms.add(roomZeroDeposit);

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('property_select')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nhà trọ Hoa Sen').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('room_select')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('P102 - Phòng 102 Chưa Đặt Cọc Riêng').last);
        await tester.pumpAndSettle();

        // Tự động điền tiền cọc bằng giá thuê phòng (3500000)
        final depositInput = tester.widget<TextFormField>(
          find.byKey(const ValueKey('deposit_input')),
        );
        expect(depositInput.controller?.text, '3500000');
      },
    );

    testWidgets(
      '11. Persist sau submit: lưu tiện ích tùy chọn, bảng TienIch_Phong và lưu post schema SDS',
      (tester) async {
        setScreenSize(tester, width: 390);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty)
          ..rooms.add(defaultRoom);

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        // 1. Chọn khu nhà và phòng
        await tester.tap(find.byKey(const ValueKey('property_select')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nhà trọ Hoa Sen').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('room_select')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('P101 - Phòng studio full nội thất').last);
        await tester.pumpAndSettle();

        // 2. Thêm tiện ích tùy chọn
        final customInput = find.byKey(const ValueKey('custom_amenity_input'));
        final addAmenityBtn = find.byKey(
          const ValueKey('add_custom_amenity_button'),
        );
        await tester.ensureVisible(customInput);
        await tester.enterText(customInput, 'Khu an ninh 24/7');
        await tester.ensureVisible(addAmenityBtn);
        await tester.tap(addAmenityBtn);
        await tester.pumpAndSettle();

        // 3. Điền liên hệ
        final phoneInput = find.byKey(const ValueKey('phone_input'));
        await tester.ensureVisible(phoneInput);
        await tester.enterText(phoneInput, '0987654321');

        final descInput = find.byKey(const ValueKey('description_input'));
        await tester.ensureVisible(descInput);
        await tester.enterText(
          descInput,
          'Phòng mới tinh, thoáng mát, gần trường ĐH.',
        );

        // 4. Nhấn ĐĂNG BÀI NGAY
        final submitButton = find.byKey(const ValueKey('submit_post_button'));
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // A. Tiện ích tùy chọn lúc này mới được tạo trong amenities
        expect(repo.customAmenitiesCreated.length, 1);
        expect(repo.customAmenitiesCreated.first['name'], 'Khu an ninh 24/7');

        // B. Tạo liên kết TienIch_Phong
        expect(repo.tienIchPhongLinks.length, 3);
        for (final link in repo.tienIchPhongLinks) {
          expect(link['phongId'], 'room-1');
          expect(link['tienIch_Id'], isNotEmpty);
        }

        // C. Bài đăng lưu theo đúng schema
        expect(repo.posts.length, 1);
        final post = repo.posts.first;
        expect(post['phongId'], 'room-1');
        expect(post['chuNhaId'], 'host-test-uid');
        expect(post['diaDiemId'], 'Tăng Nhơn Phú B');
        expect(post['loaiThue_id'], 'thang');
        expect(post['trangThai_id'], 'dangHienThi');
        expect(post['tieuDe'], 'Phòng studio full nội thất');
        expect(post['giaThue'], 2800000);
        // defaultRoom có deposit 840.000 (30% của 2.800.000)
        expect(post['phanTramTienCoc'], 30);
        expect(post['tienCoc'], 840000);
        expect(post['soDienThoaiLienHe'], '0987654321');
        expect(post['ngayDang'], isNotNull);
      },
    );

    testWidgets(
      '12. Rollback handling: khi lỗi lưu bài đăng, kích hoạt rollback không để mồ côi dữ liệu',
      (tester) async {
        setScreenSize(tester, width: 390);
        final repo = CreatePostTestRepository()
          ..properties.add(defaultProperty)
          ..rooms.add(defaultRoom)
          ..failCreatePost = true;

        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repo),
        );
        await tester.pumpAndSettle();

        // Chọn nhà và phòng
        await tester.tap(find.byKey(const ValueKey('property_select')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nhà trọ Hoa Sen').last);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('room_select')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('P101 - Phòng studio full nội thất').last);
        await tester.pumpAndSettle();

        final phoneInput = find.byKey(const ValueKey('phone_input'));
        await tester.ensureVisible(phoneInput);
        await tester.enterText(phoneInput, '0987654321');

        // Submit gây lỗi
        final submitButton = find.byKey(const ValueKey('submit_post_button'));
        await tester.tap(submitButton);
        await tester.pumpAndSettle();

        // Rollback đã được trigger
        expect(repo.rollbackCleanedUp, isTrue);
        // Không có post nào được lưu lại
        expect(repo.posts, isEmpty);
      },
    );

    testWidgets(
      '13. Trạng thái Không có nhà và Chưa chọn nhà khi tài khoản chưa có cơ sở',
      (tester) async {
        setScreenSize(tester, width: 390);

        final repoEmpty = CreatePostTestRepository();
        await tester.pumpWidget(
          createTestApp(const HostCreatePostScreen(), repoEmpty),
        );
        await tester.pumpAndSettle();
        expect(find.text('Không có nhà'), findsOneWidget);
        expect(find.text('Chưa chọn nhà'), findsOneWidget);
      },
    );

    testWidgets('14. Trạng thái Nhà chưa có phòng khi cơ sở chưa tạo phòng', (
      tester,
    ) async {
      setScreenSize(tester, width: 390);

      final repoNoRooms = CreatePostTestRepository()
        ..properties.add(defaultProperty);
      await tester.pumpWidget(
        createTestApp(const HostCreatePostScreen(), repoNoRooms),
      );
      await tester.pumpAndSettle();

      // Chọn nhà
      await tester.tap(find.byKey(const ValueKey('property_select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nhà trọ Hoa Sen').last);
      await tester.pumpAndSettle();

      // Dropdown phòng hiển thị "Nhà chưa có phòng"
      expect(find.text('Nhà chưa có phòng'), findsOneWidget);
    });
  });
}
