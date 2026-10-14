import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/room_model.dart';
import '../providers/host_management_provider.dart';
import '../widgets/host_room_widgets.dart';
import 'host_room_edit_screen.dart';

// Chủ trọ - Chi tiết phòng - Luồng đi: Chọn phòng trong danh sách,
// đọc dữ liệu trực tiếp rồi mở chỉnh sửa hoặc xác nhận xóa phòng.
class HostRoomDetailScreen extends ConsumerWidget {
  const HostRoomDetailScreen({
    super.key,
    required this.propertyId,
    required this.roomId,
    this.previewRoom,
    this.previewImages = const [],
  });
  final String propertyId, roomId;
  final RoomModel? previewRoom;
  final List<HostUpload> previewImages;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(hostRoomsProvider);
    final houses = ref.watch(hostPropertiesProvider);
    final uid = ref.watch(hostSessionProvider).value;
    final property = houses.value
        ?.where((p) => p.id == propertyId && p.hostId == uid)
        .firstOrNull;
    final room =
        previewRoom ??
        rooms.value
            ?.where(
              (r) =>
                  r.id == roomId &&
                  r.propertyId == propertyId &&
                  r.hostId == uid &&
                  r.status != 'deleted',
            )
            .firstOrNull;
    final error = rooms.error ?? houses.error;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FF),
      appBar: AppBar(
        title: Text(previewRoom == null ? 'Chi tiết phòng' : 'Xem trước phòng'),
      ),
      body: room == null || property == null
          ? Center(
              child: error != null
                  ? Text(hostErrorMessage(error))
                  : rooms.isLoading || houses.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Phòng không còn trong danh sách.'),
            )
          : ListView(
              scrollCacheExtent: const ScrollCacheExtent.pixels(5000),
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '▦ ${property.name} • Tầng ${room.floor}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                HostRoomSection(
                  title: hostRoomName(room),
                  icon: Icons.meeting_room_outlined,
                  child: Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          HostRoomBadge(room: room),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Giá thuê',
                                style: TextStyle(fontSize: 11),
                              ),
                              Text(
                                '${hostMoney(room.price)} đ',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 23,
                                ),
                              ),
                              const Text(
                                '/tháng',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 210,
                          child: room.images.isEmpty && previewImages.isEmpty
                              ? const Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 64,
                                    color: AppColors.textSecondary,
                                  ),
                                )
                              : PageView(
                                  children: [
                                    for (final url in room.images)
                                      Image.network(
                                        url,
                                        webHtmlElementStrategy:
                                            WebHtmlElementStrategy.fallback,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            size: 48,
                                          ),
                                        ),
                                      ),
                                    for (final photo in previewImages)
                                      Image.memory(
                                        photo.bytes,
                                        fit: BoxFit.cover,
                                      ),
                                  ],
                                ),
                        ),
                      ),
                      if (room.images.length + previewImages.length > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${room.images.length + previewImages.length} ảnh • Vuốt để xem',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                HostRoomSection(
                  title: 'Thông tin ${hostRoomName(room).toLowerCase()}',
                  icon: Icons.door_front_door_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${room.areaLabel} • Tầng ${room.floor} • ${room.capacity} người',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _rate('Điện', room.electricityRate, 'đ/kWh'),
                            _rate('Nước', room.waterRate, 'đ/m³'),
                            _rate('Dịch vụ', room.serviceFee, 'đ/tháng'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final amenity in room.amenities)
                            Chip(
                              label: Text(
                                amenity,
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor: const Color(0xFFF0F4FF),
                              side: BorderSide.none,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Tiền cọc: ${hostMoney(room.deposit)} đ'),
                      if (room.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(room.description),
                        ),
                    ],
                  ),
                ),
                HostRoomTenant(room: room),
                if (previewRoom == null)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          key: const ValueKey('edit_room'),
                          onPressed: () async {
                            final result = await Navigator.of(context)
                                .push<String>(
                                  MaterialPageRoute(
                                    builder: (_) => HostRoomEditScreen(
                                      room: room,
                                      property: property,
                                    ),
                                  ),
                                );
                            if (!context.mounted) return;
                            if (result == 'deleted') {
                              Navigator.pop(context, true);
                            } else if (result == 'saved') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã lưu thay đổi phòng.'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Chỉnh sửa phòng'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Xóa phòng',
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFFFFDADA),
                          foregroundColor: AppColors.danger,
                        ),
                        onPressed: () async {
                          if (await hostDeleteRoom(context, ref, room) &&
                              context.mounted) {
                            Navigator.pop(context, true);
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }

  // Chủ trọ - Phí phòng - Luồng đi: Hiển thị mức phí lưu trong phòng;
  // phòng cũ chưa có mức phí được ghi rõ thay vì tự thêm số minh họa.
  Widget _rate(String label, double? value, String unit) => Expanded(
    child: Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value == null ? 'Chưa thiết lập' : hostMoney(value),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        if (value != null) Text(unit, style: const TextStyle(fontSize: 10)),
      ],
    ),
  );
}
