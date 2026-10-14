import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/vietnam_locations.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/user_provider.dart';
import '../data/host_property.dart';
import '../providers/host_management_provider.dart';
import '../widgets/host_room_widgets.dart';
import '../widgets/host_range_input.dart';

// Chủ trọ - Bộ chọn ảnh - Luồng đi: Dùng picker có thể thay thế khi
// kiểm thử; thiết bị thực mở thư viện ảnh qua image_picker.
final hostImagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

// Chủ trọ - Tạo nhà/phòng - Luồng đi: Dấu cộng ở khu Quản lý mở form
// hai tab; lưu nhà trước rồi chọn cơ sở để tạo phòng trên Firebase.
class HostCreateScreen extends ConsumerStatefulWidget {
  const HostCreateScreen({
    super.key,
    this.propertyId,
    this.startWithRoom = false,
    this.propertyToEdit,
  });
  final String? propertyId;
  final bool startWithRoom;
  final HostProperty? propertyToEdit;
  @override
  ConsumerState<HostCreateScreen> createState() => _HostCreateScreenState();
}

class _HostCreateScreenState extends ConsumerState<HostCreateScreen> {
  final _houseForm = GlobalKey<FormState>();
  final _roomForm = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{
    for (final name in [
      'name',
      'address',
      'ward',
      'planned',
      'floors',
      'code',
      'price',
      'deposit',
      'floor',
      'capacity',
      'notes',
    ])
      name: TextEditingController(),
  };
  final _houseImages = <HostUpload>[];
  final _keptHouseImages = <String>[];
  final _roomImages = <HostUpload>[];
  final _amenities = <String>{};
  final _customAmenity = TextEditingController();
  bool _amenitiesExpanded = true;
  String _city = VietnamLocations.provinces.first;
  String? _district;
  bool get _wardRequired =>
      _district != null &&
      VietnamLocations.getWards(_city, _district!).isNotEmpty;
  String? _selectedPropertyId, _draftPropertyId;
  String? _draftOwner;
  HostProperty? _justCreated;
  HostUpload? _proof;
  bool _roomTab = false, _saving = false, _picking = false;
  RangeValues _rent = const RangeValues(2000000, 5000000);
  RangeValues _area = const RangeValues(25, 25);
  String _roomType = 'Phòng trọ';
  bool get _editingProperty => widget.propertyToEdit != null;
  final String _operationId = List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  static const _amenityOptions = [
    'Máy lạnh',
    'Có gác lửng',
    'Wifi tốc độ cao',
    'Giờ giấc tự do',
    'Máy giặt',
    'Tủ lạnh',
    'Cho nuôi thú cưng',
    'Ban công / Cửa sổ lớn',
    'Không chung chủ',
    'Chỗ để xe miễn phí',
  ];

  // Chủ trọ - Khởi tạo form - Luồng đi: Nhận cơ sở khi mở từ thẻ nhà;
  // các trường bắt đầu trống để tránh lưu nhầm dữ liệu mẫu trong HTML.
  @override
  void initState() {
    super.initState();
    _roomTab = widget.startWithRoom;
    _selectedPropertyId = widget.propertyId;
    _fields['floors']!.text = '1';
    _fields['floor']!.text = '1';
    _fields['capacity']!.text = '2';
    _fields['deposit']!.text = '0';
    final property = widget.propertyToEdit;
    if (property != null) {
      _roomTab = false;
      _city = property.city.isEmpty
          ? VietnamLocations.provinces.first
          : property.city;
      _district = property.district.isEmpty ? null : property.district;
      _fields['name']!.text = property.name;
      _fields['address']!.text = property.address;
      _fields['ward']!.text = property.ward;
      _fields['planned']!.text = property.plannedRooms.toString();
      _fields['floors']!.text = property.floors.toString();
      final minRent = property.minRent.clamp(0, 1000000000).toDouble();
      final maxRent = property.maxRent.clamp(minRent, 1000000000).toDouble();
      _rent = RangeValues(minRent, maxRent);
      _keptHouseImages.addAll(property.images);
    }
  }

  // Chủ trọ - Giải phóng form - Luồng đi: Đóng màn tạo nhà/phòng thì
  // hủy các controller; dữ liệu chỉ lưu khi bấm nút Lưu thành công.
  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    _customAmenity.dispose();
    super.dispose();
  }

  // Chủ trọ - Chọn ảnh - Luồng đi: Dùng picker đa nền tảng, kiểm tra
  // chữ ký PNG/JPEG và dung lượng rồi giữ byte để xem trước/xóa khỏi form.
  Future<void> _pickImages({bool proof = false}) async {
    setState(() => _picking = true);
    final target = _roomTab ? _roomImages : _houseImages;
    try {
      final picker = ref.read(hostImagePickerProvider);
      final List<XFile> files;
      if (proof) {
        final file = await picker.pickImage(source: ImageSource.gallery);
        files = file == null ? [] : [file];
      } else {
        files = await picker.pickMultiImage();
      }
      final max = _roomTab ? 8 : 5;
      final keptCount = !_roomTab && !proof ? _keptHouseImages.length : 0;
      if (!proof && keptCount + target.length + files.length > max) {
        throw StateError('Chỉ chọn tối đa $max ảnh.');
      }
      final selected = <HostUpload>[];
      for (final file in files) {
        final size = await file.length();
        if (size > (proof ? 15 : 5) * 1024 * 1024) {
          throw StateError('Tệp vượt quá ${proof ? 15 : 5} MB.');
        }
        final Uint8List bytes = await file.readAsBytes();
        final png =
            bytes.length >= 8 &&
            bytes[0] == 137 &&
            bytes[1] == 80 &&
            bytes[2] == 78 &&
            bytes[3] == 71 &&
            bytes[4] == 13 &&
            bytes[5] == 10 &&
            bytes[6] == 26 &&
            bytes[7] == 10;
        final jpg =
            bytes.length >= 3 &&
            bytes[0] == 255 &&
            bytes[1] == 216 &&
            bytes[2] == 255;
        if (!png && !jpg) throw StateError('Chỉ hỗ trợ ảnh JPG hoặc PNG.');
        selected.add(HostUpload(bytes, png ? 'image/png' : 'image/jpeg'));
      }
      if (!mounted) return;
      setState(() {
        if (proof && selected.isNotEmpty) {
          _proof = selected.first;
        } else {
          target.addAll(selected);
        }
      });
    } catch (error) {
      if (mounted) _message(hostErrorMessage(error));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  // Chủ trọ - Lưu form - Luồng đi: Validate và upload ảnh; chỉ báo
  // thành công sau khi Firebase ghi xong, lỗi giữ nguyên dữ liệu để thử lại.
  Future<void> _save(List<HostProperty> properties) async {
    final uid = ref.read(hostSessionProvider).value;
    if (uid == null) {
      _message('Vui lòng đăng nhập bằng tài khoản Chủ trọ.');
      return;
    }
    if (!(_roomTab ? _roomForm : _houseForm).currentState!.validate()) return;
    final images = _roomTab ? _roomImages : _houseImages;
    if (images.isEmpty && (!_editingProperty || _keptHouseImages.isEmpty)) {
      _message('Vui lòng chọn ít nhất 1 ảnh thực tế.');
      return;
    }
    if (!_roomTab &&
        (_district == null ||
            (_wardRequired && _fields['ward']!.text.trim().isEmpty))) {
      _message('Vui lòng chọn quận/huyện và phường/xã.');
      return;
    }
    final property = properties
        .where((p) => p.id == _selectedPropertyId)
        .firstOrNull;
    if (_roomTab && property == null) {
      _message('Chọn cơ sở trước khi tạo phòng.');
      return;
    }
    if (_roomTab && int.parse(_fields['floor']!.text) > property!.floors) {
      _message('Tầng phòng vượt quá số tầng của cơ sở.');
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(hostRepositoryProvider);
      if (_editingProperty) {
        final base = widget.propertyToEdit!;
        await repository.updateProperty(
          base,
          {
            'name': _fields['name']!.text.trim(),
            'address': _fields['address']!.text.trim(),
            'city': _city,
            'district': _district!,
            'ward': _fields['ward']!.text.trim(),
            'plannedRooms': int.parse(_fields['planned']!.text),
            'floors': int.parse(_fields['floors']!.text),
            'minRent': _rent.start,
            'maxRent': _rent.end,
          },
          List.of(_keptHouseImages),
          List.of(_houseImages),
          _operationId,
        );
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      if (_roomTab) {
        final user = ref.read(userProfileProvider).value;
        final parent = property!;
        await repository.createRoom(
          RoomModel(
            id: '',
            propertyId: parent.id,
            roomCode: _fields['code']!.text.trim().toUpperCase(),
            title: 'Phòng ${_fields['code']!.text.trim()} • ${parent.name}',
            description: _fields['notes']!.text.trim(),
            price: double.parse(_fields['price']!.text),
            deposit: double.parse(_fields['deposit']!.text),
            address: parent.fullAddress,
            district: parent.district.isNotEmpty
                ? parent.district
                : parent.ward,
            city: parent.city,
            area: _area.start,
            minArea: _area.start,
            maxArea: _area.end,
            roomType: _roomType,
            amenities: _amenities.toList(),
            images: const [],
            hostId: uid,
            hostName: user?.displayName ?? 'Chủ trọ',
            hostPhone: user?.phoneNumber ?? '',
            hostAvatar: user?.avatarUrl ?? '',
            capacity: int.parse(_fields['capacity']!.text),
            floor: int.parse(_fields['floor']!.text),
            rating: 0,
            createdAt: DateTime.now(),
          ),
          List.of(images),
          _operationId,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }
      if (_draftOwner != uid) {
        _draftPropertyId = null;
        _draftOwner = uid;
      }
      _draftPropertyId ??= repository.newPropertyId();
      final house = HostProperty(
        id: _draftPropertyId!,
        hostId: uid,
        name: _fields['name']!.text.trim(),
        address: _fields['address']!.text.trim(),
        city: _city,
        district: _district!,
        ward: _fields['ward']!.text.trim(),
        plannedRooms: int.parse(_fields['planned']!.text),
        floors: int.parse(_fields['floors']!.text),
        minRent: _rent.start,
        maxRent: _rent.end,
      );
      await repository.createProperty(house, List.of(images), _proof);
      if (!mounted) return;
      setState(() {
        _justCreated = house;
        _selectedPropertyId = house.id;
        _roomTab = true;
        _draftPropertyId = null;
        _houseImages.clear();
        _proof = null;
        for (final field in ['name', 'address', 'ward', 'planned']) {
          _fields[field]!.clear();
        }
      });
      _message('Đã lưu cơ sở. Bạn có thể tạo phòng cho cơ sở này.');
    } catch (error) {
      if (mounted) _message(hostErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Chủ trọ - Phản hồi thao tác - Luồng đi: Thông báo ngay tại form,
  // thay thông báo trước đó để không xếp hàng nhiều lỗi liên tiếp.
  void _message(String text) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Chủ trọ - Hiển thị form tạo - Luồng đi: Chuyển tab giữ dữ liệu
  // chưa lưu; trong lúc lưu khóa nút và quay lại để tránh gửi hai lần.
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(hostSessionProvider);
    final asyncProperties = ref.watch(hostPropertiesProvider);
    final properties = (asyncProperties.value ?? <HostProperty>[])
        .where((property) => property.hostId == session.value)
        .toList();
    if (_justCreated != null &&
        _justCreated!.hostId == session.value &&
        !properties.any((p) => p.id == _justCreated!.id)) {
      properties.add(_justCreated!);
    }
    final locked = _saving || _picking;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            _editingProperty
                ? 'Chỉnh sửa cơ sở'
                : _roomTab
                ? 'Tạo phòng'
                : 'Tạo cơ sở (Nhà)',
          ),
          leading: IconButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
        ),
        body: Column(
          children: [
            if (!_editingProperty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EEFA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      for (final room in [false, true])
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: _roomTab == room
                                  ? Colors.white
                                  : Colors.transparent,
                              foregroundColor: _roomTab == room
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            onPressed: locked
                                ? null
                                : () => setState(() => _roomTab = room),
                            child: Text(room ? 'Tạo phòng' : 'Tạo cơ sở (Nhà)'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: AbsorbPointer(
                absorbing: locked,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (session.isLoading) const LinearProgressIndicator(),
                    if (session.hasError)
                      _notice(hostErrorMessage(session.error!)),
                    if (!session.isLoading && session.value == null)
                      _notice(
                        'Bạn đang xem giao diện. Đăng nhập tài khoản Chủ trọ để lưu nhà/phòng lên Firebase.',
                      ),
                    if (_roomTab && asyncProperties.isLoading)
                      const LinearProgressIndicator(),
                    if (_roomTab && asyncProperties.hasError)
                      _notice(hostErrorMessage(asyncProperties.error!)),
                    if (_roomTab)
                      _buildRoomForm(properties)
                    else
                      _buildHouseForm(),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Hủy'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        locked ||
                            session.value == null ||
                            (_roomTab &&
                                (properties.isEmpty ||
                                    asyncProperties.hasError))
                        ? null
                        : () => _save(properties),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _saving
                          ? 'Đang lưu...'
                          : _editingProperty
                          ? 'Lưu thay đổi'
                          : _roomTab
                          ? 'Lưu phòng'
                          : 'Lưu & tạo phòng',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Chủ trọ - Form cơ sở - Luồng đi: Chọn ảnh, địa chỉ theo danh mục,
  // quy mô và khoảng giá; cùng form được dùng cho cả tạo mới và chỉnh sửa.
  Widget _buildHouseForm() {
    final cityOptions = VietnamLocations.provinces.toList();
    if (!cityOptions.contains(_city)) cityOptions.insert(0, _city);
    final districtOptions = VietnamLocations.getAdministrativeDistricts(
      _city,
    ).toList();
    if (_district != null && !districtOptions.contains(_district)) {
      districtOptions.insert(0, _district!);
    }
    final wardOptions = _district == null
        ? <String>[]
        : VietnamLocations.getWards(_city, _district!).toList();
    final currentWard = _fields['ward']!.text.trim();
    if (_district != null &&
        currentWard.isNotEmpty &&
        !wardOptions.contains(currentWard)) {
      wardOptions.insert(0, currentWard);
    }
    return Form(
      key: _houseForm,
      child: Column(
        children: [
          _photoCard(
            _houseImages,
            5,
            'Hình ảnh cơ sở / Mặt tiền',
            existingImages: _keptHouseImages,
          ),
          _section('Định danh tòa nhà', Icons.apartment, [
            _field(
              'name',
              'Tên cơ sở / Tòa nhà *',
              hint: 'Ví dụ: Nhà trọ Đặng Văn Bi',
              maxLength: 100,
            ),
            _field(
              'address',
              'Số nhà, đường *',
              hint: 'Nhập địa chỉ cụ thể',
              maxLength: 200,
            ),
            DropdownButtonFormField<String>(
              initialValue: _city,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Tỉnh / Thành phố *',
              ),
              items: cityOptions
                  .map(
                    (city) => DropdownMenuItem(value: city, child: Text(city)),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                _city = value!;
                _district = null;
                _fields['ward']!.clear();
              }),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey('host_district_$_city'),
              initialValue: _district,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Quận / Huyện *'),
              hint: const Text('Chọn quận/huyện'),
              items: districtOptions
                  .map(
                    (district) => DropdownMenuItem(
                      value: district,
                      child: Text(district, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: districtOptions.isEmpty
                  ? null
                  : (value) => setState(() {
                      _district = value;
                      _fields['ward']!.clear();
                    }),
              validator: (value) => value == null || value.isEmpty
                  ? 'Vui lòng chọn quận/huyện'
                  : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey('host_ward_${_city}_${_district ?? 'none'}'),
              initialValue: _district == null || currentWard.isEmpty
                  ? null
                  : currentWard,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _wardRequired ? 'Phường / Xã *' : 'Phường / Xã',
              ),
              hint: const Text('Chọn phường/xã'),
              items: wardOptions
                  .map(
                    (ward) => DropdownMenuItem(
                      value: ward,
                      child: Text(ward, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: wardOptions.isEmpty
                  ? null
                  : (value) => setState(() {
                      _fields['ward']!.text = value ?? '';
                    }),
              validator: (value) =>
                  _wardRequired && (value == null || value.isEmpty)
                  ? 'Vui lòng chọn phường/xã'
                  : null,
            ),
            if (wardOptions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _district == null
                      ? 'Chọn quận/huyện trước để xem danh sách phường/xã.'
                      : 'Khu vực này chưa có dữ liệu phường/xã. Bạn có thể bỏ qua và lưu cơ sở.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                  ),
                ),
              ),
          ]),
          _section('Quy mô', Icons.tune, [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    'planned',
                    'Tổng số phòng *',
                    number: true,
                    max: 1000,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field('floors', 'Số tầng *', number: true, max: 100),
                ),
              ],
            ),
            const Text(
              'Số phòng được tạo không được vượt quá tổng số phòng của cơ sở.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            HostRangeInput(
              label: 'Khung giá thuê / tháng',
              unit: 'đ',
              values: _rent,
              sliderMax: 20000000,
              onChanged: (value) => setState(() => _rent = value),
            ),
          ]),
          if (!_editingProperty)
            _section('Giấy tờ pháp lý (tùy chọn)', Icons.security, [
              const Text(
                'Ảnh sổ hồng hoặc giấy phép kinh doanh. JPG/PNG, tối đa 15 MB.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (_proof != null) ...[
                const SizedBox(height: 12),
                Image.memory(_proof!.bytes, height: 100),
                TextButton(
                  onPressed: () => setState(() => _proof = null),
                  child: const Text('Xóa giấy tờ'),
                ),
              ],
              OutlinedButton.icon(
                onPressed: () => _pickImages(proof: true),
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _proof == null ? 'Chọn ảnh giấy tờ' : 'Đổi ảnh giấy tờ',
                ),
              ),
              const Text(
                'Chỉ chủ tài khoản được truy cập. Tải lên không đồng nghĩa đã được xác minh.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ]),
        ],
      ),
    );
  }

  // Chủ trọ - Form phòng - Luồng đi: Chọn nhà đã lưu, nhập mã phòng,
  // giá và diện tích, chọn tiện ích rồi lưu phòng trống thuộc cơ sở đó.
  Widget _buildRoomForm(List<HostProperty> properties) {
    final selected = properties
        .where((p) => p.id == _selectedPropertyId)
        .firstOrNull;
    final floorCount = selected?.floors ?? 0;
    final currentFloor = int.tryParse(_fields['floor']!.text) ?? 1;
    final selectedFloor = floorCount > 0
        ? currentFloor.clamp(1, floorCount)
        : null;
    if (selectedFloor != null) {
      _fields['floor']!.text = selectedFloor.toString();
    }
    return Form(
      key: _roomForm,
      child: Column(
        children: [
          _section('Thuộc cơ sở / Tòa nhà', Icons.home_work_outlined, [
            if (properties.isEmpty) ...[
              const Text('Chưa có cơ sở. Hãy tạo nhà trước khi tạo phòng.'),
              TextButton(
                onPressed: () => setState(() => _roomTab = false),
                child: const Text('Tạo cơ sở trước'),
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                key: ValueKey('property_${selected?.id}_${properties.length}'),
                initialValue: selected?.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Chọn cơ sở *'),
                items: properties
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedPropertyId = value),
                validator: (value) =>
                    value == null ? 'Vui lòng chọn cơ sở' : null,
              ),
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    selected.fullAddress,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ]),
          _photoCard(_roomImages, 8, 'Hình ảnh thực tế'),
          _section('Thông tin phòng mới', Icons.meeting_room_outlined, [
            _field(
              'code',
              'Số / Mã phòng *',
              hint: 'Ví dụ: A101',
              maxLength: 30,
            ),
            DropdownButtonFormField<String>(
              initialValue: _roomType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Loại phòng'),
              items:
                  [
                        'Phòng trọ',
                        'Căn hộ mini',
                        'Chung cư mini',
                        'Nhà nguyên căn',
                      ]
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _roomType = value!),
            ),
            const SizedBox(height: 14),
            HostRangeInput(
              label: 'Khoảng diện tích phòng',
              unit: 'm²',
              values: _area,
              minimum: 1,
              sliderMax: 100,
              onChanged: (value) => setState(() => _area = value),
            ),
            _field(
              'price',
              'Giá thuê hàng tháng (đ) *',
              number: true,
              max: 1000000000,
              hint: 'Ví dụ: 2500000',
            ),
            _field(
              'deposit',
              'Tiền cọc (đ) *',
              number: true,
              allowZero: true,
              max: 1000000000,
            ),
            DropdownButtonFormField<int>(
              key: ValueKey('host_floor_${selected?.id}_$floorCount'),
              initialValue: selectedFloor,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Tầng *'),
              hint: const Text('Chọn cơ sở trước'),
              items: [
                for (var floor = 1; floor <= floorCount; floor++)
                  DropdownMenuItem(value: floor, child: Text('Tầng $floor')),
              ],
              onChanged: selectedFloor == null
                  ? null
                  : (value) => setState(() {
                      _fields['floor']!.text = value.toString();
                    }),
              validator: (value) => value == null ? 'Vui lòng chọn tầng' : null,
            ),
            const SizedBox(height: 14),
            _field('capacity', 'Số người ở tối đa *', number: true),
          ]),
          _amenitySection(),
          _section('Ghi chú & Quy định riêng', Icons.notes, [
            TextFormField(
              controller: _fields['notes'],
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'Giờ giấc, nội quy, thông tin thêm...',
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // Chủ trọ - Chọn tiện ích phòng - Luồng đi: Tích chọn từng dòng,
  // thêm tiện ích riêng và thu gọn; các lựa chọn được lưu cùng phòng.
  Widget _amenitySection() => HostRoomSection(
    title: 'Tiện ích & Trang bị',
    icon: Icons.tune,
    trailing: Text(
      '${_amenities.length} chọn',
      style: const TextStyle(fontSize: 11, color: Color(0xFF00865B)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customAmenity,
                maxLength: 60,
                decoration: const InputDecoration(
                  hintText: 'Thêm tiện ích...',
                  isDense: true,
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: () {
                final value = _customAmenity.text.trim();
                if (value.isNotEmpty && value.length <= 60) {
                  setState(() => _amenities.add(value));
                  _customAmenity.clear();
                }
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final value in {
          ..._amenities,
          if (_amenitiesExpanded) ..._amenityOptions,
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(value, style: const TextStyle(fontSize: 12)),
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
          onPressed: () =>
              setState(() => _amenitiesExpanded = !_amenitiesExpanded),
          child: Text(_amenitiesExpanded ? 'Thu gọn ↑' : 'Xem thêm ↓'),
        ),
      ],
    ),
  );
  // Chủ trọ - Bộ ảnh của form - Luồng đi: Thêm/xóa ảnh trước khi lưu;
  // ảnh đầu tiên là ảnh bìa và bộ ảnh nhà tách biệt với bộ ảnh phòng.
  Widget _photoCard(
    List<HostUpload> images,
    int max,
    String title, {
    List<String> existingImages = const [],
  }) => _section(title, Icons.photo_library_outlined, [
    Text(
      '${existingImages.length + images.length}/$max ảnh • JPG/PNG, tối đa 5 MB mỗi ảnh',
      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < existingImages.length; i++)
          SizedBox(
            width: 94,
            height: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    existingImages[i],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFEFF6FF),
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                if (i == 0)
                  const Positioned(
                    bottom: 3,
                    left: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Colors.black54),
                      child: Padding(
                        padding: EdgeInsets.all(3),
                        child: Text(
                          'Ảnh bìa',
                          style: TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: 'Bỏ ảnh ${i + 1}',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(28, 28),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => setState(() {
                      existingImages.removeAt(i);
                    }),
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ),
              ],
            ),
          ),
        for (var i = 0; i < images.length; i++)
          SizedBox(
            width: 94,
            height: 100,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(images[i].bytes, fit: BoxFit.cover),
                ),
                if (i == 0 && existingImages.isEmpty)
                  const Positioned(
                    bottom: 3,
                    left: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Colors.black54),
                      child: Padding(
                        padding: EdgeInsets.all(3),
                        child: Text(
                          'Ảnh bìa',
                          style: TextStyle(fontSize: 10, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    tooltip: 'Xóa ảnh ${i + 1}',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(28, 28),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => setState(() => images.removeAt(i)),
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ),
              ],
            ),
          ),
        if (existingImages.length + images.length < max)
          SizedBox(
            width: 94,
            height: 100,
            child: OutlinedButton(
              onPressed: () => _pickImages(),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined),
                  SizedBox(height: 8),
                  Text(
                    'Thêm ảnh',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  ]);

  // Chủ trọ - Nhóm thông tin và trường nhập - Luồng đi: Dùng chung
  // hai form, kiểm tra bắt buộc và số nguyên dương trước khi gửi Firebase.
  Widget _section(String title, IconData icon, List<Widget> children) =>
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      );
  Widget _notice(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: AppColors.warning),
    ),
  );
  Widget _field(
    String name,
    String label, {
    String? hint,
    bool number = false,
    bool allowZero = false,
    int max = 1000000000,
    int maxLength = 100,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      key: ValueKey('host_field_$name'),
      controller: _fields[name],
      keyboardType: number ? TextInputType.number : TextInputType.text,
      inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
      maxLength: number ? null : maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
      ),
      validator: (text) {
        if (text == null || text.trim().isEmpty) {
          return 'Vui lòng nhập thông tin';
        }
        if (number) {
          final value = int.tryParse(text);
          if (value == null || value < (allowZero ? 0 : 1) || value > max) {
            return 'Nhập từ ${allowZero ? 0 : 1} đến $max';
          }
        }
        return null;
      },
    ),
  );
}
