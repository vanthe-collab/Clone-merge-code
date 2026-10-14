import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/room_model.dart';
import '../providers/host_management_provider.dart';
import '../widgets/host_room_widgets.dart';
import 'host_create_screen.dart';
import 'host_room_detail_screen.dart';

// Chủ trọ - Danh sách phòng cơ sở - Luồng đi: Quản lý phòng từ thẻ
// nhà mở route này; lọc trạng thái, chọn phòng để mở chi tiết trực tiếp.
class HostRoomListScreen extends ConsumerStatefulWidget {
  const HostRoomListScreen({super.key, required this.propertyId});
  final String propertyId;
  @override
  ConsumerState<HostRoomListScreen> createState() => _HostRoomListScreenState();
}

class _HostRoomListScreenState extends ConsumerState<HostRoomListScreen> {
  String _filter = 'all';

  // Chủ trọ - Tạo phòng tại cơ sở - Luồng đi: Dấu cộng mở form tạo
  // chọn sẵn nhà; lưu xong trở lại danh sách đang giữ bộ lọc.
  Future<void> _createRoom() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HostCreateScreen(
          propertyId: widget.propertyId,
          startWithRoom: true,
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã tạo phòng.')));
    }
  }

  // Chủ trọ - Mở chi tiết - Luồng đi: Chạm thẻ phòng, xem và sửa/xóa;
  // trở về danh sách tự cập nhật theo stream Firebase của tài khoản.
  Future<void> _openRoom(RoomModel room) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HostRoomDetailScreen(
          propertyId: widget.propertyId,
          roomId: room.id,
        ),
      ),
    );
    if (deleted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa phòng khỏi danh sách.')),
      );
    }
  }

  // Chủ trọ - Hiển thị danh sách theo ảnh - Luồng đi: Header và bộ
  // lọc cố định; chỉ lấy phòng thuộc cơ sở và UID đang đăng nhập.
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(hostSessionProvider);
    final houses = ref.watch(hostPropertiesProvider);
    final data = ref.watch(hostRoomsProvider);
    final property = houses.value
        ?.where((p) => p.id == widget.propertyId && p.hostId == session.value)
        .firstOrNull;
    final rooms =
        (data.value ?? <RoomModel>[])
            .where(
              (r) =>
                  r.propertyId == widget.propertyId &&
                  r.hostId == session.value &&
                  r.status != 'deleted',
            )
            .toList()
          ..sort((a, b) {
            final vacant = (a.status == 'available' ? 0 : 1).compareTo(
              b.status == 'available' ? 0 : 1,
            );
            if (vacant != 0) return vacant;
            return (int.tryParse(a.roomCode) != null &&
                    int.tryParse(b.roomCode) != null)
                ? int.parse(a.roomCode).compareTo(int.parse(b.roomCode))
                : a.roomCode.compareTo(b.roomCode);
          });
    final occupied = rooms.where((r) => r.status == 'occupied').length;
    final empty = rooms.where((r) => r.status == 'available').length;
    final visible = rooms
        .where((r) => _filter == 'all' || r.status == _filter)
        .toList();
    Widget body;
    final error = session.error ?? houses.error ?? data.error;
    if (error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(hostErrorMessage(error), textAlign: TextAlign.center),
              TextButton(
                onPressed: () {
                  ref.invalidate(hostPropertiesProvider);
                  ref.invalidate(hostRoomsProvider);
                },
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    } else if (session.isLoading || houses.isLoading || data.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (property == null) {
      body = const Center(
        child: Text('Cơ sở không tồn tại hoặc bạn chưa đăng nhập.'),
      );
    } else {
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Về quản lý nhà',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '▦ Quản lý cơ sở',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            property.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Color(0xFFC2410C),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        property.fullAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBDF6CD),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$occupied/${rooms.length} phòng thuê',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF087434),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _filterChip('all', 'Tất cả', rooms.length),
                    _filterChip('occupied', 'Đang thuê', occupied),
                    _filterChip('available', 'Còn trống', empty),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      rooms.isEmpty
                          ? 'Chưa có phòng. Bấm + để thêm phòng.'
                          : 'Không có phòng trong bộ lọc này.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: visible.length,
                    itemBuilder: (context, index) => _roomCard(visible[index]),
                  ),
          ),
        ],
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.home, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'HomeShare',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () => _placeholder('Thông báo'),
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: _navigation(property != null),
    );
  }

  // Chủ trọ - Lọc phòng - Luồng đi: Chạm chip để đổi danh sách tại
  // chỗ; số lượng trên chip luôn đếm toàn bộ phòng của cơ sở.
  Widget _filterChip(String value, String label, int count) => ChoiceChip(
    key: ValueKey('room_filter_$value'),
    selected: _filter == value,
    selectedColor: AppColors.primary,
    backgroundColor: const Color(0xFFEDF2FF),
    showCheckmark: false,
    label: Text(
      '$label  $count',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: _filter == value ? Colors.white : AppColors.textSecondary,
      ),
    ),
    onSelected: (_) => setState(() => _filter = value),
  );

  // Chủ trọ - Thẻ phòng - Luồng đi: Xem số phòng, tên khách thuê nếu
  // có, giá và diện tích; nợ tiền chỉ hiện khi dữ liệu có hasRentDebt.
  Widget _roomCard(RoomModel room) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: ValueKey('host_room_${room.id}'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openRoom(room),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: room.images.isEmpty
                      ? const Icon(Icons.image_outlined)
                      : Image.network(
                          room.images.first,
                          webHtmlElementStrategy:
                              WebHtmlElementStrategy.fallback,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Tooltip(
                            message:
                                'Không tải được ảnh phòng. Kiểm tra kết nối hoặc cập nhật ảnh.',
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          hostRoomName(room),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        HostRoomBadge(room: room, showTenant: true),
                        if (room.hasRentDebt)
                          const Text(
                            '• Nợ tiền phòng',
                            style: TextStyle(fontSize: 10, color: Colors.red),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${hostMoney(room.price)} đ',
                            style: TextStyle(
                              fontSize: 14,
                              color: room.status == 'available'
                                  ? const Color(0xFFC2410C)
                                  : AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: ' /tháng  • ${room.area} m²',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // Chủ trọ - Bottom nav cơ sở - Luồng đi: Dấu cộng tạo phòng thuộc
  // nhà hiện tại; Quay lại/Thông tin chung về quản lý nhà, tab khác báo tạm.
  Widget _navigation(bool canCreate) => Container(
    color: Colors.white,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _navButton(
              Icons.home_outlined,
              'Thông tin chung',
              () => Navigator.of(context).pop(),
              active: true,
            ),
            _navButton(
              Icons.people_outline,
              'QL người thuê',
              () => _placeholder('Quản lý người thuê'),
            ),
            Expanded(
              child: Center(
                heightFactor: 1,
                child: IconButton.filled(
                  tooltip: 'Thêm phòng',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: canCreate ? _createRoom : null,
                  icon: const Icon(Icons.add, size: 28),
                ),
              ),
            ),
            _navButton(
              Icons.account_balance_wallet_outlined,
              'QL Tiền',
              () => _placeholder('Quản lý tiền'),
            ),
            _navButton(
              Icons.arrow_back,
              'Quay lại',
              () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _navButton(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool active = false,
  }) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
  void _placeholder(String label) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$label sẽ được bổ sung sau.')));
}
