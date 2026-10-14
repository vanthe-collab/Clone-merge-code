import 'host_room_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../data/host_property.dart';
import '../providers/host_management_provider.dart';
import 'host_create_screen.dart';

enum _PropertyAction { edit, delete }

// Chủ trọ - Quản lý cơ sở Firebase - Luồng đi: Mở từ Dashboard;
// properties và rooms của tài khoản cập nhật danh sách và tổng quan tự động.
class HostPropertyManagementScreen extends ConsumerWidget {
  const HostPropertyManagementScreen({super.key});
  static const _blue = AppColors.primary;
  static const _muted = AppColors.textSecondary;
  String _money(num value) => NumberFormat.decimalPattern('vi').format(value);

  // Chủ trọ - Hiển thị quản lý - Luồng đi: Chờ phiên đăng nhập rồi tải
  // hai collection; lỗi hiện nút thử lại, danh sách trống không dùng dữ liệu giả.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(hostSessionProvider);
    final properties = ref.watch(hostPropertiesProvider);
    final rooms = ref.watch(hostRoomsProvider);
    Widget content;
    if (session.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (session.hasError) {
      content = _error(ref, session.error!);
    } else if (session.value == null) {
      content = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Đăng nhập bằng tài khoản Chủ trọ để xem và lưu cơ sở trên Firebase.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (properties.hasError || rooms.hasError) {
      content = _error(ref, properties.error ?? rooms.error!);
    } else if (properties.isLoading || rooms.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else {
      final summaries = properties.value!
          .map((p) => PropertySummary(p, rooms.value!))
          .toList();
      final linkedIds = properties.value!.map((p) => p.id).toSet();
      final unlinked = rooms.value!
          .where((r) => !linkedIds.contains(r.propertyId))
          .length;
      content = ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Text(
            'Quản lý phòng trọ',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '${summaries.length} cơ sở đang quản lý',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 16),
          _overview(summaries),
          const SizedBox(height: 20),
          Text(
            'Danh sách cơ sở (${summaries.length})',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (unlinked > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '$unlinked phòng cũ chưa liên kết cơ sở, chưa tính trong tổng quan.',
                style: const TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
          if (summaries.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: _decoration(),
              child: Column(
                children: [
                  const Icon(Icons.add_home_outlined, size: 44, color: _blue),
                  const SizedBox(height: 12),
                  const Text(
                    'Chưa có cơ sở',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tạo nhà rồi thêm từng phòng để bắt đầu quản lý.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _openCreate(context),
                    child: const Text('Tạo cơ sở đầu tiên'),
                  ),
                ],
              ),
            ),
          for (final summary in summaries) ...[
            _propertyCard(context, ref, summary),
            const SizedBox(height: 14),
          ],
        ],
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.home_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'HomeShare',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Thông báo',
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Thông báo sẽ được bổ sung sau.'),
                      ),
                    ),
                    icon: const Icon(Icons.notifications_none, color: _muted),
                  ),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  // Chủ trọ - Mở form tạo - Luồng đi: Dấu cộng hoặc thẻ nhà mở form;
  // sau khi lưu phòng quay lại danh sách và hiện phản hồi thành công.
  Future<void> _openCreate(BuildContext context, {String? propertyId}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HostCreateScreen(
          propertyId: propertyId,
          startWithRoom: propertyId != null,
        ),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu phòng lên Firebase.')),
      );
    }
  }

  Future<void> _openEdit(BuildContext context, HostProperty property) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HostCreateScreen(propertyToEdit: property),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật thông tin cơ sở.')),
      );
    }
  }

  Future<void> _deleteProperty(
    BuildContext context,
    WidgetRef ref,
    PropertySummary summary,
  ) async {
    if (summary.rooms.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cơ sở còn ${summary.rooms.length} phòng. Hãy xóa các phòng trước.',
          ),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa cơ sở?'),
        content: Text(
          'Cơ sở “${summary.property.name}” sẽ bị xóa khỏi danh sách quản lý. Bạn có chắc muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa cơ sở'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(hostRepositoryProvider).deleteProperty(summary.property);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa cơ sở khỏi danh sách quản lý.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(hostErrorMessage(error))));
    }
  }

  // Chủ trọ - Phản hồi lỗi tải - Luồng đi: Không che lỗi bằng danh sách
  // mẫu; thử lại khởi động các stream phiên, nhà và phòng.
  Widget _error(WidgetRef ref, Object error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hostErrorMessage(error), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              ref.invalidate(hostSessionProvider);
              ref.invalidate(hostPropertiesProvider);
              ref.invalidate(hostRoomsProvider);
            },
            child: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );

  // Chủ trọ - Tổng quan thực - Luồng đi: Đếm phòng đã tạo theo cơ sở;
  // phòng đang thuê lấy status occupied, giữ chỗ và bảo trì nằm ở nhóm khác.
  Widget _overview(List<PropertySummary> summaries) {
    final total = summaries.fold(0, (sum, s) => sum + s.rooms.length);
    final rented = summaries.fold(0, (sum, s) => sum + s.rented);
    final vacant = summaries.fold(0, (sum, s) => sum + s.vacant);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, color: _blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tổng quan hệ thống',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              Text('Hiện tại', style: TextStyle(fontSize: 11, color: _blue)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metric(
                  'Tổng số',
                  total,
                  const Color(0xFFF0F4FF),
                  AppColors.textDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  'Đang thuê',
                  rented,
                  const Color(0xFFEAF9F1),
                  const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(
                  'Còn trống',
                  vacant,
                  const Color(0xFFFEF4EC),
                  const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          if (total > rented + vacant)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${total - rented - vacant} phòng ở trạng thái khác',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _metric(String label, int value, Color background, Color color) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const Text(
                  'phòng',
                  style: TextStyle(fontSize: 10, color: _muted),
                ),
              ],
            ),
          ],
        ),
      );

  // Chủ trọ - Thẻ nhà thực - Luồng đi: Hiển thị ảnh đã tải và số phòng
  // đã tạo; thu dự kiến từ phòng đang thuê, chưa thay thế báo cáo thanh toán.
  Widget _propertyCard(
    BuildContext context,
    WidgetRef ref,
    PropertySummary summary,
  ) {
    final p = summary.property;
    return Container(
      decoration: _decoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: p.images.isEmpty
                      ? _imageFallback()
                      : Image.network(
                          p.images.first,
                          webHtmlElementStrategy:
                              WebHtmlElementStrategy.fallback,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              _imageFallback(),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<_PropertyAction>(
                            key: ValueKey('property_menu_${p.id}'),
                            tooltip: 'Tùy chọn cơ sở',
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (action) async {
                              switch (action) {
                                case _PropertyAction.edit:
                                  await _openEdit(context, p);
                                  break;
                                case _PropertyAction.delete:
                                  await _deleteProperty(context, ref, summary);
                                  break;
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: _PropertyAction.edit,
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Sửa cơ sở'),
                                ),
                              ),
                              PopupMenuItem(
                                value: _PropertyAction.delete,
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.delete_outline,
                                    color: AppColors.danger,
                                  ),
                                  title: Text(
                                    'Xóa cơ sở',
                                    style: TextStyle(color: AppColors.danger),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.fullAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _badge(
                            '${summary.rooms.length}/${p.plannedRooms} phòng đã tạo',
                            const Color(0xFFF1F5F9),
                            AppColors.textDark,
                          ),
                          Text(
                            '${summary.rented} thuê',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF059669),
                            ),
                          ),
                          Text(
                            '${summary.vacant} trống',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFD97706),
                            ),
                          ),
                          if (summary.other > 0)
                            Text(
                              '${summary.other} khác',
                              style: const TextStyle(
                                fontSize: 10,
                                color: _muted,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Thu dự kiến: ',
                      style: const TextStyle(fontSize: 10, color: _muted),
                      children: [
                        TextSpan(
                          text: '${_money(summary.expectedRevenue)} đ/th',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _showRooms(context, summary),
                  child: const Text(
                    'Quản lý phòng',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Chủ trọ - Danh sách phòng trong nhà - Luồng đi: Bấm Quản lý phòng
  // mở màn danh sách riêng cập nhật trực tiếp, từ đó xem và sửa phòng.
  void _showRooms(BuildContext context, PropertySummary summary) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HostRoomListScreen(propertyId: summary.property.id),
      ),
    );
  }

  // Chủ trọ - Thành phần thẻ quản lý - Luồng đi: Dùng nền trắng,
  // viền mảnh và nhãn trạng thái thống nhất với giao diện HomeShare.
  Widget _imageFallback() => Container(
    width: 64,
    height: 64,
    color: const Color(0xFFEFF6FF),
    child: const Icon(Icons.apartment, color: _blue),
  );
  BoxDecoration _decoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFE9EEF5)),
  );
  Widget _badge(String text, Color background, Color foreground) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
    ),
  );
}
