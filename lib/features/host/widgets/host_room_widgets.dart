import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/room_model.dart';
import '../providers/host_management_provider.dart';

// Chủ trọ - Định dạng phòng - Luồng đi: Dùng chung danh sách, chi
// tiết và form sửa để tên phòng, giá, trạng thái hiển thị nhất quán.
String hostMoney(num value) => NumberFormat.decimalPattern('vi').format(value);
String hostRoomName(RoomModel room) =>
    room.roomCode.isEmpty ? room.title : 'Phòng ${room.roomCode}';
String hostRoomStatus(RoomModel room) => switch (room.status) {
  'available' => 'Còn trống',
  'occupied' => 'Đang thuê',
  'reserved' => 'Giữ chỗ',
  'maintenance' => 'Bảo trì',
  'deleted' => 'Đã xóa',
  _ => 'Tạm ngưng',
};

// Chủ trọ - Thẻ nhóm thông tin - Luồng đi: Giữ nền trắng, góc bo và
// nền xanh nhạt bên trong theo ảnh màn chi tiết/chỉnh sửa phòng.
class HostRoomSection extends StatelessWidget {
  const HostRoomSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

// Chủ trọ - Nhãn trạng thái - Luồng đi: Phòng trống dùng cam nhạt;
// phòng đang thuê dùng xanh, các trạng thái khác dùng nhãn trung tính.
class HostRoomBadge extends StatelessWidget {
  const HostRoomBadge({super.key, required this.room, this.showTenant = false});
  final RoomModel room;
  final bool showTenant;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: room.status == 'available'
          ? const Color(0xFFFFE4D6)
          : room.status == 'occupied'
          ? const Color(0xFFB8F8C8)
          : const Color(0xFFEAF0FF),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      showTenant && room.status == 'occupied' && room.tenantName.isNotEmpty
          ? room.tenantName
          : hostRoomStatus(room),
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),
  );
}

// Chủ trọ - Khách thuê của phòng - Luồng đi: Đọc tên và hợp đồng đã
// lưu trong phòng; dữ liệu chưa có hiển thị trạng thái trống rõ ràng.
class HostRoomTenant extends StatelessWidget {
  const HostRoomTenant({super.key, required this.room});
  final RoomModel room;
  @override
  Widget build(BuildContext context) => HostRoomSection(
    title: 'Khách thuê',
    icon: Icons.person_outline,
    child: room.tenantName.isEmpty
        ? const Text(
            'Chưa có thông tin khách thuê.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          )
        : Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFDCE7FF),
                      child: Text(
                        room.tenantName.characters.first.toUpperCase(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room.tenantName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (room.tenantPhone.isNotEmpty)
                            Text(
                              room.tenantPhone,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (room.tenantPhone.isNotEmpty)
                      IconButton(
                        tooltip: 'Sao chép số điện thoại',
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: room.tenantPhone),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Đã sao chép số điện thoại khách thuê.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(
                          Icons.phone_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
                if (room.contractId.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Hợp đồng: ${room.contractId}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                if (room.contractStart != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Ngày vào ở: ${DateFormat('dd/MM/yyyy').format(room.contractStart!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                if (room.contractEnd != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Hợp đồng đến: ${DateFormat('dd/MM/yyyy').format(room.contractEnd!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
  );
}

// Chủ trọ - Xác nhận xóa phòng - Luồng đi: Nút thùng rác mở xác
// nhận; chỉ báo thành công sau khi Firebase cập nhật phòng và số phòng.
Future<bool> hostDeleteRoom(
  BuildContext context,
  WidgetRef ref,
  RoomModel room,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Xóa ${hostRoomName(room).toLowerCase()}?'),
      content: const Text(
        'Phòng sẽ không còn trong danh sách quản lý và tìm phòng. Lịch sử liên quan vẫn được giữ.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            minimumSize: const Size(0, 44),
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Xóa phòng'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  try {
    await ref.read(hostRepositoryProvider).deleteRoom(room);
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(hostErrorMessage(error))));
    }
    return false;
  }
}
