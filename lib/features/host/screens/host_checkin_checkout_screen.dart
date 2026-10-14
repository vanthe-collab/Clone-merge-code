import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/checkin_checkout_provider.dart';
import '../repositories/checkin_checkout_repository.dart';
import '../widgets/checkin_checkout_card.dart';
import 'host_checkin_handover_screen.dart';
import 'host_management_menu.dart';
import 'host_violation_management_screen.dart';

class HostCheckinCheckoutScreen extends ConsumerStatefulWidget {
  final ValueChanged<HostManagementSection>? onSectionChanged;

  const HostCheckinCheckoutScreen({
    super.key,
    this.onSectionChanged,
  });

  @override
  ConsumerState<HostCheckinCheckoutScreen> createState() =>
      _HostCheckinCheckoutScreenState();
}

class _HostCheckinCheckoutScreenState
    extends ConsumerState<HostCheckinCheckoutScreen> {
  int _selectedTab = 1; // 0: Check-in, 1: Check-out (default matches mockup)

  void _openSwitcherMenu() {
    HostManagementMenu.show(
      context: context,
      currentSection: HostManagementSection.checkinCheckout,
      onSelect: (section) {
        if (widget.onSectionChanged != null) {
          widget.onSectionChanged!(section);
        } else if (section == HostManagementSection.tenants) {
          Navigator.of(context).pushReplacementNamed('/host/tenants');
        } else if (section == HostManagementSection.violations) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const HostViolationManagementScreen(),
            ),
          );
        }
      },
    );
  }

  void _openQrScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  _selectedTab == 0
                      ? 'Quét QR Check-in'
                      : 'Quét QR Check-out',
                  style: const TextStyle(color: Colors.white),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      onDetect: (capture) {
                        final barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final code = barcodes.first.rawValue ?? '';
                          Navigator.of(ctx).pop();
                          _handleQrDetected(code);
                        }
                      },
                    ),
                    // Khung quét QR
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF3B82F6),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                ),
              ),
              // Nút giả lập QR trên môi trường test / giả lập
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _handleQrDetected('ROOM_204_CHECKIN');
                  },
                  icon: const Icon(Icons.qr_code, color: Colors.white70),
                  label: const Text(
                    'Kiểm tra thử nghiệm quét phòng P.204',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleQrDetected(String code) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã nhận diện mã: $code')),
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const HostCheckinHandoverScreen(
          bookingId: '',
          roomId: '',
          roomCode: '204',
        ),
      ),
    );
  }

  void _showCheckoutDialog(CheckinCheckoutItem item) {
    final deductionCtrl = TextEditingController(text: '0');
    final noteCtrl = TextEditingController();
    double currentDeduction = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final refundAmount =
                (item.deposit - currentDeduction).clamp(0.0, double.infinity);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Chốt trả phòng P.${item.roomCode}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Thông tin tiền cọc
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tiền cọc ban đầu:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              '${NumberFormat.decimalPattern('vi').format(item.deposit)} đ',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Khoản khấu trừ:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            Text(
                              '- ${NumberFormat.decimalPattern('vi').format(currentDeduction)} đ',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Tiền hoàn cọc thực tế:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '${NumberFormat.decimalPattern('vi').format(refundAmount)} đ',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: deductionCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Khoản khấu trừ hư hỏng/điện nước (VNĐ)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        currentDeduction = double.tryParse(val.trim()) ?? 0.0;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lý do khấu trừ & ghi chú biên bản',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      try {
                        await ref
                            .read(checkinCheckoutRepositoryProvider)
                            .performCheckout(
                              roomId: item.roomId,
                              periodId: item.periodId,
                              renterId: item.renterId,
                              initialDeposit: item.deposit,
                              deductionAmount: currentDeduction,
                              note: noteCtrl.text.trim(),
                            );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã hoàn tất check-out phòng!'),
                              backgroundColor: Color(0xFF16A34A),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi check-out: $e')),
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Xác nhận Hoàn cọc & Check-out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkinItemsAsync = ref.watch(hostCheckinItemsProvider);
    final checkoutItemsAsync = ref.watch(hostCheckoutItemsProvider);

    final checkinCount = checkinItemsAsync.value
            ?.where((i) => !i.isCompleted)
            .length ??
        1;
    final checkoutCount = checkoutItemsAsync.value
            ?.where((i) => !i.isCompleted)
            .length ??
        2;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Row(
                children: [
                  InkWell(
                    onTap: _openSwitcherMenu,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.menu,
                        color: Color(0xFF2563EB),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Quản lý Check in & Check Out',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // Banner QR Tốc Hành
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x332563EB),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedTab == 0
                                    ? 'Quét QR Check-in\nTốc Hành'
                                    : 'Quét QR Check-out\nTốc Hành',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Bàn giao & kiểm tra phòng tức thì',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: _openQrScanner,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Quét mã',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: Color(0xFF2563EB),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tab chuyển đổi (Check-in / Check-out)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTabPill(
                            index: 0,
                            title: 'Check-in',
                            count: checkinCount,
                          ),
                        ),
                        Expanded(
                          child: _buildTabPill(
                            index: 1,
                            title: 'Check-out',
                            count: checkoutCount,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Nội dung theo Tab
                  if (_selectedTab == 0)
                    _buildCheckinContent(checkinItemsAsync)
                  else
                    _buildCheckoutContent(checkoutItemsAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill({
    required int index,
    required String title,
    required int count,
  }) {
    final isSelected = _selectedTab == index;

    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFCBD5E1),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckinContent(
    AsyncValue<List<CheckinCheckoutItem>> itemsAsync,
  ) {
    return itemsAsync.when(
      data: (items) {
        final pending = items.where((i) => !i.isCompleted).toList();
        final completed = items.where((i) => i.isCompleted).toList();

        // Sample pending nếu chưa có
        final displayPending = pending.isNotEmpty
            ? pending
            : [
                CheckinCheckoutItem(
                  id: 'sample_checkin_1',
                  bookingId: 'bk_sample',
                  roomId: 'r_204',
                  roomCode: '204',
                  renterId: 'renter_hl',
                  renterName: 'Đỗ Hoàng Long',
                  renterPhone: '0912 345 678',
                  propertyName: 'Nhà Đặng Văn Bi',
                  floor: 2,
                  deposit: 4800000.0,
                  expectedDate: DateTime(2024, 11, 30),
                  status: 'Chờ nhận phòng',
                  isCompleted: false,
                ),
              ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DANH SÁCH CẦN XỬ LÝ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${displayPending.length} phòng liên quan',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...displayPending.map((item) => CheckinCheckoutCard(
                  item: item,
                  isCheckinTab: true,
                  onAction: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HostCheckinHandoverScreen(
                          bookingId: item.bookingId,
                          roomId: item.roomId,
                          roomCode: item.roomCode,
                        ),
                      ),
                    );
                  },
                )),
            if (completed.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'PHÒNG ĐÃ HOÀN TẤT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              ...completed.map((item) => CheckinCheckoutCard(
                    item: item,
                    isCheckinTab: true,
                    onAction: () {},
                  )),
            ],
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text('Lỗi: $err'),
              ElevatedButton(
                onPressed: () => ref.refresh(hostCheckinItemsProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutContent(
    AsyncValue<List<CheckinCheckoutItem>> itemsAsync,
  ) {
    return itemsAsync.when(
      data: (items) {
        final pending = items.where((i) => !i.isCompleted).toList();
        final completed = items.where((i) => i.isCompleted).toList();

        // Sample pending & completed để match mockup nếu dữ liệu trống
        final displayPending = pending.isNotEmpty
            ? pending
            : [
                CheckinCheckoutItem(
                  id: 'sample_checkout_1',
                  bookingId: 'bk_204',
                  roomId: 'r_204',
                  roomCode: '204',
                  renterId: 'renter_hl',
                  renterName: 'Đỗ Hoàng Long',
                  renterPhone: '0912 345 678',
                  propertyName: 'Nhà Đặng Văn Bi',
                  floor: 2,
                  deposit: 4800000.0,
                  expectedDate: DateTime(2024, 11, 30),
                  status: 'Đang ở',
                  isCompleted: false,
                ),
              ];

        final displayCompleted = completed.isNotEmpty
            ? completed
            : [
                CheckinCheckoutItem(
                  id: 'sample_done_1',
                  bookingId: '',
                  roomId: 'r_105',
                  roomCode: '105',
                  renterId: 'renter_mai',
                  renterName: 'Trần Thị Mai',
                  propertyName: 'Ký túc xá L2',
                  floor: 1,
                  deposit: 3500000.0,
                  expectedDate: DateTime(2024, 11, 15),
                  status: 'Đã Check-out',
                  isCompleted: true,
                  completedTime: DateTime(2024, 11, 15, 10, 30),
                  refundedDeposit: 3500000.0,
                ),
              ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DANH SÁCH CẦN XỬ LÝ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${displayPending.length} phòng liên quan',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...displayPending.map((item) => CheckinCheckoutCard(
                  item: item,
                  isCheckinTab: false,
                  onAction: () => _showCheckoutDialog(item),
                )),
            const SizedBox(height: 16),
            const Text(
              'PHÒNG ĐÃ HOÀN TẤT',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            ...displayCompleted.map((item) => CheckinCheckoutCard(
                  item: item,
                  isCheckinTab: false,
                  onAction: () {},
                )),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text('Lỗi: $err'),
              ElevatedButton(
                onPressed: () => ref.refresh(hostCheckoutItemsProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
