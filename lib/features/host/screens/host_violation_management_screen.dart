import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/user_provider.dart';
import '../models/violation_record_model.dart';
import '../providers/violation_provider.dart';
import '../widgets/payment_action_sheet.dart';
import '../widgets/violation_record_card.dart';
import '../widgets/violation_summary_card.dart';
import 'host_create_violation_screen.dart';
import 'host_management_menu.dart';

class HostViolationManagementScreen extends ConsumerStatefulWidget {
  final ValueChanged<HostManagementSection>? onSectionChanged;

  const HostViolationManagementScreen({
    super.key,
    this.onSectionChanged,
  });

  @override
  ConsumerState<HostViolationManagementScreen> createState() =>
      _HostViolationManagementScreenState();
}

class _HostViolationManagementScreenState
    extends ConsumerState<HostViolationManagementScreen> {

  void _openSwitcherMenu() {
    HostManagementMenu.show(
      context: context,
      currentSection: HostManagementSection.violations,
      onSelect: (section) {
        if (widget.onSectionChanged != null) {
          widget.onSectionChanged!(section);
        } else if (section == HostManagementSection.tenants) {
          Navigator.of(context).pushReplacementNamed('/host/tenants');
        } else if (section == HostManagementSection.checkinCheckout) {
          Navigator.of(context).pushReplacementNamed('/host/checkin-checkout');
        }
      },
    );
  }

  Future<void> _openCreateViolation() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const HostCreateViolationScreen(),
      ),
    );

    if (result == true && mounted) {
      ref.invalidate(hostViolationRecordsStreamProvider);
    }
  }

  Future<void> _handleCollectCash(ViolationRecordModel record) async {
    final user = ref.read(userProfileProvider).value;
    final collectorName = user?.hoTen ?? user?.displayName ?? 'Chủ trọ';

    final confirmed = await PaymentActionSheet.showCashConfirmation(
      context: context,
      record: record,
      collectorName: collectorName,
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(violationRepositoryProvider);
        await repo.markCashPayment(record.id, hostId: user?.uid ?? '');

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Đã ghi nhận thu tiền mặt phòng ${record.roomCode} thành công!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi ghi nhận thanh toán: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _handleDeductInvoice(ViolationRecordModel record) async {
    final confirmed = await PaymentActionSheet.showDeductConfirmation(
      context: context,
      record: record,
    );

    if (confirmed == true && mounted) {
      try {
        final repo = ref.read(violationRepositoryProvider);
        await repo.deductToInvoice(record);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Đã cộng khoản phạt phòng ${record.roomCode} vào hóa đơn tháng sau!'),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi trừ vào hóa đơn: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _handleSendReminder(ViolationRecordModel record) async {
    try {
      final repo = ref.read(violationRepositoryProvider);
      await repo.sendPaymentReminder(record.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Đã gửi thông báo nhắc nộp phạt đến cư dân ${record.tenantName}!'),
          backgroundColor: const Color(0xFF2563EB),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi gửi nhắc nộp tiền: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Widget _buildFilterChip(String label, String value, String currentFilter) {
    final isSelected = currentFilter == value;

    return InkWell(
      onTap: () {
        ref.read(hostViolationStatusFilterProvider.notifier).state = value;
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1D4ED8)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x262563EB),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 40,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không có vi phạm nào trong tháng',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Khu trọ hoạt động trật tự và không có khoản phạt nào được ghi nhận.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openCreateViolation,
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text(
              'Lập biên bản mới',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(violationMonthlyStatsProvider);
    final selectedMonth = ref.watch(hostViolationMonthFilterProvider);
    final statusFilter = ref.watch(hostViolationStatusFilterProvider);
    final recordsAsync = ref.watch(filteredViolationRecordsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Color(0xFF1E293B)),
          onPressed: _openSwitcherMenu,
        ),
        title: const Text(
          'Quản lý vi phạm',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _openCreateViolation,
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text(
                  'Lập biên bản',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(hostViolationRecordsStreamProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Thẻ tổng quan tháng
                    ViolationSummaryCard(
                      stats: stats,
                      selectedMonth: selectedMonth,
                      onMonthChanged: (m) {
                        ref
                            .read(hostViolationMonthFilterProvider.notifier)
                            .state = m;
                      },
                      onFilterTap: (f) {
                        ref
                            .read(hostViolationStatusFilterProvider.notifier)
                            .state = f;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 2. Bộ lọc tab trạng thái
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('Tất cả', 'ALL', statusFilter),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                              'Chờ nộp (${stats.pendingCount})',
                              'PENDING',
                              statusFilter),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                              'Đã nộp (${stats.paidCount})',
                              'PAID',
                              statusFilter),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                              'Đã trừ tiền thuê',
                              'ADDED_TO_INVOICE',
                              statusFilter),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // 3. Danh sách vi phạm
            recordsAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return SliverToBoxAdapter(child: _buildEmptyState());
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final record = records[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ViolationRecordCard(
                            record: record,
                            onCollectCash: () => _handleCollectCash(record),
                            onDeductInvoice: () =>
                                _handleDeductInvoice(record),
                            onSendReminder: () =>
                                _handleSendReminder(record),
                          ),
                        );
                      },
                      childCount: records.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 40, color: Color(0xFFDC2626)),
                        const SizedBox(height: 12),
                        Text(
                          'Lỗi tải danh sách vi phạm: $err',
                          style: const TextStyle(color: Color(0xFFDC2626)),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref
                              .invalidate(hostViolationRecordsStreamProvider),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
