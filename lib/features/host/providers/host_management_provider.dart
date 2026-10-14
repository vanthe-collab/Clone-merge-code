import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/constants/vietnam_locations.dart';
import '../../../data/models/host_post_model.dart';
import '../../../data/models/room_model.dart';
import '../data/host_property.dart';

// Chủ trọ - Phiên Firebase - Luồng đi: Chỉ đọc dữ liệu khi Firebase đã
// khởi tạo và đã đăng nhập; chế độ preview không tự tạo tài khoản giả.
final hostSessionProvider = StreamProvider<String?>((ref) {
  if (Firebase.apps.isEmpty) return Stream.value(null);
  return FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
});
final hostRepositoryProvider = Provider<HostRepository>(
  (ref) => HostRepository(),
);
final hostPropertiesProvider = StreamProvider<List<HostProperty>>((ref) {
  final uid = ref.watch(hostSessionProvider).value;
  if (uid == null) return Stream.value([]);
  return ref.watch(hostRepositoryProvider).watchProperties(uid);
});
final hostRoomsProvider = StreamProvider<List<RoomModel>>((ref) {
  final uid = ref.watch(hostSessionProvider).value;
  if (uid == null) return Stream.value([]);
  return ref.watch(hostRepositoryProvider).watchRooms(uid);
});

// Chủ trọ - Ảnh đã chọn - Luồng đi: Giữ byte ảnh trong form để xem
// trước và tải bằng putData trên Chrome, Android và iOS.
class HostUpload {
  const HostUpload(this.bytes, this.contentType);
  final Uint8List bytes;
  final String contentType;
}

// Chủ trọ - Kho dữ liệu quản lý - Luồng đi: Lưu nhà vào properties,
// phòng vào host_rooms và ảnh vào đường dẫn riêng theo UID chủ trọ.
// Collection rooms được giữ riêng cho dữ liệu công khai của khách thuê.
class HostRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  // Chủ trọ - Theo dõi nhà và phòng - Luồng đi: Lọc hostId ở truy vấn;
  // sắp xếp tại ứng dụng để không yêu cầu composite index mới.
  Stream<List<HostProperty>> watchProperties(String uid) => _db
      .collection(FirestoreCollections.hostProperties)
      .where('hostId', isEqualTo: uid)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .where((doc) => doc.data()['status'] != 'deleted')
            .map((doc) => HostProperty.fromMap(doc.id, doc.data()))
            .toList();
        list.sort(
          (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
            a.createdAt ?? DateTime(1970),
          ),
        );
        return list;
      });
  Stream<List<RoomModel>> watchRooms(String uid) => _db
      .collection(FirestoreCollections.hostRooms)
      .where('hostId', isEqualTo: uid)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(RoomModel.fromFirestore)
            .where((room) => room.status != 'deleted')
            .toList(),
      );
  String newPropertyId() =>
      _db.collection(FirestoreCollections.hostProperties).doc().id;

  // Chủ trọ - Kiểm tra phiên lưu - Luồng đi: Trước khi ghi nhà/phòng,
  // xác nhận UID hiện tại vẫn là người đã mở form và có vai trò chủ trọ.
  Future<void> _requireHost(String uid) async {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Phiên đăng nhập đã thay đổi. Vui lòng đăng nhập lại.');
    }
    final profile = await _db.collection('users').doc(uid).get();
    final data = profile.data();
    if ((data?['role'] ?? data?['vaiTro']) != 'host') {
      throw StateError('Bạn cần tài khoản Chủ trọ để tạo nhà/phòng.');
    }
  }

  // Chủ trọ - Tải ảnh thực - Luồng đi: Kiểm tra định dạng và dung
  // lượng trước khi upload; lỗi Storage được báo, không thay bằng ảnh mẫu.
  Future<List<String>> _upload(
    List<HostUpload> images,
    String folder,
    int max,
  ) async {
    if (images.isEmpty || images.length > max) {
      throw StateError('Chọn từ 1 đến $max ảnh.');
    }
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      if (!['image/jpeg', 'image/png'].contains(image.contentType) ||
          image.bytes.length > 5 * 1024 * 1024) {
        throw StateError('Mỗi ảnh phải là JPG/PNG và không quá 5 MB.');
      }
      if (image.bytes.isEmpty) {
        throw StateError('Ảnh đã chọn bị rỗng. Vui lòng chọn lại ảnh.');
      }
      final object = _storage.ref('$folder/$i');
      final task = object.putData(
        image.bytes,
        SettableMetadata(contentType: image.contentType),
      );
      try {
        final snapshot = await task.timeout(
          const Duration(seconds: 60),
          onTimeout: () async {
            await task.cancel();
            throw StateError('Tải ảnh quá lâu. Kiểm tra mạng và thử lưu lại.');
          },
        );
        final url = await snapshot.ref.getDownloadURL();
        if (!url.startsWith('https://')) {
          throw StateError('Không lấy được đường dẫn ảnh. Vui lòng thử lại.');
        }
        urls.add(url);
      } on FirebaseException catch (error) {
        if (error.code == 'unauthorized') {
          throw StateError(
            'Firebase Storage chưa cho phép lưu ảnh nhà/phòng. Cần cập nhật quyền host_media cho tài khoản Chủ trọ.',
          );
        }
        rethrow;
      }
    }
    return urls;
  }

  // Chủ trọ - Tạo nhà - Luồng đi: Upload ảnh và giấy tờ tùy chọn, rồi
  // ghi cơ sở bằng ID giữ cố định khi thử lại; không tự tạo phòng giả.
  Future<String> createProperty(
    HostProperty property,
    List<HostUpload> images,
    HostUpload? proof,
  ) async {
    await _requireHost(property.hostId);
    final document = _db
        .collection(FirestoreCollections.hostProperties)
        .doc(property.id);
    if ((await document.get()).exists) return property.id;
    final urls = await _upload(
      images,
      'host_media/${property.hostId}/properties/${property.id}',
      5,
    );
    String? proofPath;
    if (proof != null) {
      if (!['image/jpeg', 'image/png'].contains(proof.contentType) ||
          proof.bytes.length > 15 * 1024 * 1024) {
        throw StateError('Giấy tờ phải là JPG/PNG và không quá 15 MB.');
      }
      proofPath = 'host_private/${property.hostId}/${property.id}/proof';
      await _storage
          .ref(proofPath)
          .putData(
            proof.bytes,
            SettableMetadata(contentType: proof.contentType),
          );
    }
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(document);
      if (!existing.exists) {
        transaction.set(document, {
          ...property.toMap(),
          'images': urls,
          'roomCount': 0,
          'roomCodes': <String, String>{},
          'proofPath': ?proofPath,
          'verificationStatus': 'unverified',
        });
      }
    });
    return property.id;
  }

  // Chủ trọ - Sửa cơ sở - Luồng đi: Giữ ID và ảnh cũ được chọn, tải ảnh
  // mới rồi cập nhật các trường quản lý; không cho giảm quy mô dưới số phòng.
  Future<void> updateProperty(
    HostProperty base,
    Map<String, dynamic> patch,
    List<String> keptImages,
    List<HostUpload> newImages,
    String operationId,
  ) async {
    await _requireHost(base.hostId);
    const allowed = {
      'name',
      'address',
      'city',
      'district',
      'ward',
      'plannedRooms',
      'floors',
      'minRent',
      'maxRent',
    };
    if (patch.keys.any((key) => !allowed.contains(key))) {
      throw StateError('Thông tin cơ sở chỉnh sửa không hợp lệ.');
    }
    if (keptImages.length + newImages.length < 1 ||
        keptImages.length + newImages.length > 5 ||
        keptImages.any((url) => !base.images.contains(url))) {
      throw StateError('Giữ từ 1 đến 5 ảnh cơ sở hợp lệ.');
    }
    final name = (patch['name'] as String).trim();
    final address = (patch['address'] as String).trim();
    final district = (patch['district'] as String).trim();
    final ward = (patch['ward'] as String).trim();
    final plannedRooms = (patch['plannedRooms'] as num).toInt();
    final floors = (patch['floors'] as num).toInt();
    final minRent = (patch['minRent'] as num).toDouble();
    final maxRent = (patch['maxRent'] as num).toDouble();
    if (name.isEmpty ||
        address.isEmpty ||
        district.isEmpty ||
        (ward.isEmpty &&
            VietnamLocations.getWards(
              patch['city'] as String,
              district,
            ).isNotEmpty) ||
        plannedRooms < 1 ||
        plannedRooms > 1000 ||
        floors < 1 ||
        floors > 100 ||
        minRent < 0 ||
        maxRent < minRent ||
        maxRent > 1000000000) {
      throw StateError('Kiểm tra tên, địa chỉ, quy mô và số tầng cơ sở.');
    }

    final activeRooms = await _db
        .collection(FirestoreCollections.hostRooms)
        .where('hostId', isEqualTo: base.hostId)
        .where('propertyId', isEqualTo: base.id)
        .get();
    final rooms = activeRooms.docs
        .map(RoomModel.fromFirestore)
        .where((room) => room.status != 'deleted')
        .toList();
    if (plannedRooms < rooms.length) {
      throw StateError(
        'Quy mô không thể nhỏ hơn ${rooms.length} phòng đã tạo.',
      );
    }
    final highestFloor = rooms.fold<int>(0, (value, room) {
      return room.floor > value ? room.floor : value;
    });
    if (floors < highestFloor) {
      throw StateError('Cơ sở đang có phòng ở tầng $highestFloor.');
    }

    final uploaded = newImages.isEmpty
        ? <String>[]
        : await _upload(
            newImages,
            'host_media/${base.hostId}/properties/${base.id}/edits/$operationId',
            5,
          );
    final images = [...keptImages, ...uploaded];
    final propertyRef = _db
        .collection(FirestoreCollections.hostProperties)
        .doc(base.id);
    await _db.runTransaction((transaction) async {
      final current = await transaction.get(propertyRef);
      final data = current.data();
      if (data == null || data['status'] == 'deleted') {
        throw StateError('Cơ sở không còn tồn tại.');
      }
      if (data['hostId'] != base.hostId) {
        throw StateError('Bạn không có quyền chỉnh sửa cơ sở này.');
      }
      if (data['lastEditOperation'] == operationId) return;
      final roomCount = (data['roomCount'] as num?)?.toInt() ?? 0;
      if (plannedRooms < roomCount) {
        throw StateError('Quy mô không thể nhỏ hơn $roomCount phòng đã tạo.');
      }
      transaction.update(propertyRef, {
        ...patch,
        'name': name,
        'address': address,
        'district': district,
        'ward': ward,
        'plannedRooms': plannedRooms,
        'floors': floors,
        'images': images,
        'lastEditOperation': operationId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Chủ trọ - Xóa cơ sở - Luồng đi: Chỉ xóa mềm cơ sở không còn phòng,
  // giữ tài liệu để lịch sử và dữ liệu liên quan không bị mất liên kết.
  Future<void> deleteProperty(HostProperty base) async {
    await _requireHost(base.hostId);
    final activeRooms = await _db
        .collection(FirestoreCollections.hostRooms)
        .where('hostId', isEqualTo: base.hostId)
        .where('propertyId', isEqualTo: base.id)
        .get();
    final activeCount = activeRooms.docs
        .where((doc) => doc.data()['status'] != 'deleted')
        .length;
    if (activeCount > 0) {
      throw StateError(
        'Cơ sở còn $activeCount phòng. Hãy xóa các phòng trước khi xóa cơ sở.',
      );
    }
    final propertyRef = _db
        .collection(FirestoreCollections.hostProperties)
        .doc(base.id);
    await _db.runTransaction((transaction) async {
      final current = await transaction.get(propertyRef);
      final data = current.data();
      if (data == null || data['status'] == 'deleted') return;
      if (data['hostId'] != base.hostId) {
        throw StateError('Bạn không có quyền xóa cơ sở này.');
      }
      final roomCount = (data['roomCount'] as num?)?.toInt() ?? 0;
      if (roomCount > 0) {
        throw StateError(
          'Cơ sở còn $roomCount phòng. Hãy xóa các phòng trước khi xóa cơ sở.',
        );
      }
      transaction.update(propertyRef, {
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Chủ trọ - Mã phòng duy nhất - Luồng đi: Cùng cơ sở và mã phòng
  // tạo cùng ID; transaction ngăn trùng mã cả khi hai thiết bị lưu cùng lúc.
  static String roomDocumentId(String propertyId, String code) =>
      '${propertyId}_${base64Url.encode(utf8.encode(code.trim().toUpperCase())).replaceAll('=', '')}';

  // Chủ trọ - Khóa mã phòng trong cơ sở - Luồng đi: Lưu bảng mã trên
  // properties để đổi số phòng vẫn giữ ID và liên kết đơn thuê cũ.
  static String _codeKey(String code) => base64Url
      .encode(utf8.encode(code.trim().toUpperCase()))
      .replaceAll('=', '');
  Map<String, dynamic> _codes(Map<String, dynamic> property) =>
      Map<String, dynamic>.from(property['roomCodes'] as Map? ?? {});
  void _checkRevision(Map<String, dynamic> current, RoomModel base) {
    final stamp = current['updatedAt'];
    final date = stamp is Timestamp ? stamp.toDate() : null;
    if (date != base.updatedAt) {
      throw StateError(
        'Phòng vừa được thay đổi trên thiết bị khác. Quay lại chi tiết rồi mở chỉnh sửa để tải dữ liệu mới.',
      );
    }
  }

  // Chủ trọ - Tạo phòng có mã duy nhất - Luồng đi: Giữ ID theo thao
  // tác khi thử lại; khóa mã và tăng số phòng cùng một transaction.
  Future<void> createRoom(
    RoomModel room,
    List<HostUpload> images,
    String operationId,
  ) async {
    await _requireHost(room.hostId);
    final propertyRef = _db
        .collection(FirestoreCollections.hostProperties)
        .doc(room.propertyId);
    final legacyRef = _db
        .collection(FirestoreCollections.hostRooms)
        .doc(roomDocumentId(room.propertyId, room.roomCode));
    final roomRef = _db
        .collection(FirestoreCollections.hostRooms)
        .doc('${roomDocumentId(room.propertyId, room.roomCode)}_$operationId');
    final existing = await roomRef.get();
    if (existing.exists && existing.data()?['operationId'] == operationId) {
      return;
    }
    await _checkRoomCodeAvailable(room.propertyId, room.hostId, room.roomCode);
    final urls = await _upload(
      images,
      'host_media/${room.hostId}/host_rooms/${roomRef.id}/$operationId',
      8,
    );
    await _db.runTransaction((transaction) async {
      final property = await transaction.get(propertyRef);
      final current = await transaction.get(roomRef);
      final legacy = await transaction.get(legacyRef);
      if (current.exists) {
        if (current.data()?['operationId'] == operationId) return;
        throw StateError('Trùng ID phòng.');
      }
      final data = property.data();
      if (data == null ||
          data['status'] == 'deleted' ||
          data['hostId'] != room.hostId) {
        throw StateError('Cơ sở không thuộc tài khoản này.');
      }
      final codes = _codes(data);
      final key = _codeKey(room.roomCode);
      final legacyData = legacy.data();
      if (codes.containsKey(key) ||
          (legacyData != null &&
              legacyData['status'] != 'deleted' &&
              _codeKey(legacyData['roomCode'] as String? ?? '') == key)) {
        throw StateError('Trùng ID phòng.');
      }
      final count = (data['roomCount'] as num?)?.toInt() ?? 0;
      if (count >= (data['plannedRooms'] as num).toInt()) {
        throw StateError('Đã đạt tổng số phòng của cơ sở.');
      }
      codes[key] = roomRef.id;
      transaction.set(roomRef, {
        ...room.toMap(),
        'images': urls,
        'anhPhong': urls,
        'operationId': operationId,
        'createdAt': FieldValue.serverTimestamp(),
        'ngayTao': FieldValue.serverTimestamp(),
      });
      transaction.update(propertyRef, {
        'roomCount': count + 1,
        'roomCodes': codes,
      });
    });
  }

  // Chủ trọ - Lưu chỉnh sửa phòng - Luồng đi: Upload ảnh mới, kiểm
  // tra phiên/bản sửa, giữ ID và chỉ cập nhật thông tin phòng được phép.
  Future<void> updateRoom(
    RoomModel base,
    Map<String, dynamic> patch,
    List<String> keptImages,
    List<HostUpload> newImages,
    String operationId,
  ) async {
    await _requireHost(base.hostId);
    const allowed = {
      'roomCode',
      'floor',
      'area',
      'minArea',
      'maxArea',
      'capacity',
      'price',
      'deposit',
      'electricityRate',
      'waterRate',
      'serviceFee',
      'amenities',
      'description',
    };
    if (patch.keys.any((key) => !allowed.contains(key))) {
      throw StateError('Thông tin chỉnh sửa không hợp lệ.');
    }
    if (keptImages.length + newImages.length < 1 ||
        keptImages.length + newImages.length > 8 ||
        keptImages.any((url) => !base.images.contains(url))) {
      throw StateError('Giữ từ 1 đến 8 ảnh phòng hợp lệ.');
    }
    final code = (patch['roomCode'] as String).trim().toUpperCase();
    final minArea = patch['minArea'] as num? ?? patch['area'] as num;
    final maxArea = patch['maxArea'] as num? ?? patch['area'] as num;
    if (!minArea.isFinite ||
        !maxArea.isFinite ||
        minArea <= 0 ||
        maxArea < minArea) {
      throw StateError('Khoảng diện tích phòng không hợp lệ.');
    }
    for (final key in [
      'price',
      'deposit',
      'area',
      'electricityRate',
      'waterRate',
      'serviceFee',
    ]) {
      final value = patch[key] as num?;
      if (value != null &&
          (!value.isFinite || value < 0 || value > 1000000000)) {
        throw StateError('Giá thuê và phí phòng không hợp lệ.');
      }
    }
    if (code.isEmpty ||
        code.length > 30 ||
        (patch['price'] as num) <= 0 ||
        (patch['deposit'] as num) < 0 ||
        (patch['area'] as num) <= 0 ||
        patch['capacity'] is! int ||
        (patch['capacity'] as int) < 1) {
      throw StateError('Kiểm tra mã, diện tích, sức chứa và giá thuê.');
    }
    final roomRef = _db.collection(FirestoreCollections.hostRooms).doc(base.id);
    await _checkRoomCodeAvailable(
      base.propertyId,
      base.hostId,
      code,
      exceptRoomId: base.id,
    );
    final propertyRef = _db
        .collection(FirestoreCollections.hostProperties)
        .doc(base.propertyId);
    final legacyRef = _db
        .collection(FirestoreCollections.hostRooms)
        .doc(roomDocumentId(base.propertyId, code));
    final uploaded = newImages.isEmpty
        ? <String>[]
        : await _upload(
            newImages,
            'host_media/${base.hostId}/host_rooms/${base.id}/edits/$operationId',
            8,
          );
    final images = [...keptImages, ...uploaded];
    await _db.runTransaction((transaction) async {
      final current = await transaction.get(roomRef);
      final property = await transaction.get(propertyRef);
      final legacy = await transaction.get(legacyRef);
      final data = current.data();
      final parent = property.data();
      if (data == null || data['status'] == 'deleted') {
        throw StateError('Phòng không còn tồn tại.');
      }
      if (data['hostId'] != base.hostId ||
          data['propertyId'] != base.propertyId ||
          parent?['hostId'] != base.hostId) {
        throw StateError('Bạn không có quyền chỉnh sửa phòng này.');
      }
      if (data['lastEditOperation'] == operationId) return;
      _checkRevision(data, base);
      if ((patch['floor'] as num) < 1 ||
          (patch['floor'] as num) > (parent!['floors'] as num)) {
        throw StateError('Tầng phòng vượt quá số tầng của cơ sở.');
      }
      final codes = _codes(parent);
      final key = _codeKey(code);
      final legacyData = legacy.data();
      if ((codes.containsKey(key) && codes[key] != base.id) ||
          (legacy.id != base.id &&
              legacyData != null &&
              legacyData['status'] != 'deleted' &&
              _codeKey(legacyData['roomCode'] as String? ?? '') == key)) {
        throw StateError('Trùng ID phòng.');
      }
      final oldKey = _codeKey(data['roomCode'] as String? ?? '');
      if (oldKey != key && codes[oldKey] == base.id) codes.remove(oldKey);
      codes[key] = base.id;
      final title = 'Phòng $code • ${parent['name']}';
      transaction.update(roomRef, {
        ...patch,
        'roomCode': code,
        'title': title,
        'tieuDe': title,
        'gia': patch['price'],
        'giaThue': patch['price'],
        'giaThueThang': patch['price'],
        'tienCoc': patch['deposit'],
        'dienTich': patch['area'],
        'dienTichM2': patch['area'],
        'sucChua': patch['capacity'],
        'tang': patch['floor'],
        'tienIch': patch['amenities'],
        'moTa': patch['description'],
        'noiDung': patch['description'],
        'images': images,
        'anhPhong': images,
        'lastEditOperation': operationId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(propertyRef, {'roomCodes': codes});
    });
  }

  // Kiểm tra trước transaction để lỗi nghiệp vụ không bị cầu nối web
  // chuyển thành lỗi chung; transaction vẫn khóa mã khi lưu đồng thời.
  Future<void> _checkRoomCodeAvailable(
    String propertyId,
    String hostId,
    String code, {
    String? exceptRoomId,
  }) async {
    final snapshot = await _db
        .collection(FirestoreCollections.hostRooms)
        .where('hostId', isEqualTo: hostId)
        .where('propertyId', isEqualTo: propertyId)
        .get();
    final normalized = code.trim().toUpperCase();
    if (snapshot.docs.any((document) {
      final data = document.data();
      return document.id != exceptRoomId &&
          data['status'] != 'deleted' &&
          (data['roomCode'] as String? ?? '').trim().toUpperCase() ==
              normalized;
    })) {
      throw StateError('Trùng ID phòng.');
    }
  }

  // Chủ trọ - Xóa phòng khỏi quản lý - Luồng đi: Sau xác nhận, đánh
  // dấu deleted và giảm số phòng; giữ bản ghi/ảnh để đơn thuê cũ còn liên kết.
  Future<void> deleteRoom(RoomModel base) async {
    await _requireHost(base.hostId);
    final roomRef = _db.collection(FirestoreCollections.hostRooms).doc(base.id);
    final propertyRef = _db
        .collection(FirestoreCollections.hostProperties)
        .doc(base.propertyId);
    await _db.runTransaction((transaction) async {
      final current = await transaction.get(roomRef);
      final property = await transaction.get(propertyRef);
      final data = current.data();
      final parent = property.data();
      if (data == null || data['status'] == 'deleted') return;
      if (data['hostId'] != base.hostId || parent?['hostId'] != base.hostId) {
        throw StateError('Bạn không có quyền xóa phòng này.');
      }
      _checkRevision(data, base);
      if (data['status'] == 'occupied' ||
          data['status'] == 'reserved' ||
          (data['tenantName'] as String? ?? '').isNotEmpty ||
          (data['contractId'] as String? ?? '').isNotEmpty) {
        throw StateError(
          'Phòng còn khách thuê hoặc hợp đồng. Hãy kết thúc hợp đồng trước khi xóa.',
        );
      }
      final codes = _codes(parent!);
      final key = _codeKey(data['roomCode'] as String? ?? '');
      if (codes[key] == base.id) codes.remove(key);
      final count = (parent['roomCount'] as num?)?.toInt() ?? 0;
      transaction.update(roomRef, {
        'status': 'deleted',
        'isAvailable': false,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(propertyRef, {
        'roomCount': count > 0 ? count - 1 : 0,
        'roomCodes': codes,
      });
    });
  }

  // Chủ trọ - Theo dõi danh sách phòng theo cơ sở
  Stream<List<RoomModel>> watchRoomsByProperty(String uid, String propertyId) =>
      _db
          .collection(FirestoreCollections.hostRooms)
          .where('hostId', isEqualTo: uid)
          .where('propertyId', isEqualTo: propertyId)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(RoomModel.fromFirestore)
                .where((room) => room.status != 'deleted')
                .toList(),
          );

  // Chủ trọ - Lấy danh sách tiện ích thực tế từ bảng TienIch_Phong của phòng
  Future<List<String>> getRoomAmenitiesFromTienIchPhong(String roomId) async {
    if (roomId.isEmpty) return const [];
    try {
      final snap = await _db
          .collection('TienIch_Phong')
          .where('phongId', isEqualTo: roomId)
          .get();
      return snap.docs
          .map((d) {
            final data = d.data();
            return (data['amenityName'] ?? data['tenTienIch'] ?? '') as String;
          })
          .where((name) => name.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // Chủ trọ - Lấy danh sách ảnh thực tế từ bảng AnhPhong của phòng nếu có
  Future<List<String>> getRoomImagesFromAnhPhong(String roomId) async {
    if (roomId.isEmpty) return const [];
    try {
      final results = <String>[];
      for (final col in ['AnhPhong', 'anhPhong', 'room_images', 'roomImages']) {
        for (final field in ['phongId', 'roomId']) {
          final snap = await _db
              .collection(col)
              .where(field, isEqualTo: roomId)
              .get();
          for (final doc in snap.docs) {
            final data = doc.data();
            final url = (data['duongDan'] ??
                    data['url'] ??
                    data['image'] ??
                    data['imageUrl'] ??
                    data['link'] ??
                    '')
                .toString()
                .trim();
            if (url.isNotEmpty && !results.contains(url)) {
              results.add(url);
            }
          }
        }
      }

      // Kiểm tra trực tiếp document phòng nếu chưa có
      if (results.isEmpty) {
        for (final col in [
          FirestoreCollections.hostRooms,
          FirestoreCollections.publicRooms,
        ]) {
          final doc = await _db.collection(col).doc(roomId).get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            final raw = data['images'] ??
                data['roomImages'] ??
                data['anhPhong'] ??
                data['imageUrls'] ??
                data['photos'] ??
                data['photoUrls'] ??
                data['hinhAnh'];
            if (raw is List) {
              for (final item in raw) {
                final u = item.toString().trim();
                if (u.isNotEmpty && !results.contains(u)) results.add(u);
              }
            } else if (raw is String && raw.trim().isNotEmpty) {
              results.add(raw.trim());
            }
            if (results.isNotEmpty) break;
          }
        }
      }

      return results;
    } catch (_) {
      return const [];
    }
  }

  // Chủ trọ - Đăng bài kèm liên kết tiện ích TienIch_Phong và tạo bài đăng posts
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
    await _requireHost(chuNhaId);
    final calculatedDeposit = tienCoc ?? (giaThue * phanTramTienCoc / 100);
    String targetRoomId = phongId ?? (room.id.isNotEmpty ? room.id : '');

    final finalUrls = <String>[...room.images];
    if (images.isNotEmpty) {
      final uploadRoomId = targetRoomId.isNotEmpty
          ? targetRoomId
          : DateTime.now().millisecondsSinceEpoch.toString();
      final uploaded = await _upload(
        images,
        'host_media/$chuNhaId/host_rooms/$uploadRoomId',
        10,
      );
      finalUrls.addAll(uploaded);
    }

    if (targetRoomId.isEmpty) {
      final newRoomRef = _db.collection(FirestoreCollections.hostRooms).doc();
      targetRoomId = newRoomRef.id;
      await newRoomRef.set({
        ...room.toMap(),
        'id': targetRoomId,
        'images': finalUrls,
        'anhPhong': finalUrls,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final batch = _db.batch();

    final amenityNameToId = <String, String>{};
    for (final name in selectedAmenities) {
      final key = name.trim().toLowerCase();
      if (catalogAmenitiesMap.containsKey(key)) {
        amenityNameToId[name] = catalogAmenitiesMap[key]!;
      } else {
        final amRef = _db.collection(FirestoreCollections.amenities).doc();
        batch.set(amRef, {
          'id': amRef.id,
          AmenityFields.name: name,
        });
        amenityNameToId[name] = amRef.id;
      }
    }

    for (final entry in amenityNameToId.entries) {
      final linkRef = _db.collection('TienIch_Phong').doc();
      batch.set(linkRef, {
        'id': linkRef.id,
        'phongId': targetRoomId,
        'tienIch_Id': entry.value,
        'amenityName': entry.key,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final postRef = _db.collection(FirestoreCollections.posts).doc();
    final postModel = HostPostModel(
      id: postRef.id,
      roomId: targetRoomId,
      hostId: chuNhaId,
      locationId: diaDiemId,
      rentalTypeId: loaiThueId,
      statusId: trangThaiId,
      title: tieuDe,
      description: moTa,
      rentalPrice: giaThue,
      depositAmount: calculatedDeposit,
      depositPercentage: phanTramTienCoc,
      amenities: selectedAmenities.toList(),
      images: finalUrls,
      address: room.address,
      contactPhone: soDienThoaiLienHe,
      createdAt: DateTime.now(),
      status: trangThaiId,
    );

    final postPayload = {
      ...postModel.toFirestore(),
      'id': postRef.id,
      PostFields.createdAt: FieldValue.serverTimestamp(),
    };
    batch.set(postRef, postPayload);

    await batch.commit();
    return postRef.id;
  }
}

final hostRoomsByPropertyProvider =
    StreamProvider.family<List<RoomModel>, String>((ref, propertyId) {
      final uid = ref.watch(hostSessionProvider).value;
      if (uid == null || propertyId.isEmpty) return Stream.value(const []);
      return ref
          .watch(hostRepositoryProvider)
          .watchRoomsByProperty(uid, propertyId);
    });

// Chủ trọ - Thông báo lỗi Firebase - Luồng đi: Hiển thị nguyên nhân
// lưu/tải thất bại bằng tiếng Việt để người dùng có thể sửa và thử lại.
String hostErrorMessage(Object error) {
  // Một số lỗi callback transaction trên web được bọc lại thành chuỗi.
  if (error.toString().contains('Trùng ID phòng.')) {
    return 'Trùng ID phòng.';
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthorized':
        return 'Chưa có quyền truy cập. Kiểm tra tài khoản Chủ trọ và Firebase Rules.';
      case 'unauthenticated':
        return 'Vui lòng đăng nhập lại để lưu nhà/phòng.';
      case 'unavailable':
      case 'network-request-failed':
      case 'retry-limit-exceeded':
        return 'Không kết nối được Firebase. Kiểm tra mạng rồi thử lại.';
      case 'bucket-not-found':
      case 'object-not-found':
        return 'Chưa truy cập được Storage. Kiểm tra bucket trong Firebase Console.';
      default:
        return 'Firebase báo lỗi ${error.code}. Vui lòng kiểm tra cấu hình rồi thử lại.';
    }
  }
  return error is StateError
      ? error.message.toString()
      : 'Không thể hoàn tất thao tác. Vui lòng thử lại.';
}
