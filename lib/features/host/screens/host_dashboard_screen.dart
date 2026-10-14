import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/vietnam_locations.dart';
import '../../../core/utils/vietnamese_utils.dart';
import '../../../data/models/host_post_model.dart';
import '../../auth/providers/user_provider.dart';
import '../data/host_post_repository.dart';
import '../providers/host_amenity_provider.dart';
import '../providers/host_home_provider.dart';
import '../widgets/host_post_card.dart';
import '../notifications/screens/host_notifications_screen.dart';

/// Màn hình Bảng tin Chủ trọ (Host Dashboard):
/// - Lọc khu vực dạng spinner/dropdown xổ xuống danh sách đầy đủ tất cả các tỉnh thành
///   trên bản đồ Việt Nam (63 tỉnh/thành + Toàn quốc), đối chiếu lọc với Firebase.
/// - Khi mở bộ lọc nâng cao, thanh khu vực bên ngoài tự động ẩn đi và tái sử dụng bên trong mục 1.
/// - Tiện ích lấy trực tiếp từ bảng tiện ích (Firestore 'amenities' qua hostAmenityNamesProvider).
/// - Sắp xếp kết quả:
///   + "Mới nhất" và "Được quan tâm nhất" là dạng Checkbox (có thể chọn cùng lúc).
///   + "Giá thấp đến cao" và "Giá cao đến thấp" là dạng Radio (chỉ chọn 1 trong 2).
/// - Theme xanh dương (Primary Blue) sang trọng, nhất quán.
class HostDashboardScreen extends ConsumerStatefulWidget {
  final bool initialLocationExpanded;

  const HostDashboardScreen({
    super.key,
    this.initialLocationExpanded = false,
  });

  @override
  ConsumerState<HostDashboardScreen> createState() =>
      _HostDashboardScreenState();
}

class _HostDashboardScreenState extends ConsumerState<HostDashboardScreen> {
  // Theme màu xanh dương chủ đạo theo yêu cầu người dùng
  static const Color _primaryBlue = Color(0xFF155EEF);
  static const Color _softBlueBg = Color(0xFFEFF6FF);
  static const Color _softBlueBorder = Color(0xFFBFDBFE);
  static const Color _borderGray = Color(0xFFE2E8F0);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF475569);
  static const Color _textMuted = Color(0xFF94A3B8);

  // Danh sách các khu vực hardcoded theo bản đồ Việt Nam đầy đủ 63 tỉnh/thành
  static const List<String> _hardcodedLocations = [
    'Tất cả khu vực (Toàn quốc)',
    ...VietnamLocations.provinces63,
  ];

  final _searchController = TextEditingController();
  final _locationSearchController = TextEditingController();
  final _customRequirementController = TextEditingController();
  final _locationScrollController = ScrollController();

  Timer? _debounceTimer;
  late bool _isLocationExpanded = widget.initialLocationExpanded;
  bool _isAdvancedFilterExpanded = false;
  bool _isAmenitiesExpanded = false;

  // Trạng thái khu vực: mới vào trang chủ hiển thị "Tất cả khu vực"
  final Set<String> _tempSelectedLocations = {'Tất cả khu vực (Toàn quốc)'};
  String _appliedLocationsLabel = 'Tất cả khu vực';

  // Trạng thái bộ lọc nâng cao tạm thời: mặc định 0 - 20 triệu, không giới hạn tiện ích
  RangeValues _priceRangeValues = const RangeValues(0, 20000000);
  final Set<String> _tempSelectedAmenities = <String>{};
  final List<String> _tempCustomRequirements = <String>[];
  final Set<String> _tempSelectedCustomRequirements = <String>{};

  // Sắp xếp:
  // - "Mới nhất" và "Được quan tâm nhất": Checkbox (chọn cùng lúc được)
  // - "Giá thấp đến cao" và "Giá cao đến thấp": Radio (luôn chọn 1 trong 2)
  bool _tempSortNewest = true;
  bool _tempSortMostInterested = false;
  HostPriceSort _tempPriceSort = HostPriceSort.ascending;

  @override
  void initState() {
    super.initState();
    // Mới vào trang chủ: hiển thị tất cả bài đăng các khu vực, không áp đặt tiêu chí lọc hạn chế
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hostHomeFilterProvider.notifier).resetFilters();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _locationSearchController.dispose();
    _customRequirementController.dispose();
    _locationScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(hostHomeFilterProvider.notifier).setSearchQuery(query.trim());
      }
    });
  }

  void _toggleLocationPanel() {
    setState(() {
      _isLocationExpanded = !_isLocationExpanded;
      if (_isLocationExpanded) {
        _isAdvancedFilterExpanded = false;
      }
    });
  }

  void _toggleAdvancedFilterPanel() {
    setState(() {
      _isAdvancedFilterExpanded = !_isAdvancedFilterExpanded;
      if (_isAdvancedFilterExpanded) {
        // Khi mở Nâng cao, đóng panel dropdown khu vực bên ngoài
        _isLocationExpanded = false;
      }
    });
  }

  void _toggleLocationItem(String location) {
    final isAll = location.contains('Toàn quốc');
    setState(() {
      if (isAll) {
        if (_tempSelectedLocations.contains(location)) {
          _tempSelectedLocations.remove(location);
        } else {
          _tempSelectedLocations.clear();
          _tempSelectedLocations.add(location);
        }
      } else {
        _tempSelectedLocations.remove('Tất cả khu vực (Toàn quốc)');
        if (_tempSelectedLocations.contains(location)) {
          _tempSelectedLocations.remove(location);
        } else {
          _tempSelectedLocations.add(location);
        }
      }
    });
  }

  void _clearLocations() {
    setState(() {
      _tempSelectedLocations.clear();
    });
  }

  void _applyLocations() {
    setState(() {
      final specificLocations = _tempSelectedLocations
          .where((l) => !l.contains('Toàn quốc'))
          .toList();

      if (_tempSelectedLocations.contains('Tất cả khu vực (Toàn quốc)') ||
          specificLocations.isEmpty) {
        _appliedLocationsLabel = 'Tất cả khu vực';
      } else {
        _appliedLocationsLabel =
            '${specificLocations.join(', ')} (${specificLocations.length})';
      }
      _isLocationExpanded = false;
    });

    ref.read(hostHomeFilterProvider.notifier).setSelectedLocations(
          _tempSelectedLocations.contains('Tất cả khu vực (Toàn quốc)')
              ? {}
              : _tempSelectedLocations,
        );
  }

  void _applyAdvancedFilter() {
    setState(() {
      final specificLocations = _tempSelectedLocations
          .where((l) => !l.contains('Toàn quốc'))
          .toList();

      if (_tempSelectedLocations.contains('Tất cả khu vực (Toàn quốc)') ||
          specificLocations.isEmpty) {
        _appliedLocationsLabel = 'Tất cả khu vực';
      } else {
        _appliedLocationsLabel =
            '${specificLocations.join(', ')} (${specificLocations.length})';
      }
      _isAdvancedFilterExpanded = false;
    });

    final locationsToApply =
        _tempSelectedLocations.contains('Tất cả khu vực (Toàn quốc)')
            ? <String>{}
            : _tempSelectedLocations;

    ref.read(hostHomeFilterProvider.notifier).applyAllFilters(
          selectedLocations: locationsToApply,
          minPrice: _priceRangeValues.start > 0 ? _priceRangeValues.start : null,
          maxPrice:
              _priceRangeValues.end < 20000000 ? _priceRangeValues.end : null,
          selectedAmenities: _tempSelectedAmenities,
          customRequirements: _tempSelectedCustomRequirements.toList(),
          sortNewest: _tempSortNewest,
          sortMostInterested: _tempSortMostInterested,
          priceSort: _tempPriceSort,
          clearPriceSort: false,
        );
  }

  void _resetAdvancedFilter() {
    setState(() {
      _tempSelectedLocations.clear();
      _tempSelectedLocations.add('Tất cả khu vực (Toàn quốc)');
      _appliedLocationsLabel = 'Tất cả khu vực';
      _priceRangeValues = const RangeValues(0, 20000000);
      _tempSelectedAmenities.clear();
      _tempCustomRequirements.clear();
      _tempSelectedCustomRequirements.clear();
      _tempSortNewest = true;
      _tempSortMostInterested = false;
      _tempPriceSort = HostPriceSort.ascending;
      _isAmenitiesExpanded = false;
      _locationSearchController.clear();
      _customRequirementController.clear();
    });

    ref.read(hostHomeFilterProvider.notifier).resetFilters();
  }

  Future<void> _handleRefresh() async {
    ref.invalidate(hostHomePostsProvider);
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleAddCustomRequirement(List<String> amenityNames) {
    final raw = _customRequirementController.text;
    final normalized = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return;

    final normalizedInput = normalizeVietnameseComparison(normalized);

    // 1. Kiểm tra chống trùng với danh mục tiện ích sẵn có từ Firestore (không phân biệt dấu tiếng Việt, hoa/thường)
    final catalogMatch = amenityNames.where((item) {
      return normalizeVietnameseComparison(item) == normalizedInput;
    }).firstOrNull;

    if (catalogMatch != null) {
      setState(() {
        if (!_tempSelectedAmenities.contains(catalogMatch)) {
          _tempSelectedAmenities.add(catalogMatch);
        }
        _customRequirementController.clear();
        _isAmenitiesExpanded = true;
      });
      _showNotice(
        'Tiện ích "$catalogMatch" đã có trong danh mục (đã tự động chọn).',
      );
      return;
    }

    // 2. Kiểm tra chống trùng với tiện ích tùy chọn đã thêm trước đó
    final customMatch = _tempCustomRequirements.where((item) {
      return normalizeVietnameseComparison(item) == normalizedInput;
    }).firstOrNull;

    if (customMatch != null) {
      setState(() {
        if (!_tempSelectedCustomRequirements.contains(customMatch)) {
          _tempSelectedCustomRequirements.add(customMatch);
        }
        _customRequirementController.clear();
        _isAmenitiesExpanded = true;
      });
      _showNotice('Tiện ích tùy chọn "$customMatch" đã tồn tại.');
      return;
    }

    // 3. Thêm mới vào danh sách tùy chọn
    setState(() {
      _tempCustomRequirements.add(normalized);
      _tempSelectedCustomRequirements.add(normalized);
      _customRequirementController.clear();
      _isAmenitiesExpanded = true;
    });
  }

  String _formatCurrency(num value) {
    final formatted =
        NumberFormat.decimalPattern('vi').format(value.toInt());
    return '$formattedđ';
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final filterState = ref.watch(hostHomeFilterProvider);
    final postsAsync = ref.watch(hostHomePostsProvider);
    // Lấy danh sách tiện ích trực tiếp từ bảng tiện ích (Firestore 'amenities')
    final amenityNames = ref.watch(hostAmenityNamesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: _primaryBlue,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Header Figma: Logo, Tên, Xác minh/VIP, Avatar, Chuông thông báo
              _buildHeader(profile),
              const SizedBox(height: 14),

              // 2. Thanh tìm kiếm (debounce) & Nút Nâng cao (theme xanh dương)
              _buildSearchBar(),
              const SizedBox(height: 12),

              // 3. Thanh hiển thị khu vực: KHI ẤN NÂNG CAO THÌ ẨN KHU VỰC NÀY ĐI
              if (!_isAdvancedFilterExpanded) ...[
                _buildLocationCard(),
                if (_isLocationExpanded) ...[
                  const SizedBox(height: 8),
                  _buildStandaloneLocationDropdown(),
                ],
                const SizedBox(height: 10),
              ],

              // 4. Panel Bộ lọc nâng cao (ảnh 2, 3) dùng lại lọc khu vực bên trong
              if (_isAdvancedFilterExpanded) ...[
                _buildAdvancedFilterPanel(amenityNames),
                const SizedBox(height: 14),
              ],

              // 5. Thẻ chào & Trạng thái bảng tin
              _buildWelcomeCard(profile),
              const SizedBox(height: 14),

              // 6. Danh sách Bài đăng đối chiếu Firebase
              _buildFeedContent(postsAsync, filterState),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Header HomeShare
  Widget _buildHeader(UserProfile? profile) {
    final hostName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : 'Chủ trọ';
    final isVip = profile != null &&
        (profile.reputationScore >= 80 || profile.isCccdVerified);
    final avatarUrl = profile?.avatarUrl ?? '';
    final initials = hostName.isNotEmpty
        ? hostName.trim().split(' ').last.substring(0, 1).toUpperCase()
        : 'HS';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primaryBlue,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.home, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'HomeShare',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (isVip)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF59E0B)),
                      ),
                      child: const Text(
                        'Chủ trọ VIP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Mạng lưới Đối tác & Chủ trọ • $hostName',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF65758F),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Stack(
          children: [
            IconButton(
              tooltip: 'Thông báo',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HostNotificationsScreen(),
                  ),
                );
              },
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF475569),
                size: 26,
              ),
            ),
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
        CircleAvatar(
          radius: 18,
          backgroundColor: _softBlueBg,
          child: avatarUrl.isNotEmpty && avatarUrl.startsWith('http')
              ? ClipOval(
                  child: Image.network(
                    avatarUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Text(
                      initials,
                      style: const TextStyle(
                        color: _primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              : Text(
                  initials,
                  style: const TextStyle(
                    color: _primaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
        ),
      ],
    );
  }

  // 2. Thanh tìm kiếm & Nút Nâng cao (Màu xanh dương)
  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderGray),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm bài đăng, chủ trọ, đối tác...',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: _textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(hostHomeFilterProvider.notifier)
                              .setSearchQuery('');
                        },
                      )
                    : null,
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _primaryBlue,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            elevation: 0,
          ),
          onPressed: _toggleAdvancedFilterPanel,
          icon: const Icon(
            Icons.tune_rounded,
            size: 17,
            color: Colors.white,
          ),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Nâng cao',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                _isAdvancedFilterExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 3. Thẻ khu vực dạng spinner hiển thị (Ảnh 1)
  Widget _buildLocationCard() {
    return InkWell(
      onTap: _toggleLocationPanel,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderGray),
        ),
        child: Row(
          children: [
            const Text(
              'Khu vực:',
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _softBlueBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _softBlueBorder),
                ),
                child: Text(
                  _appliedLocationsLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _isLocationExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: _primaryBlue,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // Dropdown khu vực độc lập khi click thẻ khu vực bên ngoài (Ảnh 1)
  Widget _buildStandaloneLocationDropdown() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildLocationSelectorWidget(
        isInsideAdvancedFilter: false,
      ),
    );
  }

  /// Thành phần lọc khu vực dùng chung cho cả Dropdown ngoài (Ảnh 1)
  /// và Bộ lọc nâng cao (Ảnh 2).
  /// Hiển thị đầy đủ tất cả 63 tỉnh thành Việt Nam + Toàn quốc.
  Widget _buildLocationSelectorWidget({
    required bool isInsideAdvancedFilter,
  }) {
    final query = _locationSearchController.text.trim().toLowerCase();
    final filteredLocations = _hardcodedLocations.where((loc) {
      if (query.isEmpty) return true;
      return loc.toLowerCase().contains(query);
    }).toList();

    final selectedCount = _tempSelectedLocations
        .where((l) => !l.contains('Toàn quốc'))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ô tìm nhanh tỉnh/thành phố
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _borderGray),
          ),
          child: TextField(
            controller: _locationSearchController,
            onChanged: (val) => setState(() {}),
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: 'Tìm nhanh tỉnh/thành phố...',
              hintStyle: const TextStyle(
                fontSize: 12,
                color: _textMuted,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF94A3B8),
                size: 18,
              ),
              suffixIcon: _locationSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _locationSearchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Danh sách các khu vực có checkbox (Đầy đủ tất cả khu vực VN)
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: Scrollbar(
            controller: _locationScrollController,
            thumbVisibility: true,
            child: ListView.separated(
              controller: _locationScrollController,
              shrinkWrap: true,
              itemCount: filteredLocations.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final location = filteredLocations[index];
                final isAll = location.contains('Toàn quốc');
                final isSelected = _tempSelectedLocations.contains(location);

                return InkWell(
                  onTap: () => _toggleLocationItem(location),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected && !isAll
                          ? _softBlueBg
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected && !isAll
                            ? _primaryBlue
                            : _borderGray,
                        width: isSelected && !isAll ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Checkbox custom vuông bo góc
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isSelected ? _primaryBlue : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? _primaryBlue
                                  : const Color(0xFFCBD5E1),
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 15,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? (isAll ? _textDark : _primaryBlue)
                                  : _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Hàng nút dưới cùng
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _clearLocations,
              child: const Text(
                'Bỏ chọn tất cả',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _textSecondary,
                ),
              ),
            ),
            if (!isInsideAdvancedFilter)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  elevation: 0,
                ),
                onPressed: _applyLocations,
                child: Text(
                  'Áp dụng ($selectedCount khu vực)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // 4. Panel Bộ lọc nâng cao (Ảnh 2, 3)
  Widget _buildAdvancedFilterPanel(List<String> amenityNames) {
    final selectedLocationsCount = _tempSelectedLocations
        .where((l) => !l.contains('Toàn quốc'))
        .length;
    final totalSelectedAmenities =
        _tempSelectedAmenities.length + _tempSelectedCustomRequirements.length;

    // Danh sách tiện ích lấy từ Firestore: mặc định hiển thị 4 tiện ích đầu + các tiện ích đã chọn
    final displayedAmenities = _isAmenitiesExpanded
        ? amenityNames
        : {
            ...amenityNames.take(4),
            ...amenityNames.where((a) => _tempSelectedAmenities.contains(a)),
          }.toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ================= MỤC 1. KHU VỰC TÌM KIẾM =================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _primaryBlue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        '1. Khu vực tìm kiếm',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _softBlueBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _softBlueBorder),
                ),
                child: Text(
                  'Đã chọn ($selectedLocationsCount)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Tái sử dụng chính widget lọc khu vực (nút áp dụng sẽ áp dụng toàn bộ ở cuối)
          _buildLocationSelectorWidget(
            isInsideAdvancedFilter: true,
          ),
          const Divider(height: 24),

          // ================= MỤC 2. GIÁ THUÊ / THÁNG =================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _primaryBlue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Giá thuê / tháng',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatCurrency(_priceRangeValues.start)} – ${_formatCurrency(_priceRangeValues.end)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2 ô Tối thiểu & Tối đa
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _borderGray),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tối thiểu',
                        style: TextStyle(fontSize: 11, color: _textSecondary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatCurrency(_priceRangeValues.start),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _borderGray),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tối đa',
                        style: TextStyle(fontSize: 11, color: _textSecondary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatCurrency(_priceRangeValues.end),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Range Slider
          RangeSlider(
            values: _priceRangeValues,
            min: 0,
            max: 20000000,
            divisions: 40,
            activeColor: _primaryBlue,
            inactiveColor: const Color(0xFFE2E8F0),
            onChanged: (values) {
              setState(() => _priceRangeValues = values);
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0đ',
                  style: TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '20.000.000đ',
                  style: TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24),

          // ================= MỤC 3. TIỆN ÍCH & YÊU CẦU (TỪ FIRESTORE) =================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_rounded,
                      size: 18,
                      color: _primaryBlue,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Tiện ích & Yêu cầu',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _softBlueBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _softBlueBorder),
                ),
                child: Text(
                  '$totalSelectedAmenities đang chọn',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Ô thêm tiện ích riêng
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _borderGray),
                  ),
                  child: TextField(
                    controller: _customRequirementController,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: const InputDecoration(
                      hintText: 'Thêm tiện ích, yêu cầu riêng...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: _textMuted,
                      ),
                      prefixIcon: Icon(
                        Icons.add_circle_outline_rounded,
                        color: Color(0xFF94A3B8),
                        size: 18,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onSubmitted: (_) => _handleAddCustomRequirement(amenityNames),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  elevation: 0,
                ),
                onPressed: () => _handleAddCustomRequirement(amenityNames),
                child: const Text(
                  'Thêm',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Danh sách các tiện ích & yêu cầu tuỳ chọn (lấy từ bảng tiện ích)
          Column(
            children: [
              // 1. Tiện ích từ bảng Firestore
              for (final amenity in displayedAmenities)
                _buildAmenityCard(
                  name: amenity,
                  isSelected: _tempSelectedAmenities.contains(amenity),
                  isCustom: false,
                  onToggle: () {
                    setState(() {
                      if (_tempSelectedAmenities.contains(amenity)) {
                        _tempSelectedAmenities.remove(amenity);
                      } else {
                        _tempSelectedAmenities.add(amenity);
                      }
                    });
                  },
                ),

              // 2. Tiện ích tự nhập tùy chọn (có thể chọn check hoặc bỏ check tùy ý)
              for (final customReq in _tempCustomRequirements)
                _buildAmenityCard(
                  name: customReq,
                  isSelected: _tempSelectedCustomRequirements.contains(customReq),
                  isCustom: true,
                  onToggle: () {
                    setState(() {
                      if (_tempSelectedCustomRequirements.contains(customReq)) {
                        _tempSelectedCustomRequirements.remove(customReq);
                      } else {
                        _tempSelectedCustomRequirements.add(customReq);
                      }
                    });
                  },
                  onRemove: () {
                    setState(() {
                      _tempCustomRequirements.remove(customReq);
                      _tempSelectedCustomRequirements.remove(customReq);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Nút Thu gọn / Xem thêm tiện ích full-width đúng chuẩn UI Figma (Ảnh 2)
          if (amenityNames.length > 4)
            InkWell(
              key: const ValueKey('amenities_toggle_button'),
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  setState(() => _isAmenitiesExpanded = !_isAmenitiesExpanded),
              child: Container(
                width: double.infinity,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  _isAmenitiesExpanded ? 'Thu gọn ^' : 'Xem thêm v',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E60F2),
                  ),
                ),
              ),
            ),
          const Divider(height: 20),

          // ================= MỤC 4. SẮP XẾP KẾT QUẢ =================
          // "Mới nhất", "Được quan tâm nhất" là Checkbox (CHỌN ĐỒNG THỜI CÙNG LÚC ĐƯỢC)
          // "Giá thấp đến cao", "Giá cao đến thấp" là Radio (LUÔN CHỌN 1 TRONG 2)
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: _primaryBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Sắp xếp kết quả',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Hàng 1: Dạng Checkbox ("Mới nhất", "Được quan tâm nhất") - Chọn cùng lúc được
          Row(
            children: [
              Expanded(
                child: _buildSortCheckboxCard(
                  'Mới nhất',
                  isSelected: _tempSortNewest,
                  onToggle: () {
                    setState(() => _tempSortNewest = !_tempSortNewest);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSortCheckboxCard(
                  'Được quan tâm nhất',
                  isSelected: _tempSortMostInterested,
                  onToggle: () {
                    setState(() =>
                        _tempSortMostInterested = !_tempSortMostInterested);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Hàng 2: Dạng Radio ("Giá thấp đến cao", "Giá cao đến thấp") - Luôn chọn 1 trong 2
          Row(
            children: [
              Expanded(
                child: _buildSortRadioCard(
                  'Giá thấp đến cao',
                  isSelected: _tempPriceSort == HostPriceSort.ascending,
                  onTap: () {
                    setState(() {
                      _tempPriceSort = HostPriceSort.ascending;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSortRadioCard(
                  'Giá cao đến thấp',
                  isSelected: _tempPriceSort == HostPriceSort.descending,
                  onTap: () {
                    setState(() {
                      _tempPriceSort = HostPriceSort.descending;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ================= NÚT ĐẶT LẠI & ÁP DỤNG BỘ LỌC =================
          Row(
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(90, 46),
                  side: const BorderSide(color: _borderGray),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _resetAdvancedFilter,
                child: const Text(
                  'Đặt lại',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _primaryBlue,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _applyAdvancedFilter,
                  icon: const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Áp dụng bộ lọc',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Thẻ tiện ích theo phong cách ảnh 3
  Widget _buildAmenityCard({
    required String name,
    required bool isSelected,
    required bool isCustom,
    required VoidCallback onToggle,
    VoidCallback? onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _softBlueBg : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? _primaryBlue : _borderGray,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? _primaryBlue : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected
                        ? _primaryBlue
                        : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? _primaryBlue : _textDark,
                  ),
                ),
              ),
              if (isCustom) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Tùy chọn',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: onRemove,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                ),
              ] else if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _softBlueBorder),
                  ),
                  child: const Text(
                    'Đã chọn',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _primaryBlue,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Thẻ sắp xếp DẠNG CHECK BOX (Mới nhất, Được quan tâm nhất - chọn cùng lúc được)
  Widget _buildSortCheckboxCard(
    String label, {
    required bool isSelected,
    required VoidCallback onToggle,
  }) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? _softBlueBg : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _primaryBlue : _borderGray,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Checkbox vuông bo góc
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: isSelected ? _primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: isSelected ? _primaryBlue : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? _primaryBlue : _textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Thẻ sắp xếp DẠNG RADIO (Giá thấp đến cao, Giá cao đến thấp - chỉ chọn 1 trong 2)
  Widget _buildSortRadioCard(
    String label, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? _softBlueBg : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _primaryBlue : _borderGray,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Radio button tròn
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _primaryBlue : const Color(0xFFCBD5E1),
                  width: 1.8,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: _primaryBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? _primaryBlue : _textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(UserProfile? profile) {
    return Container(
      decoration: BoxDecoration(
        color: _softBlueBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _softBlueBorder),
      ),
      padding: const EdgeInsets.all(12),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFDBEAFE),
            radius: 18,
            child: Icon(Icons.people_alt, color: _primaryBlue, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bảng tin kết nối chia sẻ khách thuê & hợp tác quản lý phòng trọ.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Danh sách feed hoặc các trạng thái Loading / Empty / Error / Retry
  Widget _buildFeedContent(
    AsyncValue<List<HostPostModel>> postsAsync,
    HostHomeFilterState filterState,
  ) {
    return postsAsync.when(
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorState(error),
      data: (posts) {
        if (posts.isEmpty) {
          final hasSpecificLocation = filterState.selectedLocations.isNotEmpty &&
              !filterState.selectedLocations.any((l) =>
                  l.toLowerCase().contains('toàn quốc') ||
                  l.toLowerCase().contains('tất cả'));
          final isFiltering = filterState.searchQuery.isNotEmpty ||
              hasSpecificLocation ||
              filterState.minPrice != null ||
              filterState.maxPrice != null ||
              filterState.selectedAmenities.isNotEmpty ||
              filterState.customRequirements.isNotEmpty;

          return isFiltering
              ? _buildNoFilterResultState()
              : _buildEmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  const Text(
                    'Bài đăng từ đối tác',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _softBlueBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${posts.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            for (final post in posts)
              HostPostCard(
                key: ValueKey(post.id),
                post: post,
                onInterestPressed: () async {
                  final profile = ref.read(userProfileProvider).value;
                  final uid = profile?.uid ?? '';
                  if (uid.isEmpty) {
                    _showNotice('Vui lòng đăng nhập để lưu quan tâm');
                    return;
                  }
                  await ref
                       .read(hostPostRepositoryProvider)
                      .toggleInterest(postId: post.id, userId: uid);
                },
                onChatPressed: () {
                  final profile = ref.read(userProfileProvider).value;
                  final myUid = profile?.uid ?? '';
                  final myName = profile?.displayName.isNotEmpty == true
                      ? profile!.displayName
                      : 'Chủ trọ';
                  ref.read(hostPostRepositoryProvider).openChatWithHost(
                        context,
                        post,
                        currentUserId: myUid,
                        currentUserName: myName,
                      );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _primaryBlue,
            ),
            SizedBox(height: 16),
            Text(
              'Đang tải bảng tin đối tác...',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    bool isPermissionError = false;
    bool isNetworkError = false;
    String errorMessage = 'Không thể tải bảng tin. Vui lòng thử lại sau.';

    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        isPermissionError = true;
        errorMessage =
            'Chưa có quyền đọc bài đăng từ Firestore. Kiểm tra quyền tài khoản chủ trọ.';
      } else if (error.code == 'unavailable' ||
          error.code == 'network-request-failed') {
        isNetworkError = true;
        errorMessage = 'Lỗi kết nối mạng đến Firebase. Vui lòng kiểm tra internet.';
      }
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFEE2E2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              isPermissionError
                  ? Icons.lock_outline
                  : (isNetworkError
                      ? Icons.wifi_off_outlined
                      : Icons.error_outline),
              size: 48,
              color: const Color(0xFFEF4444),
            ),
            const SizedBox(height: 14),
            Text(
              isPermissionError
                  ? 'Lỗi phân quyền Firestore'
                  : (isNetworkError ? 'Lỗi kết nối mạng' : 'Đã có lỗi xảy ra'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => ref.invalidate(hostHomePostsProvider),
              style: FilledButton.styleFrom(
                backgroundColor: _primaryBlue,
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _borderGray),
      ),
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.dynamic_feed_outlined,
              size: 56,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 14),
            Text(
              'Chưa có bài đăng nào từ đối tác',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Các bài đăng mới từ chủ trọ khác sẽ hiển thị tại đây khi được đăng tải.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFilterResultState() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _borderGray),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 52,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(height: 14),
            const Text(
              'Không tìm thấy bài đăng phù hợp',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hãy thử thay đổi từ khoá tìm kiếm hoặc đặt lại các tiêu chí bộ lọc.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _searchController.clear();
                _resetAdvancedFilter();
                ref.read(hostHomeFilterProvider.notifier).clearLocations();
                ref.read(hostHomeFilterProvider.notifier).setSearchQuery('');
              },
              child: const Text('Xóa bộ lọc'),
            ),
          ],
        ),
      ),
    );
  }
}
