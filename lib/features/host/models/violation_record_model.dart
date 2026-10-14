import 'package:cloud_firestore/cloud_firestore.dart';

/// Model Biên bản vi phạm theo Database homeShare & SDS
/// Collection: violation_records/{bienBanId}
class ViolationRecordModel {
  final String id;
  final String landlordId;
  final String roomId;
  final String roomCode;
  final String propertyName;
  final String periodId;
  final String tenantId;
  final String tenantName;
  final String tenantPhone;
  final List<String> violationIds;
  final List<String> violationTitles;
  final double totalFine;
  final String paymentMethod; // 'NEXT_INVOICE', 'CASH', 'DEPOSIT'
  final String status; // 'PENDING', 'PAID', 'ADDED_TO_INVOICE', 'CANCELLED'
  final String description;
  final List<String> evidenceUrls;
  final DateTime? lastReminderAt;
  final DateTime? paidAt;
  final String? paidMethod;
  final String? paidCollector;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // SDS / Database.docx Dual Aliases
  String get bienBanId => id;
  String get chuNhaId => landlordId;
  String get phongId => roomId;
  String get soPhong => roomCode;
  String get tenKhu => propertyName;
  // ignore: non_constant_identifier_names
  String get kyThue_id => periodId;
  String get kyOId => periodId;
  String get nguoiDungId => tenantId;
  String get hoTen => tenantName;
  String get tenNguoiThue => tenantName;
  String get sdt => tenantPhone;
  List<String> get viPhamIds => violationIds;
  List<String> get danhSachTenViPham => violationTitles;
  double get tongTienPhat => totalFine;
  String get hinhThucXuLy => paymentMethod;
  String get trangThai => status;
  String get moTa => description;
  List<String> get chungCu => evidenceUrls;
  DateTime? get nhacNhoCuoiLuc => lastReminderAt;
  DateTime? get thanhToanLuc => paidAt;
  DateTime get ngayLap => createdAt;
  DateTime? get ngayCapNhat => updatedAt;

  // Status checks
  bool get isPending => status == 'PENDING' || status == 'choNop';
  bool get isPaid => status == 'PAID' || status == 'daThanhToan' || status == 'daNop';
  bool get isAddedToInvoice =>
      status == 'ADDED_TO_INVOICE' ||
      status == 'daCongTienPhong' ||
      status == 'daTruVaoTienThue';
  bool get isCancelled => status == 'CANCELLED' || status == 'daHuy';

  String get statusDisplayText {
    if (isPaid) return 'Đã thanh toán';
    if (isAddedToInvoice) return 'Đã trừ vào tiền thuê';
    if (isCancelled) return 'Đã hủy';
    return 'Chờ nộp';
  }

  String get paymentMethodDisplayText {
    switch (paymentMethod) {
      case 'NEXT_INVOICE':
        return 'Cộng vào tiền phòng tháng sau';
      case 'CASH':
        return 'Thu tiền mặt trực tiếp';
      case 'DEPOSIT':
        return 'Khấu trừ vào tiền cọc';
      default:
        return paymentMethod;
    }
  }

  const ViolationRecordModel({
    required this.id,
    required this.landlordId,
    required this.roomId,
    this.roomCode = '',
    this.propertyName = '',
    this.periodId = '',
    required this.tenantId,
    required this.tenantName,
    this.tenantPhone = '',
    this.violationIds = const [],
    this.violationTitles = const [],
    required this.totalFine,
    this.paymentMethod = 'NEXT_INVOICE',
    this.status = 'PENDING',
    this.description = '',
    this.evidenceUrls = const [],
    this.lastReminderAt,
    this.paidAt,
    this.paidMethod,
    this.paidCollector,
    required this.createdAt,
    this.updatedAt,
  });

  ViolationRecordModel copyWith({
    String? id,
    String? landlordId,
    String? roomId,
    String? roomCode,
    String? propertyName,
    String? periodId,
    String? tenantId,
    String? tenantName,
    String? tenantPhone,
    List<String>? violationIds,
    List<String>? violationTitles,
    double? totalFine,
    String? paymentMethod,
    String? status,
    String? description,
    List<String>? evidenceUrls,
    DateTime? lastReminderAt,
    DateTime? paidAt,
    String? paidMethod,
    String? paidCollector,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ViolationRecordModel(
      id: id ?? this.id,
      landlordId: landlordId ?? this.landlordId,
      roomId: roomId ?? this.roomId,
      roomCode: roomCode ?? this.roomCode,
      propertyName: propertyName ?? this.propertyName,
      periodId: periodId ?? this.periodId,
      tenantId: tenantId ?? this.tenantId,
      tenantName: tenantName ?? this.tenantName,
      tenantPhone: tenantPhone ?? this.tenantPhone,
      violationIds: violationIds ?? this.violationIds,
      violationTitles: violationTitles ?? this.violationTitles,
      totalFine: totalFine ?? this.totalFine,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      description: description ?? this.description,
      evidenceUrls: evidenceUrls ?? this.evidenceUrls,
      lastReminderAt: lastReminderAt ?? this.lastReminderAt,
      paidAt: paidAt ?? this.paidAt,
      paidMethod: paidMethod ?? this.paidMethod,
      paidCollector: paidCollector ?? this.paidCollector,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ViolationRecordModel.fromFirestore(DocumentSnapshot doc) {
    return ViolationRecordModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  factory ViolationRecordModel.fromMap(Map<String, dynamic> data, String id) {
    // Normalization of violation IDs and titles
    final vIds = <String>[];
    if (data['violationIds'] is List) {
      vIds.addAll((data['violationIds'] as List).map((e) => e.toString()));
    } else if (data['viPhamId'] != null) {
      vIds.add(data['viPhamId'].toString());
    }

    final vTitles = <String>[];
    if (data['violationTitles'] is List) {
      vTitles.addAll((data['violationTitles'] as List).map((e) => e.toString()));
    } else if (data['title'] != null) {
      vTitles.add(data['title'].toString());
    } else if (data['ten'] != null) {
      vTitles.add(data['ten'].toString());
    }

    final evUrls = <String>[];
    if (data['evidenceUrls'] is List) {
      evUrls.addAll((data['evidenceUrls'] as List).map((e) => e.toString()));
    } else if (data['chungCu'] is List) {
      evUrls.addAll((data['chungCu'] as List).map((e) => e.toString()));
    } else if (data['evidence_urls'] is List) {
      evUrls.addAll((data['evidence_urls'] as List).map((e) => e.toString()));
    }

    final rawStatus = (data['status'] ?? data['trangThai'] ?? 'PENDING').toString();
    final normalizedStatus = _normalizeStatus(rawStatus);

    final rawMethod = (data['paymentMethod'] ??
            data['payment_method'] ??
            data['hinhThucXuLy'] ??
            'NEXT_INVOICE')
        .toString();

    return ViolationRecordModel(
      id: id,
      landlordId: (data['landlordId'] ??
              data['landlord_id'] ??
              data['chuNhaId'] ??
              '')
          .toString(),
      roomId: (data['roomId'] ?? data['room_id'] ?? data['phongId'] ?? '')
          .toString(),
      roomCode: (data['roomCode'] ??
              data['room_code'] ??
              data['soPhong'] ??
              '')
          .toString(),
      propertyName: (data['propertyName'] ??
              data['property_name'] ??
              data['tenKhu'] ??
              '')
          .toString(),
      periodId: (data['periodId'] ??
              data['period_id'] ??
              data['kyThue_id'] ??
              data['kyOId'] ??
              '')
          .toString(),
      tenantId: (data['tenantId'] ??
              data['tenant_id'] ??
              data['nguoiDungId'] ??
              '')
          .toString(),
      tenantName: (data['tenantName'] ??
              data['tenant_name'] ??
              data['hoTen'] ??
              data['tenNguoiThue'] ??
              'Cư dân')
          .toString(),
      tenantPhone: (data['tenantPhone'] ??
              data['tenant_phone'] ??
              data['sdt'] ??
              '')
          .toString(),
      violationIds: vIds,
      violationTitles: vTitles,
      totalFine: ((data['totalFine'] ??
                  data['fine_amount'] ??
                  data['tongTienPhat'] ??
                  data['mucPhat']) as num?)
              ?.toDouble() ??
          0.0,
      paymentMethod: rawMethod,
      status: normalizedStatus,
      description: (data['description'] ?? data['moTa'] ?? '').toString(),
      evidenceUrls: evUrls,
      lastReminderAt: (data['lastReminderAt'] is Timestamp)
          ? (data['lastReminderAt'] as Timestamp).toDate()
          : (data['nhacNhoCuoiLuc'] is Timestamp)
              ? (data['nhacNhoCuoiLuc'] as Timestamp).toDate()
              : null,
      paidAt: (data['paidAt'] is Timestamp)
          ? (data['paidAt'] as Timestamp).toDate()
          : (data['thanhToanLuc'] is Timestamp)
              ? (data['thanhToanLuc'] as Timestamp).toDate()
              : null,
      paidMethod: data['paidMethod']?.toString(),
      paidCollector: data['paidCollector']?.toString(),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['ngayLap'] is Timestamp)
              ? (data['ngayLap'] as Timestamp).toDate()
              : (data['created_at'] is Timestamp)
                  ? (data['created_at'] as Timestamp).toDate()
                  : DateTime.now(),
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : (data['ngayCapNhat'] is Timestamp)
              ? (data['ngayCapNhat'] as Timestamp).toDate()
              : null,
    );
  }

  static String _normalizeStatus(String raw) {
    switch (raw.toUpperCase()) {
      case 'PAID':
      case 'DANOP':
      case 'DATHANHTOAN':
        return 'PAID';
      case 'ADDED_TO_INVOICE':
      case 'DACONTIENPHONG':
      case 'DACONGTIENPHONG':
      case 'DATRUVAOTIENTHUE':
        return 'ADDED_TO_INVOICE';
      case 'CANCELLED':
      case 'DAHUY':
        return 'CANCELLED';
      default:
        return 'PENDING';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bienBanId': id,
      'landlordId': landlordId,
      'landlord_id': landlordId,
      'chuNhaId': landlordId,
      'roomId': roomId,
      'room_id': roomId,
      'phongId': roomId,
      'roomCode': roomCode,
      'soPhong': roomCode,
      'propertyName': propertyName,
      'tenKhu': propertyName,
      'periodId': periodId,
      'period_id': periodId,
      'kyThue_id': periodId,
      'kyOId': periodId,
      'tenantId': tenantId,
      'tenant_id': tenantId,
      'nguoiDungId': tenantId,
      'tenantName': tenantName,
      'hoTen': tenantName,
      'tenNguoiThue': tenantName,
      'tenantPhone': tenantPhone,
      'sdt': tenantPhone,
      'violationIds': violationIds,
      'viPhamId': violationIds.isNotEmpty ? violationIds.first : '',
      'violationTitles': violationTitles,
      'title': violationTitles.isNotEmpty ? violationTitles.first : '',
      'ten': violationTitles.isNotEmpty ? violationTitles.first : '',
      'totalFine': totalFine,
      'fine_amount': totalFine,
      'tongTienPhat': totalFine,
      'paymentMethod': paymentMethod,
      'payment_method': paymentMethod,
      'hinhThucXuLy': paymentMethod,
      'status': status,
      'trangThai': status,
      'description': description,
      'moTa': description,
      'evidenceUrls': evidenceUrls,
      'evidence_urls': evidenceUrls,
      'chungCu': evidenceUrls,
      'lastReminderAt':
          lastReminderAt != null ? Timestamp.fromDate(lastReminderAt!) : null,
      'nhacNhoCuoiLuc':
          lastReminderAt != null ? Timestamp.fromDate(lastReminderAt!) : null,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'thanhToanLuc': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'paidMethod': paidMethod,
      'paidCollector': paidCollector,
      'createdAt': Timestamp.fromDate(createdAt),
      'ngayLap': Timestamp.fromDate(createdAt),
      'created_at': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'ngayCapNhat': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
}
