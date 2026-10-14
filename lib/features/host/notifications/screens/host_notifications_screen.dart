import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/host_notification_model.dart';
import '../notification_types.dart';
import '../providers/host_notification_provider.dart';
import '../widgets/notification_card.dart';

/// Màn hình Quản lý Thông báo Chủ trọ (Figma Image 2 & Image 4)
/// Tích hợp đầy đủ 3 trạng thái nghiệp vụ trong 1 module:
/// - Đang xử lý (pendingAction)
/// - Đã cọc (deposit)
/// - Đã thanh toán (paymentCompleted)
class HostNotificationsScreen extends ConsumerStatefulWidget {
  const HostNotificationsScreen({super.key});

  @override
  ConsumerState<HostNotificationsScreen> createState() =>
      _HostNotificationsScreenState();
}

class _HostNotificationsScreenState
    extends ConsumerState<HostNotificationsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = ref.watch(selectedHostNotificationTypeProvider);
    final countsAsync = ref.watch(hostNotificationCountsProvider);
    final counts = countsAsync.asData?.value ?? {
      HostNotificationType.pendingAction: 3,
      HostNotificationType.deposit: 5,
      HostNotificationType.paymentCompleted: 2,
    };

    final notificationsAsync = ref.watch(filteredHostNotificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header & Thanh tìm kiếm
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hàng nút quay lại & Tiêu đề
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFEAECF0)),
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: Color(0xFF101828),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Thông báo',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101828),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Thanh tìm kiếm theo mã booking
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4E7EC)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF98A2B3),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF101828),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Tìm kiếm theo mã booking...',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF98A2B3),
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (val) {
                              ref
                                  .read(hostNotificationSearchQueryProvider.notifier)
                                  .setQuery(val);
                            },
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          InkWell(
                            onTap: () {
                              _searchController.clear();
                              ref
                                  .read(hostNotificationSearchQueryProvider.notifier)
                                  .setQuery('');
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.clear_rounded,
                                size: 16,
                                color: Color(0xFF98A2B3),
                              ),
                            ),
                          ),
                        const Icon(
                          Icons.tune_rounded,
                          color: Color(0xFF667085),
                          size: 20,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Bộ chuyển đổi Tab / Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        // Tab 1: Đang xử lý
                        _buildFilterChip(
                          type: HostNotificationType.pendingAction,
                          label: 'Đang xử lý',
                          count: counts[HostNotificationType.pendingAction] ?? 0,
                          isSelected:
                              selectedType == HostNotificationType.pendingAction,
                          badgeColor: const Color(0xFFFDB022), // Vàng cam nổi bật
                        ),
                        const SizedBox(width: 8),

                        // Tab 2: Đã cọc
                        _buildFilterChip(
                          type: HostNotificationType.deposit,
                          label: 'Đã cọc',
                          count: counts[HostNotificationType.deposit] ?? 0,
                          isSelected: selectedType == HostNotificationType.deposit,
                          badgeColor: const Color(0xFF2E90FA), // Xanh phụ trợ
                        ),
                        const SizedBox(width: 8),

                        // Tab 3: Đã thanh toán hết
                        _buildFilterChip(
                          type: HostNotificationType.paymentCompleted,
                          label: 'Đã thanh toán hết',
                          count:
                              counts[HostNotificationType.paymentCompleted] ?? 0,
                          isSelected: selectedType ==
                              HostNotificationType.paymentCompleted,
                          badgeColor: const Color(0xFF12B76A),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFEAECF0)),

            // 2. Dòng mô tả số lượng yêu cầu
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                _getSubheaderText(selectedType, notificationsAsync.asData?.value),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF667085),
                ),
              ),
            ),

            // 3. Danh sách thông báo
            Expanded(
              child: notificationsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
                error: (err, _) => Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 40,
                          color: Color(0xFFF04438),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Không thể tải dữ liệu thông báo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101828),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          err.toString().split('\n').first,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF667085),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.refresh(
                            hostNotificationsProvider(selectedType),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF2F4F7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_off_outlined,
                                size: 36,
                                color: Color(0xFF98A2B3),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Không có thông báo nào',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF101828),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Khi có yêu cầu đặt cọc hoặc thanh toán mới, thông báo sẽ hiển thị ở đây.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(hostNotificationsProvider(selectedType));
                      ref.invalidate(hostNotificationCountsProvider);
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        return NotificationCard(
                          notification: list[index],
                          currentTabType: selectedType,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required HostNotificationType type,
    required String label,
    required int count,
    required bool isSelected,
    required Color badgeColor,
  }) {
    return InkWell(
      onTap: () {
        ref.read(selectedHostNotificationTypeProvider.notifier).setType(type);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF667085),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (type == HostNotificationType.pendingAction
                          ? const Color(0xFFFDB022)
                          : const Color(0x33FFFFFF))
                      : const Color(0xFFE4E7EC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? (type == HostNotificationType.pendingAction
                            ? const Color(0xFF101828)
                            : Colors.white)
                        : const Color(0xFF344054),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getSubheaderText(
    HostNotificationType type,
    List<HostNotificationModel>? list,
  ) {
    final count = list?.length ?? 0;
    switch (type) {
      case HostNotificationType.pendingAction:
        return 'Hiển thị $count yêu cầu đang chờ xử lý';
      case HostNotificationType.deposit:
        return 'Hiển thị $count yêu cầu đã đặt cọc giữ chỗ';
      case HostNotificationType.paymentCompleted:
        return 'Hiển thị $count giao dịch đã thanh toán hết';
    }
  }
}
