import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'image_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/roommate_post_model.dart';
import '../constants/vietnam_locations.dart';
import 'chat_service.dart';

class RoommateFilterParams {
  final String province;
  final String district;
  final String ward;
  final String targetGender;
  final bool? hasRoom; // null: Tất cả, true: Đã có phòng sẵn, false: Chưa có phòng
  final String occupation; // 'Tất cả', hoặc một nghề khi chỉ chọn một mục
  final List<String> occupations;
  final double? budgetMin;
  final double? budgetMax;
  final List<String> habits;
  final int minMatchRate;
  final String searchQuery;

  const RoommateFilterParams({
    this.province = 'Tất cả',
    this.district = 'Tất cả',
    this.ward = 'Tất cả',
    this.targetGender = 'Tất cả',
    this.hasRoom,
    this.occupation = 'Tất cả',
    this.occupations = const [],
    this.budgetMin,
    this.budgetMax,
    this.habits = const [],
    this.minMatchRate = 0,
    this.searchQuery = '',
  });

  RoommateFilterParams copyWith({
    String? province,
    String? district,
    String? ward,
    String? targetGender,
    bool? hasRoom,
    bool clearHasRoom = false,
    String? occupation,
    List<String>? occupations,
    double? budgetMin,
    double? budgetMax,
    bool clearBudget = false,
    List<String>? habits,
    int? minMatchRate,
    String? searchQuery,
  }) {
    return RoommateFilterParams(
      province: province ?? this.province,
      district: district ?? this.district,
      ward: ward ?? this.ward,
      targetGender: targetGender ?? this.targetGender,
      hasRoom: clearHasRoom ? null : (hasRoom ?? this.hasRoom),
      occupation: occupation ?? this.occupation,
      occupations: occupations ?? this.occupations,
      budgetMin: clearBudget ? null : (budgetMin ?? this.budgetMin),
      budgetMax: clearBudget ? null : (budgetMax ?? this.budgetMax),
      habits: habits ?? this.habits,
      minMatchRate: minMatchRate ?? this.minMatchRate,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoommateFilterParams &&
          province == other.province &&
          district == other.district &&
          ward == other.ward &&
          targetGender == other.targetGender &&
          hasRoom == other.hasRoom &&
          occupation == other.occupation &&
          listEquals(occupations, other.occupations) &&
          budgetMin == other.budgetMin &&
          budgetMax == other.budgetMax &&
          listEquals(habits, other.habits) &&
          minMatchRate == other.minMatchRate &&
          searchQuery == other.searchQuery;

  @override
  int get hashCode => Object.hash(
        province,
        district,
        ward,
        targetGender,
        hasRoom,
        occupation,
        Object.hashAll(occupations),
        budgetMin,
        budgetMax,
        Object.hashAll(habits),
        minMatchRate,
        searchQuery,
      );
}

class _PlaceParts {
  final String street;
  final String ward;
  final String district;
  final String province;

  const _PlaceParts({
    required this.street,
    required this.ward,
    required this.district,
    required this.province,
  });
}

class RoommateService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // Danh sách bài đăng tạo mới trong bộ nhớ (đảm bảo luôn hiển thị ngay lập tức)
  static final List<RoommatePostModel> _localCreatedPosts = [];
  static final Map<String, RoommatePostModel> _linkCache = {};
  static bool _authorRepairStarted = false;
  static bool _sampleSeedStarted = false;

  // Stream bài đăng tìm ở ghép (an toàn bộ lọc, in-memory filter & sort)
  Stream<List<RoommatePostModel>> getRoommatePostsStream({
    String? district,
    String? targetGender,
    RoommateFilterParams? filters,
  }) {
    final effectiveProvince = filters?.province ?? 'Tất cả';
    final effectiveDistrict = filters?.district ?? district;
    final effectiveWard = filters?.ward ?? 'Tất cả';
    final effectiveTargetGender = filters?.targetGender ?? targetGender;
    final hasRoom = filters?.hasRoom;
    final occupation = filters?.occupation;
    final occupations = filters?.occupations ?? const <String>[];
    final budgetMin = filters?.budgetMin;
    final budgetMax = filters?.budgetMax;
    final habits = filters?.habits ?? const [];
    final minMatchRate = filters?.minMatchRate ?? 0;
    final searchQuery = filters?.searchQuery.trim().toLowerCase() ?? '';
    _scheduleAuthorIdRepair();
    _scheduleFirestoreSamples();

    return _firestore.collection('roommate_posts').snapshots().handleError((err) {
      debugPrint('Firestore stream error, fallback to local: $err');
      return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }).asyncMap((snapshot) async {
      List<RoommatePostModel> list;
      if (snapshot.docs.isNotEmpty) {
        list = snapshot.docs.map((doc) {
          try {
            return RoommatePostModel.fromFirestore(doc);
          } catch (e) {
            debugPrint('Error parsing roommate post ${doc.id}: $e');
            return null;
          }
        }).whereType<RoommatePostModel>().toList();
      } else {
        list = [];
      }

      // Hợp nhất bài đăng tạo trong phiên (Local) và Cloud Firestore (Local ưu tiên trên đầu)
      final merged = <RoommatePostModel>[];
      for (final p in _localCreatedPosts) {
        merged.add(p);
      }
      for (final p in list) {
        if (!merged.any((item) => item.id == p.id)) {
          merged.add(p);
        }
      }

      // Bài mẫu không còn gắn trong bộ nhớ. Bài trên Firestore, gồm bài của Vanthe, vẫn hiện.
      const obsoleteSampleIds = {'figma_post_1', 'figma_post_2', 'figma_post_3', 'figma_post_4'};
      merged.removeWhere((post) => obsoleteSampleIds.contains(post.id));

      final filtered = filterPosts(
        merged,
        RoommateFilterParams(
          province: effectiveProvince,
          district: (effectiveDistrict == null || effectiveDistrict.isEmpty) ? 'Tất cả' : effectiveDistrict,
          ward: effectiveWard,
          targetGender: (effectiveTargetGender == null || effectiveTargetGender.isEmpty) ? 'Tất cả' : effectiveTargetGender,
          hasRoom: hasRoom,
          occupation: (occupation == null || occupation.isEmpty) ? 'Tất cả' : occupation,
          occupations: occupations,
          budgetMin: budgetMin,
          budgetMax: budgetMax,
          habits: habits,
          minMatchRate: minMatchRate,
          searchQuery: searchQuery,
        ),
      );
      return _hydratePosts(filtered);
    });
  }

  /// Lọc bài ở ghép đúng các điều kiện trên màn tìm kiếm.
  List<RoommatePostModel> filterPosts(List<RoommatePostModel> posts, RoommateFilterParams filters) {
    final province = filters.province;
    final district = filters.district;
    final ward = filters.ward;
    final targetGender = filters.targetGender;
    final hasRoom = filters.hasRoom;
    final occupation = filters.occupation;
    final occupations = filters.occupations;
    final budgetMin = filters.budgetMin;
    final budgetMax = filters.budgetMax;
    final habits = filters.habits;
    final minMatchRate = filters.minMatchRate;
    final searchQuery = filters.searchQuery.trim().toLowerCase();

    final filtered = posts.where((post) {
      if (hasRoom != null && post.hasRoom != hasRoom) return false;

      if (searchQuery.isNotEmpty) {
        final matched = post.title.toLowerCase().contains(searchQuery) ||
            post.address.toLowerCase().contains(searchQuery) ||
            post.district.toLowerCase().contains(searchQuery) ||
            post.authorName.toLowerCase().contains(searchQuery) ||
            post.authorOccupation.toLowerCase().contains(searchQuery);
        if (!matched) return false;
      }

      if (province.isNotEmpty && province != 'Tất cả') {
        if (!_postMatchesProvince(post, province)) return false;
      }
      if (district.isNotEmpty && district != 'Tất cả') {
        if (!_placeHit(post.district, district) && !_placeHit(post.address, district)) return false;
      }
      if (ward.isNotEmpty && ward != 'Tất cả') {
        if (!_placeHit(post.address, ward) && !_placeHit(post.district, ward)) return false;
      }

      if (targetGender.isNotEmpty && targetGender != 'Tất cả') {
        if (targetGender == 'LGBT+') {
          final isLgbt = post.targetGender.toLowerCase().contains('lgbt') ||
              post.habits.any((habit) => habit.toLowerCase().contains('lgbt'));
          if (!isLgbt && post.targetGender != 'Tất cả') return false;
        } else {
          final target = post.targetGender.trim();
          final author = post.authorGender.trim();
          final seeksWanted = target == 'Tất cả' || target == 'tatCa' || target == targetGender.trim();
          final authorIsWanted = author == targetGender.trim();
          if (!seeksWanted && !authorIsWanted) return false;
        }
      }

      final selectedOccupations = <String>{
        ...occupations.where((item) => item.trim().isNotEmpty && item != 'Tất cả'),
        if (occupation.isNotEmpty && occupation != 'Tất cả') occupation,
      };
      if (selectedOccupations.isNotEmpty) {
        final authorJob = post.authorOccupation.toLowerCase();
        final matched = selectedOccupations.any((item) => authorJob.contains(item.toLowerCase()));
        if (!matched) return false;
      }

      if (budgetMin != null && budgetMax != null) {
        final price = post.pricePerPerson > 0 ? post.pricePerPerson : post.budgetMax;
        if (price < budgetMin || price > budgetMax) return false;
      }

      if (habits.isNotEmpty && !habits.every((item) => _habitHit(item, post.habits))) return false;
      if (minMatchRate > 0 && post.matchRate < minMatchRate) return false;
      return true;
    }).toList();

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  // Đăng bài tìm ở ghép mới: tin gọn, địa điểm, ảnh và sở thích nằm ở collection riêng.
  Future<RoommatePostModel> createPost(RoommatePostModel post) async {
    final newId = post.id.isNotEmpty ? post.id : 'rm_${DateTime.now().millisecondsSinceEpoch}';
    final diaDiemId = post.diaDiemId.isNotEmpty ? post.diaDiemId : 'loc_$newId';
    final savedPost = post.copyWith(
      id: newId,
      diaDiemId: diaDiemId,
      ngayHetHan: post.ngayHetHan ?? post.createdAt.add(const Duration(days: 30)),
    );
    _localCreatedPosts.removeWhere((p) => p.id == newId);
    _localCreatedPosts.insert(0, savedPost);

    try {
      final place = _splitAddress(savedPost.address, savedPost.district);
      final batch = _firestore.batch();
      batch.set(_firestore.collection('locations').doc(diaDiemId), {
        'placeId': diaDiemId,
        'postId': newId,
        'province': place.province,
        'district': place.district,
        'ward': place.ward,
        'address': place.street.isNotEmpty ? place.street : savedPost.address,
        if (savedPost.latitude != null) 'latitude': savedPost.latitude,
        if (savedPost.longitude != null) 'longitude': savedPost.longitude,
      });
      final imageStorage = ImageStorageService();
      final displayUrls = <String>[];
      for (var i = 0; i < savedPost.images.length; i++) {
        final source = savedPost.images[i];
        if (source.trim().isEmpty) continue;
        final storagePath = await imageStorage.uploadRoommateStorageImage(
          source: source,
          postId: newId,
          index: i,
        );
        displayUrls.add(await imageStorage.downloadUrlForStoragePath(storagePath));
        final imageId = 'image_${newId}_$i';
        batch.set(_firestore.collection('roommate_post_images').doc(imageId), {
          'imageId': imageId,
          'postId': newId,
          'storagePath': storagePath,
          'caption': i < savedPost.imageCaptions.length ? savedPost.imageCaptions[i] : '',
        });
      }
      if (displayUrls.isNotEmpty) {
        final shown = savedPost.copyWith(images: displayUrls);
        _localCreatedPosts.removeWhere((post) => post.id == newId);
        _localCreatedPosts.insert(0, shown);
      }
      for (final habit in savedPost.habits) {
        final habitName = habit.trim();
        if (habitName.isEmpty || savedPost.authorId.isEmpty) continue;
        final linkId = '${savedPost.authorId}_${habitName.toLowerCase()}';
        batch.set(
          _firestore.collection('user_hobbies').doc(linkId),
          {'userId': savedPost.authorId, 'hobbyId': habitName, 'postId': newId},
          SetOptions(merge: true),
        );
      }
      batch.set(_firestore.collection('roommate_posts').doc(newId), savedPost.toMap());
      await batch.commit();
    } catch (e) {
      debugPrint('Firestore save roommate post offline fallback: $e');
    }
    return savedPost;
  }

  Future<void> setRoommateFavorite({
    required String userId,
    required String postId,
    required bool saved,
  }) async {
    final newRef = _firestore.collection('favorites').doc('${userId}_roommatePost_$postId');
    final oldRef = _firestore.collection('yeu_thich').doc('${userId}_tinOGhep_$postId');
    if (!saved) {
      await newRef.delete();
      await oldRef.delete();
      return;
    }
    await oldRef.delete();
    await newRef.set({
      'userId': userId,
      'targetType': 'roommatePost',
      'targetId': postId,
    });
  }

  Future<List<String>> favoritePostIds(String userId) async {
    final ids = <String>{};
    final saved = await _firestore.collection('favorites').where('userId', isEqualTo: userId).get();
    for (final doc in saved.docs) {
      if (doc.data()['targetType'] != 'roommatePost') continue;
      final id = '${doc.data()['targetId'] ?? ''}';
      if (id.isNotEmpty) ids.add(id);
    }
    final older = await _firestore.collection('yeu_thich').where('nguoiDungId', isEqualTo: userId).get();
    for (final doc in older.docs) {
      if (doc.data()['loaiDoiTuong_id'] != 'tinOGhep') continue;
      final id = '${doc.data()['doiTuongId'] ?? ''}';
      if (id.isNotEmpty) ids.add(id);
    }
    return ids.toList();
  }

  /// Một thỏa thuận đi với đúng một yêu cầu nhận người ở ghép.
  Future<void> createRoommateAgreement({
    required String tinId,
    required String requesterId,
    required String ownerId,
    required String message,
  }) async {
    final chatId = ChatService.getChatId(requesterId, ownerId);
    final agreementId = 'tt_${tinId}_$requesterId';
    final requestId = 'yc_$agreementId';
    final now = Timestamp.now();
    final batch = _firestore.batch();
    batch.delete(_firestore.collection('thoa_thuan_o_ghep').doc(agreementId));
    batch.delete(_firestore.collection('yeu_cau_nhan_nguoi_o_ghep').doc(requestId));
    batch.set(
      _firestore.collection('roommate_agreements').doc(agreementId),
      {
        'agreementId': agreementId,
        'postId': tinId,
        'requesterId': requesterId,
        'chatId': chatId,
        'requestStatus': 'pending',
        'message': message,
        'createdAt': now,
      },
    );
    batch.set(
      _firestore.collection('roommate_join_requests').doc(requestId),
      {
        'requestId': requestId,
        'agreementId': agreementId,
        'hostId': ownerId,
        'attachmentId': '',
        'status': 'pending',
        'note': message,
        'createdAt': now,
      },
    );
    await batch.commit();
  }

  Future<List<RoommatePostModel>> _hydratePosts(List<RoommatePostModel> posts) async {
    final out = <RoommatePostModel>[];
    for (final post in posts) {
      if (!_needsLinkData(post)) {
        out.add(post);
        continue;
      }
      final cached = _linkCache[post.id];
      if (cached != null && cached.updatedAt == post.updatedAt) {
        out.add(cached);
        continue;
      }
      try {
        final filled = await _fillFromLinks(post);
        _linkCache[post.id] = filled;
        out.add(filled);
      } catch (e) {
        debugPrint('hydrate roommate ${post.id}: $e');
        out.add(post);
      }
    }
    return out;
  }

  bool _needsLinkData(RoommatePostModel post) {
    if (post.id.startsWith('demo_') || post.id.startsWith('figma_')) return false;
    return post.authorName.isEmpty || post.address.isEmpty || post.images.isEmpty || post.habits.isEmpty;
  }

  Future<RoommatePostModel> _fillFromLinks(RoommatePostModel post) async {
    var name = post.authorName;
    var age = post.authorAge;
    var gender = post.authorGender;
    var job = post.authorOccupation;
    var avatar = post.authorAvatar;
    var phone = post.contactPhone;
    var verified = post.isVerified;
    var habits = post.habits;
    var images = post.images;
    var captions = post.imageCaptions;
    var address = post.address;
    var district = post.district;
    var latitude = post.latitude;
    var longitude = post.longitude;

    Map<String, dynamic> user = const {};
    if (post.authorId.isNotEmpty && name.isEmpty) {
      final userDoc = await _firestore.collection('users').doc(post.authorId).get();
      user = userDoc.data() ?? const {};
      name = '${user['displayName'] ?? user['hoTen'] ?? 'Thành viên HomeShare'}';
      phone = '${user['phone'] ?? user['phoneNumber'] ?? user['soDienThoai'] ?? phone}';
      job = '${user['occupation'] ?? user['ngheNghiep'] ?? job}';
      gender = '${user['gender'] ?? user['gioiTinh'] ?? gender}';
      avatar = '${user['avatarUrl'] ?? user['avatar'] ?? user['anhDaiDien'] ?? avatar}';
      verified = user['isCccdVerified'] == true || user['cccdVerified'] == true || verified;
      final birth = user['birthDate'] ?? user['ngaySinh'];
      if (birth is Timestamp) {
        age = DateTime.now().year - birth.toDate().year;
      }
    }

    if (address.isEmpty && post.diaDiemId.isNotEmpty) {
      var placeDoc = await _firestore.collection('locations').doc(post.diaDiemId).get();
      if (!placeDoc.exists) {
        placeDoc = await _firestore.collection('places').doc(post.diaDiemId).get();
      }
      if (!placeDoc.exists) {
        placeDoc = await _firestore.collection('dia_diem').doc(post.diaDiemId).get();
      }
      final place = placeDoc.data();
      if (place != null) {
        final street = '${place['address'] ?? ''}'.trim();
        final ward = '${place['ward'] ?? ''}'.trim();
        final placeDistrict = '${place['district'] ?? ''}'.trim();
        final province = '${place['province'] ?? ''}'.trim();
        address = [street, ward, placeDistrict, province].where((part) => part.isNotEmpty).join(', ');
        if (placeDistrict.isNotEmpty) district = placeDistrict;
        if (place['latitude'] is num) latitude = (place['latitude'] as num).toDouble();
        if (place['longitude'] is num) longitude = (place['longitude'] as num).toDouble();
      }
    }

    if (images.isEmpty) {
      var anhSnap = await _firestore.collection('roommate_post_images').where('postId', isEqualTo: post.id).get();
      if (anhSnap.docs.isEmpty) {
        anhSnap = await _firestore.collection('anh_tin_o_ghep').where('tinId', isEqualTo: post.id).get();
      }
      if (anhSnap.docs.isNotEmpty) {
        final imageStorage = ImageStorageService();
        final resolved = <String>[];
        for (final doc in anhSnap.docs) {
          final data = doc.data();
          final storagePath = '${data['storagePath'] ?? ''}';
          if (storagePath.isNotEmpty) {
            resolved.add(await imageStorage.downloadUrlForStoragePath(storagePath));
            continue;
          }
          final url = '${data['imageUrl'] ?? data['urlAnh'] ?? ''}';
          if (url.isNotEmpty) resolved.add(url);
        }
        images = resolved;
        captions = anhSnap.docs
            .map((doc) => '${doc.data()['caption'] ?? doc.data()['moTa'] ?? ''}')
            .where((text) => text.isNotEmpty)
            .toList();
      }
    }

    if (habits.isEmpty && post.authorId.isNotEmpty) {
      var habitSnap = await _firestore.collection('user_hobbies').where('userId', isEqualTo: post.authorId).get();
      if (habitSnap.docs.isEmpty) {
        habitSnap = await _firestore.collection('nguoi_dung_so_thich').where('nguoiDungId', isEqualTo: post.authorId).get();
      }
      habits = habitSnap.docs
          .map((doc) => '${doc.data()['hobbyId'] ?? doc.data()['soThichId'] ?? ''}')
          .where((item) => item.isNotEmpty)
          .toList();
      if (habits.isEmpty) {
        final raw = user['hobbies'] ?? user['soThich'];
        if (raw is List) {
          habits = raw.map((item) => '$item').where((item) => item.isNotEmpty).toList();
        }
      }
    }

    return post.copyWith(
      authorName: name,
      authorAge: age,
      authorGender: gender,
      authorOccupation: job,
      authorAvatar: avatar,
      contactPhone: phone,
      isVerified: verified,
      habits: habits,
      images: images,
      imageCaptions: captions,
      address: address,
      district: district,
      latitude: latitude,
      longitude: longitude,
    );
  }

  _PlaceParts _splitAddress(String fullAddress, String selectedDistrict) {
    final parts = fullAddress.split(',').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    if (parts.length >= 4) {
      return _PlaceParts(
        street: parts.sublist(0, parts.length - 3).join(', '),
        ward: parts[parts.length - 3],
        district: selectedDistrict.isNotEmpty ? selectedDistrict : parts[parts.length - 2],
        province: parts.last,
      );
    }
    return _PlaceParts(
      street: fullAddress,
      ward: '',
      district: selectedDistrict,
      province: '',
    );
  }

  /// Sửa authorId giả trên tin ở ghép. Chỉ gán khi tên người đăng trùng đúng một document users.
  void _scheduleAuthorIdRepair() {
    if (_authorRepairStarted) return;
    _authorRepairStarted = true;
    repairRoommateAuthorIds();
  }

  Future<void> repairRoommateAuthorIds() async {
    try {
      final usersSnap = await _firestore.collection('users').get();
      final userIds = <String>{};
      final nameToIds = <String, Set<String>>{};
      for (final doc in usersSnap.docs) {
        userIds.add(doc.id);
        final data = doc.data();
        for (final key in ['displayName', 'hoTen', 'hoten']) {
          final name = _normName('${data[key] ?? ''}');
          if (name.isEmpty) continue;
          nameToIds.putIfAbsent(name, () => <String>{}).add(doc.id);
        }
      }

      final postsSnap = await _firestore.collection('roommate_posts').get();
      for (final doc in postsSnap.docs) {
        final data = doc.data();
        final authorId = '${data['authorId'] ?? data['nguoiDangId'] ?? ''}'.trim();
        if (authorId.isNotEmpty && userIds.contains(authorId)) continue;
        final name = _normName('${data['authorName'] ?? data['hoTen'] ?? data['tenNguoiDang'] ?? ''}');
        final matches = nameToIds[name];
        if (matches == null || matches.length != 1) continue;
        final uid = matches.first;
        await doc.reference.update({'authorId': uid});
      }
    } catch (e) {
      debugPrint('repair roommate authorId: $e');
    }
  }

  String _normName(String raw) => raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Khớp thói quen khi bài ghi cách viết khác bộ lọc, ví dụ "Sạch sẽ ngăn nắp" với "Sạch sẽ, ngăn nắp cao".
  bool _habitHit(String selected, List<String> postHabits) {
    final needle = _habitKey(selected);
    if (needle.isEmpty) return true;
    for (final raw in postHabits) {
      final hay = _habitKey(raw);
      if (hay.isEmpty) continue;
      if (hay == needle || hay.contains(needle) || needle.contains(hay)) return true;
      if (_sameHabitFamily(needle, hay)) return true;
    }
    return false;
  }

  String _habitKey(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[,./()]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _sameHabitFamily(String a, String b) {
    const groups = <List<String>>[
      ['thuốc', 'hút thuốc'],
      ['sạch sẽ', 'ngăn nắp'],
      ['yên tĩnh'],
      ['giờ giấc tự do'],
    ];
    for (final group in groups) {
      if (group.any(a.contains) && group.any(b.contains)) return true;
    }
    return false;
  }

  /// Vài bài cố định để thử tìm kiếm. Hai bài ở TP.HCM mỗi phía, một bài tỉnh khác để không ra hết.
  static List<RoommatePostModel> getDemoRoommatePosts() {
    final now = DateTime.now();
    return [
      RoommatePostModel(
        id: 'oghep_has_lan',
        authorId: 'demo_lan_anh',
        authorName: 'Lan Anh',
        authorAge: 21,
        authorGender: 'Nữ',
        authorOccupation: 'Sinh viên',
        title: 'Cần một bạn nữ ghép căn hộ Linh Trung',
        description: 'Đã thuê căn 2 phòng ngủ ở Linh Trung, còn một chỗ. Mình học buổi sáng, về sớm.',
        postType: 'timNguoiOGhep',
        pricePerPerson: 1800000,
        budgetMin: 1500000,
        budgetMax: 2000000,
        address: 'Số 20 Đường Số 1, Phường Linh Trung, Thành phố Thủ Đức, TP. Hồ Chí Minh',
        latitude: 10.8696,
        longitude: 106.7782,
        district: 'Thành phố Thủ Đức',
        targetGender: 'Nữ',
        habits: ['Sạch sẽ, ngăn nắp cao', 'Yên tĩnh sau 23h'],
        hasRoom: true,
        contactPhone: '0901000001',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      RoommatePostModel(
        id: 'oghep_has_khoa',
        authorId: 'demo_minh_khoa',
        authorName: 'Minh Khoa',
        authorAge: 24,
        authorGender: 'Nam',
        authorOccupation: 'Người đi làm',
        title: 'Ghép phòng Bình Thạnh, đã có nhà',
        description: 'Phòng đã thuê gần chợ Bà Chiểu, tìm một bạn nam đi làm giờ hành chính.',
        postType: 'timNguoiOGhep',
        pricePerPerson: 2800000,
        budgetMin: 2500000,
        budgetMax: 3000000,
        address: '88 Đường D2, Phường 25, Quận Bình Thạnh, TP. Hồ Chí Minh',
        latitude: 10.8036,
        longitude: 106.7302,
        district: 'Quận Bình Thạnh',
        targetGender: 'Nam',
        habits: ['Giờ giấc tự do', 'Có xe máy riêng'],
        hasRoom: true,
        contactPhone: '0901000002',
        createdAt: now.subtract(const Duration(hours: 8)),
      ),
      RoommatePostModel(
        id: 'oghep_has_hamy',
        authorId: 'demo_ha_my',
        authorName: 'Hà My',
        authorAge: 22,
        authorGender: 'Nữ',
        authorOccupation: 'Sinh viên',
        title: 'Tìm bạn nữ ghép phòng Cầu Giấy',
        description: 'Phòng ở Cầu Giấy đã có, chỉ nhận bạn nữ.',
        postType: 'timNguoiOGhep',
        pricePerPerson: 2500000,
        budgetMin: 2000000,
        budgetMax: 3000000,
        address: '18 Trần Thái Tông, Phường Dịch Vọng, Cầu Giấy, Hà Nội',
        latitude: 21.0360,
        longitude: 105.7895,
        district: 'Cầu Giấy',
        targetGender: 'Nữ',
        habits: ['Chăm học/Làm việc'],
        hasRoom: true,
        contactPhone: '0901000003',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      RoommatePostModel(
        id: 'oghep_need_phuong',
        authorId: 'demo_phuong_anh',
        authorName: 'Phương Anh',
        authorAge: 20,
        authorGender: 'Nữ',
        authorOccupation: 'Sinh viên',
        title: 'Tìm bạn nữ cùng thuê phòng Quận 7',
        description: 'Mình chưa có phòng, muốn kiếm một bạn nữ cùng xem phòng quanh Quận 7.',
        postType: 'dangTimPhong',
        pricePerPerson: 1600000,
        budgetMin: 1400000,
        budgetMax: 1800000,
        address: '88 Nguyễn Thị Thập, Phường Tân Phong, Quận 7, TP. Hồ Chí Minh',
        latitude: 10.7312,
        longitude: 106.7204,
        district: 'Quận 7',
        targetGender: 'Nữ',
        habits: ['Nấu ăn thường xuyên', 'Sạch sẽ, ngăn nắp cao'],
        hasRoom: false,
        contactPhone: '0901000004',
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      RoommatePostModel(
        id: 'oghep_need_duc',
        authorId: 'demo_duc_anh',
        authorName: 'Đức Anh',
        authorAge: 25,
        authorGender: 'Nam',
        authorOccupation: 'Freelancer',
        title: 'Cần bạn nam cùng tìm phòng Gò Vấp',
        description: 'Làm việc ở nhà, chưa thuê phòng, muốn tìm một bạn nam cùng gu ở Gò Vấp.',
        postType: 'dangTimPhong',
        pricePerPerson: 2600000,
        budgetMin: 2400000,
        budgetMax: 2800000,
        address: '102 Quang Trung, Phường 16, Quận Gò Vấp, TP. Hồ Chí Minh',
        latitude: 10.8380,
        longitude: 106.6648,
        district: 'Quận Gò Vấp',
        targetGender: 'Nam',
        habits: ['Tuyệt đối không thuốc lá'],
        hasRoom: false,
        contactPhone: '0901000005',
        createdAt: now.subtract(const Duration(hours: 10)),
      ),
      RoommatePostModel(
        id: 'oghep_need_viet',
        authorId: 'demo_quoc_viet',
        authorName: 'Quốc Việt',
        authorAge: 23,
        authorGender: 'Nam',
        authorOccupation: 'Người đi làm',
        title: 'Tìm bạn cùng thuê phòng Hải Châu',
        description: 'Mình ở Đà Nẵng, chưa có phòng, tìm một bạn nam cùng thuê.',
        postType: 'dangTimPhong',
        pricePerPerson: 1500000,
        budgetMin: 1200000,
        budgetMax: 1800000,
        address: '36 Bạch Đằng, Phường Hải Châu, Hải Châu, Đà Nẵng',
        latitude: 16.0715,
        longitude: 108.2238,
        district: 'Hải Châu',
        targetGender: 'Nam',
        habits: ['Giờ giấc tự do'],
        hasRoom: false,
        contactPhone: '0901000006',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  void _scheduleFirestoreSamples() {
    if (_sampleSeedStarted) return;
    _sampleSeedStarted = true;
    publishSampleRoommatePosts();
  }

  /// Xóa bài gắn cứng cũ trên Firestore, trừ bài của Vanthe, rồi ghi 3 bài mỗi tab.
  Future<void> publishSampleRoommatePosts() async {
    const imageUrls = [
      'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1493809842364-78817add7ffb?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1505693416388-ac5ce068fe85?auto=format&fit=crop&w=800&q=80',
      'https://images.unsplash.com/photo-1484154218962-a197022b5858?auto=format&fit=crop&w=800&q=80',
    ];
    final samples = getDemoRoommatePosts();
    final keepIds = samples.map((post) => post.id).toSet();
    const retiredIds = [
      'demo_has_room_lan',
      'demo_has_room_khoa',
      'demo_has_room_hamy',
      'demo_need_room_phuong',
      'demo_need_room_duc',
      'demo_need_room_viet',
      'figma_post_1',
      'figma_post_2',
      'figma_post_3',
      'figma_post_4',
    ];
    try {
      _localCreatedPosts.removeWhere((post) => retiredIds.contains(post.id) || post.id.startsWith('demo_') || post.id.startsWith('figma_'));
      for (final id in retiredIds) {
        await _deletePostLinks(id, 'dd_$id');
        await _firestore.collection('roommate_posts').doc(id).delete();
      }
      final snap = await _firestore.collection('roommate_posts').get();
      for (final doc in snap.docs) {
        if (keepIds.contains(doc.id)) continue;
        final data = doc.data();
        if (_belongsToVanthe(doc.id, data)) continue;
        if (!_isOldHardcode(doc.id, data)) continue;
        await _deletePostLinks(doc.id, '${data['placeId'] ?? data['diaDiemId'] ?? ''}');
        await doc.reference.delete();
      }

      for (var i = 0; i < samples.length; i++) {
        final post = samples[i].copyWith(
          images: [imageUrls[i]],
          imageCaptions: const ['Ảnh phòng mẫu'],
        );
        await _firestore.collection('users').doc(post.authorId).set({
          'displayName': post.authorName,
          'phone': post.contactPhone,
          'occupation': post.authorOccupation,
          'gender': post.authorGender,
          'birthDate': Timestamp.fromDate(DateTime(DateTime.now().year - post.authorAge, 1, 1)),
          'role': 'renter',
        });
        await _deletePostLinks(post.id, 'loc_${post.id}');
        final oldHobbies = await _firestore.collection('nguoi_dung_so_thich').where('nguoiDungId', isEqualTo: post.authorId).get();
        for (final doc in oldHobbies.docs) {
          await doc.reference.delete();
        }
        await createPost(post);
      }
    } catch (e) {
      debugPrint('Ghi bài mẫu ở ghép lên Firestore: $e');
    }
  }

  Future<void> seedInitialRoommatesIfEmpty() => publishSampleRoommatePosts();

  Future<void> _deletePostLinks(String postId, String placeId) async {
    Future<void> deleteMatched(String collection, String field) async {
      final snap = await _firestore.collection(collection).where(field, isEqualTo: postId).get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    }

    await deleteMatched('roommate_post_images', 'postId');
    await deleteMatched('anh_tin_o_ghep', 'tinId');
    final placeIds = <String>{
      if (placeId.isNotEmpty) placeId,
      'loc_$postId',
      'dd_$postId',
    };
    for (final id in placeIds) {
      await _firestore.collection('locations').doc(id).delete();
      await _firestore.collection('places').doc(id).delete();
      await _firestore.collection('dia_diem').doc(id).delete();
    }
  }

  bool _belongsToVanthe(String id, Map<String, dynamic> data) {
    final blob = [
      id,
      data['authorId'],
      data['nguoiDangId'],
      data['authorName'],
      data['hoTen'],
      data['tenNguoiDang'],
      data['email'],
      data['displayName'],
    ].join(' ').toLowerCase();
    return blob.contains('vanthe') || blob.contains('van the') || blob.contains('văn thế');
  }

  bool _isOldHardcode(String id, Map<String, dynamic> data) {
    if (id.startsWith('demo_') || id.startsWith('figma_') || id.startsWith('sample_') || id.startsWith('mau_')) {
      return true;
    }
    final author = '${data['authorId'] ?? data['nguoiDangId'] ?? ''}';
    return author.startsWith('demo_') || author.startsWith('figma_');
  }
}

final roommateServiceProvider = Provider<RoommateService>((ref) => RoommateService());

/// Bài đăng thuộc tỉnh đã chọn khi địa chỉ hoặc quận trùng tỉnh, hoặc trùng một quận của tỉnh đó.
bool _postMatchesProvince(RoommatePostModel post, String province) {
  if (_placeHit(post.address, province) || _placeHit(post.district, province)) return true;
  for (final district in VietnamLocations.getAdministrativeDistricts(province)) {
    if (_placeHit(post.district, district) || _placeHit(post.address, district)) return true;
  }
  return false;
}

/// Khớp tên địa danh, kể cả khi một bên có tiền tố Quận/Phường. "Quận 1" không ăn "Quận 10".
bool _placeHit(String haystack, String needle) {
  final h = haystack.toLowerCase();
  final n = needle.toLowerCase().trim();
  if (n.length < 2 || h.isEmpty) return false;
  if (_boundedContains(h, n)) return true;
  final core = n
      .replaceAll('quận ', '')
      .replaceAll('huyện ', '')
      .replaceAll('thị xã ', '')
      .replaceAll('thành phố ', '')
      .replaceAll('tp. ', '')
      .replaceAll('phường ', '')
      .replaceAll('xã ', '')
      .trim();
  if (core.length < 2 || core == n) return false;
  return _boundedContains(h, core);
}

bool _boundedContains(String haystack, String needle) {
  var start = 0;
  while (true) {
    final index = haystack.indexOf(needle, start);
    if (index < 0) return false;
    final end = index + needle.length;
    final prevOk = index == 0 || !_isDigit(haystack[index - 1]);
    final nextOk = end >= haystack.length || !_isDigit(haystack[end]);
    if (prevOk && nextOk) return true;
    start = index + 1;
  }
}

bool _isDigit(String char) {
  final code = char.codeUnitAt(0);
  return code >= 48 && code <= 57;
}

class RoommatePostsRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

final roommatePostsRefreshTrigger = NotifierProvider<RoommatePostsRefreshNotifier, int>(RoommatePostsRefreshNotifier.new);

final roommatePostsStreamProvider = StreamProvider.autoDispose.family<List<RoommatePostModel>, RoommateFilterParams>((ref, filters) {
  ref.watch(roommatePostsRefreshTrigger);
  final service = ref.watch(roommateServiceProvider);
  return service.getRoommatePostsStream(
    filters: filters,
  );
});
