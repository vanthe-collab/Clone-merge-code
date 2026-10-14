import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/features/host/providers/host_management_provider.dart';
import 'package:home_share/features/host/screens/host_room_list_screen.dart';
import 'package:home_share/features/host/screens/host_room_edit_screen.dart';
import 'host_management_test.dart' as fixture;

// Chủ trọ - Kiểm thử sửa/xóa - Luồng đi: Stream giả nhận cập nhật;
// kiểm tra chuyển màn và kết quả giao diện, không ghi Firebase thật.
class EditRepository extends fixture.TestRepository {
  bool failEdit = false;
  int edits = 0, deletes = 0;
  @override
  Future<void> updateRoom(
    RoomModel base,
    Map<String, dynamic> patch,
    List<String> keptImages,
    List<HostUpload> newImages,
    String operationId,
  ) async {
    edits++;
    if (failEdit) throw StateError('Không lưu được phòng kiểm thử');
    final index = rooms.indexWhere((r) => r.id == base.id);
    rooms[index] = RoomModel.fromMap({
      ...base.toMap(),
      ...patch,
      'images': keptImages,
    }, base.id);
    roomEvents.add(List.of(rooms));
  }

  @override
  Future<void> deleteRoom(RoomModel base) async {
    deletes++;
    rooms.removeWhere((r) => r.id == base.id);
    roomEvents.add(List.of(rooms));
  }
}

RoomModel photoRoom() => RoomModel.fromMap({
  ...fixture.makeRoom('101').toMap(),
  'images': ['https://example.com/room.jpg'],
  'tenantName': '',
  'electricityRate': 3500,
}, '101');
void main() {
  test(
    'Room details round trip with fees and lease; legacy fees stay unset',
    () {
      final room = photoRoom();
      final restored = RoomModel.fromMap(room.toMap(), room.id);
      expect(restored.electricityRate, 3500);
      expect(restored.waterRate, isNull);
      expect(restored.propertyId, 'house-1');
      expect(fixture.makeRoom('old').serviceFee, isNull);
    },
  );
  testWidgets('List filters and edit saves through detail preserving room ID', (
    tester,
  ) async {
    fixture.phone(tester, width: 320);
    final repo = EditRepository()
      ..properties.add(fixture.house)
      ..rooms.addAll([
        photoRoom(),
        fixture.makeRoom('102', status: 'occupied'),
      ]);
    addTearDown(repo.close);
    await tester.pumpWidget(
      fixture.app(const HostRoomListScreen(propertyId: 'house-1'), repo),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('room_filter_occupied')));
    await tester.pumpAndSettle();
    expect(find.text('Phòng 101'), findsNothing);
    expect(find.text('Phòng 102'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('room_filter_all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('host_room_101')));
    await tester.pumpAndSettle();
    final edit = find.byKey(const ValueKey('edit_room'));
    await tester.scrollUntilVisible(
      edit,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(edit);
    await tester.pumpAndSettle();
    for (final entry in {
      'roomCode': '103',
      'price': '3200000',
      'waterRate': '20000',
      'capacity': '35',
    }.entries) {
      final field = find.byKey(ValueKey('edit_${entry.key}'));
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, entry.value);
    }
    await tester.tap(find.byKey(const ValueKey('save_room')));
    await tester.pumpAndSettle();
    expect(repo.edits, 1);
    expect(repo.rooms.first.id, '101');
    expect(repo.rooms.first.roomCode, '103');
    expect(repo.rooms.first.waterRate, 20000);
    expect(repo.rooms.first.capacity, 35);
    expect(find.text('Chi tiết phòng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Failed save keeps input and invalid price prevents write', (
    tester,
  ) async {
    fixture.phone(tester);
    final repo = EditRepository()
      ..properties.add(fixture.house)
      ..rooms.add(photoRoom())
      ..failEdit = true;
    addTearDown(repo.close);
    await tester.pumpWidget(
      fixture.app(
        HostRoomEditScreen(room: repo.rooms.first, property: fixture.house),
        repo,
      ),
    );
    await tester.pumpAndSettle();
    final price = find.byKey(const ValueKey('edit_price'));
    await tester.ensureVisible(price);
    await tester.enterText(price, '0');
    await tester.tap(find.byKey(const ValueKey('save_room')));
    await tester.pumpAndSettle();
    expect(repo.edits, 0);
    await tester.ensureVisible(price);
    await tester.enterText(price, '3100000');
    await tester.tap(find.byKey(const ValueKey('save_room')));
    await tester.pumpAndSettle();
    expect(repo.edits, 1);
    expect(find.text('Không lưu được phòng kiểm thử'), findsOneWidget);
    expect(find.text('3100000'), findsOneWidget);
    expect(find.text('Chỉnh sửa phòng'), findsOneWidget);
  });
  testWidgets('Deletion requires confirmation and returns to room list', (
    tester,
  ) async {
    fixture.phone(tester);
    final repo = EditRepository()
      ..properties.add(fixture.house)
      ..rooms.add(photoRoom());
    addTearDown(repo.close);
    await tester.pumpWidget(
      fixture.app(const HostRoomListScreen(propertyId: 'house-1'), repo),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('host_room_101')));
    await tester.pumpAndSettle();
    final trash = find.byTooltip('Xóa phòng');
    await tester.scrollUntilVisible(
      trash,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(trash);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(repo.deletes, 0);
    await tester.tap(trash);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa phòng'));
    await tester.pumpAndSettle();
    expect(repo.deletes, 1);
    expect(find.text('Chưa có phòng. Bấm + để thêm phòng.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
