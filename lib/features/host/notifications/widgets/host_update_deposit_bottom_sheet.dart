import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/host_notification_model.dart';
import '../providers/host_notification_provider.dart';

/// BottomSheet thao tác chủ nhà: Cập nhật thông tin cọc (Theo Figma Image 3)
class HostUpdateDepositBottomSheet extends ConsumerStatefulWidget {
  final HostNotificationModel notification;

  const HostUpdateDepositBottomSheet({
    super.key,
    required this.notification,
  });

  static Future<bool?> show(
    BuildContext context, {
    required HostNotificationModel notification,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HostUpdateDepositBottomSheet(notification: notification),
    );
  }

  @override
  ConsumerState<HostUpdateDepositBottomSheet> createState() =>
      _HostUpdateDepositBottomSheetState();
}

class _HostUpdateDepositBottomSheetState
    extends ConsumerState<HostUpdateDepositBottomSheet> {
  late String _selectedRoomId;
  late String _selectedRoomTitle;
  late DateTime _selectedCheckInDate;
  late TextEditingController _reasonController;
  bool _isLoading = false;

  final List<Map<String, String>> _roomOptions = [
    {
      'id': 'room_101',
      'title': 'Phòng 101 (Tầng 1 • 25m² • 3.2tr/tháng)',
    },
    {
      'id': 'room_201',
      'title': 'Phòng 201 (Tầng 2 • Có gác lửng • 3.2tr/tháng)',
    },
    {
      'id': 'room_203',
      'title': 'Phòng 203 (Tầng 2 • Khép kín 22m² • 3.5tr/tháng)',
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedRoomId = widget.notification.newRoomId ??
        widget.notification.roomId.ifEmpty('room_101');
    _selectedRoomTitle = widget.notification.newRoomTitle ??
        'Phòng 101 (Tầng 1 • 25m² • 3.2tr/tháng)';
    _selectedCheckInDate = widget.notification.newCheckInDate ??
        widget.notification.checkInDate ??
        DateTime(2026, 10, 15);
    _reasonController = TextEditingController(
      text: widget.notification.adjustmentReason ??
          'Phòng 101 đang được vệ sinh và bảo dưỡng điều hòa, giữ nguyên giá cọc và hỗ trợ nhận phòng sớm.',
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(amount)} đ';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedCheckInDate,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2027, 12, 31),
    );
    if (picked != null) {
      setState(() => _selectedCheckInDate = picked);
    }
  }

  Future<void> _saveAndSend() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(hostNotificationRepositoryProvider);
      await repo.updateDepositAdjustment(
        notificationId: widget.notification.id,
        bookingId: widget.notification.bookingId,
        newRoomId: _selectedRoomId,
        newRoomTitle: _selectedRoomTitle,
        newCheckInDate: _selectedCheckInDate,
        adjustmentReason: _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF027A48),
            content: Text('Đã lưu & gửi thông báo điều chỉnh cọc đến khách thuê'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Lỗi: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notif = widget.notification;
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thanh kéo trên đỉnh modal
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Tiêu đề & Nút đóng
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THAO TÁC CHỦ NHÀ • ${notif.displayBookingCode}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Cập nhật thông tin cọc',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2F4F7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFFEAECF0), height: 1),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hộp thông tin khách đặt cọc
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEAECF0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFE0EAFF),
                          child: Text(
                            notif.renterName.isNotEmpty
                                ? notif.renterName[0].toUpperCase()
                                : 'L',
                            style: const TextStyle(
                              color: Color(0xFF3538CD),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Khách đặt cọc:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF667085),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                notif.renterName.isNotEmpty
                                    ? notif.renterName
                                    : 'Trần Phương Linh',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Đã cọc trước:',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF667085),
                              ),
                            ),
                            const SizedBox(height: 2),
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

                  const SizedBox(height: 18),

                  // Mục 1: Đổi phòng
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Đổi phòng',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101828),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Hiện tại: ${notif.roomCode.isNotEmpty ? 'Phòng ${notif.roomCode}' : 'Phòng 101'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD0D5DD)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _roomOptions.any((r) => r['id'] == _selectedRoomId)
                            ? _selectedRoomId
                            : _roomOptions.first['id'],
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF667085),
                        ),
                        items: _roomOptions.map((room) {
                          return DropdownMenuItem<String>(
                            value: room['id'],
                            child: Text(
                              room['title']!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF101828),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedRoomId = val;
                              _selectedRoomTitle = _roomOptions.firstWhere(
                                (r) => r['id'] == val,
                              )['title']!;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Phòng 101 đang có khách chuyển sang ngày 15/10',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Mục 2: Đổi ngày Check-in
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Đổi ngày Check-in',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101828),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Gốc: ${dateFmt.format(notif.checkInDate ?? DateTime(2026, 10, 15))}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD0D5DD)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: Color(0xFF667085),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            dateFmt.format(_selectedCheckInDate),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101828),
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.edit_calendar_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Bộ chọn nhanh ngày trong tháng 10
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tháng 10, 2026',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF667085),
                        ),
                      ),
                      InkWell(
                        onTap: _pickDate,
                        child: const Text(
                          'Chọn nhanh',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildQuickDateChip(
                        day: 13,
                        label: '13 Th2',
                        date: DateTime(2026, 10, 13),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickDateChip(
                        day: 14,
                        label: '14 Th3',
                        date: DateTime(2026, 10, 14),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickDateChip(
                        day: 15,
                        label: '15 Th4',
                        date: DateTime(2026, 10, 15),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickDateChip(
                        day: 16,
                        label: '16 Th5',
                        date: DateTime(2026, 10, 16),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickDateChip(
                        day: 17,
                        label: '17 Th6',
                        date: DateTime(2026, 10, 17),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Mục 3: Lý do điều chỉnh
                  const Text(
                    'Lý do điều chỉnh (Gửi kèm khách)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF101828)),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      hintText: 'Nhập lý do gửi đến người thuê...',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF98A2B3),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Lưu ý cảnh báo màu vàng
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF0C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFEDF89)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: Color(0xFFB54708),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Khách thuê sẽ nhận được thông báo thay đổi và có quyền Đồng ý hoặc Từ chối nhận lại cọc.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFB54708),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Nút Lưu & Gửi xác nhận cho khách
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveAndSend,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send_rounded, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Lưu & Gửi xác nhận cho khách',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 8),

                  // Nút Hủy bỏ thay đổi
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Hủy bỏ thay đổi',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDateChip({
    required int day,
    required String label,
    required DateTime date,
  }) {
    final isSelected = _selectedCheckInDate.year == date.year &&
        _selectedCheckInDate.month == date.month &&
        _selectedCheckInDate.day == date.day;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedCheckInDate = date),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : const Color(0xFF344054),
            ),
          ),
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
