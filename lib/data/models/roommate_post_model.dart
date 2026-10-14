import 'package:cloud_firestore/cloud_firestore.dart';

/// Model Tin ở ghép chuẩn hóa theo Database homeShare (DrawIO pkg_4: Ở ghép)
/// Bảng: Tin ở ghép, Ảnh tin ở ghép, Yêu cầu trao đổi ở ghép
class RoommatePostModel {
  final String id;
  final String authorId; // nguoiDangId
  final String authorName; // hoTen / tenNguoiDang
  final int authorAge; // tuoi
  final String authorGender; // Nam / Nữ (gioiTinh)
  final String authorOccupation; // ngheNghiep
  final String authorAvatar; // anhDaiDien
  final String title; // tieuDe
  final String description; // noiDung
  final String postType; // loaiTin: 'timNguoiOGhep' (daCoPhong) | 'dangTimPhong'
  final String? propertyType; // loaiNhaO: 'Căn hộ chung cư' | 'Nhà trọ / Phòng trọ / Căn hộ mini' | 'Nhà nguyên căn' | 'Ký túc xá / Sleepbox'
  final double pricePerPerson; // giaMoiNguoi
  final double budgetMin; // nganSachTu
  final double budgetMax; // nganSachDen
  final String address; // diaChi
  final double? latitude; // viDo, dùng để ghim bản đồ
  final double? longitude; // kinhDo, dùng để ghim bản đồ
  final String district; // khuVuc / quanHuyen (diaDiemId)
  final String targetGender; // gioiTinhMongMuon: nu | nam | tatCa
  final List<String> habits; // thoiQuen / soThich
  final List<String> images; // anhTinOGhep (duongDan)
  final List<String> imageCaptions; // ghiChuAnh
  final bool isVerified; // daXacThuc
  final int matchRate; // doTuongThich (AI Match Rate 0-100%)
  final bool hasRoom; // true = daCoPhong (timNguoiOGhep), false = dangTimPhong
  final String status; // trangThai: dangMo | daDong
  final String contactPhone; // soDienThoai / sdtLienHe — chỉ giữ trên bộ nhớ, đọc từ users
  final String donId; // khóa đơn đặt phòng, để trống nếu người đăng chưa có phòng
  final String diaDiemId; // khóa dia_diem
  final int soNguoiHienTai;
  final int soNguoiToiDa;
  final DateTime? ngayHetHan;
  final DateTime createdAt; // ngayDang
  final DateTime updatedAt; // ngayCapNhat

  // Vietnamese DrawIO Alias Getters
  String get tieuDe => title;
  String get noiDung => description;
  String get nguoiDangId => authorId;
  String get loaiTin => postType;
  String get displayPropertyType => (propertyType != null && propertyType!.isNotEmpty)
      ? propertyType!
      : (hasRoom ? 'Căn hộ chung cư' : 'Phòng trọ sinh viên');
  String get loaiNhaO => displayPropertyType;
  double get giaMoiNguoi => pricePerPerson;
  double get nganSachTu => budgetMin;
  double get nganSachDen => budgetMax;
  String get diaChi => address;
  String get gioiTinhMongMuon => targetGender;
  List<String> get thoiQuen => habits;
  List<String> get anhTinOGhep => images;
  String get trangThai => status;
  String get soDienThoai => contactPhone;
  DateTime get ngayTao => createdAt;
  DateTime get ngayCapNhat => updatedAt;

  RoommatePostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAge,
    required this.authorGender,
    required this.authorOccupation,
    this.authorAvatar = '',
    required this.title,
    required this.description,
    this.postType = 'timNguoiOGhep',
    this.propertyType,
    this.pricePerPerson = 0.0,
    required this.budgetMin,
    required this.budgetMax,
    this.address = '',
    this.latitude,
    this.longitude,
    required this.district,
    required this.targetGender,
    required this.habits,
    this.images = const [],
    this.imageCaptions = const [],
    this.isVerified = true,
    this.matchRate = 94,
    required this.hasRoom,
    this.status = 'dangMo',
    required this.contactPhone,
    this.donId = '',
    this.diaDiemId = '',
    this.soNguoiHienTai = 1,
    this.soNguoiToiDa = 2,
    this.ngayHetHan,
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  RoommatePostModel copyWith({
    String? id,
    String? authorId,
    String? authorName,
    int? authorAge,
    String? authorGender,
    String? authorOccupation,
    String? authorAvatar,
    String? title,
    String? description,
    String? postType,
    String? propertyType,
    double? pricePerPerson,
    double? budgetMin,
    double? budgetMax,
    String? address,
    double? latitude,
    double? longitude,
    String? district,
    String? targetGender,
    List<String>? habits,
    List<String>? images,
    List<String>? imageCaptions,
    bool? isVerified,
    int? matchRate,
    bool? hasRoom,
    String? status,
    String? contactPhone,
    String? donId,
    String? diaDiemId,
    int? soNguoiHienTai,
    int? soNguoiToiDa,
    DateTime? ngayHetHan,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoommatePostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAge: authorAge ?? this.authorAge,
      authorGender: authorGender ?? this.authorGender,
      authorOccupation: authorOccupation ?? this.authorOccupation,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      title: title ?? this.title,
      description: description ?? this.description,
      postType: postType ?? this.postType,
      propertyType: propertyType ?? this.propertyType,
      pricePerPerson: pricePerPerson ?? this.pricePerPerson,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      district: district ?? this.district,
      targetGender: targetGender ?? this.targetGender,
      habits: habits ?? this.habits,
      images: images ?? this.images,
      imageCaptions: imageCaptions ?? this.imageCaptions,
      isVerified: isVerified ?? this.isVerified,
      matchRate: matchRate ?? this.matchRate,
      hasRoom: hasRoom ?? this.hasRoom,
      status: status ?? this.status,
      contactPhone: contactPhone ?? this.contactPhone,
      donId: donId ?? this.donId,
      diaDiemId: diaDiemId ?? this.diaDiemId,
      soNguoiHienTai: soNguoiHienTai ?? this.soNguoiHienTai,
      soNguoiToiDa: soNguoiToiDa ?? this.soNguoiToiDa,
      ngayHetHan: ngayHetHan ?? this.ngayHetHan,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory RoommatePostModel.fromFirestore(DocumentSnapshot doc) {
    return RoommatePostModel.fromMap(doc.data() as Map<String, dynamic>? ?? {}, doc.id);
  }

  factory RoommatePostModel.fromMap(Map<String, dynamic> data, String id) {
    final donId = '${data['bookingId'] ?? data['donId'] ?? ''}';
    final loaiTinVal = data['postType'] ?? data['loaiTin'] ?? (data['hasRoom'] == true || donId.isNotEmpty ? 'timNguoiOGhep' : 'dangTimPhong');
    final hasRoomVal = data['hasRoom'] == true || donId.isNotEmpty || loaiTinVal == 'timNguoiOGhep' || loaiTinVal == 'daCoPhong';
    final rawStatus = '${data['status'] ?? data['trangThai_id'] ?? data['trangThai'] ?? 'open'}';
    final status = rawStatus == 'open' || rawStatus == 'mo' || rawStatus == 'dangMo'
        ? 'dangMo'
        : rawStatus == 'closed' || rawStatus == 'dong' || rawStatus == 'daDong'
            ? 'daDong'
            : rawStatus;
    final storedPrice = ((data['pricePerPerson'] ?? data['giaMoiNguoi']) as num?)?.toDouble() ?? 0.0;
    final budgetMax = ((data['budgetMax'] ?? data['nganSachDen']) as num?)?.toDouble() ?? 2500000;
    
    // Parse habits / thoiQuen
    final rawHabits = (data['habits'] ?? data['thoiQuen'] ?? data['soThich']) as List<dynamic>?;
    final parsedHabits = rawHabits
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    // Parse images / anhTinOGhep
    final rawImages = (data['images'] ?? data['anhTinOGhep'] ?? data['anhPhong']) as List<dynamic>?;
    final parsedImages = rawImages
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    final rawCaptions = (data['imageCaptions'] ?? data['ghiChuAnh']) as List<dynamic>?;
    final parsedCaptions = rawCaptions
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    return RoommatePostModel(
      id: id,
      authorId: data['authorId'] ?? data['nguoiDangId'] ?? '',
      authorName: data['authorName'] ?? data['hoTen'] ?? data['tenNguoiDang'] ?? '',
      authorAge: (data['authorAge'] ?? data['tuoi']) is num ? (data['authorAge'] ?? data['tuoi']).toInt() : 20,
      authorGender: data['authorGender'] ?? data['gioiTinh'] ?? '',
      authorOccupation: data['authorOccupation'] ?? data['ngheNghiep'] ?? '',
      authorAvatar: data['authorAvatar'] ?? data['anhDaiDien'] ?? '',
      title: data['title'] ?? data['tieuDe'] ?? '',
      description: data['description'] ?? data['noiDung'] ?? data['moTa'] ?? '',
      postType: loaiTinVal.toString(),
      propertyType: data['propertyType'] ?? data['loaiNhaO'] ?? data['loaiHinh'] ?? (hasRoomVal ? 'Căn hộ chung cư' : 'Phòng trọ sinh viên'),
      pricePerPerson: storedPrice > 0 ? storedPrice : budgetMax,
      budgetMin: ((data['budgetMin'] ?? data['nganSachTu']) as num?)?.toDouble() ?? 1000000,
      budgetMax: budgetMax,
      address: data['address'] ?? data['diaChi'] ?? '',
      latitude: data['latitude'] is num ? (data['latitude'] as num).toDouble() : double.tryParse('${data['latitude'] ?? ''}'),
      longitude: data['longitude'] is num ? (data['longitude'] as num).toDouble() : double.tryParse('${data['longitude'] ?? ''}'),
      district: data['district'] ?? data['quanHuyen'] ?? data['khuVuc'] ?? '',
      targetGender: data['targetGender'] ?? data['gioiTinhMongMuon'] ?? 'Tất cả',
      habits: parsedHabits,
      images: parsedImages,
      imageCaptions: parsedCaptions,
      isVerified: data['isVerified'] ?? data['daXacThuc'] ?? true,
      matchRate: (data['matchRate'] ?? data['doTuongThich'] ?? 94) is num ? (data['matchRate'] ?? data['doTuongThich'] ?? 94).toInt() : 94,
      hasRoom: hasRoomVal,
      status: status,
      contactPhone: data['contactPhone'] ?? data['soDienThoai'] ?? data['sdtLienHe'] ?? '',
      donId: donId,
      diaDiemId: '${data['placeId'] ?? data['diaDiemId'] ?? ''}',
      soNguoiHienTai: ((data['currentOccupants'] ?? data['soNguoiHienTai']) as num?)?.toInt() ?? 1,
      soNguoiToiDa: ((data['maxOccupants'] ?? data['soNguoiToiDa']) as num?)?.toInt() ?? 2,
      ngayHetHan: (data['expiresAt'] ?? data['ngayHetHan']) is Timestamp
          ? ((data['expiresAt'] ?? data['ngayHetHan']) as Timestamp).toDate()
          : null,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['ngayDang'] is Timestamp)
              ? (data['ngayDang'] as Timestamp).toDate()
              : (data['ngayTao'] is Timestamp)
                  ? (data['ngayTao'] as Timestamp).toDate()
                  : DateTime.now(),
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : (data['ngayCapNhat'] is Timestamp)
              ? (data['ngayCapNhat'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  /// Document `roommate_posts` chỉ ghi một tên tiếng Anh cho mỗi trường.
  /// Ảnh, địa điểm và sở thích nằm ở roommate_post_images, locations, user_hobbies.
  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      if (donId.isNotEmpty) 'bookingId': donId,
      'placeId': diaDiemId,
      'status': status == 'daDong' ? 'closed' : 'open',
      'title': title,
      'description': description,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'targetGender': targetGender,
      'currentOccupants': soNguoiHienTai,
      'maxOccupants': soNguoiToiDa,
      'hasRoom': hasRoom,
      'propertyType': displayPropertyType,
      'createdAt': Timestamp.fromDate(createdAt),
      if (ngayHetHan != null) 'expiresAt': Timestamp.fromDate(ngayHetHan!),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
