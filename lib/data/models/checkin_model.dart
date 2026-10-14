import 'package:cloud_firestore/cloud_firestore.dart';

/// Model Phiếu nhận phòng theo Database homeShare & SDS
/// Collection: checkins/{checkinId}
class CheckinModel {
  final String id;
  final String bookingId;
  final String periodId;
  final String scannerId;
  final DateTime scanTime;
  final String status; // 'daNhanPhong', 'hoanTat'
  final double initialElectricityMeter;
  final double initialWaterMeter;
  final double electricityRate;
  final double waterRate;
  final bool isKeyHandedOver;
  final String note;
  final DateTime createdAt;

  // SDS Dual Aliases
  String get checkinId => id;
  String get donId => bookingId;
  String get kyOId => periodId;
  String get nguoiQuetId => scannerId;
  DateTime get thoiGianQuet => scanTime;
  // ignore: non_constant_identifier_names
  String get trangThaiPhieuNhan_id => status;
  double get chiSoDienBanDau => initialElectricityMeter;
  double get chiSoNuocBanDau => initialWaterMeter;
  double get donGiaDien => electricityRate;
  double get donGiaNuoc => waterRate;
  bool get daBanGiaoChiaKhoa => isKeyHandedOver;
  String get ghiChu => note;
  DateTime get ngayTao => createdAt;

  const CheckinModel({
    required this.id,
    required this.bookingId,
    required this.periodId,
    required this.scannerId,
    required this.scanTime,
    this.status = 'daNhanPhong',
    this.initialElectricityMeter = 0.0,
    this.initialWaterMeter = 0.0,
    this.electricityRate = 3500.0,
    this.waterRate = 20000.0,
    this.isKeyHandedOver = true,
    this.note = '',
    required this.createdAt,
  });

  CheckinModel copyWith({
    String? id,
    String? bookingId,
    String? periodId,
    String? scannerId,
    DateTime? scanTime,
    String? status,
    double? initialElectricityMeter,
    double? initialWaterMeter,
    double? electricityRate,
    double? waterRate,
    bool? isKeyHandedOver,
    String? note,
    DateTime? createdAt,
  }) {
    return CheckinModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      periodId: periodId ?? this.periodId,
      scannerId: scannerId ?? this.scannerId,
      scanTime: scanTime ?? this.scanTime,
      status: status ?? this.status,
      initialElectricityMeter:
          initialElectricityMeter ?? this.initialElectricityMeter,
      initialWaterMeter: initialWaterMeter ?? this.initialWaterMeter,
      electricityRate: electricityRate ?? this.electricityRate,
      waterRate: waterRate ?? this.waterRate,
      isKeyHandedOver: isKeyHandedOver ?? this.isKeyHandedOver,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory CheckinModel.fromFirestore(DocumentSnapshot doc) {
    return CheckinModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  factory CheckinModel.fromMap(Map<String, dynamic> data, String id) {
    return CheckinModel(
      id: id,
      bookingId: data['bookingId'] ?? data['donId'] ?? '',
      periodId: data['periodId'] ?? data['kyOId'] ?? '',
      scannerId: data['scannerId'] ?? data['nguoiQuetId'] ?? '',
      scanTime: (data['scanTime'] is Timestamp)
          ? (data['scanTime'] as Timestamp).toDate()
          : (data['thoiGianQuet'] is Timestamp)
          ? (data['thoiGianQuet'] as Timestamp).toDate()
          : DateTime.now(),
      status: data['status'] ?? data['trangThaiPhieuNhan_id'] ?? 'daNhanPhong',
      initialElectricityMeter:
          ((data['initialElectricityMeter'] ?? data['chiSoDienBanDau'])
                  as num?)
              ?.toDouble() ??
          0.0,
      initialWaterMeter:
          ((data['initialWaterMeter'] ?? data['chiSoNuocBanDau']) as num?)
              ?.toDouble() ??
          0.0,
      electricityRate:
          ((data['electricityRate'] ?? data['donGiaDien']) as num?)
              ?.toDouble() ??
          3500.0,
      waterRate:
          ((data['waterRate'] ?? data['donGiaNuoc']) as num?)?.toDouble() ??
          20000.0,
      isKeyHandedOver:
          data['isKeyHandedOver'] ?? data['daBanGiaoChiaKhoa'] ?? true,
      note: data['note'] ?? data['ghiChu'] ?? '',
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['ngayTao'] is Timestamp)
          ? (data['ngayTao'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'donId': bookingId,
      'periodId': periodId,
      'kyOId': periodId,
      'scannerId': scannerId,
      'nguoiQuetId': scannerId,
      'scanTime': Timestamp.fromDate(scanTime),
      'thoiGianQuet': Timestamp.fromDate(scanTime),
      'status': status,
      'trangThaiPhieuNhan_id': status,
      'initialElectricityMeter': initialElectricityMeter,
      'chiSoDienBanDau': initialElectricityMeter,
      'initialWaterMeter': initialWaterMeter,
      'chiSoNuocBanDau': initialWaterMeter,
      'electricityRate': electricityRate,
      'donGiaDien': electricityRate,
      'waterRate': waterRate,
      'donGiaNuoc': waterRate,
      'isKeyHandedOver': isKeyHandedOver,
      'daBanGiaoChiaKhoa': isKeyHandedOver,
      'note': note,
      'ghiChu': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'ngayTao': Timestamp.fromDate(createdAt),
    };
  }
}
