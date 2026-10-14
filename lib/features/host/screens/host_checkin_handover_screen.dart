import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/handover_item_model.dart';
import '../providers/handover_provider.dart';
import '../providers/host_management_provider.dart';
import '../repositories/handover_repository.dart';
import '../widgets/handover_item_card.dart';
import '../widgets/handover_meter_card.dart';

class HostCheckinHandoverScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final String roomId;
  final String roomCode;

  const HostCheckinHandoverScreen({
    super.key,
    required this.bookingId,
    required this.roomId,
    this.roomCode = '204',
  });

  @override
  ConsumerState<HostCheckinHandoverScreen> createState() =>
      _HostCheckinHandoverScreenState();
}

class _HostCheckinHandoverScreenState
    extends ConsumerState<HostCheckinHandoverScreen> {
  final _electricityController = TextEditingController(text: '1428');
  final _waterController = TextEditingController(text: '84');
  final _noteController = TextEditingController();

  bool _isKeyHandedOver = true;
  bool _isSubmitting = false;
  List<HandoverItemModel>? _currentItems;

  String _formatMoney(double amount) {
    return '${NumberFormat.decimalPattern('vi').format(amount)} đ';
  }

  @override
  void dispose() {
    _electricityController.dispose();
    _waterController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onToggleItem(int index, bool value) {
    setState(() {
      if (_currentItems != null && index < _currentItems!.length) {
        _currentItems![index] =
            _currentItems![index].copyWith(isChecked: value);
      }
    });
  }

  Future<void> _submitHandover(HandoverRoomContext ctx) async {
    final elecVal = double.tryParse(_electricityController.text.trim());
    final waterVal = double.tryParse(_waterController.text.trim());

    if (elecVal == null || elecVal < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập chỉ số điện hợp lệ')),
      );
      return;
    }

    if (waterVal == null || waterVal < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập chỉ số nước hợp lệ')),
      );
      return;
    }

    if (!_isKeyHandedOver) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng xác nhận bàn giao chìa khóa và thiết bị'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final hostId = ref.read(hostSessionProvider).value ?? '';

    try {
      await ref.read(handoverRepositoryProvider).confirmHandover(
            bookingId: ctx.bookingId,
            roomId: ctx.roomId,
            renterId: ctx.renterId,
            renterName: ctx.renterName,
            renterPhone: ctx.renterPhone,
            hostId: hostId,
            electricityMeter: elecVal,
            electricityRate: ctx.electricityRate,
            waterMeter: waterVal,
            waterRate: ctx.waterRate,
            isKeyHandedOver: _isKeyHandedOver,
            note: _noteController.text.trim(),
            items: _currentItems ?? ctx.items,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bàn giao nhận phòng thành công!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi bàn giao phòng: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = HandoverParams(
      bookingId: widget.bookingId,
      roomId: widget.roomId,
    );
    final contextAsync = ref.watch(handoverContextProvider(params));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: contextAsync.when(
          data: (handoverCtx) {
            _currentItems ??= List.from(handoverCtx.items);
            final checkedCount =
                _currentItems?.where((i) => i.isChecked).length ?? 0;
            final totalCount = _currentItems?.length ?? 0;

            final displayRoomCode = widget.roomCode.isNotEmpty
                ? widget.roomCode
                : handoverCtx.roomCode;

            return Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: Colors.white,
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF0F172A),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'QUY TRÌNH CHECK-IN',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bàn giao nhận phòng -\nP.$displayRoomCode',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Badge Trực tiếp
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 7,
                              color: Color(0xFF16A34A),
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Trực tiếp',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Nội dung quy trình 3 bước
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      // Card Thông tin người thuê
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFFDBEAFE),
                                  child: const Text(
                                    'HL',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            handoverCtx.renterName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          if (handoverCtx.isVerified) ...[
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.verified,
                                              size: 16,
                                              color: Color(0xFF2563EB),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.domain_outlined,
                                            size: 14,
                                            color: Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              'P.$displayRoomCode • ${handoverCtx.address}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Hai hộp thông tin: Tiền cọc & Thời hạn thuê
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Tiền cọc giữ chỗ',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatMoney(handoverCtx.deposit),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Row(
                                          children: [
                                            Icon(
                                              Icons.lock_outline,
                                              size: 12,
                                              color: Color(0xFF16A34A),
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Đã giữ qua Escrow',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF16A34A),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Thời hạn thuê',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${handoverCtx.rentalMonths} tháng',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Bắt đầu từ hôm nay',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // BƯỚC 1: Chốt chỉ số đầu vào
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    _buildStepBadge('1'),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Chốt chỉ số đầu vào',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const Text(
                                  'Bắt buộc',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Điện
                            HandoverMeterCard(
                              title: 'Chỉ số điện ban đầu (kWh)',
                              unit: 'kWh',
                              rate: handoverCtx.electricityRate,
                              controller: _electricityController,
                              isElectricity: true,
                            ),
                            // Nước
                            HandoverMeterCard(
                              title: 'Chỉ số nước ban đầu (m³)',
                              unit: 'm³',
                              rate: handoverCtx.waterRate,
                              controller: _waterController,
                              isElectricity: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // BƯỚC 2: Hiện trạng trang thiết bị
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    _buildStepBadge('2'),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Hiện trạng trang thiết bị',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$checkedCount/$totalCount Đạt chuẩn',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (_currentItems != null)
                              ...List.generate(
                                _currentItems!.length,
                                (idx) => HandoverItemCard(
                                  item: _currentItems![idx],
                                  onToggle: (val) => _onToggleItem(idx, val),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // BƯỚC 3: Xác nhận bàn giao
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    _buildStepBadge('3'),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Xác nhận bàn giao',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      size: 15,
                                      color: Color(0xFF16A34A),
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Đồng thuận hai bên',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Checkbox bàn giao chìa khóa & thiết bị
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: _isKeyHandedOver,
                                    activeColor: const Color(0xFF2563EB),
                                    onChanged: (val) {
                                      setState(() {
                                        _isKeyHandedOver = val ?? true;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Đã bàn giao chìa khóa & kiểm tra đủ thiết bị',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'Hai bên đã cùng kiểm tra hiện trạng thiết bị và chỉ số công tơ ban đầu.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Ghi chú thêm (nếu có)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _noteController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText:
                                    'Nhập ghi chú hoặc thỏa thuận phát sinh (nếu có)...',
                                hintStyle: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Nút cố định ở đáy
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _submitHandover(handoverCtx),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.check_circle_outline,
                              size: 20,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isSubmitting
                            ? 'Đang lưu bàn giao...'
                            : 'Xác nhận bàn giao phòng',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Lỗi tải thông tin phòng bàn giao: $err',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepBadge(String number) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Color(0xFF2563EB),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        number,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
