import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/room_model.dart';
import '../data/host_property.dart';
import '../providers/host_management_provider.dart';
import '../widgets/host_room_widgets.dart';
import '../widgets/host_range_input.dart';
import 'host_create_screen.dart';
import 'host_room_detail_screen.dart';

// Chủ trọ - Chỉnh sửa phòng - Luồng đi: Chi tiết mở form có sẵn dữ
// liệu; xem trước tại máy, lưu lên Firebase rồi quay về chi tiết phòng.
class HostRoomEditScreen extends ConsumerStatefulWidget {
  const HostRoomEditScreen({
    super.key,
    required this.room,
    required this.property,
  });
  final RoomModel room;
  final HostProperty property;
  @override
  ConsumerState<HostRoomEditScreen> createState() => _HostRoomEditScreenState();
}

class _HostRoomEditScreenState extends ConsumerState<HostRoomEditScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _custom = TextEditingController();
  final _newImages = <HostUpload>[];
  late List<String> _images;
  late Set<String> _amenities;
  late int _floor;
  late RangeValues _area;
  bool _busy = false, _picking = false, _expanded = true;
  final _operationId = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  static const _choices = [
    'Máy lạnh',
    'Có gác lửng',
    'Wifi tốc độ cao',
    'Giờ giấc tự do',
    'Máy giặt',
    'Tủ lạnh',
    'Cho nuôi thú cưng',
  ];

  // Chủ trọ - Nạp form - Luồng đi: Sao chép giá trị gốc để chỉnh sửa;
  // giữ phiên bản phòng nhằm phát hiện người khác sửa cùng lúc.
  @override
  void initState() {
    super.initState();
    final r = widget.room;
    _area = RangeValues(r.minArea ?? r.area, r.maxArea ?? r.area);
    final values = <String, String>{
      'roomCode': r.roomCode,
      'capacity': r.capacity.toString(),
      'area': '${r.area}',
      'price': r.price.toStringAsFixed(0),
      'deposit': r.deposit.toStringAsFixed(0),
      'electricityRate': r.electricityRate?.toStringAsFixed(0) ?? '',
      'waterRate': r.waterRate?.toStringAsFixed(0) ?? '',
      'serviceFee': r.serviceFee?.toStringAsFixed(0) ?? '',
      'description': r.description,
    };
    for (final entry in values.entries) {
      _fields[entry.key] = TextEditingController(text: entry.value);
    }
    _images = [...r.images];
    _amenities = {...r.amenities};
    _floor = r.floor;
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _custom.dispose();
    super.dispose();
  }

  // Chủ trọ - Chọn ảnh chỉnh sửa - Luồng đi: Thêm ảnh JPEG/PNG từ
  // máy; kiểm tra dung lượng trước khi tải Storage khi nhấn lưu.
  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final files = await ref.read(hostImagePickerProvider).pickMultiImage();
      if (_images.length + _newImages.length + files.length > 8) {
        throw StateError('Tối đa 8 ảnh phòng.');
      }
      final uploads = <HostUpload>[];
      for (final file in files) {
        final bytes = await file.readAsBytes();
        final png =
            bytes.length > 8 &&
            bytes[0] == 137 &&
            bytes[1] == 80 &&
            bytes[2] == 78 &&
            bytes[3] == 71;
        final jpeg =
            bytes.length > 3 &&
            bytes[0] == 255 &&
            bytes[1] == 216 &&
            bytes[2] == 255;
        if ((!png && !jpeg) || bytes.length > 5 * 1024 * 1024) {
          throw StateError('Chọn ảnh JPEG/PNG không quá 5 MB.');
        }
        uploads.add(HostUpload(bytes, png ? 'image/png' : 'image/jpeg'));
      }
      if (mounted) setState(() => _newImages.addAll(uploads));
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(hostErrorMessage(e))));
    }
  }

  // Chủ trọ - Giá trị chỉnh sửa - Luồng đi: Chỉ gửi trường được sửa;
  // trạng thái, khách thuê, hợp đồng và ID phòng được giữ nguyên.
  Map<String, dynamic> _patch() => {
    'roomCode': _fields['roomCode']!.text.trim().toUpperCase(),
    'floor': _floor,
    'capacity': int.parse(_fields['capacity']!.text.trim()),
    'area': _area.start,
    'minArea': _area.start,
    'maxArea': _area.end,
    for (final key in ['price', 'deposit'])
      key: double.parse(_fields[key]!.text.trim()),
    for (final key in ['electricityRate', 'waterRate', 'serviceFee'])
      key: double.tryParse(_fields[key]!.text.trim()),
    'amenities': _amenities.toList(),
    'description': _fields['description']!.text.trim(),
  };
  bool _validate() {
    if (!_form.currentState!.validate()) return false;
    if (_images.isEmpty && _newImages.isEmpty) {
      _error(StateError('Giữ ít nhất một ảnh phòng.'));
      return false;
    }
    return true;
  }

  Future<void> _preview() async {
    if (!_validate()) return;
    final room = RoomModel.fromMap({
      ...widget.room.toMap(),
      ..._patch(),
      'images': _images,
    }, widget.room.id);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HostRoomDetailScreen(
          propertyId: room.propertyId,
          roomId: room.id,
          previewRoom: room,
          previewImages: [..._newImages],
        ),
      ),
    );
  }

  // Chủ trọ - Lưu phòng - Luồng đi: Khóa thao tác khi gửi; Firebase
  // cập nhật xong mới đóng form, lỗi vẫn giữ nguyên nội dung đã nhập.
  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(hostRepositoryProvider)
          .updateRoom(widget.room, _patch(), _images, _newImages, _operationId);
      if (mounted) {
        setState(() => _busy = false);
        Navigator.pop(context, 'saved');
      }
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    final deleted = await hostDeleteRoom(context, ref, widget.room);
    if (!mounted) return;
    setState(() => _busy = false);
    if (deleted) Navigator.pop(context, 'deleted');
  }

  // Chủ trọ - Giao diện chỉnh sửa - Luồng đi: Nhóm ảnh, thông tin,
  // phí, tiện ích và khách thuê theo mẫu; nút lưu cố định cuối màn hình.
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_picking,
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F8FF),
      appBar: AppBar(title: const Text('Chỉnh sửa phòng')),
      body: AbsorbPointer(
        absorbing: _busy || _picking,
        child: Form(
          key: _form,
          child: ListView(
            scrollCacheExtent: const ScrollCacheExtent.pixels(5000),
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  HostRoomBadge(room: widget.room),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.room.contractId,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _preview,
                    child: const Text('Xem trước'),
                  ),
                ],
              ),
              HostRoomSection(
                title: 'Hình ảnh phòng',
                icon: Icons.photo_library_outlined,
                trailing: Text(
                  '${_images.length + _newImages.length}/8 ảnh',
                  style: const TextStyle(fontSize: 11),
                ),
                child: SizedBox(
                  height: 110,
                  child: ListView(
                    scrollCacheExtent: const ScrollCacheExtent.pixels(5000),
                    scrollDirection: Axis.horizontal,
                    children: [
                      SizedBox(
                        width: 100,
                        child: InkWell(
                          onTap: _pick,
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  color: AppColors.primary,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '+ Thêm ảnh',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < _images.length; i++)
                        _photo(
                          Image.network(
                            webHtmlElementStrategy:
                                WebHtmlElementStrategy.fallback,
                            _images[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                          () => setState(() => _images.removeAt(i)),
                        ),
                      for (var i = 0; i < _newImages.length; i++)
                        _photo(
                          Image.memory(_newImages[i].bytes, fit: BoxFit.cover),
                          () => setState(() => _newImages.removeAt(i)),
                        ),
                    ],
                  ),
                ),
              ),
              HostRoomSection(
                title: 'Thông tin cơ bản',
                icon: Icons.apartment,
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _field(
                            'roomCode',
                            'Số phòng *',
                            numeric: false,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _floor,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Tầng',
                            ),
                            items: [
                              for (
                                var i = 1;
                                i <= max(widget.property.floors, _floor);
                                i++
                              )
                                DropdownMenuItem(
                                  value: i,
                                  child: Text('Tầng $i'),
                                ),
                            ],
                            onChanged: (v) => setState(() => _floor = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    HostRangeInput(
                      label: 'Khoảng diện tích phòng',
                      unit: 'm²',
                      values: _area,
                      minimum: 1,
                      sliderMax: 100,
                      onChanged: (value) => setState(() => _area = value),
                    ),
                    _field('capacity', 'Số người ở tối đa *', suffix: 'người'),
                    const SizedBox(height: 16),
                    _field('price', 'Giá thuê tháng *', suffix: 'đ/tháng'),
                    const SizedBox(height: 16),
                    _field('deposit', 'Tiền đặt cọc', suffix: 'đ'),
                  ],
                ),
              ),
              HostRoomSection(
                title: 'Điện, Nước & Dịch vụ',
                icon: Icons.bolt,
                child: Column(
                  children: [
                    _field(
                      'electricityRate',
                      'Tiền điện',
                      suffix: 'đ/kWh',
                      optional: true,
                    ),
                    const SizedBox(height: 16),
                    _field(
                      'waterRate',
                      'Tiền nước',
                      suffix: 'đ/m³',
                      optional: true,
                    ),
                    const SizedBox(height: 16),
                    _field(
                      'serviceFee',
                      'Wifi + Rác + Vệ sinh',
                      suffix: 'đ/tháng',
                      optional: true,
                    ),
                  ],
                ),
              ),
              HostRoomSection(
                title: 'Tiện ích & Trang bị',
                icon: Icons.tune,
                trailing: Text(
                  '${_amenities.length} chọn',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF00865B),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _custom,
                            decoration: const InputDecoration(
                              hintText: 'Thêm tiện ích...',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: () {
                            final value = _custom.text.trim();
                            if (value.isNotEmpty && value.length <= 60) {
                              setState(() => _amenities.add(value));
                              _custom.clear();
                            }
                          },
                          child: const Text('Thêm'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final value in {
                      ..._amenities,
                      if (_expanded) ..._choices,
                    })
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: _amenities.contains(value)
                              ? const Color(0xFFE8FCF4)
                              : Colors.white,
                          border: Border.all(
                            color: _amenities.contains(value)
                                ? const Color(0xFF8BD4B8)
                                : const Color(0xFFE3E6EF),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              value,
                              style: const TextStyle(fontSize: 12),
                            ),
                            value: _amenities.contains(value),
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                _amenities.add(value);
                              } else {
                                _amenities.remove(value);
                              }
                            }),
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      child: Text(_expanded ? 'Thu gọn ↑' : 'Xem thêm ↓'),
                    ),
                  ],
                ),
              ),
              HostRoomSection(
                title: 'Mô tả phòng',
                icon: Icons.notes,
                child: _field(
                  'description',
                  'Thông tin bổ sung',
                  numeric: false,
                  optional: true,
                  maxLines: 3,
                ),
              ),
              HostRoomTenant(room: widget.room),
              TextButton(
                onPressed: _delete,
                child: const Text(
                  'Xóa phòng này',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const ValueKey('save_room'),
            onPressed: _busy || _picking ? null : _save,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Lưu thay đổi'),
          ),
        ),
      ),
    ),
  );

  // Chủ trọ - Kiểm tra trường sửa - Luồng đi: Báo lỗi ngay tại ô;
  // giá, diện tích phải dương, phí và tiền cọc không được âm.
  Widget _field(
    String key,
    String label, {
    bool numeric = true,
    bool optional = false,
    String? suffix,
    int maxLines = 1,
  }) => TextFormField(
    key: ValueKey('edit_$key'),
    controller: _fields[key],
    maxLines: maxLines,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      filled: true,
      fillColor: const Color(0xFFF0F4FF),
    ),
    validator: (raw) {
      final value = raw?.trim() ?? '';
      if (optional && value.isEmpty) return null;
      if (value.isEmpty) return 'Vui lòng nhập';
      if (!numeric) {
        if (key == 'roomCode' && value.length > 30) return 'Tối đa 30 ký tự';
        return null;
      }
      if (key == 'capacity') {
        final capacity = int.tryParse(value);
        return capacity == null || capacity < 1 || capacity > 1000000000
            ? 'Nhập số nguyên từ 1 trở lên'
            : null;
      }
      final number = double.tryParse(value);
      if (number == null ||
          !number.isFinite ||
          number < 0 ||
          number > 1000000000 ||
          ((key == 'area' || key == 'price') && number == 0)) {
        return 'Giá trị không hợp lệ';
      }
      return null;
    },
  );
  Widget _photo(Widget image, VoidCallback remove) => Container(
    width: 100,
    margin: const EdgeInsets.only(right: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Bỏ ảnh',
              onPressed: remove,
              icon: const Icon(Icons.cancel, color: Colors.black54),
            ),
          ),
        ],
      ),
    ),
  );
}
