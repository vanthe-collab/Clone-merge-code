import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/host_notification_model.dart';
import '../notification_types.dart';
import '../providers/host_notification_provider.dart';
import 'host_update_deposit_bottom_sheet.dart';

/// Card thông báo role Chủ Trọ (Figma Image 2 & Image 4)
class NotificationCard extends ConsumerWidget {
  final HostNotificationModel notification;
  final HostNotificationType currentTabType;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.currentTabType,
  });

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(amount)} đ';
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes.clamp(1, 59);
      return 'Gửi $m phút trước';
    } else if (diff.inHours < 24) {
      return 'Gửi ${diff.inHours} giờ trước';
    } else {
      return 'Gửi ${diff.inDays} ngày trước';
    }
  }

  Color _getBadgeBg(String roomCode) {
    if (roomCode.startsWith('3')) {
      return const Color(0xFFECFDF3); // Xanh lá dịu
    } else if (roomCode.startsWith('2')) {
      return const Color(0xFFF4EBFF); // Tím nhạt dịu
    }
    return const Color(0xFFEFF8FF); // Xanh dương
  }

  Color _getBadgeTextColor(String roomCode) {
    if (roomCode.startsWith('3')) {
      return const Color(0xFF027A48);
    } else if (roomCode.startsWith('2')) {
      return const Color(0xFF6941C6);
    }
    return AppColors.primary;
  }

  Color _getAvatarBg(String name) {
    if (name.startsWith('N')) return const Color(0xFFD1E9FF);
    if (name.startsWith('L')) return const Color(0xFFFCE7F6);
    return const Color(0xFFF2F4F7);
  }

  Color _getAvatarTextColor(String name) {
    if (name.startsWith('N')) return const Color(0xFF175CD3);
    if (name.startsWith('L')) return const Color(0xFFC11574);
    return const Color(0xFF344054);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notif = notification;
    final dateFmt = DateFormat('dd/MM/yyyy');
    final checkInStr = dateFmt.format(notif.checkInDate ?? notif.createdAt);
    final relativeTimeStr = _formatRelativeTime(notif.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: notif.isRead
              ? const Color(0xFFEAECF0)
              : const Color(0x4D155EEF),
          width: notif.isRead ? 1 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Đánh dấu đã đọc trên Firestore khi chạm vào thẻ
            ref.read(hostNotificationRepositoryProvider).markAsRead(notif.id);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Hàng trên: Huy hiệu số phòng, tiêu đề & mã booking
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Huy hiệu số phòng (101, 203, 302...)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getBadgeBg(notif.displayRoomCode),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        notif.displayRoomCode,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getBadgeTextColor(notif.displayRoomCode),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Tiêu đề phòng & tầng
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notif.roomTitle.isNotEmpty
                                ? notif.roomTitle
                                : 'Phòng ${notif.displayRoomCode} – Căn hộ thoáng mát',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101828),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            notif.roomFloorInfo.isNotEmpty
                                ? notif.roomFloorInfo
                                : 'Tầng 1 • Căn hộ mini 25m²',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tag mã booking #BK12345
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF8FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        notif.displayBookingCode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 2. Khối thông tin khách thuê & tiền cọc
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      // Avatar chữ cái của khách thuê
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _getAvatarBg(notif.renterName),
                        child: Text(
                          notif.renterName.isNotEmpty
                              ? notif.renterName[0].toUpperCase()
                              : 'K',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _getAvatarTextColor(notif.renterName),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Tên khách thuê
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Khách thuê',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF667085),
                              ),
                            ),
                            Text(
                              notif.renterName.isNotEmpty
                                  ? notif.renterName
                                  : 'Khách thuê HomeShare',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF101828),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Số tiền cọc
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currentTabType == HostNotificationType.paymentCompleted
                                ? 'Đã thanh toán'
                                : 'Tiền cọc giữ phòng',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF667085),
                            ),
                          ),
                          Text(
                            _formatCurrency(
                              notif.amount > 0 ? notif.amount : 1500000,
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 3. Ngày nhận phòng & thời gian gửi
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: Color(0xFF667085),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Dự kiến nhận phòng: $checkInStr  •  $relativeTimeStr',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 4. Khối trạng thái hoặc Nút hành động tương ứng với từng Tab
                _buildBottomAction(context, ref, notif),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction(
    BuildContext context,
    WidgetRef ref,
    HostNotificationModel notif,
  ) {
    if (currentTabType == HostNotificationType.pendingAction) {
      // Tab "Đang xử lý": Thanh hiển thị trạng thái Chờ xác nhận cọc màu vàng (Figma Ảnh 2)
      // Quyền xác nhận thuộc role Admin, chủ nhà chỉ xem trạng thái
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0x99FEF0C7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFEDF89)),
        ),
        child: const Row(
          children: [
            Text(
              '⏳',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(width: 6),
            Text(
              'Chờ xác nhận cọc',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB54708),
              ),
            ),
          ],
        ),
      );
    } else if (currentTabType == HostNotificationType.deposit) {
      // Tab "Đã cọc": Hai nút [Chỉnh sửa] và [Duyệt check-in] (Figma Image 4)
      return Row(
        children: [
          // Nút Chỉnh sửa
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                ref.read(hostNotificationRepositoryProvider).markAsRead(notif.id);
                HostUpdateDepositBottomSheet.show(context, notification: notif);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF344054),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD0D5DD)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: const Text(
                'Chỉnh sửa',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Nút Duyệt check-in
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Xác nhận Check-in'),
                    content: Text(
                      'Duyệt nhận phòng ${notif.roomCode} cho khách ${notif.renterName}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Hủy'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text('Xác nhận'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await ref
                      .read(hostNotificationRepositoryProvider)
                      .approveCheckIn(
                        bookingId: notif.bookingId,
                        notificationId: notif.id,
                      );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF027A48),
                        content: Text(
                          'Đã duyệt check-in phòng ${notif.roomCode} thành công!',
                        ),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text(
                'Duyệt check-in',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // Tab "Đã thanh toán": Thông tin phương thức & Xem hóa đơn
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 13,
                  color: Color(0xFF027A48),
                ),
                const SizedBox(width: 4),
                Text(
                  notif.paymentMethod,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF027A48),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Hóa đơn giao dịch: ${notif.displayBookingCode} - ${_formatCurrency(notif.amount)}',
                  ),
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              side: const BorderSide(color: Color(0xFFD0D5DD)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Xem hóa đơn',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF344054),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }
  }
}
