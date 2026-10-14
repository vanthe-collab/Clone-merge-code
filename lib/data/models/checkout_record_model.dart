import 'package:cloud_firestore/cloud_firestore.dart';

/// Model Biên bản trả phòng theo Database homeShare & SDS
/// Collection: checkout_records/{checkoutId}
class CheckoutRecordModel {
  final String id;
  final String periodId;
  final String roomId;
  final String renterId;
  final DateTime checkoutTime;
  final double depositAmount;
  final double deductionAmount;
  final double refundAmount;
  final String status; // 'daCheckout', 'daHoanCoc'
  final String note;

  // SDS Dual Aliases
  String get checkoutId => id;
  String get kyOId => periodId;
  String get phongId => roomId;
  String get nguoiDungId => renterId;
  DateTime get thoiGianCheckout => checkoutTime;
  double get tienCoc => depositAmount;
  double get khoanKhauTru => deductionAmount;
  double get tienHoan => refundAmount;
  String get trangThai => status;
  String get ghiChu => note;

  const CheckoutRecordModel({
    required this.id,
    required this.periodId,
    required this.roomId,
    required this.renterId,
    required this.checkoutTime,
    required this.depositAmount,
    this.deductionAmount = 0.0,
    required this.refundAmount,
    this.status = 'daCheckout',
    this.note = '',
  });

  CheckoutRecordModel copyWith({
    String? id,
    String? periodId,
    String? roomId,
    String? renterId,
    DateTime? checkoutTime,
    double? depositAmount,
    double? deductionAmount,
    double? refundAmount,
    String? status,
    String? note,
  }) {
    return CheckoutRecordModel(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      roomId: roomId ?? this.roomId,
      renterId: renterId ?? this.renterId,
      checkoutTime: checkoutTime ?? this.checkoutTime,
      depositAmount: depositAmount ?? this.depositAmount,
      deductionAmount: deductionAmount ?? this.deductionAmount,
      refundAmount: refundAmount ?? this.refundAmount,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }

  factory CheckoutRecordModel.fromFirestore(DocumentSnapshot doc) {
    return CheckoutRecordModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  factory CheckoutRecordModel.fromMap(Map<String, dynamic> data, String id) {
    return CheckoutRecordModel(
      id: id,
      periodId: data['periodId'] ?? data['kyOId'] ?? '',
      roomId: data['roomId'] ?? data['phongId'] ?? '',
      renterId: data['renterId'] ?? data['nguoiDungId'] ?? '',
      checkoutTime: (data['checkoutTime'] is Timestamp)
          ? (data['checkoutTime'] as Timestamp).toDate()
          : (data['thoiGianCheckout'] is Timestamp)
          ? (data['thoiGianCheckout'] as Timestamp).toDate()
          : DateTime.now(),
      depositAmount:
          ((data['depositAmount'] ?? data['tienCoc']) as num?)?.toDouble() ??
          0.0,
      deductionAmount:
          ((data['deductionAmount'] ?? data['khoanKhauTru']) as num?)
              ?.toDouble() ??
          0.0,
      refundAmount:
          ((data['refundAmount'] ?? data['tienHoan']) as num?)?.toDouble() ??
          0.0,
      status: data['status'] ?? data['trangThai'] ?? 'daCheckout',
      note: data['note'] ?? data['ghiChu'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'periodId': periodId,
      'kyOId': periodId,
      'roomId': roomId,
      'phongId': roomId,
      'renterId': renterId,
      'nguoiDungId': renterId,
      'checkoutTime': Timestamp.fromDate(checkoutTime),
      'thoiGianCheckout': Timestamp.fromDate(checkoutTime),
      'depositAmount': depositAmount,
      'tienCoc': depositAmount,
      'deductionAmount': deductionAmount,
      'khoanKhauTru': deductionAmount,
      'refundAmount': refundAmount,
      'tienHoan': refundAmount,
      'status': status,
      'trangThai': status,
      'note': note,
      'ghiChu': note,
    };
  }
}
