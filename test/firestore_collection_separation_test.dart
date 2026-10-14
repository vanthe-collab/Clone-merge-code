import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/constants/firestore_collections.dart';

void main() {
  test('kho phòng chủ trọ tách khỏi danh sách phòng công khai', () {
    expect(FirestoreCollections.publicRooms, 'rooms');
    expect(FirestoreCollections.hostRooms, 'host_rooms');
    expect(
      FirestoreCollections.hostRooms,
      isNot(FirestoreCollections.publicRooms),
    );
  });
}
