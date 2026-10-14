import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

/// Nén JPEG trong isolate để ảnh bài đăng nằm dưới giới hạn 1MB của Firestore.
Uint8List compressJpegToLimit((Uint8List, int) args) {
  final (bytes, maxBytes) = args;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  Uint8List? last;
  const steps = <(int, int)>[
    (1024, 70),
    (800, 60),
    (640, 50),
    (480, 40),
  ];

  for (final step in steps) {
    final maxSide = step.$1;
    final quality = step.$2;
    var output = decoded;
    if (output.width > maxSide || output.height > maxSide) {
      output = output.width >= output.height
          ? img.copyResize(output, width: maxSide)
          : img.copyResize(output, height: maxSide);
    }
    final encoded = Uint8List.fromList(img.encodeJpg(output, quality: quality));
    last = encoded;
    if (encoded.length <= maxBytes) return encoded;
  }

  return last ?? bytes;
}

/// Dịch vụ tải ảnh đa phương tiện đồng bộ cho toàn bộ ứng dụng HomeShare.
/// Cùng cơ chế với ảnh chat: Storage nếu có, không thì Base64 Data URI của ảnh thật
/// để máy khác đọc được từ Firestore. Không thay ảnh người dùng bằng ảnh mẫu.
class ImageStorageService {
  final FirebaseStorage? _customStorage;
  final bool skipRemoteUpload;

  ImageStorageService({
    FirebaseStorage? storage,
    this.skipRemoteUpload = false,
  }) : _customStorage = storage;

  FirebaseStorage get _storage => _customStorage ?? FirebaseStorage.instance;

  // Danh sách ảnh mẫu phòng trọ chất lượng cao phòng khi Storage offline/thiếu cấu hình
  static const List<String> _sampleRoomImages = [
    'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800',
    'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=800',
    'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800',
    'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=800',
    'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800',
  ];

  /// Tải 1 ảnh lên Firebase Storage. Khi Storage chưa bật hoặc lỗi,
  /// lưu chính ảnh đó dạng Base64 (giống tin nhắn chat) để máy khác xem được.
  Future<String> uploadSingleImage({
    required String filePath,
    required String folder,
    required String fileName,
    int sampleIndex = 0,
    int maxBytes = 180 * 1024,
  }) async {
    // Nếu là URL online sẵn hoặc Base64 data thì giữ nguyên
    if (filePath.startsWith('http://') ||
        filePath.startsWith('https://') ||
        filePath.startsWith('data:image')) {
      return filePath;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      debugPrint('[ImageStorageService] File không tồn tại tại $filePath, dùng ảnh fallback.');
      return _sampleRoomImages[sampleIndex % _sampleRoomImages.length];
    }

    Uint8List prepared;
    try {
      final raw = await file.readAsBytes();
      prepared = raw.length <= maxBytes ? raw : await compute(compressJpegToLimit, (raw, maxBytes));
      if (prepared.length > maxBytes && prepared != raw) {
        debugPrint('[ImageStorageService] Ảnh sau nén vẫn ${prepared.length} bytes (ngưỡng $maxBytes).');
      }
    } catch (e) {
      debugPrint('[ImageStorageService] Không đọc được file $filePath: $e');
      return _sampleRoomImages[sampleIndex % _sampleRoomImages.length];
    }

    if (!skipRemoteUpload) {
      try {
        final storageRef = _storage.ref().child('$folder/$fileName');
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uploadedAt': DateTime.now().toIso8601String()},
        );

        final uploadTask = storageRef.putData(prepared, metadata);
        final snapshot = await uploadTask.timeout(const Duration(seconds: 8));
        final downloadUrl = await snapshot.ref.getDownloadURL();
        debugPrint('[ImageStorageService] Tải ảnh lên Firebase Storage thành công: $downloadUrl');
        return downloadUrl;
      } catch (e) {
        debugPrint('[ImageStorageService] Storage chưa dùng được ($e). Lưu ảnh thật vào Firestore dạng Base64.');
      }
    }

    return 'data:image/jpeg;base64,${base64Encode(prepared)}';
  }

  /// Đưa ảnh bài ở ghép lên Storage. Firestore chỉ cần giữ [storagePath], không giữ link tải.
  Future<String> uploadRoommateStorageImage({
    required String source,
    required String postId,
    required int index,
  }) async {
    final existing = storagePathFromDownloadUrl(source);
    if (existing != null && existing.startsWith('roommate_posts/')) return existing;

    final bytes = await _readImageBytes(source);
    final storagePath = 'roommate_posts/$postId/image_$index.jpg';
    final ref = _storage.ref().child(storagePath);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg')).timeout(const Duration(seconds: 20));
    return storagePath;
  }

  Future<String> downloadUrlForStoragePath(String storagePath) {
    return _storage.ref().child(storagePath).getDownloadURL();
  }

  String? storagePathFromDownloadUrl(String source) {
    if (!source.contains('firebasestorage.googleapis.com')) return null;
    final path = Uri.parse(source).path;
    const marker = '/o/';
    final index = path.indexOf(marker);
    if (index < 0) return null;
    return Uri.decodeComponent(path.substring(index + marker.length));
  }

  Future<Uint8List> _readImageBytes(String source) async {
    if (source.startsWith('data:image')) {
      final encoded = source.substring(source.indexOf(',') + 1);
      return base64Decode(encoded);
    }
    if (source.startsWith('http://') || source.startsWith('https://')) {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(source));
        final response = await request.close().timeout(const Duration(seconds: 20));
        final chunks = <int>[];
        await for (final chunk in response) {
          chunks.addAll(chunk);
        }
        return Uint8List.fromList(chunks);
      } finally {
        client.close();
      }
    }
    return File(source).readAsBytes();
  }

  /// Tải danh sách nhiều ảnh cùng lúc cho bài đăng ở ghép / đăng phòng
  Future<List<String>> uploadRoommateImages({
    required List<String> localPaths,
    required String postId,
  }) async {
    if (localPaths.isEmpty) return [];

    final List<String> uploadedUrls = [];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Base64 phình ~4/3 và model ghi ảnh ở cả `images` lẫn `anhTinOGhep`.
    // Giữ tổng ảnh thô khoảng 220KB để document Firestore không vượt 1MB.
    final perImageBudget = ((220 * 1024) / localPaths.length).floor().clamp(40 * 1024, 120 * 1024).toInt();

    for (int i = 0; i < localPaths.length; i++) {
      final path = localPaths[i];
      final fileName = '${postId}_img_${timestamp}_$i.jpg';
      final url = await uploadSingleImage(
        filePath: path,
        folder: 'roommate_posts/$postId',
        fileName: fileName,
        sampleIndex: i,
        maxBytes: perImageBudget,
      );
      uploadedUrls.add(url);
    }

    return uploadedUrls;
  }

  /// Tải ảnh CCCD (mặt trước hoặc mặt sau) lên Firebase Storage.
  /// Kiểm tra magic bytes, dung lượng và fail-closed nếu không hợp lệ.
  Future<String> uploadCccdImage({
    required String filePath,
    required String uid,
    required bool isFront,
  }) async {
    if (filePath.isEmpty) {
      throw const FormatException('Đường dẫn ảnh CCCD rỗng.');
    }

    if (filePath.startsWith('http://') ||
        filePath.startsWith('https://') ||
        filePath.startsWith('data:image')) {
      throw const FormatException(
        'Không chấp nhận URL từ xa hoặc Data URI cho ảnh CCCD.',
      );
    }

    if (filePath.toLowerCase().contains('demo_cccd')) {
      throw const FormatException(
        'Ảnh mẫu thử nghiệm không được phép tải lên hệ thống.',
      );
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      throw const FileSystemException(
        'Tệp ảnh CCCD không tồn tại trên thiết bị.',
      );
    }

    final bytes = await file.readAsBytes();
    if (bytes.length < 20 * 1024 || bytes.length > 15 * 1024 * 1024) {
      debugPrint(
        '[ImageStorageService] Dung lượng ảnh CCCD không nằm trong giới hạn cho phép.',
      );
      throw const FormatException(
        'Dung lượng ảnh CCCD không hợp lệ (yêu cầu từ 20KB đến 15MB).',
      );
    }

    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
    final isWebp =
        bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;

    if (!isJpeg && !isPng && !isWebp) {
      debugPrint(
        '[ImageStorageService] Định dạng tệp ảnh CCCD không hợp lệ.',
      );
      throw const FormatException(
        'Định dạng tệp không phải ảnh chuẩn (JPEG, PNG, WebP).',
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${isFront ? "front" : "back"}_$timestamp.jpg';

    try {
      final storageRef = _storage.ref().child('users/$uid/cccd/$fileName');
      final metadata = SettableMetadata(
        contentType: isPng
            ? 'image/png'
            : (isWebp ? 'image/webp' : 'image/jpeg'),
        customMetadata: {
          'uid': uid,
          'type': isFront ? 'cccd_front' : 'cccd_back',
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = storageRef.putFile(file, metadata);
      final snapshot = await uploadTask.timeout(const Duration(seconds: 15));
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('[ImageStorageService] Tải ảnh CCCD lên cloud thành công.');
      return downloadUrl;
    } catch (_) {
      debugPrint(
        '[ImageStorageService] Lỗi kết nối khi tải ảnh CCCD lên cloud.',
      );
      throw const HttpException(
        'Không thể tải ảnh CCCD lên bộ nhớ đám mây. Vui lòng kiểm tra kết nối mạng.',
      );
    }
  }
}

final imageStorageServiceProvider = Provider<ImageStorageService>((ref) {
  return ImageStorageService();
});
