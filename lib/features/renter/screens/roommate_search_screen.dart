import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/vietnam_locations.dart';
import '../../../data/models/roommate_post_model.dart';
import '../../../core/theme/phong_sang_theme.dart';
import '../../../core/services/roommate_service.dart';
import 'roommate_lifestyle_filter_sheet.dart';
import 'roommate_room_detail_screen.dart';
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
class RoommateSearchScreen extends ConsumerStatefulWidget {
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
  ConsumerState<RoommateSearchScreen> createState() => _RoommateSearchScreenState();
}

class _RoommateSearchScreenState extends ConsumerState<RoommateSearchScreen> {
  static const Color _accent = PhongSangColors.accent;
  static const Color _accentSoft = PhongSangColors.accentSoft;

  late String _selectedCity;
  String _selectedDistrict = 'Tất cả';
  String _selectedWard = 'Tất cả';
  late bool _hasRoom;
  late RoommateFilterParams _advanced;
  bool _advancedExpanded = false;
  bool _hasSearched = false;
  RoommateFilterParams _activeQuery = const RoommateFilterParams();

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

  void _toggleAdvanced() {
    setState(() => _advancedExpanded = !_advancedExpanded);
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
          if (dist != 'Tất cả') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showWardPicker();
            });
          }
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
    setState(() {
      _hasSearched = true;
      _advancedExpanded = false;
      _activeQuery = RoommateFilterParams(
        province: _selectedCity,
        district: _selectedDistrict,
        ward: _selectedWard,
        hasRoom: _hasRoom,
        targetGender: _advanced.targetGender,
        occupation: _advanced.occupation,
        occupations: _advanced.occupations,
        habits: _advanced.habits,
        budgetMin: _advanced.budgetMin,
        budgetMax: _advanced.budgetMax,
        minMatchRate: _advanced.minMatchRate,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PhongSangTheme.light,
      child: Scaffold(
      backgroundColor: PhongSangColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () {
            if (_hasSearched) {
              setState(() => _hasSearched = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text('Tìm kiếm', style: PhongSangText.roomName),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasSearched) ...[
              _buildCompactFilterBar(),
              const SizedBox(height: 16),
              _buildResults(ref.watch(roommatePostsStreamProvider(_activeQuery))),
            ] else ...[
            _buildLocationCard(),
            if (_advancedExpanded) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(
                  color: PhongSangColors.card,
                  borderRadius: BorderRadius.circular(PhongSangRadii.card),
                  border: Border.all(color: PhongSangColors.line),
                  boxShadow: PhongSangTokens.standard.shadow,
                ),
                child: RoommateLifestyleFilterSheet(
                  embedded: true,
                  initialFilters: _advanced,
                  onApply: (_) {},
                  onChanged: (updated) => setState(() => _advanced = updated),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.search, size: 20, color: Colors.white),
                label: Text('Tìm kiếm', style: PhongSangText.button),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: PhongSangColors.onAccent,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PhongSangRadii.control)),
                  elevation: 0,
                  textStyle: PhongSangText.button,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.circle, size: 6, color: _accent),
                const SizedBox(width: 6),
                Text(
                  'Hơn 12.400+ phòng trọ chính chủ đang sẵn sàng',
                  style: PhongSangText.caption,
                ),
              ],
            ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCompactFilterBar() {
    final status = _hasRoom ? 'Đã có phòng' : 'Chưa có phòng';
    final place = _selectedWard != 'Tất cả'
        ? '$_selectedWard, $_selectedCity'
        : (_selectedDistrict == 'Tất cả' ? _selectedCity : '$_selectedDistrict, $_selectedCity');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: PhongSangColors.card,
        borderRadius: BorderRadius.circular(PhongSangRadii.card),
        border: Border.all(color: PhongSangColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 18, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$place • $status',
              style: PhongSangText.label(color: PhongSangColors.ink, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _hasSearched = false),
            child: Text('Đổi bộ lọc', style: PhongSangText.button.copyWith(color: _accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(AsyncValue<List<RoommatePostModel>> postsAsync) {
    return postsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator(color: _accent)),
      ),
      error: (err, _) => Text('Không tải được bài đăng: $err', style: PhongSangText.body),
      data: (posts) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kết quả tìm kiếm (${posts.length} bài)', style: PhongSangText.roomName.copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            if (posts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                decoration: BoxDecoration(
                  color: PhongSangColors.card,
                  borderRadius: BorderRadius.circular(PhongSangRadii.card),
                  border: Border.all(color: PhongSangColors.line),
                ),
                child: Text(
                  'Không có bài khớp. Hãy bỏ phường/xã hoặc chọn lại Đã có phòng / Chưa có phòng.',
                  style: PhongSangText.body,
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...posts.map(_buildResultCard),
          ],
        );
      },
    );
  }

  Widget _buildResultCard(RoommatePostModel post) {
    final millions = post.pricePerPerson / 1000000;
    final price = '${millions.toStringAsFixed(millions.truncateToDouble() == millions ? 0 : 1)} triệu/người';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: PhongSangColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PhongSangRadii.card),
          side: const BorderSide(color: PhongSangColors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(PhongSangRadii.card),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => RoommateRoomDetailScreen(post: post)));
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _accentSoft,
                  child: Text(post.authorName.isEmpty ? '?' : post.authorName.characters.first, style: PhongSangText.label(color: _accent)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.authorName, style: PhongSangText.label(color: PhongSangColors.ink, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: PhongSangText.body.copyWith(color: PhongSangColors.ink)),
                      const SizedBox(height: 4),
                      Text('${post.district} • $price', style: PhongSangText.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final districtLabel = _selectedDistrict == 'Tất cả' ? 'Chọn Quận / Huyện' : _selectedDistrict;
    final wardLabel = _selectedWard == 'Tất cả' ? 'Chọn Phường / Xã' : _selectedWard;

    return Container(
      decoration: BoxDecoration(
        color: PhongSangColors.card,
        borderRadius: BorderRadius.circular(PhongSangRadii.card),
        border: Border.all(color: PhongSangColors.line),
        boxShadow: PhongSangTokens.standard.shadow,
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
                decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 6),
              Text('Khu vực', style: PhongSangText.roomName.copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          _buildFieldLabel('Tỉnh/Thành phố *'),
          const SizedBox(height: 6),
          _buildLocationDropdown(label: _selectedCity, icon: Icons.near_me_outlined, onTap: _showCityPicker),
          const SizedBox(height: 12),
          _buildFieldLabel('Quận / Huyện'),
          const SizedBox(height: 6),
          _buildLocationDropdown(
            label: districtLabel,
            icon: Icons.map_outlined,
            onTap: _showDistrictPicker,
          ),
          const SizedBox(height: 12),
          _buildFieldLabel('Phường / Xã'),
          const SizedBox(height: 6),
          _buildLocationDropdown(
            label: wardLabel,
            icon: Icons.location_on_outlined,
            onTap: _showWardPicker,
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
                onTap: _toggleAdvanced,
                borderRadius: BorderRadius.circular(PhongSangRadii.control),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: _accentSoft,
                    borderRadius: BorderRadius.circular(PhongSangRadii.control),
                    border: Border.all(color: PhongSangColors.line),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_advancedExpanded ? Icons.remove : Icons.add, size: 18, color: _accent),
                      const SizedBox(width: 6),
                      Text(
                        _advancedExpanded ? 'Thu gọn' : 'Nâng cao',
                        style: PhongSangText.button.copyWith(color: _accent),
                      ),
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
    return Text(label, style: PhongSangText.label(color: PhongSangColors.ink, fontSize: 12));
  }

  Widget _buildLocationDropdown({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PhongSangRadii.control),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: PhongSangColors.priceSoft,
          borderRadius: BorderRadius.circular(PhongSangRadii.control),
          border: Border.all(color: PhongSangColors.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: _accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: PhongSangText.search, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: PhongSangColors.muted),
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
      borderRadius: BorderRadius.circular(PhongSangRadii.control),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? _accentSoft : PhongSangColors.card,
          borderRadius: BorderRadius.circular(PhongSangRadii.control),
          border: Border.all(color: selected ? _accent : PhongSangColors.line, width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? _accent : PhongSangColors.muted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PhongSangText.label(color: selected ? _accent : PhongSangColors.ink, fontSize: 12),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 14,
              color: selected ? _accent : PhongSangColors.line,
            ),
          ],
        ),
      ),
    );
  }
}
