import 'package:cloud_firestore/cloud_firestore.dart';

/// Model Danh mục loại vi phạm theo Database homeShare & SDS
/// Collection: violations/{viPhamId}
class ViolationModel {
  final String id;
  final String title;
  final String description;
  final double defaultFine;
  final String category;
  final String iconName;
  final bool isActive;
  final DateTime createdAt;

  // SDS / Database Dual Aliases
  String get viPhamId => id;
  String get ten => title;
  String get moTa => description;
  double get mucPhatMacDinh => defaultFine;
  String get nhomViPham => category;
  String get trangThai => isActive ? 'active' : 'inactive';
  DateTime get ngayTao => createdAt;

  const ViolationModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.defaultFine,
    this.category = 'Nội quy chung',
    this.iconName = 'warning_amber_rounded',
    this.isActive = true,
    required this.createdAt,
  });

  ViolationModel copyWith({
    String? id,
    String? title,
    String? description,
    double? defaultFine,
    String? category,
    String? iconName,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ViolationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      defaultFine: defaultFine ?? this.defaultFine,
      category: category ?? this.category,
      iconName: iconName ?? this.iconName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ViolationModel.fromFirestore(DocumentSnapshot doc) {
    return ViolationModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  factory ViolationModel.fromMap(Map<String, dynamic> data, String id) {
    return ViolationModel(
      id: id,
      title: (data['title'] ?? data['ten'] ?? '').toString(),
      description: (data['description'] ?? data['moTa'] ?? '').toString(),
      defaultFine: ((data['defaultFine'] ??
                  data['mucPhatMacDinh'] ??
                  data['fine_amount']) as num?)
              ?.toDouble() ??
          0.0,
      category:
          (data['category'] ?? data['nhomViPham'] ?? 'Nội quy chung').toString(),
      iconName:
          (data['iconName'] ?? data['icon'] ?? 'warning_amber_rounded').toString(),
      isActive: data['isActive'] == true ||
          data['trangThai'] == 'active' ||
          data['trangThai'] == 'hoatDong' ||
          data['status'] == 'active' ||
          data['status'] == true,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['ngayTao'] is Timestamp)
              ? (data['ngayTao'] as Timestamp).toDate()
              : (data['created_at'] is Timestamp)
                  ? (data['created_at'] as Timestamp).toDate()
                  : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'viPhamId': id,
      'title': title,
      'ten': title,
      'description': description,
      'moTa': moTa,
      'defaultFine': defaultFine,
      'mucPhatMacDinh': defaultFine,
      'fine_amount': defaultFine,
      'category': category,
      'nhomViPham': category,
      'iconName': iconName,
      'isActive': isActive,
      'trangThai': trangThai,
      'status': trangThai,
      'createdAt': Timestamp.fromDate(createdAt),
      'ngayTao': Timestamp.fromDate(createdAt),
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
