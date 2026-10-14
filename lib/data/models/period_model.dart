import 'package:cloud_firestore/cloud_firestore.dart';

/// Model Kỳ ở theo Database homeShare (pkg_3: Đặt phòng và kỳ ở)
/// Bảng: Kỳ ở (kyOId, donId, phongId, nguoiDungId, ngayBatDau, ngayKetThuc, trangThai, daBanGiaoChiaKhoa...)
class PeriodModel {
  final String id;
  final String bookingId;
  final String roomId;
  final String renterId;
  final DateTime startDate;
  final DateTime? endDate;
  final String status; // 'dangO', 'daKetThuc'
  final bool isKeyHandedOver;
  final String handoverNote;
  final double initialElectricityMeter;
  final double initialWaterMeter;
  final DateTime createdAt;

  // SDS Dual Aliases
  String get kyOId => id;
  String get donId => bookingId;
  String get phongId => roomId;
  String get nguoiDungId => renterId;
  DateTime get ngayBatDau => startDate;
  DateTime get batDauLuc => startDate;
  DateTime? get ngayKetThuc => endDate;
  DateTime? get ketThucLuc => endDate;
  String get trangThai => status;
  bool get daBanGiaoChiaKhoa => isKeyHandedOver;
  String get ghiChuBanGiao => handoverNote;
  double get chiSoDienDau => initialElectricityMeter;
  double get chiSoNuocDau => initialWaterMeter;
  DateTime get ngayTao => createdAt;

  const PeriodModel({
    required this.id,
    required this.bookingId,
    required this.roomId,
    required this.renterId,
    required this.startDate,
    this.endDate,
    this.status = 'dangO',
    this.isKeyHandedOver = true,
    this.handoverNote = '',
    this.initialElectricityMeter = 0.0,
    this.initialWaterMeter = 0.0,
    required this.createdAt,
  });

  PeriodModel copyWith({
    String? id,
    String? bookingId,
    String? roomId,
    String? renterId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    bool? isKeyHandedOver,
    String? handoverNote,
    double? initialElectricityMeter,
    double? initialWaterMeter,
    DateTime? createdAt,
  }) {
    return PeriodModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      roomId: roomId ?? this.roomId,
      renterId: renterId ?? this.renterId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      isKeyHandedOver: isKeyHandedOver ?? this.isKeyHandedOver,
      handoverNote: handoverNote ?? this.handoverNote,
      initialElectricityMeter:
          initialElectricityMeter ?? this.initialElectricityMeter,
      initialWaterMeter: initialWaterMeter ?? this.initialWaterMeter,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory PeriodModel.fromFirestore(DocumentSnapshot doc) {
    return PeriodModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  factory PeriodModel.fromMap(Map<String, dynamic> data, String id) {
    return PeriodModel(
      id: id,
      bookingId: data['bookingId'] ?? data['donId'] ?? '',
      roomId: data['roomId'] ?? data['phongId'] ?? '',
      renterId: data['renterId'] ?? data['nguoiDungId'] ?? '',
      startDate: (data['startDate'] is Timestamp)
          ? (data['startDate'] as Timestamp).toDate()
          : (data['ngayBatDau'] is Timestamp)
          ? (data['ngayBatDau'] as Timestamp).toDate()
          : (data['batDauLuc'] is Timestamp)
          ? (data['batDauLuc'] as Timestamp).toDate()
          : DateTime.now(),
      endDate: (data['endDate'] is Timestamp)
          ? (data['endDate'] as Timestamp).toDate()
          : (data['ngayKetThuc'] is Timestamp)
          ? (data['ngayKetThuc'] as Timestamp).toDate()
          : (data['ketThucLuc'] is Timestamp)
          ? (data['ketThucLuc'] as Timestamp).toDate()
          : null,
      status: data['status'] ?? data['trangThai'] ?? 'dangO',
      isKeyHandedOver:
          data['isKeyHandedOver'] ?? data['daBanGiaoChiaKhoa'] ?? true,
      handoverNote: data['handoverNote'] ?? data['ghiChuBanGiao'] ?? '',
      initialElectricityMeter:
          ((data['initialElectricityMeter'] ??
                      data['chiSoDienDau'] ??
                      data['chiSoDienBanDau'])
                  as num?)
              ?.toDouble() ??
          0.0,
      initialWaterMeter:
          ((data['initialWaterMeter'] ??
                      data['chiSoNuocDau'] ??
                      data['chiSoNuocBanDau'])
                  as num?)
              ?.toDouble() ??
          0.0,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['ngayTao'] is Timestamp)
          ? (data['ngayTao'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kyOId': id,
      'bookingId': bookingId,
      'donId': bookingId,
      'roomId': roomId,
      'phongId': roomId,
      'renterId': renterId,
      'nguoiDungId': renterId,
      'startDate': Timestamp.fromDate(startDate),
      'ngayBatDau': Timestamp.fromDate(startDate),
      'batDauLuc': Timestamp.fromDate(startDate),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      if (endDate != null) 'ngayKetThuc': Timestamp.fromDate(endDate!),
      if (endDate != null) 'ketThucLuc': Timestamp.fromDate(endDate!),
      'status': status,
      'trangThai': status,
      'isKeyHandedOver': isKeyHandedOver,
      'daBanGiaoChiaKhoa': isKeyHandedOver,
      'handoverNote': handoverNote,
      'ghiChuBanGiao': handoverNote,
      'initialElectricityMeter': initialElectricityMeter,
      'chiSoDienDau': initialElectricityMeter,
      'chiSoDienBanDau': initialElectricityMeter,
      'initialWaterMeter': initialWaterMeter,
      'chiSoNuocDau': initialWaterMeter,
      'chiSoNuocBanDau': initialWaterMeter,
      'createdAt': Timestamp.fromDate(createdAt),
      'ngayTao': Timestamp.fromDate(createdAt),
    };
  }
}
