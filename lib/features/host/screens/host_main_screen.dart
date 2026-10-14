import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../chat/screens/chat_list_screen.dart';
import '../../home/screens/home_screen.dart';
import 'host_dashboard_screen.dart';
import 'host_property_management_screen.dart';
import 'host_create_screen.dart';
import 'host_create_post_screen.dart';
import 'host_tenant_management_screen.dart';
import 'host_checkin_checkout_screen.dart';
import 'host_violation_management_screen.dart';
import 'host_management_menu.dart';

// Chủ trọ - Khung điều hướng - Luồng đi: Mở Dashboard và giữ trạng thái
// của 5 tab; các tab chưa triển khai hiển thị màn hình tạm.
class HostMainScreen extends StatefulWidget {
  const HostMainScreen({super.key});

  @override
  State<HostMainScreen> createState() => _HostMainScreenState();
}

class _HostMainScreenState extends State<HostMainScreen> {
  int _currentIndex = 0;
  int _managementIndex = 0;
  HostManagementSection _hostManagementSection = HostManagementSection.tenants;
  static const _labels = [
    'Trang chủ',
    'Tin nhắn',
    'Tạo mới',
    'Quản lý',
    'Cá nhân',
  ];
  static const _icons = [
    Icons.home_outlined,
    Icons.chat_bubble_outline,
    Icons.add,
    Icons.grid_view_outlined,
    Icons.person_outline,
  ];

  // Chủ trọ - Chuyển tab - Luồng đi: Chạm bottom nav để đổi màn hình
  // trong IndexedStack; Dấu cộng mở tạo bài đăng; Quản lý mở cơ sở và đổi sang bottom nav quản lý.
  void _selectTab(int index) {
    if (index == 2) {
      _openCreatePost();
      return;
    }
    setState(() {
      _currentIndex = index;
      if (index == 3) _managementIndex = 0;
    });
  }

  // Chủ trọ - Mở màn Tạo bài đăng
  Future<void> _openCreatePost() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const HostCreatePostScreen()),
    );
    if (!mounted) return;
    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã tạo bài đăng thành công!')),
      );
    }
  }

  // Chủ trọ - Điều hướng quản lý - Luồng đi: Chọn chức năng trong khu
  // quản lý; Quay lại trở về Dashboard và giữ trạng thái khu vực đã chọn.
  void _selectManagementTab(int index) {
    if (index == 2) {
      _openCreate();
      return;
    }
    setState(() {
      if (index == 4) {
        _currentIndex = 0;
      } else {
        _managementIndex = index;
      }
    });
  }

  // Chủ trọ - Mở màn tạo nhà/phòng - Luồng đi: Dấu cộng trong bottom
  // nav quản lý mở route riêng; lưu xong trở về Thông tin chung.
  Future<void> _openCreate() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const HostCreateScreen()));
    if (!mounted) return;
    if (saved == true) {
      setState(() => _managementIndex = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu phòng lên Firebase.')),
      );
    }
  }

  Widget _buildActiveManagementSection() {
    if (_hostManagementSection == HostManagementSection.checkinCheckout) {
      return HostCheckinCheckoutScreen(
        onSectionChanged: (sec) {
          setState(() => _hostManagementSection = sec);
        },
      );
    }
    if (_hostManagementSection == HostManagementSection.violations) {
      return HostViolationManagementScreen(
        onSectionChanged: (sec) {
          setState(() => _hostManagementSection = sec);
        },
      );
    }
    return HostTenantManagementScreen(
      onSectionChanged: (sec) {
        setState(() => _hostManagementSection = sec);
      },
    );
  }

  // Chủ trọ - Bottom nav quản lý - Luồng đi: Thông tin chung mở danh
  // sách cơ sở; dấu cộng mở tạo nhà/phòng; nút cuối về Dashboard.
  Widget _buildManagementNavigation() {
    const labels = [
      'Thông tin chung',
      'QL người thuê',
      'Thêm mới',
      'QL Tiền tệ',
      'Quay lại',
    ];
    const icons = [
      Icons.home_outlined,
      Icons.people_outline,
      Icons.add,
      Icons.credit_card,
      Icons.arrow_back,
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(labels.length, (index) {
              final selected = index == _managementIndex;
              final color = selected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF64748B);
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: labels[index],
                  child: InkWell(
                    onTap: () => _selectManagementTab(index),
                    child: index == 2
                        ? Center(
                            heightFactor: 1,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x662563EB),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icons[index], color: color, size: 20),
                                const SizedBox(height: 4),
                                Text(
                                  labels[index],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // Chủ trọ - Hiển thị khung chủ trọ - Luồng đi: Dashboard là tab mặc định;
  // IndexedStack giữ trạng thái giao diện khi chuyển qua lại giữa các tab.
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex != 3,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _selectManagementTab(4);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            const HostDashboardScreen(),
            const ChatListScreen(),
            const HostCreatePostScreen(),
            IndexedStack(
              index: _managementIndex,
              children: [
                const HostPropertyManagementScreen(),
                _buildActiveManagementSection(),
                const _HostPlaceholderScreen(
                  title: 'Thêm mới',
                  icon: Icons.add_home_outlined,
                ),
                const _HostPlaceholderScreen(
                  title: 'Tiền tệ',
                  icon: Icons.credit_card,
                ),
              ],
            ),
            const HomeScreen(),
          ],
        ),
        bottomNavigationBar: _currentIndex == 3
            ? _buildManagementNavigation()
            : Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5EBF1))),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: List.generate(_labels.length, (index) {
                      final selected = _currentIndex == index;
                      return Expanded(
                        child: Semantics(
                          selected: selected,
                          button: true,
                          label: _labels[index],
                          child: InkWell(
                            onTap: () => _selectTab(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (index == 2)
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF1673C8),
                                            AppColors.primary,
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    )
                                  else
                                    Icon(
                                      _icons[index],
                                      color: selected
                                          ? AppColors.primary
                                          : const Color(0xFF92A4BE),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _labels[index],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: selected
                                          ? AppColors.primary
                                          : const Color(0xFF92A4BE),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
      ),
    );
  }
}

// Chủ trọ - Màn hình tạm - Luồng đi: Nhận tên tab từ khung điều hướng;
// thay widget này bằng màn hình thật khi triển khai từng Sprint.
class _HostPlaceholderScreen extends StatelessWidget {
  const _HostPlaceholderScreen({required this.title, required this.icon});
  final String title;
  final IconData icon;

  // Chủ trọ - Hiển thị tab tạm - Luồng đi: Đứng tại tab đã chọn;
  // người dùng dùng bottom nav để trở về Dashboard hoặc chuyển tab khác.
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Màn hình sẽ được bổ sung sau.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
