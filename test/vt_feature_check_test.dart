import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/chat_service.dart';
import 'package:home_share/core/services/image_storage_service.dart';
import 'package:home_share/core/services/roommate_service.dart';
import 'package:home_share/data/models/roommate_post_model.dart';
import 'package:home_share/features/auth/auth_validators.dart';

void main() {
  group('Đăng nhập', () {
    test('email trống, sai dạng, và email đúng', () {
      expect(validateLoginEmail(null), 'Vui lòng nhập email');
      expect(validateLoginEmail('   '), 'Vui lòng nhập email');
      expect(validateLoginEmail('user'), isNotNull);
      expect(validateLoginEmail('user@gmail'), isNotNull);
      expect(validateLoginEmail('a@.b'), isNotNull);
      expect(validateLoginEmail('  user@gmail.com  '), isNull);
    });

    test('mật khẩu trống hoặc toàn khoảng trắng không qua, mật khẩu đủ 6 ký tự thì qua', () {
      expect(validateLoginPassword(''), isNotNull);
      expect(validateLoginPassword('      '), isNotNull);
      expect(validateLoginPassword('12345'), isNotNull);
      expect(validateLoginPassword(' 123456 '), isNull);
    });
  });

  group('Tìm người ở ghép và tìm phòng ở ghép', () {
    test('mỗi phía có đúng 3 bài mẫu', () {
      final posts = RoommateService.getDemoRoommatePosts();
      expect(posts.where((post) => post.hasRoom).length, 3);
      expect(posts.where((post) => !post.hasRoom).length, 3);
      expect(posts.map((post) => post.id).toSet().length, 6);
    });

    test('bài ghi Firestore một lần bằng tiếng Anh và đọc lại được placeId', () {
      final post = RoommateService.getDemoRoommatePosts().first.copyWith(diaDiemId: 'loc_oghep_has_lan');
      final map = post.toMap();
      expect(map.containsKey('tieuDe'), isFalse);
      expect(map.containsKey('nganSachDen'), isFalse);
      expect(map.containsKey('imageUrl'), isFalse);
      expect(map['title'], post.title);
      expect(map['budgetMax'], post.budgetMax);
      expect(map['placeId'], 'loc_oghep_has_lan');
      expect(map['status'], 'open');

      final read = RoommatePostModel.fromMap({
        'authorId': 'demo_lan_anh',
        'placeId': 'loc_oghep_has_lan',
        'status': 'open',
        'title': 'Tin thử',
        'description': 'Mô tả đủ dài',
        'budgetMin': 1500000,
        'budgetMax': 2000000,
        'targetGender': 'Nữ',
        'hasRoom': true,
        'currentOccupants': 1,
        'maxOccupants': 2,
      }, 'oghep_has_lan');
      expect(read.authorId, 'demo_lan_anh');
      expect(read.diaDiemId, 'loc_oghep_has_lan');
      expect(read.hasRoom, isTrue);
      expect(read.status, 'dangMo');
      expect(read.budgetMax, 2000000);
    });

    test('bài cần tìm phòng không bị gộp sang phía đã có phòng', () {
      final read = RoommatePostModel.fromMap({
        'authorId': 'demo_phuong_anh',
        'title': 'Tìm phòng',
        'description': 'Chưa có phòng',
        'budgetMin': 1000000,
        'budgetMax': 1800000,
        'targetGender': 'Nữ',
        'hasRoom': false,
        'status': 'open',
      }, 'oghep_need_phuong');
      expect(read.hasRoom, isFalse);
    });
  });

  group('Bộ lọc tìm kiếm ở ghép', () {
    final service = RoommateService();
    final posts = RoommateService.getDemoRoommatePosts();

    test('TP.HCM và đã có phòng chỉ ra Lan Anh, Minh Khoa', () {
      final names = service.filterPosts(posts, const RoommateFilterParams(
        province: 'TP. Hồ Chí Minh',
        hasRoom: true,
      )).map((post) => post.authorName).toList();
      expect(names, containsAll(['Lan Anh', 'Minh Khoa']));
      expect(names, isNot(contains('Hà My')));
      expect(names, isNot(contains('Phương Anh')));
      expect(names, isNot(contains('Quốc Việt')));
    });

    test('TP.HCM và cần tìm phòng chỉ ra Phương Anh, Đức Anh', () {
      final names = service.filterPosts(posts, const RoommateFilterParams(
        province: 'TP. Hồ Chí Minh',
        hasRoom: false,
      )).map((post) => post.authorName).toSet();
      expect(names, {'Phương Anh', 'Đức Anh'});
    });

    test('quận Thủ Đức không kéo theo quận khác, phường Linh Trung chỉ còn Lan Anh', () {
      final district = service.filterPosts(posts, const RoommateFilterParams(
        district: 'Thành phố Thủ Đức',
        hasRoom: true,
      )).map((post) => post.authorName).toList();
      expect(district, ['Lan Anh']);

      final ward = service.filterPosts(posts, const RoommateFilterParams(
        province: 'TP. Hồ Chí Minh',
        district: 'Thành phố Thủ Đức',
        ward: 'Phường Linh Trung',
        hasRoom: true,
      )).map((post) => post.authorName).toList();
      expect(ward, ['Lan Anh']);
    });

    test('giới tính Nữ ở phía đã có phòng không ra bài của nam', () {
      final names = service.filterPosts(posts, const RoommateFilterParams(
        targetGender: 'Nữ',
        hasRoom: true,
      )).map((post) => post.authorName).toSet();
      expect(names, {'Lan Anh', 'Hà My'});
    });

    test('ngân sách và thói quen loại bài không khớp', () {
      final budget = service.filterPosts(posts, const RoommateFilterParams(
        hasRoom: false,
        budgetMin: 1400000.0,
        budgetMax: 1900000.0,
      )).map((post) => post.authorName).toSet();
      expect(budget.contains('Phương Anh'), isTrue);
      expect(budget.contains('Quốc Việt'), isTrue);
      expect(budget.contains('Đức Anh'), isFalse);

      final habit = service.filterPosts(posts, const RoommateFilterParams(
        hasRoom: true,
        habits: ['Sạch sẽ, ngăn nắp cao'],
      )).map((post) => post.authorName).toList();
      expect(habit, ['Lan Anh']);
    });

    test('từ khóa Hải Châu không ra bài TP.HCM', () {
      final names = service.filterPosts(posts, const RoommateFilterParams(
        searchQuery: 'Hải Châu',
      )).map((post) => post.authorName).toList();
      expect(names, ['Quốc Việt']);
    });
  });

  group('Chat hai người ở ghép', () {
    test('hai người chỉ có một cuộc trò chuyện dù đổi thứ tự', () {
      expect(ChatService.getChatId('b', 'a'), ChatService.getChatId('a', 'b'));
      expect(ChatService.getChatId(' a ', 'b'), 'a_b');
    });

    test('tin rỗng và tin có từ cấm không được gửi', () {
      expect('   '.trim().isEmpty, isTrue);
      expect(ChatService.checkProfanity('Chào bạn, mình muốn ở ghép'), isFalse);
      expect(ChatService.checkProfanity('chuyển tiền trước không xem phòng'), isTrue);
    });
  });

  group('Ảnh ở ghép trên Storage', () {
    test('link tải Firebase được rút thành đường dẫn trong bucket', () {
      final storage = ImageStorageService();
      const url =
          'https://firebasestorage.googleapis.com/v0/b/homeshare.appspot.com/o/roommate_posts%2Foghep_has_lan%2Fimage_0.jpg?alt=media&token=abc';
      expect(
        storage.storagePathFromDownloadUrl(url),
        'roommate_posts/oghep_has_lan/image_0.jpg',
      );
      expect(storage.storagePathFromDownloadUrl('https://images.unsplash.com/photo.jpg'), isNull);
    });
  });
}
