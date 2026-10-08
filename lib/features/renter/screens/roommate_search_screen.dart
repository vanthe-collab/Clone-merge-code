import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/vietnam_locations.dart';
import '../../../core/services/roommate_service.dart';
import 'roommate_lifestyle_filter_sheet.dart';
import 'search_filter_screen.dart';

/// Kết quả bộ lọc ở ghép trả về màn danh sách.
class RoommateSearchResult {
  final String province;
  final String district;
  final bool hasRoom;
  final double? budgetMin;
  final double? budgetMax;
  final String targetGender;
  final String occupation;
  final List<String> occupations;
  final List<String> habits;
  final int minMatchRate;

  const RoommateSearchResult({
    required this.province,
    required this.district,
    required this.hasRoom,
    this.budgetMin,
    this.budgetMax,
    this.targetGender = 'Tất cả',
    this.occupation = 'Tất cả',
    this.occupations = const [],
    this.habits = const [],
    this.minMatchRate = 0,
  });
}

/// Bộ lọc tìm ở ghép, cùng khung với tìm phòng trên trang chủ.
/// Chỗ hình thức thuê đổi thành Đã có phòng / Chưa có phòng.
class RoommateSearchScreen extends StatefulWidget {
  final String initialProvince;
  final bool initialHasRoom;
  final RoommateFilterParams initialFilters;

  const RoommateSearchScreen({
    super.key,
    this.initialProvince = 'TP. Hồ Chí Minh',
    this.initialHasRoom = true,
    this.initialFilters = const RoommateFilterParams(),
  });

  @override
  State<RoommateSearchScreen> createState() => _RoommateSearchScreenState();
}

class _RoommateSearchScreenState extends State<RoommateSearchScreen> {
  static const Color _emerald = Color(0xFF006948);
  static const Color _emeraldLight = Color(0xFFE8F5E9);
  static const Color _lavenderBg = Color(0xFFE8F5E9);
  static const Color _lavenderBorder = Color(0xFFA5D6A7);
  static const Color _lavenderText = Color(0xFF006948);

  late String _selectedCity;
  String _selectedDistrict = 'Tất cả';
  String _selectedWard = 'Tất cả';
  late bool _hasRoom;
  late RoommateFilterParams _advanced;

  List<String> get _districts {
    if (_selectedCity == 'Tất cả') return const ['Tất cả'];
    return ['Tất cả', ...VietnamLocations.getAdministrativeDistricts(_selectedCity)];
  }

  List<String> get _wards {
    if (_selectedCity == 'Tất cả' || _selectedDistrict == 'Tất cả') return const ['Tất cả'];
    return ['Tất cả', ...VietnamLocations.getWards(_selectedCity, _selectedDistrict)];
  }

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.initialProvince;
    _hasRoom = widget.initialHasRoom;
    _advanced = widget.initialFilters;
  }

  void _openAdvanced() {
    RoommateLifestyleFilterSheet.show(
      context,
      initialFilters: _advanced.copyWith(hasRoom: _hasRoom),
      onApply: (updated) {
        setState(() {
          _advanced = updated;
          if (updated.hasRoom != null) _hasRoom = updated.hasRoom!;
        });
      },
    );
  }

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationSearchBottomSheet(
        title: 'Chọn Tỉnh / Thành phố',
        searchHint: 'Tìm kiếm tỉnh hoặc thành phố...',
        items: const ['Tất cả', ...VietnamLocations.provinces],
        selectedItem: _selectedCity,
        allLabel: 'Tất cả Tỉnh / Thành phố',
        onSelected: (val) {
          setState(() {
            _selectedCity = val;
            _selectedDistrict = 'Tất cả';
            _selectedWard = 'Tất cả';
          });
        },
      ),
    );
  }

  void _showDistrictPicker() {
    if (_selectedCity == 'Tất cả') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn Tỉnh / Thành phố trước'), duration: Duration(seconds: 2)),
      );
      _showCityPicker();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationSearchBottomSheet(
        title: 'Chọn Quận / Huyện ($_selectedCity)',
        searchHint: 'Tìm quận, huyện, thị xã...',
        items: _districts,
        selectedItem: _selectedDistrict,
        allLabel: 'Tất cả Quận / Huyện',
        onSelected: (dist) {
          setState(() {
            _selectedDistrict = dist;
            _selectedWard = 'Tất cả';
          });
        },
      ),
    );
  }

  void _showWardPicker() {
    if (_selectedDistrict == 'Tất cả') {
      _showDistrictPicker();
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationSearchBottomSheet(
        title: 'Chọn Phường / Xã ($_selectedDistrict)',
        searchHint: 'Tìm phường, xã, thị trấn...',
        items: _wards,
        selectedItem: _selectedWard,
        allLabel: 'Tất cả Phường / Xã',
        onSelected: (w) => setState(() => _selectedWard = w),
      ),
    );
  }

  void _submit() {
    final place = _selectedWard != 'Tất cả'
        ? _selectedWard
        : (_selectedDistrict != 'Tất cả' ? _selectedDistrict : 'Tất cả');
    Navigator.pop(
      context,
      RoommateSearchResult(
        province: _selectedCity,
        district: place,
        hasRoom: _hasRoom,
        budgetMin: _advanced.budgetMin,
        budgetMax: _advanced.budgetMax,
        targetGender: _advanced.targetGender,
        occupation: _advanced.occupation,
        occupations: _advanced.occupations,
        habits: _advanced.habits,
        minMatchRate: _advanced.minMatchRate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tìm kiếm',
          style: TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLocationCard(),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.search, size: 20, color: Colors.white),
                label: const Text(
                  'Tìm kiếm phòng',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle, size: 6, color: _emerald),
                SizedBox(width: 6),
                Text(
                  'Hơn 12.400+ phòng trọ chính chủ đang sẵn sàng',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final placeLabel = _selectedDistrict == 'Tất cả'
        ? 'Chọn Phường / Xã'
        : (_selectedWard == 'Tất cả' ? _selectedDistrict : '$_selectedWard, $_selectedDistrict');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3.5,
                height: 16,
                decoration: BoxDecoration(color: _emerald, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 6),
              const Text('Khu vực', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('Tỉnh/Thành phố *'),
          const SizedBox(height: 6),
          _buildLocationDropdown(label: _selectedCity, icon: Icons.near_me_outlined, onTap: _showCityPicker),
          const SizedBox(height: 12),
          _buildFieldLabel('Phường / Xã'),
          const SizedBox(height: 6),
          _buildLocationDropdown(
            label: placeLabel,
            icon: Icons.map_outlined,
            onTap: () {
              if (_selectedDistrict == 'Tất cả') {
                _showDistrictPicker();
              } else {
                _showWardPicker();
              }
            },
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('Tình trạng phòng'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatusCard(
                  selected: _hasRoom,
                  icon: Icons.home_outlined,
                  title: 'Đã có phòng',
                  onTap: () => setState(() => _hasRoom = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatusCard(
                  selected: !_hasRoom,
                  icon: Icons.person_search_outlined,
                  title: 'Chưa có phòng',
                  onTap: () => setState(() => _hasRoom = false),
                ),
              ),
            ],
          ),
          Padding(
              padding: const EdgeInsets.only(top: 14),
              child: InkWell(
                onTap: _openAdvanced,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: _lavenderBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _lavenderBorder),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 18, color: _lavenderText),
                      SizedBox(width: 6),
                      Text('Nâng cao', style: TextStyle(color: _lavenderText, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textDark));
  }

  Widget _buildLocationDropdown({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _emerald),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textDark), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required bool selected,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? _emeraldLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _emerald : const Color(0xFFE5E7EB), width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? _emerald : AppColors.textMuted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? _emerald : AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 14,
              color: selected ? _emerald : const Color(0xFFD1D5DB),
            ),
          ],
        ),
      ),
    );
  }
}
