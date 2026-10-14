import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/period_model.dart';
import '../../../data/models/resident_model.dart';
import '../../../data/models/room_model.dart';
import '../models/invoice_line_model.dart';
import '../models/violation_model.dart';
import '../models/violation_record_model.dart';

/// Dữ liệu phòng đang có khách thuê để chọn trong Form lập biên bản
class HostOccupiedRoomItem {
  final String roomId;
  final String roomCode;
  final String propertyId;
  final String propertyName;
  final String periodId;
  final String tenantId;
  final String tenantName;
  final String tenantPhone;

  String get dropdownLabel => '$roomCode - $propertyName ($tenantName)';

  const HostOccupiedRoomItem({
    required this.roomId,
    required this.roomCode,
    this.propertyId = '',
    this.propertyName = '',
    this.periodId = '',
    required this.tenantId,
    required this.tenantName,
    this.tenantPhone = '',
  });
}

/// Thống kê vi phạm theo tháng
class ViolationMonthlyStats {
  final double totalFineRecorded; // Tổng tiền phạt ghi nhận
  final int totalCount; // Số vi phạm
  final double totalPaid; // Tổng đã nộp
  final double totalPending; // Tổng chờ nộp
  final int paidCount; // Số đã nộp
  final int pendingCount; // Số chờ nộp

  const ViolationMonthlyStats({
    this.totalFineRecorded = 0.0,
    this.totalCount = 0,
    this.totalPaid = 0.0,
    this.totalPending = 0.0,
    this.paidCount = 0,
    this.pendingCount = 0,
  });

  factory ViolationMonthlyStats.fromRecords(List<ViolationRecordModel> records) {
    double totalFine = 0.0;
    double paid = 0.0;
    double pending = 0.0;
    int pCount = 0;
    int pendCount = 0;

    for (final r in records) {
      if (r.isCancelled) continue;
      totalFine += r.totalFine;
      if (r.isPaid) {
        paid += r.totalFine;
        pCount++;
      } else {
        pending += r.totalFine;
        pendCount++;
      }
    }

    return ViolationMonthlyStats(
      totalFineRecorded: totalFine,
      totalCount: records.where((r) => !r.isCancelled).length,
      totalPaid: paid,
      totalPending: pending,
      paidCount: pCount,
      pendingCount: pendCount,
    );
  }
}

class ViolationRepository {
  final FirebaseFirestore? _customFirestore;
  final FirebaseStorage? _storage;

  ViolationRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _customFirestore = firestore,
        // ignore: prefer_initializing_formals
        _storage = storage;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  FirebaseStorage get _storageInstance =>
      _storage ?? FirebaseStorage.instance;

  // 4 hành vi vi phạm chuẩn theo thiết kế Figma & SRS
  static final List<ViolationModel> defaultViolationTypes = [
    ViolationModel(
      id: 'vp_rac',
      title: 'Để rác sai nơi quy định',
      description: 'Để rác ngoài hành lang hoặc khu vực chung',
      defaultFine: 150000,
      category: 'Vệ sinh chung',
      iconName: 'delete_outline',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    ViolationModel(
      id: 'vp_on_ao',
      title: 'Ồn ào sau 23h',
      description: 'Làm ồn, mở loa công suất lớn sau 23h đêm',
      defaultFine: 200000,
      category: 'Trật tự an ninh',
      iconName: 'volume_up_outlined',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    ViolationModel(
      id: 'vp_hut_thuoc',
      title: 'Hút thuốc trong phòng',
      description: 'Hút thuốc trong phòng gây nguy cơ hỏa hoạn',
      defaultFine: 300000,
      category: 'Phòng cháy chữa cháy',
      iconName: 'smoke_free_outlined',
      isActive: true,
      createdAt: DateTime.now(),
    ),
    ViolationModel(
      id: 'vp_nguoi_la',
      title: 'Dẫn người lạ qua đêm',
      description: 'Không đăng ký tạm trú cho người lạ ở qua đêm',
      defaultFine: 250000,
      category: 'An ninh trật tự',
      iconName: 'group_outlined',
      isActive: true,
      createdAt: DateTime.now(),
    ),
  ];

  /// Lắng nghe danh mục loại vi phạm từ Firestore, tự động seed nếu rỗng
  Stream<List<ViolationModel>> watchViolationTypes() {
    return _firestore
        .collection(FirestoreCollections.violations)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) {
        // Tự động seed 4 hành vi mẫu theo quyết định của người dùng
        try {
          final batch = _firestore.batch();
          for (final item in defaultViolationTypes) {
            final docRef = _firestore
                .collection(FirestoreCollections.violations)
                .doc(item.id);
            batch.set(docRef, item.toMap());
          }
          await batch.commit();
        } catch (_) {}
        return defaultViolationTypes;
      }

      return snapshot.docs
          .map(ViolationModel.fromFirestore)
          .where((v) => v.isActive)
          .toList();
    });
  }

  /// Lắng nghe danh sách biên bản vi phạm của chủ trọ hiện tại
  Stream<List<ViolationRecordModel>> watchHostViolationRecords(String hostId) {
    if (hostId.isEmpty) return Stream.value([]);

    return _firestore
        .collection(FirestoreCollections.violationRecords)
        .where('landlordId', isEqualTo: hostId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map(ViolationRecordModel.fromFirestore)
          .toList();
      // Sắp xếp ngày tạo mới nhất lên đầu
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Lấy danh sách các phòng đang có người thuê (`dangO`) thuộc chủ trọ
  Future<List<HostOccupiedRoomItem>> getHostOccupiedRooms(String hostId) async {
    if (hostId.isEmpty) return [];

    // 1. Lấy danh sách phòng thuộc chủ trọ
    final roomsSnap = await _firestore
        .collection(FirestoreCollections.hostRooms)
        .where('hostId', isEqualTo: hostId)
        .get();

    final hostRooms = roomsSnap.docs
        .map(RoomModel.fromFirestore)
        .where((r) => r.status != 'deleted')
        .toList();

    if (hostRooms.isEmpty) return [];
    final roomMap = {for (var r in hostRooms) r.id: r};

    // 2. Lấy tên các cơ sở/properties
    final propertyIds = hostRooms
        .map((r) => r.propertyId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final propertyNameMap = <String, String>{};
    for (final pid in propertyIds) {
      try {
        final doc = await _firestore
            .collection(FirestoreCollections.hostProperties)
            .doc(pid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          propertyNameMap[pid] = (data?['name'] ??
                  data?['tenNha'] ??
                  data?['title'] ??
                  'Nhà trọ')
              .toString();
        }
      } catch (_) {}
    }

    // 3. Lấy kỳ ở (periods) đang hoạt động
    final periodsSnap = await _firestore
        .collection(FirestoreCollections.periods)
        .where('status', isEqualTo: 'dangO')
        .get();

    final activePeriods = periodsSnap.docs
        .map(PeriodModel.fromFirestore)
        .where((p) => roomMap.containsKey(p.roomId))
        .toList();

    // 4. Lấy đơn đặt phòng (bookings)
    final bookingsSnap = await _firestore
        .collection(FirestoreCollections.bookings)
        .where('hostId', isEqualTo: hostId)
        .get();

    final bookings = bookingsSnap.docs
        .map(BookingRequestModel.fromFirestore)
        .toList();
    final bookingMap = {for (var b in bookings) b.id: b};

    final result = <HostOccupiedRoomItem>[];
    for (final period in activePeriods) {
      final room = roomMap[period.roomId];
      if (room == null) continue;

      // Tìm cư dân chính
      final resSnap = await _firestore
          .collection(FirestoreCollections.residents)
          .where('kyThue_id', isEqualTo: period.id)
          .get();

      final residents =
          resSnap.docs.map(ResidentModel.fromFirestore).toList();
      final booking = bookingMap[period.bookingId];

      final propName = propertyNameMap[room.propertyId] ??
          (room.address.isNotEmpty ? room.address : 'KTX / Nhà trọ');

      final tenantName = residents.isNotEmpty
          ? residents.first.fullName
          : (booking?.renterName.isNotEmpty == true
              ? booking!.renterName
              : (room.tenantName.isNotEmpty ? room.tenantName : 'Khách thuê'));

      final tenantPhone = residents.isNotEmpty &&
              residents.first.phone.isNotEmpty
          ? residents.first.phone
          : (booking?.renterPhone.isNotEmpty == true
              ? booking!.renterPhone
              : room.tenantPhone);

      final tenantId = residents.isNotEmpty
          ? residents.first.userId
          : (booking?.renterId.isNotEmpty == true
              ? booking!.renterId
              : period.renterId);

      result.add(HostOccupiedRoomItem(
        roomId: room.id,
        roomCode: room.roomCode.isNotEmpty
            ? room.roomCode
            : (room.title.isNotEmpty ? room.title : 'Phòng ${room.id}'),
        propertyId: room.propertyId,
        propertyName: propName,
        periodId: period.id,
        tenantId: tenantId,
        tenantName: tenantName,
        tenantPhone: tenantPhone,
      ));
    }

    return result;
  }

  /// Tải danh sách tệp bằng chứng lên Firebase Storage
  Future<List<String>> uploadEvidenceFiles({
    required String hostId,
    required String recordId,
    required List<File> files,
  }) async {
    if (files.isEmpty) return [];

    final downloadUrls = <String>[];
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final ext = file.path.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      final ref = _storageInstance
          .ref()
          .child('violations_media/$hostId/$recordId/$fileName');

      final metadata = SettableMetadata(
        contentType: ext == 'mp4' ? 'video/mp4' : 'image/jpeg',
      );

      final uploadTask = await ref.putFile(file, metadata);
      final url = await uploadTask.ref.getDownloadURL();
      downloadUrls.add(url);
    }

    return downloadUrls;
  }

  /// Tạo biên bản vi phạm mới kèm tạo dòng hóa đơn tự động nếu chọn cộng vào tiền phòng
  Future<String> createViolationRecord(ViolationRecordModel record) async {
    final docRef = _firestore
        .collection(FirestoreCollections.violationRecords)
        .doc(record.id.isNotEmpty ? record.id : null);

    final recordToSave = record.id.isEmpty
        ? record.copyWith(id: docRef.id)
        : record;

    final batch = _firestore.batch();
    batch.set(docRef, recordToSave.toMap());

    // Nếu chọn hình thức 'NEXT_INVOICE', tự động tạo Dòng hóa đơn (invoice_lines)
    if (recordToSave.paymentMethod == 'NEXT_INVOICE') {
      final lineDocRef =
          _firestore.collection(FirestoreCollections.invoiceLines).doc();

      final invoiceLine = InvoiceLineModel(
        id: lineDocRef.id,
        violationRecordId: recordToSave.id,
        violationId: recordToSave.violationIds.isNotEmpty
            ? recordToSave.violationIds.first
            : '',
        roomId: recordToSave.roomId,
        periodId: recordToSave.periodId,
        amount: recordToSave.totalFine,
        purpose: 'PhatViPham',
        title: recordToSave.violationTitles.isNotEmpty
            ? 'Phạt: ${recordToSave.violationTitles.join(', ')}'
            : 'Phạt vi phạm nội quy',
        status: 'pending',
        createdAt: DateTime.now(),
      );

      batch.set(lineDocRef, invoiceLine.toMap());
    }

    await batch.commit();
    return recordToSave.id;
  }

  /// Thu tiền mặt: cập nhật trạng thái đã thanh toán
  Future<void> markCashPayment(
    String recordId, {
    required String hostId,
  }) async {
    await _firestore
        .collection(FirestoreCollections.violationRecords)
        .doc(recordId)
        .update({
      'status': 'PAID',
      'trangThai': 'PAID',
      'paidAt': Timestamp.now(),
      'thanhToanLuc': Timestamp.now(),
      'paidMethod': 'CASH',
      'paidCollector': hostId,
      'updatedAt': Timestamp.now(),
      'ngayCapNhat': Timestamp.now(),
    });
  }

  /// Trừ vào hóa đơn: tạo dòng hóa đơn và cập nhật trạng thái biên bản
  Future<void> deductToInvoice(ViolationRecordModel record) async {
    final batch = _firestore.batch();

    // 1. Tạo invoice_line
    final lineDocRef =
        _firestore.collection(FirestoreCollections.invoiceLines).doc();
    final invoiceLine = InvoiceLineModel(
      id: lineDocRef.id,
      violationRecordId: record.id,
      violationId:
          record.violationIds.isNotEmpty ? record.violationIds.first : '',
      roomId: record.roomId,
      periodId: record.periodId,
      amount: record.totalFine,
      purpose: 'PhatViPham',
      title: record.violationTitles.isNotEmpty
          ? 'Phạt: ${record.violationTitles.join(', ')}'
          : 'Phạt vi phạm nội quy',
      status: 'pending',
      createdAt: DateTime.now(),
    );
    batch.set(lineDocRef, invoiceLine.toMap());

    // 2. Cập nhật violation_records
    final recDocRef = _firestore
        .collection(FirestoreCollections.violationRecords)
        .doc(record.id);
    batch.update(recDocRef, {
      'status': 'ADDED_TO_INVOICE',
      'trangThai': 'ADDED_TO_INVOICE',
      'paymentMethod': 'NEXT_INVOICE',
      'updatedAt': Timestamp.now(),
      'ngayCapNhat': Timestamp.now(),
    });

    await batch.commit();
  }

  /// Gửi nhắc nộp tiền: ghi nhận thời gian gửi nhắc
  Future<void> sendPaymentReminder(String recordId) async {
    await _firestore
        .collection(FirestoreCollections.violationRecords)
        .doc(recordId)
        .update({
      'lastReminderAt': Timestamp.now(),
      'nhacNhoCuoiLuc': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'ngayCapNhat': Timestamp.now(),
    });
  }
}
