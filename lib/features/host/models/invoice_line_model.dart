import 'package:cloud_firestore/cloud_firestore.dart';

/// Model Dòng hóa đơn theo Database homeShare (Vi phạm - Dòng hóa đơn qua viPhamId)
/// Collection: invoice_lines/{lineId}
class InvoiceLineModel {
  final String id;
  final String violationRecordId;
  final String violationId;
  final String roomId;
  final String periodId;
  final double amount;
  final String purpose; // 'PhatViPham', 'violation_fine'
  final String title;
  final String status; // 'pending', 'paid'
  final DateTime createdAt;

  // SDS / Database.docx Dual Aliases
  String get lineId => id;
  String get bienBanId => violationRecordId;
  String get viPhamId => violationId;
  String get phongId => roomId;
  // ignore: non_constant_identifier_names
  String get kyThue_id => periodId;
  String get kyOId => periodId;
  double get soTien => amount;
  String get mucDich => purpose;
  String get ten => title;
  String get trangThai => status;
  DateTime get ngayTao => createdAt;

  const InvoiceLineModel({
    required this.id,
    required this.violationRecordId,
    this.violationId = '',
    required this.roomId,
    required this.periodId,
    required this.amount,
    this.purpose = 'PhatViPham',
    this.title = 'Phạt vi phạm nội quy',
    this.status = 'pending',
    required this.createdAt,
  });

  InvoiceLineModel copyWith({
    String? id,
    String? violationRecordId,
    String? violationId,
    String? roomId,
    String? periodId,
    double? amount,
    String? purpose,
    String? title,
    String? status,
    DateTime? createdAt,
  }) {
    return InvoiceLineModel(
      id: id ?? this.id,
      violationRecordId: violationRecordId ?? this.violationRecordId,
      violationId: violationId ?? this.violationId,
      roomId: roomId ?? this.roomId,
      periodId: periodId ?? this.periodId,
      amount: amount ?? this.amount,
      purpose: purpose ?? this.purpose,
      title: title ?? this.title,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory InvoiceLineModel.fromFirestore(DocumentSnapshot doc) {
    return InvoiceLineModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  factory InvoiceLineModel.fromMap(Map<String, dynamic> data, String id) {
    return InvoiceLineModel(
      id: id,
      violationRecordId: (data['violationRecordId'] ??
              data['bienBanId'] ??
              data['recordId'] ??
              '')
          .toString(),
      violationId: (data['violationId'] ?? data['viPhamId'] ?? '').toString(),
      roomId: (data['roomId'] ?? data['phongId'] ?? '').toString(),
      periodId: (data['periodId'] ?? data['kyThue_id'] ?? data['kyOId'] ?? '')
          .toString(),
      amount: ((data['amount'] ?? data['soTien']) as num?)?.toDouble() ?? 0.0,
      purpose:
          (data['purpose'] ?? data['mucDich'] ?? 'PhatViPham').toString(),
      title: (data['title'] ?? data['ten'] ?? 'Phạt vi phạm nội quy').toString(),
      status: (data['status'] ?? data['trangThai'] ?? 'pending').toString(),
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
      'lineId': id,
      'violationRecordId': violationRecordId,
      'bienBanId': violationRecordId,
      'viPhamId': violationId,
      'violationId': violationId,
      'roomId': roomId,
      'phongId': roomId,
      'periodId': periodId,
      'kyThue_id': periodId,
      'kyOId': periodId,
      'amount': amount,
      'soTien': amount,
      'purpose': purpose,
      'mucDich': purpose,
      'title': title,
      'ten': title,
      'status': status,
      'trangThai': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'ngayTao': Timestamp.fromDate(createdAt),
    };
  }
}
