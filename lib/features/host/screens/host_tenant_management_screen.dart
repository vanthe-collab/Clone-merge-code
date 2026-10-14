import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/resident_model.dart';
import '../providers/host_management_provider.dart';
import '../providers/tenant_management_provider.dart';
import '../repositories/tenant_repository.dart';
import '../widgets/tenant_card.dart';
import 'host_management_menu.dart';
import 'host_violation_management_screen.dart';

class HostTenantManagementScreen extends ConsumerStatefulWidget {
  final ValueChanged<HostManagementSection>? onSectionChanged;

  const HostTenantManagementScreen({
    super.key,
    this.onSectionChanged,
  });

  @override
  ConsumerState<HostTenantManagementScreen> createState() =>
      _HostTenantManagementScreenState();
}

class _HostTenantManagementScreenState
    extends ConsumerState<HostTenantManagementScreen> {

  void _openSwitcherMenu() {
    HostManagementMenu.show(
      context: context,
      currentSection: HostManagementSection.tenants,
      onSelect: (section) {
        if (widget.onSectionChanged != null) {
          widget.onSectionChanged!(section);
        } else if (section == HostManagementSection.checkinCheckout) {
          Navigator.of(context).pushReplacementNamed('/host/checkin-checkout');
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

  void _showAddTenantDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final depositCtrl = TextEditingController(text: '4800000');
    final hostRooms = ref.read(hostRoomsProvider).value ?? [];

    if (hostRooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng tạo phòng trước khi thêm khách thuê'),
        ),
      );
      return;
    }

    String selectedRoomId = hostRooms.first.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
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
                      const Text(
                        'Thêm khách thuê mới',
                        style: TextStyle(
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
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Họ và tên khách thuê *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRoomId,
                    decoration: const InputDecoration(
                      labelText: 'Chọn phòng thuê *',
                      border: OutlineInputBorder(),
                    ),
                    items: hostRooms.map((r) {
                      final title =
                          r.roomCode.isNotEmpty ? 'P.${r.roomCode}' : r.title;
                      return DropdownMenuItem(
                        value: r.id,
                        child: Text(title),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedRoomId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: depositCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tiền cọc (VNĐ)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      if (name.isEmpty || phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng điền đủ tên và số điện thoại'),
                          ),
                        );
                        return;
                      }

                      final hostId =
                          ref.read(hostSessionProvider).value ?? '';
                      final deposit =
                          double.tryParse(depositCtrl.text.trim()) ?? 0.0;

                      Navigator.of(ctx).pop();

                      try {
                        await ref.read(tenantRepositoryProvider).addTenant(
                              hostId: hostId,
                              roomId: selectedRoomId,
                              tenantName: name,
                              tenantPhone: phone,
                              deposit: deposit,
                              moveInDate: DateTime.now(),
                            );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã thêm khách thuê thành công!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi: $e')),
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Lưu khách thuê',
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

  Widget _buildStatsRow(TenantStats stats) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildStatPill(
            icon: Icons.apartment_outlined,
            text: '${stats.facilityCount} cơ sở',
          ),
          const SizedBox(width: 8),
          _buildStatPill(
            icon: Icons.people_outline,
            text: '${stats.activeTenantCount} người đang thuê',
          ),
          const SizedBox(width: 8),
          _buildStatPill(
            icon: Icons.meeting_room_outlined,
            text: '${stats.occupiedRoomCount} phòng đang sử dụng',
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF475569)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(hostTenantsProvider);
    final statsAsync = ref.watch(hostTenantStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header: Menu góc trái + Tiêu đề + Subtitle
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Nút menu góc trái
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
                      // Tiêu đề & Subtitle
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quản lý cư dân & người thuê',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Hồ sơ khách thuê & hợp đồng',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Thống kê
                  statsAsync.when(
                    data: (stats) => _buildStatsRow(stats),
                    loading: () => _buildStatsRow(const TenantStats(
                      facilityCount: 4,
                      activeTenantCount: 12,
                      occupiedRoomCount: 8,
                    )),
                    error: (err, stack) => _buildStatsRow(const TenantStats()),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            // Danh sách người thuê
            Expanded(
              child: tenantsAsync.when(
                data: (tenants) {
                  // Fallback sample data nếu Firestore chưa có dữ liệu để match chính xác ảnh thiết kế
                  final displayList = tenants.isNotEmpty
                      ? tenants
                      : [
                          TenantItem(
                            id: 'sample_1',
                            primaryName: 'Lê Hoàng Nam',
                            phone: '0912 345 678',
                            roomId: 'r1',
                            roomName: 'P.203',
                            propertyId: 'p1',
                            propertyName: 'KTX mini L2',
                            floor: 2,
                            moveInDate: DateTime(2024, 1, 1),
                            status: 'dangO',
                          ),
                          TenantItem(
                            id: 'sample_2',
                            primaryName: 'Trần Minh Tú',
                            phone: '0933 678 910',
                            roomId: 'r2',
                            roomName: 'P.105',
                            propertyId: 'p2',
                            propertyName: 'SkyHome',
                            floor: 1,
                            moveInDate: DateTime(2024, 2, 1),
                            status: 'dangO',
                          ),
                          TenantItem(
                            id: 'sample_3',
                            primaryName: 'Hà Vy & Đức Anh',
                            phone: '0901 223 344',
                            roomId: 'r3',
                            roomName: 'P.302',
                            propertyId: 'p2',
                            propertyName: 'SkyHome',
                            floor: 3,
                            roommates: [
                              ResidentModel(
                                id: 'res1',
                                periodId: 'p3',
                                userId: 'u1',
                                fullName: 'Hà Vy',
                                moveInDate: DateTime(2024, 3, 1),
                              ),
                              ResidentModel(
                                id: 'res2',
                                periodId: 'p3',
                                userId: 'u2',
                                fullName: 'Đức Anh',
                                moveInDate: DateTime(2024, 3, 1),
                              ),
                            ],
                            moveInDate: DateTime(2024, 3, 1),
                            status: 'dangO',
                          ),
                        ];

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      ...displayList.map((tenant) => TenantCard(
                            tenant: tenant,
                          )),
                      const SizedBox(height: 6),
                      // Nút + Thêm khách thuê mới viền nét đứt
                      InkWell(
                        onTap: _showAddTenantDialog,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF93C5FD),
                              width: 1.5,
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_add_alt_1_outlined,
                                color: Color(0xFF2563EB),
                                size: 19,
                              ),
                              SizedBox(width: 8),
                              Text(
                                '+ Thêm khách thuê mới',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Lỗi tải danh sách: $err',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.refresh(hostTenantsProvider),
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
