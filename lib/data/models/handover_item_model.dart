import 'package:cloud_firestore/cloud_firestore.dart';

/// Model Hạng mục bàn giao theo Database homeShare & SDS
/// Collection: handover_items/{itemId}
class HandoverItemModel {
  final String id;
  final String periodId;
  final String itemName;
  final String description;
  final String condition;
  final bool isChecked;

  // SDS Dual Aliases
  String get itemId => id;
  // ignore: non_constant_identifier_names
  String get kyThue_id => periodId;
  String get kyOId => periodId;
  String get tenHangMuc => itemName;
  String get moTa => description;
  String get tinhTrang => condition;
  bool get daKiemTra => isChecked;

  const HandoverItemModel({
    required this.id,
    required this.periodId,
    required this.itemName,
    this.description = '',
    this.condition = 'Tốt',
    this.isChecked = true,
  });

  HandoverItemModel copyWith({
    String? id,
    String? periodId,
    String? itemName,
    String? description,
    String? condition,
    bool? isChecked,
  }) {
    return HandoverItemModel(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      itemName: itemName ?? this.itemName,
      description: description ?? this.description,
      condition: condition ?? this.condition,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  factory HandoverItemModel.fromFirestore(DocumentSnapshot doc) {
    return HandoverItemModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  factory HandoverItemModel.fromMap(Map<String, dynamic> data, String id) {
    return HandoverItemModel(
      id: id,
      periodId: data['periodId'] ?? data['kyThue_id'] ?? data['kyOId'] ?? '',
      itemName: data['itemName'] ?? data['tenHangMuc'] ?? '',
      description: data['description'] ?? data['moTa'] ?? '',
      condition: data['condition'] ?? data['tinhTrang'] ?? 'Tốt',
      isChecked: data['isChecked'] ?? data['daKiemTra'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'periodId': periodId,
      'kyThue_id': periodId,
      'kyOId': periodId,
      'itemName': itemName,
      'tenHangMuc': itemName,
      'description': description,
      'moTa': description,
      'condition': condition,
      'tinhTrang': condition,
      'isChecked': isChecked,
      'daKiemTra': isChecked,
    };
  }
}
