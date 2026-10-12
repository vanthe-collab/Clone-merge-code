import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/roommate_service.dart';

/// Modal Bottom Sheet "Bộ lọc Lifestyle & Ở ghép AI Match" chuẩn Figma 100%
/// Cho phép người dùng lọc theo tình trạng phòng, đối tượng, ngân sách và các tiêu chí lối sống thực tế
class RoommateLifestyleFilterSheet extends StatefulWidget {
  final RoommateFilterParams initialFilters;
  final int matchingCount;
  final ValueChanged<RoommateFilterParams> onApply;
  final bool embedded;
  final ValueChanged<RoommateFilterParams>? onChanged;

  const RoommateLifestyleFilterSheet({
    super.key,
    required this.initialFilters,
    this.matchingCount = 0,
    required this.onApply,
    this.embedded = false,
    this.onChanged,
  });

  static Future<RoommateFilterParams?> show(
    BuildContext context, {
    required RoommateFilterParams initialFilters,
    int matchingCount = 0,
    required ValueChanged<RoommateFilterParams> onApply,
  }) {
    return showModalBottomSheet<RoommateFilterParams>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RoommateLifestyleFilterSheet(
        initialFilters: initialFilters,
        matchingCount: matchingCount,
        onApply: onApply,
      ),
    );
  }

  @override
  State<RoommateLifestyleFilterSheet> createState() => _RoommateLifestyleFilterSheetState();
}

class _RoommateLifestyleFilterSheetState extends State<RoommateLifestyleFilterSheet> {
  // 1. Tình trạng phòng (null = Tất cả, true = Đã có phòng sẵn, false = Chưa có phòng)
  bool? _hasRoom;

  // 2. Đối tượng phù hợp
  String _selectedGender = 'Tất cả';
  static const List<String> _defaultOccupations = ['Sinh viên', 'Người đi làm', 'Freelancer'];
  static const List<String> _defaultHabits = [
    'Yên tĩnh sau 23h',
    'Sạch sẽ, ngăn nắp cao',
    'Tuyệt đối không thuốc lá',
    'Giờ giấc tự do',
    'Có xe máy riêng',
    'Thích thể thao/Gym',
    'Không ồn ào/tụ tập',
    'Chăm học/Làm việc',
    'Nấu ăn thường xuyên',
  ];
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _habitController = TextEditingController();
  late List<String> _occupationOptions;
  final Set<String> _selectedOccupations = {};

  // 3. Ngân sách mỗi người
  late RangeValues _budgetRange;
  late bool _budgetTouched;

  // 4. Lối sống & Thói quen
  final Set<String> _selectedHabits = {};

  // 5. Match Rate
  int _matchRate = 0;

  @override
  void initState() {
    super.initState();
    _hasRoom = widget.initialFilters.hasRoom;
    _selectedGender = widget.initialFilters.targetGender;
    _occupationOptions = List<String>.from(_defaultOccupations);
    final initialJobs = <String>{
      ...widget.initialFilters.occupations,
      if (widget.initialFilters.occupation != 'Tất cả' && widget.initialFilters.occupation.isNotEmpty)
        widget.initialFilters.occupation,
    };
    for (final job in initialJobs) {
      if (!_occupationOptions.contains(job)) _occupationOptions.add(job);
      _selectedOccupations.add(job);
    }

    final minVal = (widget.initialFilters.budgetMin ?? 1000000).clamp(500000.0, 6000000.0);
    final maxVal = (widget.initialFilters.budgetMax ?? 3000000).clamp(minVal, 6000000.0);
    _budgetRange = RangeValues(minVal, maxVal);
    _budgetTouched = widget.initialFilters.budgetMin != null || widget.initialFilters.budgetMax != null;

    if (widget.initialFilters.habits.isNotEmpty) {
      _selectedHabits.addAll(widget.initialFilters.habits);
      _selectedHabits.removeAll(const ['Thú cưng (Chó/Mèo)', 'Quy định dẫn bạn về phòng']);
    }
    _habitOptions = List<String>.from(_defaultHabits);
    for (final habit in _selectedHabits) {
      if (!_habitOptions.contains(habit)) _habitOptions.add(habit);
    }

    _matchRate = widget.initialFilters.minMatchRate;
    if (widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
    }
  }

  RoommateFilterParams _snapshot() {
    return widget.initialFilters.copyWith(
      hasRoom: widget.embedded ? null : _hasRoom,
      clearHasRoom: !widget.embedded && _hasRoom == null,
      targetGender: _selectedGender,
      occupation: _selectedOccupations.length == 1 ? _selectedOccupations.first : 'Tất cả',
      occupations: _selectedOccupations.toList(),
      budgetMin: _budgetTouched ? _budgetRange.start : null,
      budgetMax: _budgetTouched ? _budgetRange.end : null,
      clearBudget: !_budgetTouched,
      habits: _selectedHabits.toList(),
      minMatchRate: _matchRate,
    );
  }

  void _notify() {
    if (!mounted || !widget.embedded) return;
    widget.onChanged?.call(_snapshot());
  }

  late List<String> _habitOptions;

  @override
  void dispose() {
    _occupationController.dispose();
    _habitController.dispose();
    super.dispose();
  }

  void _addOccupation() {
    final text = _occupationController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      if (!_occupationOptions.contains(text)) _occupationOptions.add(text);
      _selectedOccupations.add(text);
      _occupationController.clear();
    });
  }

  void _addHabit() {
    final text = _habitController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      if (!_habitOptions.contains(text)) _habitOptions.add(text);
      _selectedHabits.add(text);
      _habitController.clear();
    });
  }

  void _resetFilters() {
    setState(() {
      _hasRoom = null;
      _selectedGender = 'Tất cả';
      _occupationOptions = List<String>.from(_defaultOccupations);
      _selectedOccupations.clear();
      _occupationController.clear();
      _habitOptions = List<String>.from(_defaultHabits);
      _habitController.clear();
      _budgetRange = const RangeValues(1000000, 3000000);
      _budgetTouched = false;
      _selectedHabits.clear();
      _matchRate = 0;
    });
  }

  void _applyFilters() {
    final updated = _snapshot();
    widget.onApply(updated);
    Navigator.pop(context, updated);
  }

  List<Widget> _formSections() {
    return [
      if (!widget.embedded) ...[
        _buildSection1RoomStatus(),
        const SizedBox(height: 22),
      ],
      _buildSection2TargetCriteria(),
      const SizedBox(height: 22),
      _buildSection3Budget(),
      const SizedBox(height: 22),
      _buildSection4LifestyleHabits(),
      const SizedBox(height: 22),
      _buildSection5MatchRate(),
      const SizedBox(height: 12),
    ];
  }

  String _formatBudget(double value) {
    if (value >= 1000000) {
      final millions = value / 1000000;
      return '${millions.toStringAsFixed(millions.truncateToDouble() == millions ? 0 : 1)}tr';
    }
    return '${(value / 1000).round()}k';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _formSections(),
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.90;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag indicator bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Bộ lọc Lifestyle & Ở ghép',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: AppColors.primarySurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                            ),
                            child: const Text(
                              'AI Match',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Tìm bạn cùng phòng hợp phong cách sống và tính tình',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.close, size: 18, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Body Form cuộn mượt mà
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: _formSections(),
            ),
          ),

          // Sticky Footer Action Bar
          _buildStickyFooter(widget.matchingCount),
        ],
      ),
    );
  }

  /// 1. TÌNH TRẠNG PHÒNG
  Widget _buildSection1RoomStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.apartment_rounded, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  '1. TÌNH TRẠNG PHÒNG',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () => setState(() => _hasRoom = null),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  'Tất cả',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Option: Đã có phòng sẵn
            Expanded(
              child: _buildRoomStatusCard(
                title: 'Đã có phòng sẵn',
                subtitle: 'Tìm người dọn vào ở chung căn đã thuê',
                icon: Icons.home_rounded,
                isSelected: _hasRoom == true,
                onTap: () => setState(() => _hasRoom = true),
              ),
            ),
            const SizedBox(width: 10),
            // Option: Chưa có phòng
            Expanded(
              child: _buildRoomStatusCard(
                title: 'Chưa có phòng',
                subtitle: 'Tìm bạn cùng gu rồi cùng đi thuê phòng mới',
                icon: Icons.group_rounded,
                isSelected: _hasRoom == false,
                onTap: () => setState(() => _hasRoom = false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoomStatusCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: isSelected ? AppColors.primary : const Color(0xFF94A3B8),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), height: 1.25),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 2. ĐỐI TƯỢNG PHÙ HỢP
  Widget _buildSection2TargetCriteria() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.people_outline_rounded, size: 18, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              '2. ĐỐI TƯỢNG PHÙ HỢP',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Giới tính mong muốn
        const Text(
          'Giới tính mong muốn',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            _buildChoiceChip(
              label: 'Tất cả',
              isSelected: _selectedGender == 'Tất cả',
              onSelected: () => setState(() => _selectedGender = 'Tất cả'),
            ),
            _buildChoiceChip(
              label: 'Nữ',
              isSelected: _selectedGender == 'Nữ',
              isPrimarySolid: true,
              hasCheckmark: true,
              onSelected: () => setState(() => _selectedGender = 'Nữ'),
            ),
            _buildChoiceChip(
              label: 'Nam',
              isSelected: _selectedGender == 'Nam',
              onSelected: () => setState(() => _selectedGender = 'Nam'),
            ),
          ],
        ),
        const SizedBox(height: 14),

        const Text(
          'Nghề nghiệp / Tình trạng',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        _buildChecklist(
          controller: _occupationController,
          hint: 'Nhập nghề nghiệp muốn thêm',
          onAdd: _addOccupation,
          options: _occupationOptions,
          selected: _selectedOccupations,
          onToggle: (item) {
            setState(() {
              if (_selectedOccupations.contains(item)) {
                _selectedOccupations.remove(item);
              } else {
                _selectedOccupations.add(item);
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    IconData? icon,
    bool isSelected = false,
    bool isPrimarySolid = false,
    bool hasCheckmark = false,
    required VoidCallback onSelected,
  }) {
    Color bg;
    Color textColor;
    Border? border;

    if (isSelected && isPrimarySolid) {
      bg = AppColors.primary;
      textColor = Colors.white;
      border = null;
    } else if (isSelected) {
      bg = AppColors.primarySurface;
      textColor = AppColors.primary;
      border = Border.all(color: AppColors.primary, width: 1.2);
    } else {
      bg = Colors.white;
      textColor = const Color(0xFF334155);
      border = Border.all(color: const Color(0xFFE2E8F0));
    }

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (hasCheckmark && isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check, size: 14, color: textColor),
            ],
          ],
        ),
      ),
    );
  }

  /// 3. NGÂN SÁCH MỖI NGƯỜI
  Widget _buildSection3Budget() {
    final startStr = _formatBudget(_budgetRange.start);
    final endStr = _formatBudget(_budgetRange.end);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    '3. NGÂN SÁCH MỖI\nNGƯỜI',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.2),
                ),
                child: Text(
                  '$startStr - $endStr/tháng',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: const Color(0xFFCBD5E1),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 3),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              trackHeight: 4,
            ),
            child: RangeSlider(
              values: _budgetRange,
              min: 500000,
              max: 6000000,
              divisions: 55,
              onChanged: (values) {
                setState(() {
                  _budgetTouched = true;
                  _budgetRange = values;
                });
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('500k', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                Text('2.5 triệu', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                Text('6 triệu+', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 4. TIÊU CHÍ LỐI SỐNG & THÓI QUEN
  Widget _buildSection4LifestyleHabits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.psychology_outlined, size: 19, color: AppColors.primary),
            SizedBox(width: 8),
            Text(
              '4. TIÊU CHÍ LỐI SỐNG & THÓI QUEN',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Chọn các tiêu chí mà bạn coi trọng nhất ở bạn cùng phòng',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        _buildChecklist(
          controller: _habitController,
          hint: 'Nhập thói quen muốn thêm',
          onAdd: _addHabit,
          options: _habitOptions,
          selected: _selectedHabits,
          onToggle: (item) {
            setState(() {
              if (_selectedHabits.contains(item)) {
                _selectedHabits.remove(item);
              } else {
                _selectedHabits.add(item);
              }
            });
          },
        ),
      ],
    );
  }

  /// Dòng đầu là ô nhập và nút Thêm, các dòng sau là checklist.
  Widget _buildChecklist({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onAdd,
    required List<String> options,
    required Set<String> selected,
    required ValueChanged<String> onToggle,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onAdd(),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Thêm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...options.map((item) {
          final isSelected = selected.contains(item);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: isSelected ? AppColors.primarySurface : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                width: isSelected ? 1.4 : 1,
              ),
            ),
            child: InkWell(
              onTap: () => onToggle(item),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 22,
                      color: isSelected ? AppColors.primary : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }


  /// 5. MỨC ĐỘ TƯƠNG THÍCH (MATCH RATE)
  Widget _buildSection5MatchRate() {
    return InkWell(
      onTap: () {
        setState(() {
          _matchRate = _matchRate >= 80 ? 0 : 80;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mức độ tương thích (Match rate)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Chỉ hiện hồ sơ có độ trùng thói quen từ 80%',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Text(
                _matchRate > 0 ? '≥ $_matchRate%' : 'Tất cả',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sticky Footer Action Bar
  Widget _buildStickyFooter(int matchingCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Nút Đặt lại
            OutlinedButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Đặt lại', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(width: 12),

            // Nút Áp dụng bộ lọc
            Expanded(
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: Text(
                  matchingCount > 0
                      ? 'Áp dụng bộ lọc ($matchingCount bạn phù hợp)'
                      : 'Áp dụng bộ lọc',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
