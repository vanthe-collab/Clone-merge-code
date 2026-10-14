import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/roommate_service.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/roommate_post_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';

/// Một dòng thói quen. `detail` để trống khi chữ lấy thẳng từ bài đăng.
class _HabitItem {
  final IconData icon;
  final String tag;
  final String detail;

  const _HabitItem(this.icon, this.tag, this.detail);
}

/// Màn chi tiết phòng ở ghép, mở từ thẻ tin ở Tìm ở ghép.
/// Phòng của chủ nhà không dùng màn này.
///
/// Dữ liệu thật lấy từ [RoommatePostModel]: người đăng, tiêu đề, mô tả,
/// địa chỉ, giá, ảnh, thói quen, giới tính cần tìm, thời điểm đăng, bản đồ.
/// Phần chưa có field (diện tích, phí điện nước, chip hòa hợp)
/// đang gắn tạm và được ghi trong `tiendo.md`.
class RoommateRoomDetailScreen extends ConsumerStatefulWidget {
  final RoommatePostModel post;

  const RoommateRoomDetailScreen({super.key, required this.post});

  @override
  ConsumerState<RoommateRoomDetailScreen> createState() => _RoommateRoomDetailScreenState();
}

class _RoommateRoomDetailScreenState extends ConsumerState<RoommateRoomDetailScreen> {
  /// Lời nhắn mẫu, chỉ hiện khi bài không có mô tả.
  static const String _fallbackNote =
      'Chào mọi người nha! Mình là Trang, hiện đang là sinh viên năm 3 chuyên ngành Kinh tế Đối ngoại tại FTU CS2. Tính mình vui vẻ, hòa đồng, gọn gàng và rất tôn trọng sự riêng tư của bạn cùng phòng. Ngày thường mình hay đi học và làm thêm, tối về thích tự nấu ăn nhẹ rồi ôn bài. Mình luôn tìm một bạn nữ hiền lành, trung thực, giữ vệ sinh chung để cùng san sẻ tiền nhà và nấu nướng. Phòng đã sẵn đồ dùng, bạn chỉ cần dọn vali vào ở thôi ạ.';

  /// Sáu hashtag mẫu khi bài chưa ghi `habits`.
  static const List<_HabitItem> _fallbackHabits = [
    _HabitItem(Icons.menu_book_rounded, '#DocSach', 'Đọc sách, phát triển bản thân'),
    _HabitItem(Icons.self_improvement_rounded, '#Yoga', 'Tập yoga, thiền mỗi sáng'),
    _HabitItem(Icons.restaurant_rounded, '#NauAnHealthy', 'Tự nấu ăn Eat-Clean'),
    _HabitItem(Icons.headphones_rounded, '#Acoustic', 'Nghe nhạc nhẹ qua tai nghe'),
    _HabitItem(Icons.yard_rounded, '#ThichCayXanh', 'Yêu thích trồng cây cảnh'),
    _HabitItem(Icons.nightlight_round, '#KhongOnAo', 'Không gian yên tĩnh sau 23h'),
  ];

  /// Tiện ích tòa nhà, chưa đọc bảng `Tiện ích`.
  static const List<(IconData, String)> _buildingPerks = [
    (Icons.pool_rounded, 'Hồ bơi tràn viền'),
    (Icons.park_rounded, 'Công viên ven sông'),
    (Icons.storefront_rounded, 'WinMart, 7-Eleven'),
    (Icons.videocam_rounded, 'Bảo vệ & Camera 24/7'),
    (Icons.local_parking_rounded, 'Hầm đỗ xe thông minh'),
    (Icons.fitness_center_rounded, 'Phòng tập Gym & Yoga'),
  ];

  int _photoIndex = 0;
  late final PageController _pageController;

  RoommatePostModel get _post => widget.post;

  String get _posterName {
    final name = _post.authorName.trim();
    return name.isEmpty ? 'Người đăng' : name;
  }

  String get _givenName {
    final parts = _posterName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.last.isEmpty) return 'bạn';
    return parts.last;
  }

  String get _ageLabel {
    final age = _post.authorAge;
    if (age > 0) return '$age tuổi';
    return '';
  }

  String get _occupation {
    final job = _post.authorOccupation.trim();
    return job.isEmpty ? 'Chưa cập nhật nghề nghiệp' : job;
  }

  /// Nhãn xác minh. Chữ "SV & CCCD" là tạm; cờ thật chỉ là `isVerified`.
  String get _verifiedLabel => _post.isVerified ? 'Đã xác minh SV & CCCD' : 'Chưa xác minh';

  String get _seekLabel {
    final raw = _post.targetGender.trim().toLowerCase();
    if (raw == 'nu' || raw == 'nữ' || raw == 'female') return 'Chỉ tìm nữ';
    if (raw == 'nam' || raw == 'male') return 'Chỉ tìm nam';
    if (raw.isEmpty || raw == 'tất cả' || raw == 'tatca' || raw == 'tat ca') return 'Tìm mọi giới tính';
    return 'Chỉ tìm $raw';
  }

  /// "Chính chủ duyệt" chưa có field, gắn cố định cho đúng thiết kế.
  String get _statusLabel => 'Đã có phòng sẵn • Chính chủ duyệt';

  int get _matchRate {
    final rate = _post.matchRate;
    if (rate < 0) return 0;
    if (rate > 100) return 100;
    return rate;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Ảnh của bài. Không có ảnh thì không chèn ảnh mẫu.
  List<String> get _photos {
    return _post.images.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  List<_HabitItem> get _habits {
    final fromPost = _post.habits;
    if (fromPost.isEmpty) return _fallbackHabits;
    return fromPost.map((habit) => _HabitItem(_habitIcon(habit), habit, '')).toList();
  }

  IconData _habitIcon(String habit) {
    final lower = habit.toLowerCase();
    if (lower.contains('thuốc') || lower.contains('ồn')) return Icons.smoke_free_rounded;
    if (lower.contains('yên') || lower.contains('ngủ')) return Icons.nightlight_round;
    if (lower.contains('sạch') || lower.contains('gọn')) return Icons.cleaning_services_rounded;
    if (lower.contains('nấu') || lower.contains('ăn')) return Icons.restaurant_rounded;
    if (lower.contains('học') || lower.contains('sách')) return Icons.menu_book_rounded;
    if (lower.contains('yoga') || lower.contains('thể')) return Icons.self_improvement_rounded;
    if (lower.contains('nhạc')) return Icons.headphones_rounded;
    if (lower.contains('cây') || lower.contains('pet') || lower.contains('thú')) return Icons.yard_rounded;
    return Icons.check_circle_outline;
  }

  String get _title {
    final title = _post.title.trim();
    return title.isEmpty ? 'Tin ở ghép chưa có tiêu đề' : title;
  }

  /// Địa chỉ hiện một lần, dưới tiêu đề. Không nối thêm quận nếu địa chỉ đã có.
  String get _address {
    final address = _post.address.trim();
    final district = _post.district.trim();
    if (address.isEmpty && district.isEmpty) return 'Chưa có địa chỉ';
    if (address.isEmpty) return district;
    if (district.isEmpty || address.toLowerCase().contains(district.toLowerCase())) return address;
    return '$address, $district';
  }

  double get _priceEach {
    if (_post.pricePerPerson > 0) return _post.pricePerPerson;
    if (_post.budgetMin > 0) return _post.budgetMin;
    return 0;
  }

  /// Bài ở ghép chưa có tiền cọc riêng, nên tạm lấy bằng giá một tháng.
  double get _deposit => _priceEach;

  /// Luôn false: số cọc không đọc từ Firestore.
  bool get _depositIsStored => false;

  /// Diện tích tổng chưa có trên tin ở ghép.
  String get _areaLabel => '56 m²';

  DateTime get _createdAt => _post.createdAt;

  String get _message {
    final fromPost = _post.description.trim();
    return fromPost.isEmpty ? _fallbackNote : fromPost;
  }

  /// Người nhận chat là người đăng tin, không phải chủ nhà của collection `rooms`.
  String get _peerId => _post.authorId;
  String get _peerAvatar => _post.authorAvatar;
  String get _peerPhone => _post.contactPhone;

  String get _groupLabel {
    if (_seekLabel == 'Chỉ tìm nam') return 'Chỉ 2 bạn\nnam';
    if (_seekLabel == 'Tìm mọi giới tính') return 'Ở ghép\nlinh hoạt';
    return 'Chỉ 2 bạn\nnữ';
  }

  String _money(num value) => '${NumberFormat('#,###', 'vi_VN').format(value.round())}đ';

  String _shortMoney(num value) {
    if (value >= 1000000) {
      final tr = value / 1000000;
      final text = tr == tr.roundToDouble() ? tr.toStringAsFixed(0) : tr.toStringAsFixed(1);
      return '${text}tr';
    }
    return _money(value);
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Vừa đăng';
    if (diff.inMinutes < 60) return 'Đăng ${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return 'Đăng ${diff.inHours} giờ trước';
    if (diff.inDays < 7) return 'Đăng ${diff.inDays} ngày trước';
    return 'Đăng ${DateFormat('dd/MM/yyyy').format(time)}';
  }

  /// Mở chat với người đăng tin. `isLandlord: false` để hội thoại theo kiểu ở ghép.
  void _openChat() {
    final currentUser = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để nhắn tin')),
      );
      return;
    }
    if (_peerId.isNotEmpty && currentUser.uid == _peerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đây là bài của chính bạn')),
      );
      return;
    }
    if (_peerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bài này chưa có người đăng để nhắn tin')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          receiverId: _peerId,
          receiverName: _posterName,
          receiverAvatar: _peerAvatar,
          receiverPhone: _peerPhone,
          isLandlord: false,
          currentUserId: currentUser.uid,
          currentUserName: profile?.displayName ?? currentUser.displayName ?? 'Khách thuê',
          pinnedRoom: null,
          roommatePostId: _post.id,
        ),
      ),
    );
  }

  /// Soạn lời ghép nối, ghi thỏa thuận và yêu cầu nhận người, rồi vào chat.
  void _openJoinRequest() {
    final controller = TextEditingController(
      text: 'Chào $_posterName, mình thấy phòng và lối sống của bạn hợp với mình. Mình muốn kết nối để ở ghép cùng nhé.',
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Yêu cầu ghép nối', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                'Lời nhắn được lưu vào thỏa thuận ở ghép và yêu cầu nhận người, rồi mở cuộc trò chuyện.',
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập lời nhắn trước khi gửi yêu cầu ghép')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    final user = ref.read(currentUserProvider);
                    final profile = ref.read(userProfileProvider).value;
                    if (user != null && _peerId.isNotEmpty && user.uid != _peerId) {
                      final senderName = profile?.displayName ?? user.displayName ?? 'Khách thuê';
                      try {
                        await ref.read(roommateServiceProvider).createRoommateAgreement(
                          tinId: _post.id,
                          requesterId: user.uid,
                          ownerId: _peerId,
                          message: text,
                        );
                        await ref.read(chatServiceProvider).sendMessage(
                          ChatMessageModel(
                            id: '',
                            senderId: user.uid,
                            senderName: senderName,
                            receiverId: _peerId,
                            text: text,
                            timestamp: DateTime.now(),
                            status: 'sent',
                          ),
                          receiverName: _posterName,
                          receiverAvatar: _peerAvatar,
                          receiverPhone: _peerPhone,
                          roomMetadata: {
                            'roommatePostId': _post.id,
                            'targetType': 'roommatePost',
                            'isLandlord': false,
                          },
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Chưa gửi được lời nhắn: $e')),
                          );
                        }
                      }
                    }
                    if (mounted) _openChat();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Gửi và mở trò chuyện', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final photos = _photos;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Chi Tiết Phòng Ở ghép',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryContainer,
              backgroundImage: _networkImage(profile?.avatarUrl ?? ''),
              child: _networkImage(profile?.avatarUrl ?? '') == null
                  ? const Icon(Icons.person, size: 18, color: AppColors.primary)
                  : null,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _photoCard(photos),
          const SizedBox(height: 14),
          _posterCard(),
          const SizedBox(height: 12),
          _matchCard(),
          const SizedBox(height: 12),
          // Chỉ còn thời điểm đăng. Địa chỉ nằm một lần, ngay dưới tiêu đề.
          Text(
            _timeAgo(_createdAt),
            style: const TextStyle(fontSize: 14.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Text(_title, style: const TextStyle(fontSize: 24, height: 1.25, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
              ),
              const SizedBox(width: 4),
              Expanded(child: Text(_address, style: const TextStyle(fontSize: 15.5, color: AppColors.textSecondary, height: 1.35))),
            ],
          ),
          const SizedBox(height: 14),
          _priceCard(),
          const SizedBox(height: 12),
          _billsCard(),
          const SizedBox(height: 12),
          _specRow(),
          const SizedBox(height: 22),
          const Text('Tiêu chí Thói quen & Sở thích', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Xem mức độ hòa hợp giữa bạn và người đăng', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          ..._habits.map(_habitTile),
          const SizedBox(height: 18),
          _quoteCard(),
          const SizedBox(height: 18),
          Text(
            'Tiện ích quanh ${_post.district.trim().isEmpty ? 'khu vực' : _post.district}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _perkGrid(),
          const SizedBox(height: 16),
          const Text('Vị trí toạ lạc:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _AddressMap(
            address: _address,
            latitude: _post.latitude,
            longitude: _post.longitude,
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  /// Ảnh lớn hiện trọn khung, nhãn trạng thái nằm dưới ảnh để không che hình.
  Widget _photoCard(List<String> photos) {
    if (photos.isEmpty) {
      return Container(
        height: 280,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFE4E7EC), borderRadius: BorderRadius.circular(18)),
        child: const Text('Bài này chưa có ảnh', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      );
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ColoredBox(
            color: const Color(0xFFE8EEF5),
            child: SizedBox(
              height: 320,
              width: double.infinity,
              child: PageView.builder(
                controller: _pageController,
                itemCount: photos.length,
                onPageChanged: (index) => setState(() => _photoIndex = index),
                itemBuilder: (_, index) => _photo(photos[index], fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _pill(_statusLabel, const Color(0xFFE8F8EF), const Color(0xFF067647)),
            _pill(_seekLabel, const Color(0xFFFFF1F3), const Color(0xFFE11D48), icon: Icons.female_rounded),
            _pill(_verifiedLabel, const Color(0xFF101828), Colors.white, icon: Icons.verified_rounded),
            _pill('${_photoIndex + 1}/${photos.length} ảnh thực tế', const Color(0xFF101828), Colors.white),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 58,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final selected = index == _photoIndex;
              return GestureDetector(
                onTap: () {
                  setState(() => _photoIndex = index);
                  _pageController.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
                },
                child: Container(
                  width: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 2),
                  ),
                  child: ClipRRect(borderRadius: BorderRadius.circular(8), child: _photo(photos[index])),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Thẻ người đăng: tên, tuổi, nghề và avatar lấy từ bài.
  Widget _posterCard() {
    return _infoCard(
      child: Row(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFE8F0FE),
              backgroundImage: _avatarProvider(_peerAvatar),
              child: _avatarProvider(_peerAvatar) == null
                  ? Text(
                      _posterName.isNotEmpty ? _posterName[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary),
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_posterName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(width: 6),
                  if (_ageLabel.isNotEmpty) Text(_ageLabel, style: const TextStyle(color: AppColors.textMuted, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.school_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(_occupation, style: const TextStyle(fontSize: 14.5, color: AppColors.textSecondary))),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.verified_rounded, size: 14, color: _post.isVerified ? AppColors.success : AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    _verifiedLabel,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: _post.isVerified ? AppColors.success : AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }

  /// Thẻ độ tương thích. Phần trăm lấy từ `matchRate`. Ba chip lối sống vẫn là chữ cố định.
  Widget _matchCard() {
    return _infoCard(
      color: const Color(0xFFF3F7FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Text('$_matchRate%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary)),
              SizedBox(width: 8),
              const Text('Tương\nthích', style: TextStyle(fontWeight: FontWeight.w700, height: 1.15)),
              const Spacer(),
              const Text('Dựa trên lối sống\n& thói quen', textAlign: TextAlign.right, style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _miniChip('Khung giờ ngủ: Trùng khớp'),
              _miniChip('Nấu ăn: 100% Phù hợp'),
              _miniChip('Sạch sẽ: Đồng thuận'),
            ],
          ),
        ],
      ),
    );
  }

  /// Khung thẻ trắng bo góc cho người đăng và độ tương thích.
  Widget _infoCard({required Widget child, Color color = Colors.white}) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }

  /// Giá mỗi người từ bài. Dòng cọc và ngày dọn vào chưa có field riêng.
  Widget _priceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TIỀN PHÒNG MỖI NGƯỜI', style: TextStyle(fontSize: 13, letterSpacing: 0.4, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              text: _money(_priceEach),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary),
              children: const [
                TextSpan(text: ' / người / tháng', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: AppColors.success),
              SizedBox(width: 6),
              Text('Đã gồm phí quản lý toà nhà', style: TextStyle(fontSize: 15, color: AppColors.success, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _priceMeta('Tiền cọc phòng', _money(_deposit), _depositIsStored ? 'đã lưu' : 'ước tính 1 tháng')),
              Expanded(child: _priceMeta('Thời gian dọn vào', '01/11/2024 hoặc', 'ngay', valueColor: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceMeta(String label, String value, String extra, {Color valueColor = AppColors.textDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: valueColor)),
        Text(extra, style: TextStyle(fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }

  /// Điện, wifi, gửi xe: số tạm, chưa có bảng phí.
  Widget _billsCard() {
    const rows = [
      ('Điện thoại & Điện sinh hoạt\n(giá nhà nước chia đều)', '~150k - 200k/người'),
      ('Wifi tốc độ cao & Phí rác chung cư', '60k/người'),
      ('Gửi xe máy (hầm toà nhà)', '80k/xe/tháng'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(child: Text('Khoản phí phát sinh chia đều (ước tính):', style: TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: AppColors.textMuted)),
                  Expanded(child: Text(row.$1, style: const TextStyle(fontSize: 15, height: 1.3))),
                  const SizedBox(width: 8),
                  Text(row.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Diện tích và quy mô đang gắn tạm. Giới trên quy mô theo giới tính bài tìm.
  Widget _specRow() {
    return Row(
      children: [
        _specCard(Icons.square_foot_rounded, 'Tổng diện tích', _areaLabel),
        const SizedBox(width: 8),
        _specCard(Icons.bed_rounded, 'Phòng bạn ở', '18 m²\n(Rộng)'),
        const SizedBox(width: 8),
        _specCard(Icons.groups_rounded, 'Quy mô', _groupLabel),
      ],
    );
  }

  Widget _specCard(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _habitTile(_HabitItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          CircleAvatar(radius: 18, backgroundColor: AppColors.primaryContainer, child: Icon(item.icon, size: 18, color: AppColors.primary)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.tag, style: const TextStyle(fontWeight: FontWeight.w800)),
                if (item.detail.isNotEmpty)
                  Text(item.detail, style: const TextStyle(fontSize: 14.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Icon(item.icon, size: 18, color: AppColors.textMuted),
        ],
      ),
    );
  }

  /// Mô tả bài đăng. Hết mô tả thì dùng lời nhắn mẫu.
  Widget _quoteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('“', style: TextStyle(fontSize: 28, height: 1, color: AppColors.primary, fontWeight: FontWeight.w800)),
              const SizedBox(width: 6),
              Expanded(child: Text('Lời nhắn từ $_posterName', style: const TextStyle(fontWeight: FontWeight.w800))),
            ],
          ),
          const SizedBox(height: 8),
          Text(_message, style: const TextStyle(fontSize: 16, height: 1.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  /// Lưới tiện ích cố định. Chỉ tên khu vực lấy từ bài.
  Widget _perkGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _buildingPerks.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.7,
      ),
      itemBuilder: (_, index) {
        final perk = _buildingPerks[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Icon(perk.$1, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(perk.$2, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
            ],
          ),
        );
      },
    );
  }

  /// Thanh dưới: yêu cầu ghép nối mở lời nhắn, nút còn lại mở chat.
  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chi phí ở ghép', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                Text.rich(
                  TextSpan(
                    text: _shortMoney(_priceEach),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    children: const [
                      TextSpan(text: '/tháng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _openJoinRequest,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Yêu cầu ghép nối', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _openChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Nhắn $_givenName ngay', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String text, Color background, Color foreground, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(text, style: TextStyle(color: foreground, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _miniChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _photo(String raw, {BoxFit fit = BoxFit.cover}) {
    final url = raw.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFE4E7EC), child: Icon(Icons.image_not_supported_outlined)),
      );
    }
    if (url.startsWith('data:image')) {
      try {
        final comma = url.indexOf(',');
        return Image.memory(base64Decode(comma == -1 ? url : url.substring(comma + 1)), fit: fit);
      } catch (_) {}
    }
    return const ColoredBox(color: Color(0xFFE4E7EC), child: Icon(Icons.photo_outlined));
  }

  ImageProvider? _avatarProvider(String raw) {
    final url = raw.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) return NetworkImage(url);
    if (url.startsWith('data:image')) {
      try {
        final comma = url.indexOf(',');
        return MemoryImage(base64Decode(comma == -1 ? url : url.substring(comma + 1)));
      } catch (_) {}
    }
    if (url.isNotEmpty) return FileImage(File(url));
    return null;
  }

  ImageProvider? _networkImage(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return NetworkImage(url);
    return null;
  }
}

/// Bản đồ cuối bài. Có tọa độ thì ghim ngay, không có thì dò theo địa chỉ.
class _AddressMap extends StatefulWidget {
  final String address;
  final double? latitude;
  final double? longitude;

  const _AddressMap({required this.address, this.latitude, this.longitude});

  @override
  State<_AddressMap> createState() => _AddressMapState();
}

class _AddressMapState extends State<_AddressMap> {
  LatLng? _point;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final lat = widget.latitude;
    final lng = widget.longitude;
    if (lat != null && lng != null) {
      _point = LatLng(lat, lng);
      return;
    }
    final query = widget.address.trim();
    if (query.isEmpty || query == 'Chưa có địa chỉ') return;
    _point = _knownPlace(query);
    _loading = _point == null;
    _resolve(query);
  }

  Future<void> _resolve(String query) async {
    final point = await _photonSearch(query);
    if (!mounted) return;
    final known = _point;
    // Kết quả dò quá xa điểm đang ghim thì bỏ, kẻo ghim chạy ra ngoài khung.
    final accept = point != null && _inVietnam(point) && (known == null || _isNear(known, point));
    setState(() {
      if (accept) _point = point;
      _loading = false;
      _failed = _point == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final point = _point;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 260,
        width: double.infinity,
        child: ColoredBox(
          color: const Color(0xFFE4E7EC),
          child: Stack(
            children: [
              if (point != null)
                Positioned.fill(
                  child: FlutterMap(
                  key: ValueKey('${point.latitude.toStringAsFixed(5)}:${point.longitude.toStringAsFixed(5)}'),
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 17,
                    maxZoom: 20,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.google.com/vt/lyrs=m&hl=vi&x={x}&y={y}&z={z}',
                      subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
                      userAgentPackageName: 'com.homeshare.app.home_share',
                      maxNativeZoom: 20,
                      tileDisplay: const TileDisplay.instantaneous(),
                    ),
                  ],
                  ),
                ),
              if (point != null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.location_on, color: Color(0xFFE11D48), size: 40),
                  ),
                )
              else
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFE7F0E4), Color(0xFFC5D7C8), Color(0xFFB7C9D6)],
                      ),
                    ),
                  ),
                ),
              if (_loading) const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    _failed ? '${widget.address}\nChưa định vị được trên bản đồ' : widget.address,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<LatLng?> _photonSearch(String query) async {
  final client = HttpClient();
  try {
    final bias = _knownPlace(query);
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': query,
      'limit': '1',
      'lat': '${bias?.latitude ?? 10.7769}',
      'lon': '${bias?.longitude ?? 106.7009}',
    });
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, 'HomeShare/1.0 (com.homeshare.app.home_share)');
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final features = decoded['features'];
    if (features is! List || features.isEmpty) return null;
    final geometry = features.first is Map ? features.first['geometry'] : null;
    if (geometry is! Map) return null;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;
    final lon = double.tryParse('${coordinates[0]}');
    final lat = double.tryParse('${coordinates[1]}');
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Điểm dự phòng theo tên phường, quận trong địa chỉ, để bài nào cũng có bản đồ.
LatLng? _knownPlace(String query) {
  final text = query.toLowerCase();
  const places = <(String, double, double)>[
    ('phường linh trung', 10.8696, 106.7782),
    ('linh trung', 10.8696, 106.7782),
    ('phường 25', 10.8036, 106.7302),
    ('bình thạnh', 10.8036, 106.7302),
    ('binh thanh', 10.8036, 106.7302),
    ('tân phong', 10.7312, 106.7204),
    ('tan phong', 10.7312, 106.7204),
    ('quận 7', 10.7340, 106.7218),
    ('quan 7', 10.7340, 106.7218),
    ('phường 16', 10.8380, 106.6648),
    ('gò vấp', 10.8380, 106.6648),
    ('go vap', 10.8380, 106.6648),
    ('dịch vọng', 21.0360, 105.7895),
    ('cầu giấy', 21.0278, 105.7900),
    ('hải châu', 16.0715, 108.2238),
    ('thủ đức', 10.8497, 106.7717),
    ('thu duc', 10.8497, 106.7717),
    ('hà nội', 21.0285, 105.8542),
    ('ha noi', 21.0285, 105.8542),
    ('đà nẵng', 16.0544, 108.2022),
    ('da nang', 16.0544, 108.2022),
    ('hồ chí minh', 10.7769, 106.7009),
    ('ho chi minh', 10.7769, 106.7009),
  ];
  for (final place in places) {
    if (text.contains(place.$1)) return LatLng(place.$2, place.$3);
  }
  return null;
}

bool _inVietnam(LatLng point) {
  return point.latitude >= 8 && point.latitude <= 24 && point.longitude >= 102 && point.longitude <= 110;
}

bool _isNear(LatLng a, LatLng b) {
  return (a.latitude - b.latitude).abs() < 0.08 && (a.longitude - b.longitude).abs() < 0.08;
}
