import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../../features/auth/providers/user_provider.dart';
import 'room_model.dart';

/// Model Bài đăng Chủ trọ chuẩn hóa theo Database.docx & quy ước schema:
/// - Code sử dụng biến tiếng Anh chuẩn (roomId, hostId, rentalPrice, depositAmount, ...)
/// - Khi ghi Firestore: chỉ trả về các field trong [PostFields] bằng [toFirestore()]
/// - Cung cấp alias tiếng Việt (phongId, chuNhaId, giaThue, ...) để tương thích giao diện
class HostPostModel {
  // Các trường cốt lõi trong Schema Firestore
  final String id; // postId / baiDangId
  final String roomId; // phongId [FK -> rooms]
  final String hostId; // chuNhaId [FK -> users]
  final String locationId; // diaDiemId [FK -> locations]
  final String rentalTypeId; // loaiThue_id
  final String statusId; // trangThai_id
  final String title; // tieuDe
  final String description; // moTa
  final double rentalPrice; // giaThue
  final double depositAmount; // tienCoc
  final int depositPercentage; // phanTramTienCoc (10, 20, 30, 40, 50)
  final List<String> amenities; // tienIch
  final List<String> images; // anhPhong
  final String address; // diaChi
  final String contactPhone; // soDienThoaiLienHe
  final DateTime createdAt; // ngayDang
  final String status; // trangThai

  // Các trường nghiệp vụ giao diện và ghép nối bộ nhớ (IN-MEMORY ONLY - KHÔNG LƯU FIRESTORE)
  final String authorName;
  final String authorAvatar;
  final String propertyName;
  final String city;
  final String district;
  final double roomArea;
  final String roomType;
  final String mucDichHopTac;
  final int interestedCount;
  final int responseCount;
  final bool isVerified;
  final bool isVip;
  final bool isUserInterested;
  final RoomModel? joinedRoom;
  final UserProfile? joinedHost;

  HostPostModel({
    required this.id,
    String? roomId,
    String? hostId,
    String? locationId,
    String? rentalTypeId,
    String? statusId,
    String? title,
    String? description,
    double? rentalPrice,
    double? depositAmount,
    int? depositPercentage,
    this.amenities = const [],
    this.images = const [],
    this.address = '',
    String? contactPhone,
    DateTime? createdAt,
    this.status = 'dangHienThi',
    // In-memory UI fields
    this.authorName = '',
    this.authorAvatar = '',
    this.propertyName = '',
    this.city = '',
    this.district = '',
    this.roomArea = 0.0,
    this.roomType = 'Phòng trọ',
    this.mucDichHopTac = 'Chia sẻ khách thuê & Hợp tác quản lý',
    this.interestedCount = 0,
    this.responseCount = 0,
    this.isVerified = false,
    this.isVip = false,
    this.isUserInterested = false,
    this.joinedRoom,
    this.joinedHost,
    // Vietnamese legacy named parameters
    String? phongId,
    String? chuNhaId,
    String? diaDiemId,
    String? loaiThueId,
    String? trangThaiId,
    String? tieuDe,
    String? moTa,
    double? giaThue,
    double? tienCoc,
    int? phanTramTienCoc,
    String? soDienThoaiLienHe,
    DateTime? ngayDang,
  })  : roomId = roomId ?? phongId ?? '',
        hostId = hostId ?? chuNhaId ?? '',
        locationId = locationId ?? diaDiemId ?? '',
        rentalTypeId = rentalTypeId ?? loaiThueId ?? 'thang',
        statusId = statusId ?? trangThaiId ?? 'dangHienThi',
        title = title ?? tieuDe ?? '',
        description = description ?? moTa ?? '',
        rentalPrice = rentalPrice ?? giaThue ?? 0.0,
        depositAmount = depositAmount ?? tienCoc ?? 0.0,
        depositPercentage = depositPercentage ?? phanTramTienCoc ?? 20,
        contactPhone = contactPhone ?? soDienThoaiLienHe ?? '',
        createdAt = createdAt ?? ngayDang ?? DateTime.now();

  // Vietnamese Schema Aliases for backward compatibility in code
  String get phongId => roomId;
  String get chuNhaId => hostId;
  String get diaDiemId => locationId;
  String get loaiThueId => rentalTypeId;
  String get trangThaiId => statusId;
  String get tieuDe => title;
  String get moTa => description;
  double get giaThue => rentalPrice;
  double get tienCoc => depositAmount;
  int get phanTramTienCoc => depositPercentage;
  List<String> get tienIch => amenities;
  List<String> get anhPhong => images;
  String get diaChi => address;
  String get soDienThoaiLienHe => contactPhone;
  DateTime get ngayDang => createdAt;
  String get trangThai => status;

  bool get isActive =>
      statusId != 'daAn' &&
      statusId != 'deleted' &&
      statusId != 'closed' &&
      statusId != 'hidden' &&
      status != 'daAn' &&
      status != 'deleted';

  /// Mapper chuẩn: CHỈ trả về đúng tập hợp các field trong [PostFields] bằng tiếng Anh theo schema Firestore
  Map<String, dynamic> toFirestore() {
    return {
      PostFields.postId: id,
      PostFields.roomId: roomId,
      PostFields.hostId: hostId,
      PostFields.locationId: locationId,
      PostFields.rentalTypeId: rentalTypeId,
      PostFields.statusId: statusId,
      PostFields.title: title,
      PostFields.description: description,
      PostFields.rentalPrice: rentalPrice,
      PostFields.depositAmount: depositAmount,
      PostFields.depositPercentage: depositPercentage,
      PostFields.amenities: amenities,
      PostFields.images: images,
      PostFields.address: address,
      PostFields.contactPhone: contactPhone,
      PostFields.createdAt: Timestamp.fromDate(createdAt),
      PostFields.status: status,
    };
  }

  /// Alias kiểm soát: Không tự gom toàn bộ biến object, ủy thác về [toFirestore]
  Map<String, dynamic> toMap() => toFirestore();

  factory HostPostModel.fromFirestore(
    DocumentSnapshot doc, {
    String currentUserId = '',
  }) {
    return HostPostModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
      currentUserId: currentUserId,
    );
  }

  factory HostPostModel.fromMap(
    Map<String, dynamic> data,
    String id, {
    String currentUserId = '',
  }) {
    final imagesList = _parseStringList(
      data[PostFields.images] ??
          data['images'] ??
          data['anhPhong'] ??
          data['danhSachAnh'] ??
          data['imageUrls'],
    );
    final amenitiesList = _parseStringList(
      data[PostFields.amenities] ??
          data['amenities'] ??
          data['tienIch'] ??
          data['danhSachTienIch'],
    );

    DateTime postDate = DateTime.now();
    final rawDate =
        data[PostFields.createdAt] ??
        data['createdAt'] ??
        data['ngayDang'] ??
        data['ngayTao'];
    if (rawDate is Timestamp) {
      postDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      postDate = rawDate;
    } else if (rawDate is String) {
      postDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    final double price = (data[PostFields.rentalPrice] ??
            data['rentalPrice'] ??
            data['giaThue'] ??
            data['price'] ??
            data['gia'] ??
            data['giaThueThang'] ??
            0.0 as num)
        .toDouble();

    final int depositPct = (data[PostFields.depositPercentage] ??
            data['depositPercentage'] ??
            data['phanTramTienCoc'] as num?)
        ?.toInt() ??
        20;

    final double deposit = (data[PostFields.depositAmount] ??
            data['depositAmount'] ??
            data['tienCoc'] ??
            data['deposit'] ??
            (price > 0 ? (price * depositPct / 100) : 0.0) as num)
        .toDouble();

    final interestedList = data['interestedUsers'];
    final bool isUserInterested =
        currentUserId.isNotEmpty &&
        interestedList is List &&
        interestedList.contains(currentUserId);

    final int interestedCount = (data['interestedCount'] ??
            data['soNguoiQuanTam'] ??
            data['luotQuanTam'] ??
            (interestedList is List ? interestedList.length : 0) as num?)
        ?.toInt() ??
        0;

    final int responseCount = (data['responseCount'] ??
            data['soPhanHoi'] ??
            data['repliesCount'] ??
            0 as num?)
        ?.toInt() ??
        0;

    final effectiveId = id.isNotEmpty
        ? id
        : (data[PostFields.postId] ?? data['postId'] ?? data['baiDangId'] ?? '')
            .toString()
            .trim();

    return HostPostModel(
      id: effectiveId,
      roomId: (data[PostFields.roomId] ??
              data['roomId'] ??
              data['phongId'] ??
              '')
          .toString()
          .trim(),
      hostId: (data[PostFields.hostId] ??
              data['hostId'] ??
              data['chuNhaId'] ??
              data['userId'] ??
              '')
          .toString()
          .trim(),
      locationId: (data[PostFields.locationId] ??
              data['locationId'] ??
              data['diaDiemId'] ??
              data['placeId'] ??
              '')
          .toString()
          .trim(),
      rentalTypeId: (data[PostFields.rentalTypeId] ??
              data['rentalTypeId'] ??
              data['loaiThue_id'] ??
              'thang')
          .toString()
          .trim(),
      statusId: (data[PostFields.statusId] ??
              data['statusId'] ??
              data['trangThai_id'] ??
              data['status'] ??
              'dangHienThi')
          .toString()
          .trim(),
      title: (data[PostFields.title] ??
              data['title'] ??
              data['tieuDe'] ??
              '')
          .toString()
          .trim(),
      description: (data[PostFields.description] ??
              data['description'] ??
              data['moTa'] ??
              '')
          .toString()
          .trim(),
      rentalPrice: price,
      depositAmount: deposit,
      depositPercentage: depositPct,
      amenities: amenitiesList,
      images: imagesList,
      address: (data[PostFields.address] ??
              data['address'] ??
              data['diaChi'] ??
              '')
          .toString()
          .trim(),
      contactPhone: (data[PostFields.contactPhone] ??
              data['contactPhone'] ??
              data['soDienThoaiLienHe'] ??
              data['phone'] ??
              '')
          .toString()
          .trim(),
      createdAt: postDate,
      status: (data[PostFields.status] ??
              data['status'] ??
              data['trangThai'] ??
              'dangHienThi')
          .toString()
          .trim(),
      // In-memory UI/Join properties
      authorName: (data['authorName'] ?? data['hostName'] ?? '')
          .toString()
          .trim(),
      authorAvatar: (data['authorAvatar'] ?? data['hostAvatar'] ?? '')
          .toString()
          .trim(),
      propertyName: (data['propertyName'] ?? data['tenNhaTro'] ?? '')
          .toString()
          .trim(),
      city: (data['city'] ?? data['thanhPho'] ?? '').toString().trim(),
      district: (data['district'] ?? data['quanHuyen'] ?? '')
          .toString()
          .trim(),
      roomArea: (data['roomArea'] ??
              data['dienTich'] ??
              data['area'] ??
              0.0 as num)
          .toDouble(),
      roomType: (data['roomType'] ?? data['loaiPhong'] ?? 'Phòng trọ')
          .toString()
          .trim(),
      mucDichHopTac: (data['mucDichHopTac'] ??
              data['purpose'] ??
              'Chia sẻ khách thuê & Hợp tác quản lý')
          .toString()
          .trim(),
      interestedCount: interestedCount,
      responseCount: responseCount,
      isVerified: data['isVerified'] == true ||
          data['xacThuc'] == true ||
          data['daXacThuc'] == true,
      isVip: data['isVip'] == true || data['vip'] == true,
      isUserInterested: isUserInterested,
    );
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      final list = <String>[];
      for (final item in raw) {
        if (item is String && item.trim().isNotEmpty) {
          list.add(item.trim());
        } else if (item is Map) {
          final s = (item['url'] ??
                  item['duongDan'] ??
                  item['name'] ??
                  item['ten'] ??
                  item['amenityName'] ??
                  '')
              .toString()
              .trim();
          if (s.isNotEmpty) list.add(s);
        }
      }
      return list;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return [raw.trim()];
    }
    return const [];
  }

  HostPostModel copyWith({
    String? id,
    String? roomId,
    String? hostId,
    String? locationId,
    String? rentalTypeId,
    String? statusId,
    String? title,
    String? description,
    double? rentalPrice,
    double? depositAmount,
    int? depositPercentage,
    List<String>? amenities,
    List<String>? images,
    String? address,
    String? contactPhone,
    DateTime? createdAt,
    String? status,
    // UI/Join fields
    String? authorName,
    String? authorAvatar,
    String? propertyName,
    String? city,
    String? district,
    double? roomArea,
    String? roomType,
    String? mucDichHopTac,
    int? interestedCount,
    int? responseCount,
    bool? isVerified,
    bool? isVip,
    bool? isUserInterested,
    RoomModel? joinedRoom,
    UserProfile? joinedHost,
    // Vietnamese legacy named params
    String? phongId,
    String? chuNhaId,
    String? diaDiemId,
    String? loaiThueId,
    String? trangThaiId,
    String? tieuDe,
    String? moTa,
    double? giaThue,
    double? tienCoc,
    int? phanTramTienCoc,
    String? soDienThoaiLienHe,
    DateTime? ngayDang,
  }) {
    return HostPostModel(
      id: id ?? this.id,
      roomId: roomId ?? phongId ?? this.roomId,
      hostId: hostId ?? chuNhaId ?? this.hostId,
      locationId: locationId ?? diaDiemId ?? this.locationId,
      rentalTypeId: rentalTypeId ?? loaiThueId ?? this.rentalTypeId,
      statusId: statusId ?? trangThaiId ?? this.statusId,
      title: title ?? tieuDe ?? this.title,
      description: description ?? moTa ?? this.description,
      rentalPrice: rentalPrice ?? giaThue ?? this.rentalPrice,
      depositAmount: depositAmount ?? tienCoc ?? this.depositAmount,
      depositPercentage:
          depositPercentage ?? phanTramTienCoc ?? this.depositPercentage,
      amenities: amenities ?? this.amenities,
      images: images ?? this.images,
      address: address ?? this.address,
      contactPhone: contactPhone ?? soDienThoaiLienHe ?? this.contactPhone,
      createdAt: createdAt ?? ngayDang ?? this.createdAt,
      status: status ?? this.status,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      propertyName: propertyName ?? this.propertyName,
      city: city ?? this.city,
      district: district ?? this.district,
      roomArea: roomArea ?? this.roomArea,
      roomType: roomType ?? this.roomType,
      mucDichHopTac: mucDichHopTac ?? this.mucDichHopTac,
      interestedCount: interestedCount ?? this.interestedCount,
      responseCount: responseCount ?? this.responseCount,
      isVerified: isVerified ?? this.isVerified,
      isVip: isVip ?? this.isVip,
      isUserInterested: isUserInterested ?? this.isUserInterested,
      joinedRoom: joinedRoom ?? this.joinedRoom,
      joinedHost: joinedHost ?? this.joinedHost,
    );
  }

  /// Nối dữ liệu từ RoomModel (bộ nhớ tạm, không ghi vào posts document)
  HostPostModel withRoom(RoomModel room) {
    return copyWith(
      joinedRoom: room,
      roomArea: room.area > 0 ? room.area : (roomArea > 0 ? roomArea : 20.0),
      roomType: room.roomType.isNotEmpty ? room.roomType : roomType,
      propertyName: room.title.isNotEmpty ? room.title : propertyName,
      address: address.isNotEmpty ? address : room.address,
      city: city.isNotEmpty ? city : room.city,
      district: district.isNotEmpty ? district : room.district,
      images: images.isNotEmpty ? images : room.images,
      amenities: amenities.isNotEmpty ? amenities : room.amenities,
    );
  }

  /// Nối dữ liệu từ UserProfile của chủ trọ (bộ nhớ tạm, không ghi vào posts document)
  HostPostModel withHost(UserProfile host) {
    return copyWith(
      joinedHost: host,
      authorName: authorName.isNotEmpty ? authorName : host.displayName,
      authorAvatar: authorAvatar.isNotEmpty ? authorAvatar : host.avatarUrl,
      contactPhone: contactPhone.isNotEmpty ? contactPhone : host.phoneNumber,
      isVerified: host.isCccdVerified || isVerified,
      isVip: host.reputationScore >= 80 || host.isCccdVerified || isVip,
    );
  }

  /// Nối dữ liệu địa điểm (bộ nhớ tạm)
  HostPostModel withLocation({String? resolvedCity, String? resolvedDistrict}) {
    return copyWith(
      city: resolvedCity?.isNotEmpty == true ? resolvedCity : city,
      district:
          resolvedDistrict?.isNotEmpty == true ? resolvedDistrict : district,
    );
  }
}
