import 'package:cloud_firestore/cloud_firestore.dart';

/// Model Cư dân theo Database homeShare & SDS
/// Collection: residents/{residentId}
class ResidentModel {
  final String id;
  final String periodId;
  final String userId;
  final String fullName;
  final String phone;
  final String avatar;
  final String roommateRequestId;
  final String formId; // 'chinh', 'oGhep'
  final String statusId; // 'dangO', 'daRoi'
  final DateTime moveInDate;
  final DateTime? moveOutDate;

  // SDS Dual Aliases
  String get residentId => id;
  // ignore: non_constant_identifier_names
  String get kyThue_id => periodId;
  String get kyOId => periodId;
  String get nguoiDungId => userId;
  String get hoTen => fullName;
  String get sdt => phone;
  String get soDienThoai => phone;
  String get yeuCauOGhepId => roommateRequestId;
  // ignore: non_constant_identifier_names
  String get hinhThuc_id => formId;
  // ignore: non_constant_identifier_names
  String get trangThai_id => statusId;
  DateTime get ngayVao => moveInDate;
  DateTime? get ngayRoi => moveOutDate;

  const ResidentModel({
    required this.id,
    required this.periodId,
    required this.userId,
    required this.fullName,
    this.phone = '',
    this.avatar = '',
    this.roommateRequestId = '',
    this.formId = 'chinh',
    this.statusId = 'dangO',
    required this.moveInDate,
    this.moveOutDate,
  });

  ResidentModel copyWith({
    String? id,
    String? periodId,
    String? userId,
    String? fullName,
    String? phone,
    String? avatar,
    String? roommateRequestId,
    String? formId,
    String? statusId,
    DateTime? moveInDate,
    DateTime? moveOutDate,
  }) {
    return ResidentModel(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      roommateRequestId: roommateRequestId ?? this.roommateRequestId,
      formId: formId ?? this.formId,
      statusId: statusId ?? this.statusId,
      moveInDate: moveInDate ?? this.moveInDate,
      moveOutDate: moveOutDate ?? this.moveOutDate,
    );
  }

  factory ResidentModel.fromFirestore(DocumentSnapshot doc) {
    return ResidentModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  factory ResidentModel.fromMap(Map<String, dynamic> data, String id) {
    return ResidentModel(
      id: id,
      periodId: data['periodId'] ?? data['kyThue_id'] ?? data['kyOId'] ?? '',
      userId: data['userId'] ?? data['nguoiDungId'] ?? '',
      fullName:
          data['fullName'] ?? data['hoTen'] ?? data['ten'] ?? data['name'] ?? '',
      phone:
          data['phone'] ??
          data['soDienThoai'] ??
          data['sdt'] ??
          '',
      avatar: data['avatar'] ?? data['anhDaiDien'] ?? '',
      roommateRequestId:
          data['roommateRequestId'] ?? data['yeuCauOGhepId'] ?? '',
      formId: data['formId'] ?? data['hinhThuc_id'] ?? 'chinh',
      statusId: data['statusId'] ?? data['trangThai_id'] ?? 'dangO',
      moveInDate: (data['moveInDate'] is Timestamp)
          ? (data['moveInDate'] as Timestamp).toDate()
          : (data['ngayVao'] is Timestamp)
          ? (data['ngayVao'] as Timestamp).toDate()
          : DateTime.now(),
      moveOutDate: (data['moveOutDate'] is Timestamp)
          ? (data['moveOutDate'] as Timestamp).toDate()
          : (data['ngayRoi'] is Timestamp)
          ? (data['ngayRoi'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'periodId': periodId,
      'kyThue_id': periodId,
      'kyOId': periodId,
      'userId': userId,
      'nguoiDungId': userId,
      'fullName': fullName,
      'hoTen': fullName,
      'phone': phone,
      'soDienThoai': phone,
      'sdt': phone,
      'avatar': avatar,
      'roommateRequestId': roommateRequestId,
      'yeuCauOGhepId': roommateRequestId,
      'formId': formId,
      'hinhThuc_id': formId,
      'statusId': statusId,
      'trangThai_id': statusId,
      'moveInDate': Timestamp.fromDate(moveInDate),
      'ngayVao': Timestamp.fromDate(moveInDate),
      if (moveOutDate != null) 'moveOutDate': Timestamp.fromDate(moveOutDate!),
      if (moveOutDate != null) 'ngayRoi': Timestamp.fromDate(moveOutDate!),
    };
  }
}
