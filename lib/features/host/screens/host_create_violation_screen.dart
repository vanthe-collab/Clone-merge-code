import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/user_provider.dart';
import '../providers/violation_form_provider.dart';
import '../providers/violation_provider.dart';
import '../repositories/violation_repository.dart';
import '../widgets/evidence_picker.dart';
import '../widgets/violation_type_selector.dart';

class HostCreateViolationScreen extends ConsumerStatefulWidget {
  const HostCreateViolationScreen({super.key});

  @override
  ConsumerState<HostCreateViolationScreen> createState() =>
      _HostCreateViolationScreenState();
}

class _HostCreateViolationScreenState
    extends ConsumerState<HostCreateViolationScreen> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _formatNumber(double amount) {
    final s = amount.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return buffer.toString().split('').reversed.join();
  }

  Future<void> _handleSave() async {
    final user = ref.read(userProfileProvider).value;
    final hostId = user?.uid ?? '';
    if (hostId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập tài khoản chủ trọ')),
      );
      return;
    }

    // Cập nhật note vào provider trước khi submit
    ref
        .read(violationFormNotifierProvider.notifier)
        .setNote(_noteController.text);

    final success = await ref
        .read(violationFormNotifierProvider.notifier)
        .submit(hostId);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu biên bản vi phạm thành công!'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      final errorMsg = ref.read(violationFormNotifierProvider).errorMessage ??
          'Có lỗi xảy ra khi lưu biên bản';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Widget _buildRoomSelector(
    List<HostOccupiedRoomItem> rooms,
    HostOccupiedRoomItem? selectedRoom,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: Color(0xFF2563EB),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'THÔNG TIN NGƯỜI VI PHẠM',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Căn hộ / Khách thuê vi phạm',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<HostOccupiedRoomItem>(
                isExpanded: true,
                value: selectedRoom != null &&
                        rooms.any((r) => r.roomId == selectedRoom.roomId)
                    ? rooms.firstWhere((r) => r.roomId == selectedRoom.roomId)
                    : null,
                hint: const Text(
                  'Chọn phòng / khách thuê...',
                  style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                ),
                icon: const Icon(Icons.unfold_more_rounded,
                    color: Color(0xFF64748B)),
                items: rooms.map((item) {
                  return DropdownMenuItem<HostOccupiedRoomItem>(
                    value: item,
                    child: Text(
                      item.dropdownLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref
                        .read(violationFormNotifierProvider.notifier)
                        .selectRoom(val);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFineAndResolution(double fineAmount, String paymentMethod) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.credit_card_outlined,
                color: Color(0xFF2563EB),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'MỨC PHẠT & HÌNH THỨC XỬ LÝ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Số tiền phạt (VND)',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _formatNumber(fineAmount),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const Text(
                  'VNĐ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hình thức thu tiền',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          // Option 1: Cộng vào tiền phòng tháng sau
          InkWell(
            onTap: () => ref
                .read(violationFormNotifierProvider.notifier)
                .setPaymentMethod('NEXT_INVOICE'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: paymentMethod == 'NEXT_INVOICE'
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFE2E8F0),
                  width: paymentMethod == 'NEXT_INVOICE' ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    paymentMethod == 'NEXT_INVOICE'
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: paymentMethod == 'NEXT_INVOICE'
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Cộng vào tiền phòng tháng sau',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Option 2: Thu tiền mặt trực tiếp
          InkWell(
            onTap: () => ref
                .read(violationFormNotifierProvider.notifier)
                .setPaymentMethod('CASH'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: paymentMethod == 'CASH'
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFE2E8F0),
                  width: paymentMethod == 'CASH' ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    paymentMethod == 'CASH'
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: paymentMethod == 'CASH'
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Thu tiền mặt trực tiếp',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.edit_note_rounded,
                color: Color(0xFF2563EB),
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'GHI CHÚ / MÔ TẢ VI PHẠM',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Nhập thời gian xảy ra, vị trí, tình trạng thực tế...',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              fillColor: const Color(0xFFF8FAFC),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(violationFormNotifierProvider);
    final roomsAsync = ref.watch(hostOccupiedRoomsProvider);
    final violationsAsync = ref.watch(violationTypesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Lập biên bản vi phạm',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Khối thông tin người vi phạm
                roomsAsync.when(
                  data: (rooms) => _buildRoomSelector(rooms, formState.selectedRoom),
                  loading: () => Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('Lỗi tải danh sách phòng: $e'),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Khối hành vi vi phạm
                violationsAsync.when(
                  data: (types) => ViolationTypeSelector(
                    violations: types,
                    selectedViolations: formState.selectedViolations,
                    onToggle: (item) {
                      ref
                          .read(violationFormNotifierProvider.notifier)
                          .toggleViolation(item);
                    },
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Lỗi tải danh mục vi phạm: $e'),
                ),
                const SizedBox(height: 16),

                // 3. Khối mức phạt & hình thức xử lý
                _buildFineAndResolution(
                  formState.fineAmount,
                  formState.paymentMethod,
                ),
                const SizedBox(height: 16),

                // 4. Khối bằng chứng vi phạm
                EvidencePicker(
                  files: formState.evidenceFiles,
                  onFileAdded: (file) {
                    final err = ref
                        .read(violationFormNotifierProvider.notifier)
                        .addEvidenceFile(file);
                    if (err != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err)),
                      );
                    }
                  },
                  onFileRemoved: (index) {
                    ref
                        .read(violationFormNotifierProvider.notifier)
                        .removeEvidenceFile(index);
                  },
                ),
                const SizedBox(height: 16),

                // 5. Khối ghi chú / mô tả
                _buildNoteCard(),
              ],
            ),
          ),

          // Nút cố định dưới cùng
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: formState.isSubmitting ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      disabledBackgroundColor: const Color(0xFF93C5FD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: formState.isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Lưu biên bản vi phạm',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
