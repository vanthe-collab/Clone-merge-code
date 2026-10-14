import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/utils/vietnamese_utils.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/user_provider.dart';
import '../data/host_property.dart';
import '../providers/host_dashboard_provider.dart';
import '../providers/host_management_provider.dart';
import 'host_create_screen.dart';

/// Màn hình Tạo bài đăng role chủ trọ
/// Đáp ứng thiết kế Figma/PNG, schema SDS và Database.docx:
/// - Dropdown chọn Khu nhà & Phòng trước thông tin cơ bản
/// - Tự động điền dữ liệu phòng đã lưu (tiêu đề, giá thuê, tiền cọc, diện tích, ảnh, tiện ích...)
/// - Giá thuê digitsOnly, bố cục [ Giá thuê ] [ Tiền cọc ]
/// - Tiện ích đọc từ Firestore, tiện ích tùy chọn local-only trước khi submit
/// - Bảng liên kết TienIch_Phong, lưu bài đăng posts và rollback handling
class HostCreatePostScreen extends ConsumerStatefulWidget {
  const HostCreatePostScreen({
    super.key,
    this.initialProperty,
    this.initialRoom,
  });

  final HostProperty? initialProperty;
  final RoomModel? initialRoom;

  @override
  ConsumerState<HostCreatePostScreen> createState() =>
      _HostCreatePostScreenState();
}

class _HostCreatePostScreenState extends ConsumerState<HostCreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _price = TextEditingController();
  final _depositController = TextEditingController();
  final _areaController = TextEditingController(text: '25');
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  final _customAmenity = TextEditingController();

  final _images = <HostUpload>[];
  final _existingImageUrls = <String>[];
  final _selectedAmenities = <String>{};
  final _customAmenities = <String>[];

  HostProperty? _property;
  RoomModel? _selectedRoom;
  bool _saving = false;
  bool _picking = false;
  bool _amenitiesExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialProperty != null) {
      _property = widget.initialProperty;
      _address.text = widget.initialProperty!.fullAddress;
    }
    if (widget.initialRoom != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _onRoomSelected(widget.initialRoom);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final field in [
      _title,
      _price,
      _depositController,
      _areaController,
      _address,
      _phone,
      _description,
      _customAmenity,
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _title.clear();
    _price.clear();
    _depositController.clear();
    _areaController.text = '25';
    _address.clear();
    _phone.clear();
    _description.clear();
    _customAmenity.clear();
    setState(() {
      _property = null;
      _selectedRoom = null;
      _images.clear();
      _existingImageUrls.clear();
      _selectedAmenities.clear();
      _customAmenities.clear();
      _amenitiesExpanded = false;
    });
  }

  void _onPropertySelected(HostProperty? prop) {
    if (prop == null) return;
    setState(() {
      _property = prop;
      _selectedRoom = null;
      _title.clear();
      _price.clear();
      _depositController.clear();
      _areaController.text = '25';
      _address.text = prop.fullAddress;
      _existingImageUrls.clear();
      _images.clear();
      _selectedAmenities.clear();
    });
  }

  String _cleanImageUrl(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      final u = (raw['url'] ??
              raw['duongDan'] ??
              raw['image'] ??
              raw['imageUrl'] ??
              raw['link'] ??
              '')
          .toString()
          .trim();
      return _cleanImageUrl(u);
    }
    var s = raw.toString().trim();
    if (s.startsWith('"') && s.endsWith('"') && s.length > 2) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.startsWith("'") && s.endsWith("'") && s.length > 2) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.startsWith('{') && s.endsWith('}')) {
      final match = RegExp(r'(?:duongDan|url|image|imageUrl|link):\s*([^,}]+)')
          .firstMatch(s);
      if (match != null) {
        s = match
            .group(1)!
            .trim()
            .replaceAll('"', '')
            .replaceAll("'", "");
      }
    }
    return s;
  }

  void _onRoomSelected(RoomModel? room) async {
    if (room == null) return;
    setState(() {
      _selectedRoom = room;
      _title.text = room.title.isNotEmpty ? room.title : room.roomCode;
      _areaController.text = room.area > 0
          ? room.area.round().toString()
          : '25';
      _price.text = room.price > 0 ? room.price.round().toString() : '';

      // Tự động điền tiền cọc từ phòng đã chọn:
      if (room.deposit > 0) {
        _depositController.text = room.deposit.round().toString();
      } else if (room.price > 0) {
        _depositController.text = room.price.round().toString();
      } else {
        _depositController.text = room.deposit.round().toString();
      }

      _address.text = room.address.isNotEmpty
          ? room.address
          : (_property?.fullAddress ?? '');

      // 1. Lấy ảnh từ room.images
      _existingImageUrls.clear();
      for (final img in room.images) {
        final c = _cleanImageUrl(img);
        if (c.isNotEmpty && !_existingImageUrls.contains(c)) {
          _existingImageUrls.add(c);
        }
      }

      // 2. Tiện ích từ room.amenities
      _selectedAmenities.clear();
      _selectedAmenities.addAll(
        room.amenities.map((a) => a.trim()).where((a) => a.isNotEmpty),
      );
      if (_selectedAmenities.isNotEmpty) {
        _amenitiesExpanded = true;
      }
    });

    if (room.id.isNotEmpty) {
      // Tải trực tiếp thông tin từ Firestore nếu room trong danh sách Riverpod chưa có đầy đủ
      try {
        final db = FirebaseFirestore.instance;
        var doc = await db
            .collection(FirestoreCollections.hostRooms)
            .doc(room.id)
            .get();
        if (!doc.exists) {
          doc = await db
              .collection(FirestoreCollections.publicRooms)
              .doc(room.id)
              .get();
        }
        if (doc.exists && mounted && _selectedRoom?.id == room.id) {
          final data = doc.data() ?? {};
          final rawDeposit = data['deposit'] ??
              data['tienCoc'] ??
              data['tien_coc'] ??
              data['depositAmount'] ??
              data['tienDatCoc'] ??
              data['datCoc'];
          double? parsedDep;
          if (rawDeposit is num) parsedDep = rawDeposit.toDouble();
          if (rawDeposit is String && rawDeposit.trim().isNotEmpty) {
            parsedDep = double.tryParse(
              rawDeposit.trim().replaceAll(',', '').replaceAll('.', ''),
            );
          }
          if (parsedDep == null || parsedDep <= 0) {
            final percent =
                data['phanTramTienCoc'] ?? data['phan_tram_tien_coc'];
            final p = data['price'] ??
                data['gia'] ??
                data['giaThue'] ??
                data['giaThueThang'];
            double? parsedP;
            if (p is num) parsedP = p.toDouble();
            if (p is String && p.trim().isNotEmpty) {
              parsedP = double.tryParse(
                p.trim().replaceAll(',', '').replaceAll('.', ''),
              );
            }
            if (percent is num &&
                percent > 0 &&
                parsedP != null &&
                parsedP > 0) {
              parsedDep = parsedP * percent / 100;
            }
          }
          if (parsedDep != null && parsedDep > 0) {
            setState(() {
              _depositController.text = parsedDep!.round().toString();
            });
          }

          // Trích xuất ảnh trực tiếp từ document phòng Firestore:
          final rawDocImages = data['images'] ??
              data['roomImages'] ??
              data['anhPhong'] ??
              data['imageUrls'] ??
              data['photos'] ??
              data['photoUrls'] ??
              data['danhSachAnh'] ??
              data['hinhAnh'];
          final docImgs = <String>[];
          if (rawDocImages is List) {
            for (final item in rawDocImages) {
              final c = _cleanImageUrl(item);
              if (c.isNotEmpty && !docImgs.contains(c)) {
                docImgs.add(c);
              }
            }
          } else if (rawDocImages != null) {
            final c = _cleanImageUrl(rawDocImages);
            if (c.isNotEmpty && !docImgs.contains(c)) {
              docImgs.add(c);
            }
          }
          if (docImgs.isNotEmpty && mounted) {
            setState(() {
              for (final img in docImgs) {
                if (!_existingImageUrls.contains(img)) {
                  _existingImageUrls.add(img);
                }
              }
            });
          }
        }
      } catch (_) {}

      // Tải thêm tiện ích từ bảng liên kết TienIch_Phong của chính phòng đó nếu có
      try {
        final fromTienIch = await ref
            .read(hostRepositoryProvider)
            .getRoomAmenitiesFromTienIchPhong(room.id);
        if (mounted && _selectedRoom?.id == room.id && fromTienIch.isNotEmpty) {
          setState(() {
            _selectedAmenities.addAll(fromTienIch);
          });
        }
      } catch (_) {}

      // Tải thêm từ bảng AnhPhong / roomImages nếu danh sách ảnh hiện tại còn trống
      try {
        final fromAnhPhong = await ref
            .read(hostRepositoryProvider)
            .getRoomImagesFromAnhPhong(room.id);
        if (mounted &&
            _selectedRoom?.id == room.id &&
            fromAnhPhong.isNotEmpty) {
          setState(() {
            for (final img in fromAnhPhong) {
              final c = _cleanImageUrl(img);
              if (c.isNotEmpty && !_existingImageUrls.contains(c)) {
                _existingImageUrls.add(c);
              }
            }
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _pickImages() async {
    final totalImages = _existingImageUrls.length + _images.length;
    if (totalImages >= 10) {
      _message('Bài đăng chỉ được tối đa 10 ảnh.');
      return;
    }
    setState(() => _picking = true);
    try {
      final files = await ref
          .read(hostImagePickerProvider)
          .pickMultiImage(imageQuality: 88);
      final selected = <HostUpload>[];
      for (final file in files) {
        if (_existingImageUrls.length + _images.length + selected.length >=
            10) {
          break;
        }
        final size = await file.length();
        if (size > 5 * 1024 * 1024) {
          throw StateError('Mỗi ảnh không được vượt quá 5 MB.');
        }
        final bytes = await file.readAsBytes();
        final contentType = _imageContentType(bytes);
        if (contentType == null) {
          throw StateError('Chỉ hỗ trợ ảnh JPG hoặc PNG.');
        }
        selected.add(HostUpload(bytes, contentType));
      }
      if (mounted) setState(() => _images.addAll(selected));
    } catch (error) {
      if (mounted) _message(hostErrorMessage(error));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  String? _imageContentType(Uint8List bytes) {
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10;
    final isJpg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (isPng) return 'image/png';
    if (isJpg) return 'image/jpeg';
    return null;
  }

  void _addCustomAmenity(List<Map<String, String>> catalogItems) {
    final raw = _customAmenity.text;
    final normalized = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      _message('Vui lòng nhập tên tiện ích.');
      return;
    }

    // 1. Chống trùng với danh mục tiện ích từ Firestore (không phân biệt dấu tiếng Việt, hoa/thường)
    final catalogMatch = catalogItems
        .where(
          (item) =>
              normalizeVietnameseComparison(item['name']!) ==
              normalizeVietnameseComparison(normalized),
        )
        .firstOrNull;

    if (catalogMatch != null) {
      setState(() {
        _selectedAmenities.add(catalogMatch['name']!);
        _customAmenity.clear();
        _amenitiesExpanded = true;
      });
      _message(
        'Tiện ích "${catalogMatch['name']}" đã có trong danh mục (đã tự động chọn).',
      );
      return;
    }

    // 2. Chống trùng với tiện ích sẵn có của phòng (không phân biệt dấu tiếng Việt, hoa/thường)
    final roomMatch = (_selectedRoom?.amenities ?? [])
        .where((item) =>
            normalizeVietnameseComparison(item) ==
            normalizeVietnameseComparison(normalized))
        .firstOrNull;
    if (roomMatch != null) {
      setState(() {
        _selectedAmenities.add(roomMatch);
        _customAmenity.clear();
        _amenitiesExpanded = true;
      });
      _message('Tiện ích "$roomMatch" đã có sẵn trong phòng.');
      return;
    }

    // 3. Chống trùng với tiện ích tùy chọn local (không phân biệt dấu tiếng Việt, hoa/thường)
    final customMatch = _customAmenities
        .where((item) =>
            normalizeVietnameseComparison(item) ==
            normalizeVietnameseComparison(normalized))
        .firstOrNull;

    if (customMatch != null) {
      setState(() {
        _selectedAmenities.add(customMatch);
        _customAmenity.clear();
        _amenitiesExpanded = true;
      });
      _message('Tiện ích tùy chọn "$customMatch" đã tồn tại.');
      return;
    }

    // 4. Thêm vào list local dưới dạng checkbox đã chọn (CHỈ LƯU LOCAL TRONG FORM, CHƯA GHI FIREBASE)
    setState(() {
      _customAmenities.add(normalized);
      _selectedAmenities.add(normalized);
      _customAmenity.clear();
      _amenitiesExpanded = true;
    });
  }

  void _toggleAmenity(String name) {
    setState(() {
      if (_selectedAmenities.contains(name)) {
        _selectedAmenities.remove(name);
      } else {
        _selectedAmenities.add(name);
      }
    });
  }

  void _removeCustomAmenity(String name) {
    setState(() {
      _customAmenities.remove(name);
      _selectedAmenities.remove(name);
    });
  }

  Future<void> _save(String uid, UserProfile? profile) async {
    if (_property == null) {
      _message('Vui lòng chọn khu nhà.');
      return;
    }
    if (_selectedRoom == null) {
      _message('Vui lòng chọn phòng.');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final totalImages = _existingImageUrls.length + _images.length;
    if (totalImages == 0) {
      _message('Vui lòng chọn ít nhất 1 ảnh.');
      return;
    }

    final parsedPrice = double.tryParse(_price.text.trim()) ?? 0;
    if (parsedPrice <= 0) {
      _message('Giá thuê phải lớn hơn 0.');
      return;
    }

    setState(() => _saving = true);
    try {
      final parsedArea =
          double.tryParse(_areaController.text.trim().replaceAll(',', '.')) ??
          25.0;
      final parsedDeposit =
          double.tryParse(_depositController.text.trim()) ??
              (_selectedRoom?.deposit ?? 0.0);
      int depositPercent = 20;
      if (parsedPrice > 0 && parsedDeposit > 0) {
        depositPercent = ((parsedDeposit / parsedPrice) * 100).round();
      }
      if (!const [10, 20, 30, 40, 50].contains(depositPercent)) {
        const allowed = [10, 20, 30, 40, 50];
        depositPercent = allowed.reduce((a, b) =>
            (depositPercent - a).abs() < (depositPercent - b).abs() ? a : b);
      }

      final roomToSave = RoomModel(
        id: _selectedRoom?.id ?? '',
        propertyId: _property!.id,
        roomCode: _selectedRoom?.roomCode ?? 'P101',
        title: _title.text.trim(),
        description: _description.text.trim(),
        price: parsedPrice,
        deposit: parsedDeposit,
        address: _address.text.trim(),
        district: _property!.district.isNotEmpty
            ? _property!.district
            : (_property!.ward.isNotEmpty ? _property!.ward : 'TP. Thủ Đức'),
        city: _property!.city.isNotEmpty ? _property!.city : 'TP. Hồ Chí Minh',
        area: parsedArea,
        roomType: _selectedRoom?.roomType ?? 'Phòng trọ',
        amenities: _selectedAmenities.toList(),
        images: _existingImageUrls,
        hostId: uid,
        hostName: profile?.displayName ?? 'Chủ nhà',
        hostPhone: _phone.text.trim(),
        hostAvatar: profile?.avatarUrl ?? '',
        rating: 0.0,
        reviewCount: 0,
        isAvailable: true,
        capacity: _selectedRoom?.capacity ?? 2,
        floor: _selectedRoom?.floor ?? 1,
        createdAt: DateTime.now(),
        status: 'available',
      );

      final catalogItems = ref.read(hostAmenitiesProvider).value ?? [];
      final catalogMap = {
        for (final item in catalogItems)
          item['name']!.trim().toLowerCase(): item['id']!,
      };

      final opId = 'post_${DateTime.now().millisecondsSinceEpoch}';

      await ref
          .read(hostRepositoryProvider)
          .createPostWithAmenities(
            room: roomToSave,
            images: List.of(_images),
            operationId: opId,
            selectedAmenities: _selectedAmenities,
            customAmenities: _customAmenities,
            catalogAmenitiesMap: catalogMap,
            chuNhaId: uid,
            diaDiemId: _property!.ward.isNotEmpty
                ? _property!.ward
                : (_property!.district.isNotEmpty
                      ? _property!.district
                      : 'TP. Thủ Đức'),
            loaiThueId: 'thang',
            trangThaiId: 'dangHienThi',
            tieuDe: _title.text.trim(),
            moTa: _description.text.trim(),
            giaThue: parsedPrice,
            phanTramTienCoc: depositPercent,
            tienCoc: parsedDeposit,
            soDienThoaiLienHe: _phone.text.trim(),
            authorName: profile?.displayName ?? 'Chủ nhà',
            authorAvatar: profile?.avatarUrl ?? '',
            nhaTroId: _property!.id,
            phongId: _selectedRoom!.id,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đăng bài thành công!')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _message(hostErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatCurrency(String text) {
    if (text.isEmpty) return 'Chưa nhập';
    final numVal = int.tryParse(text);
    if (numVal == null) return text;
    return NumberFormat.decimalPattern('vi').format(numVal);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(hostSessionProvider).value;
    final profile = ref.watch(userProfileProvider).value;
    final amenities = ref.watch(hostAmenitiesProvider);
    final propertiesAsync = ref.watch(hostPropertiesProvider);
    final allRoomsAsync = ref.watch(hostRoomsProvider);
    final uid = session;

    final properties = propertiesAsync.value ?? [];
    final allRooms = allRoomsAsync.value ?? [];

    // Lọc danh sách phòng theo nhaTroId đã chọn
    final propertyRooms = _property != null
        ? allRooms.where((r) => r.propertyId == _property!.id).toList()
        : <RoomModel>[];

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _saving ? null : () => Navigator.pop(context),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tạo bài đăng',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                'Dành cho chủ nhà & đối tác uy tín',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),
          actions: [
            TextButton(
              key: const ValueKey('reset_button'),
              onPressed: _saving ? null : _resetForm,
              child: const Text(
                'Đặt lại',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E60F2),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  key: const ValueKey('submit_post_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E60F2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _saving || _picking || uid == null
                      ? null
                      : () => _save(uid, profile),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ĐĂNG BÀI NGAY',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // PHẦN 1: CHỌN DỮ LIỆU CÓ SẴN (Khu nhà & Phòng)
                    _propertyAndRoomSection(
                      propertiesAsync: propertiesAsync,
                      properties: properties,
                      allRoomsAsync: allRoomsAsync,
                      propertyRooms: propertyRooms,
                    ),
                    const SizedBox(height: 16),

                    // PHẦN 2: HÌNH ẢNH & VIDEO PHÒNG
                    _photoSection(),
                    const SizedBox(height: 16),

                    // PHẦN 3: THÔNG TIN CƠ BẢN
                    _basicInfoTitle(),
                    const SizedBox(height: 12),
                    _textField(
                      _title,
                      'Mô tả phòng *',
                      'Phòng trọ studio có gác đúc cao ráo, full nội thất, giờ tự do',
                      key: const ValueKey('title_input'),
                      maxLength: 240,
                    ),
                    // Bố cục mới: [ Giá thuê ] [ Tiền cọc: 10% ▼ ]
                    _priceAndDepositRow(),
                    const SizedBox(height: 12),
                    _textField(
                      _areaController,
                      'Diện tích (m²)',
                      '25',
                      key: const ValueKey('area_input'),
                      keyboard: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      suffixText: 'm²',
                    ),
                    const SizedBox(height: 16),

                    // PHẦN 4: TIỆN ÍCH & YÊU CẦU
                    amenities.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, _) => const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text('Không tải được danh mục tiện ích.'),
                      ),
                      data: (items) => _amenitySection(items),
                    ),
                    const SizedBox(height: 16),

                    // PHẦN 5: VỊ TRÍ & LIÊN HỆ
                    _contactTitle(),
                    const SizedBox(height: 10),
                    _contactField(
                      _address,
                      'Địa chỉ *',
                      Icons.location_on_outlined,
                      '18 Đường số 6, Tăng Nhơn Phú B, TP. Thủ Đức',
                      key: const ValueKey('address_input'),
                    ),
                    Row(
                      children: [
                        Expanded(child: _priceSummary()),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _contactField(
                            _phone,
                            'Số điện thoại *',
                            Icons.phone_outlined,
                            '0987 654 321',
                            key: const ValueKey('phone_input'),
                            keyboard: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    _textField(
                      _description,
                      'Mô tả chi tiết',
                      'Nội thất, giờ giấc, quy định, tiện ích xung quanh...',
                      key: const ValueKey('description_input'),
                      maxLines: 5,
                      maxLength: 2000,
                    ),
                    if (uid == null) _authWarning(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 2 dropdown Chọn khu nhà & Chọn phòng đặt trước Thông tin cơ bản
  Widget _propertyAndRoomSection({
    required AsyncValue<List<HostProperty>> propertiesAsync,
    required List<HostProperty> properties,
    required AsyncValue<List<RoomModel>> allRoomsAsync,
    required List<RoomModel> propertyRooms,
  }) {
    String? propertyHint;
    if (propertiesAsync.isLoading) {
      propertyHint = 'Đang tải danh sách nhà...';
    } else if (propertiesAsync.hasError) {
      propertyHint = 'Lỗi Firestore';
    } else if (properties.isEmpty) {
      propertyHint = 'Không có nhà';
    } else {
      propertyHint = 'Chọn khu nhà *';
    }

    String? roomHint;
    final bool roomEnabled;
    if (_property == null) {
      roomHint = 'Chưa chọn nhà';
      roomEnabled = false;
    } else if (allRoomsAsync.isLoading) {
      roomHint = 'Đang tải phòng...';
      roomEnabled = false;
    } else if (allRoomsAsync.hasError) {
      roomHint = 'Lỗi Firestore';
      roomEnabled = false;
    } else if (propertyRooms.isEmpty) {
      roomHint = 'Nhà chưa có phòng';
      roomEnabled = false;
    } else if (_selectedRoom == null) {
      roomHint = 'Chưa chọn phòng';
      roomEnabled = true;
    } else {
      roomHint = 'Chọn phòng *';
      roomEnabled = true;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E7FF), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.apartment_rounded, color: Color(0xFF1E60F2), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CHỌN DỮ LIỆU CÓ SẴN',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Dropdown Khu nhà
          DropdownButtonFormField<HostProperty>(
            key: const ValueKey('property_select'),
            initialValue: _property,
            isExpanded: true,
            hint: Text(propertyHint, style: const TextStyle(fontSize: 14)),
            decoration: InputDecoration(
              labelText: 'Khu nhà *',
              prefixIcon: const Icon(
                Icons.home_work_outlined,
                color: Color(0xFF1E60F2),
                size: 20,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF1E60F2),
                  width: 1.5,
                ),
              ),
            ),
            items: properties
                .map(
                  (prop) => DropdownMenuItem(
                    value: prop,
                    child: Text(prop.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _onPropertySelected,
            validator: (val) => val == null && _property == null
                ? 'Vui lòng chọn khu nhà'
                : null,
          ),
          const SizedBox(height: 12),

          // Dropdown Phòng
          DropdownButtonFormField<RoomModel>(
            key: const ValueKey('room_select'),
            initialValue: propertyRooms.any((r) => r.id == _selectedRoom?.id)
                ? propertyRooms.firstWhere((r) => r.id == _selectedRoom?.id)
                : null,
            isExpanded: true,
            hint: Text(roomHint, style: const TextStyle(fontSize: 14)),
            decoration: InputDecoration(
              labelText: 'Phòng *',
              prefixIcon: const Icon(
                Icons.meeting_room_outlined,
                color: Color(0xFF1E60F2),
                size: 20,
              ),
              filled: true,
              fillColor: roomEnabled
                  ? const Color(0xFFF8FAFC)
                  : const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF1E60F2),
                  width: 1.5,
                ),
              ),
            ),
            items: roomEnabled
                ? propertyRooms
                      .map(
                        (room) => DropdownMenuItem(
                          value: room,
                          child: Text(
                            room.title.isNotEmpty
                                ? '${room.roomCode} - ${room.title}'
                                : room.roomCode,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList()
                : null,
            onChanged: roomEnabled ? _onRoomSelected : null,
            validator: (val) => val == null && _selectedRoom == null
                ? 'Vui lòng chọn phòng'
                : null,
          ),
        ],
      ),
    );
  }

  Widget _basicInfoTitle() => const Row(
    children: [
      Icon(Icons.edit_note_rounded, color: Color(0xFF1E60F2), size: 22),
      SizedBox(width: 8),
      Text(
        'THÔNG TIN CƠ BẢN',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          color: Color(0xFF1E293B),
        ),
      ),
    ],
  );

  /// Bố cục: [ Giá thuê ] [ Tiền cọc ]
  Widget _priceAndDepositRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: _priceInput()),
      const SizedBox(width: 10),
      Expanded(child: _depositInput()),
    ],
  );

  Widget _depositInput() => TextFormField(
    key: const ValueKey('deposit_input'),
    controller: _depositController,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1E60F2),
    ),
    decoration: InputDecoration(
      labelText: 'Tiền cọc *',
      suffixText: 'đ',
      suffixStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF93C5FD), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E60F2), width: 2),
      ),
    ),
    validator: (value) {
      if (value == null || value.trim().isEmpty) return 'Nhập tiền cọc';
      final parsed = double.tryParse(value.trim());
      if (parsed == null || parsed < 0) return 'Tiền cọc không hợp lệ';
      return null;
    },
  );

  Widget _priceInput() => TextFormField(
    key: const ValueKey('price_input'),
    controller: _price,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    style: const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1E60F2),
    ),
    decoration: InputDecoration(
      labelText: 'Giá thuê / tháng *',
      suffixText: 'đ/tháng',
      suffixStyle: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF93C5FD), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E60F2), width: 2),
      ),
    ),
    validator: (value) {
      if (value == null || value.trim().isEmpty) return 'Nhập giá thuê';
      final parsed = double.tryParse(value.trim());
      if (parsed == null || parsed <= 0) return 'Giá thuê phải lớn hơn 0';
      return null;
    },
  );

  Widget _priceSummary() => ValueListenableBuilder<TextEditingValue>(
    valueListenable: _price,
    builder: (context, value, _) {
      final formatted = _formatCurrency(value.text.trim());
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          key: const ValueKey('price_readonly'),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  formatted,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Text(
                'đ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _contactTitle() => const Row(
    children: [
      Icon(Icons.location_on_outlined, color: Color(0xFF1E60F2), size: 22),
      SizedBox(width: 8),
      Expanded(
        child: Text(
          'VỊ TRÍ & LIÊN HỆ',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: Color(0xFF1E293B),
          ),
        ),
      ),
      Icon(Icons.chevron_right_rounded, color: Color(0xFF1E60F2), size: 22),
    ],
  );

  Widget _contactField(
    TextEditingController controller,
    String label,
    IconData icon,
    String hint, {
    Key? key,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboard ?? TextInputType.streetAddress,
      inputFormatters: keyboard == TextInputType.phone
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF1E60F2), size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1E60F2), width: 1.5),
        ),
      ),
      validator: (value) =>
          label.contains('*') && (value == null || value.trim().isEmpty)
          ? 'Nhập $label'
          : null,
    ),
  );

  Widget _photoSection() {
    final totalImages = _existingImageUrls.length + _images.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E7FF), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.image_outlined,
                color: Color(0xFF1E60F2),
                size: 20,
              ),
              SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'HÌNH ẢNH & VIDEO PHÒNG',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Text(
                totalImages == 0 ? '0/10 ảnh' : 'Đã chọn $totalImages/10',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 94,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _addImageButton(),
                  // Hiển thị ảnh phòng đã nạp từ trước
                  ..._existingImageUrls.asMap().entries.map(
                    (entry) => _existingImageTile(entry.key, entry.value),
                  ),
                  // Hiển thị ảnh mới chọn qua ImagePicker
                  ..._images.asMap().entries.map(
                    (entry) => _imageTile(
                      entry.key,
                      entry.value,
                      startIndex: _existingImageUrls.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.info_rounded, size: 16, color: Color(0xFF1E60F2)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Ảnh chụp thực tế góc rộng sẽ tăng 65% tỷ lệ liên hệ.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addImageButton() => InkWell(
    onTap: _picking ? null : _pickImages,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 92,
      height: 92,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8DB8FF), width: 1.5),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            color: Color(0xFF1E60F2),
            size: 26,
          ),
          SizedBox(height: 4),
          Text(
            'Thêm ảnh',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF1E60F2),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _existingImageTile(int index, String url) => Stack(
    children: [
      Container(
        width: 92,
        height: 92,
        margin: const EdgeInsets.only(right: 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD9E7FF)),
        ),
        child: _buildExistingImage(url, index),
      ),
      Positioned(
        top: 4,
        right: 14,
        child: InkWell(
          onTap: () => setState(() => _existingImageUrls.removeAt(index)),
          child: const CircleAvatar(
            radius: 11,
            backgroundColor: Color(0x99000000),
            child: Icon(Icons.close, size: 13, color: Colors.white),
          ),
        ),
      ),
      if (index == 0)
        Positioned(
          left: 5,
          bottom: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1E60F2),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              'Ảnh bìa',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _buildExistingImage(String rawUrl, int index) {
    final cleanUrl = _cleanImageUrl(rawUrl);
    if (cleanUrl.isEmpty) {
      return _buildImagePlaceholder();
    }
    // 1. Data URI hoặc Base64
    if (cleanUrl.startsWith('data:image') || cleanUrl.startsWith('base64,')) {
      try {
        final commaIdx = cleanUrl.indexOf(',');
        final base64Str = commaIdx != -1
            ? cleanUrl.substring(commaIdx + 1)
            : cleanUrl;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildImagePlaceholder(),
        );
      } catch (_) {
        return _buildImagePlaceholder();
      }
    }
    // 2. File cục bộ trên thiết bị (mobile/desktop)
    if (!kIsWeb &&
        (cleanUrl.startsWith('/') ||
            cleanUrl.startsWith('file:') ||
            cleanUrl.contains(':\\') ||
            cleanUrl.contains(':/'))) {
      try {
        final filePath = cleanUrl.startsWith('file://')
            ? cleanUrl.replaceFirst('file://', '')
            : cleanUrl;
        final file = File(filePath);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildImagePlaceholder(),
          );
        }
      } catch (_) {}
    }
    // 3. Asset cục bộ
    if (cleanUrl.startsWith('assets/')) {
      return Image.asset(
        cleanUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildImagePlaceholder(),
      );
    }
    // 4. Web URL (HTTP / HTTPS / Firebase Storage)
    return Image.network(
      cleanUrl,
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: const Color(0xFFF8FAFC),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF1E60F2),
              ),
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) => _buildImagePlaceholder(),
    );
  }

  Widget _buildImagePlaceholder() => Container(
    color: const Color(0xFFF1F5F9),
    child: const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            color: Color(0xFF94A3B8),
            size: 24,
          ),
          SizedBox(height: 2),
          Text(
            'Ảnh phòng',
            style: TextStyle(
              fontSize: 9,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _imageTile(int index, HostUpload upload, {int startIndex = 0}) {
    final overallIndex = startIndex + index;
    return Stack(
      children: [
        Container(
          width: 92,
          height: 92,
          margin: const EdgeInsets.only(right: 10),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Image.memory(upload.bytes, fit: BoxFit.cover),
        ),
        Positioned(
          top: 4,
          right: 14,
          child: InkWell(
            onTap: () => setState(() => _images.removeAt(index)),
            child: const CircleAvatar(
              radius: 11,
              backgroundColor: Color(0x99000000),
              child: Icon(Icons.close, size: 13, color: Colors.white),
            ),
          ),
        ),
        if (overallIndex == 0)
          Positioned(
            left: 5,
            bottom: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E60F2),
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'Ảnh bìa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    String hint, {
    Key? key,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
    int maxLines = 1,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffixText,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF1E60F2), width: 1.5),
        ),
      ),
      validator: (value) =>
          label.contains('*') && (value == null || value.trim().isEmpty)
          ? 'Nhập $label'
          : null,
    ),
  );

  Widget _amenitySection(List<Map<String, String>> catalogItems) {
    final catalogNames = catalogItems.map((item) => item['name']!).toList();
    final allItems = <String>[];

    // 1. Tiện ích thực tế từ chính phòng đã chọn
    if (_selectedRoom != null) {
      for (final a in _selectedRoom!.amenities) {
        final trimmed = a.trim();
        if (trimmed.isNotEmpty && !allItems.contains(trimmed)) {
          allItems.add(trimmed);
        }
      }
    }

    // 2. Tiện ích từ bảng TienIch_Phong của phòng
    for (final a in _selectedAmenities) {
      final trimmed = a.trim();
      if (trimmed.isNotEmpty && !allItems.contains(trimmed)) {
        allItems.add(trimmed);
      }
    }

    // 3. Tiện ích từ danh mục Firestore catalog
    for (final a in catalogNames) {
      if (!allItems.contains(a)) {
        allItems.add(a);
      }
    }

    // 4. Tiện ích tùy chọn do chủ trọ thêm riêng (chỉ lưu local trong form)
    for (final a in _customAmenities) {
      if (!allItems.contains(a)) {
        allItems.add(a);
      }
    }

    // Thu gọn chỉ giữ item đã chọn; Xem thêm hiện toàn bộ
    final visible = _amenitiesExpanded
        ? allItems
        : allItems.where((name) => _selectedAmenities.contains(name)).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9E7FF), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.format_list_bulleted_rounded,
                color: Color(0xFF1E60F2),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tiện ích & Yêu cầu',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Text(
                '${_selectedAmenities.length} đang chọn',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1E60F2),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF1E60F2),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: const ValueKey('custom_amenity_input'),
                    controller: _customAmenity,
                    decoration: const InputDecoration(
                      hintText: 'Thêm tiện ích, yêu cầu riêng...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addCustomAmenity(catalogItems),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  key: const ValueKey('add_custom_amenity_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E60F2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    elevation: 0,
                    minimumSize: const Size(60, 34),
                  ),
                  onPressed: () => _addCustomAmenity(catalogItems),
                  child: const Text(
                    'Thêm',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty && !_amenitiesExpanded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Text(
                  'Chưa chọn tiện ích nào. Nhấn "Xem thêm" để chọn.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
            ),
          ...visible.map((name) {
            final isCustom = _customAmenities.contains(name);
            final isSelected = _selectedAmenities.contains(name);
            return _amenityTile(name, isCustom, isSelected);
          }),
          const SizedBox(height: 6),
          InkWell(
            key: const ValueKey('amenities_toggle_button'),
            borderRadius: BorderRadius.circular(12),
            onTap: () =>
                setState(() => _amenitiesExpanded = !_amenitiesExpanded),
            child: Container(
              width: double.infinity,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5FF),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _amenitiesExpanded ? 'Thu gọn ^' : 'Xem thêm v',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E60F2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amenityTile(String name, bool isCustom, bool isSelected) {
    final Color borderColor;
    final Color bgColor;
    final Color checkColor;

    if (isSelected) {
      if (isCustom) {
        borderColor = const Color(0xFF60A5FA);
        bgColor = const Color(0xFFEFF6FF);
        checkColor = const Color(0xFF1E60F2);
      } else {
        borderColor = const Color(0xFF93C5FD);
        bgColor = const Color(0xFFF0F7FF);
        checkColor = const Color(0xFF1E60F2);
      }
    } else {
      borderColor = const Color(0xFFE2E8F0);
      bgColor = const Color(0xFFF8FAFC);
      checkColor = const Color(0xFFCBD5E1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1),
      ),
      child: InkWell(
        key: ValueKey('amenity_tile_$name'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => _toggleAmenity(name),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? checkColor : Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isSelected ? checkColor : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isCustom
                              ? const Color(0xFF1E3A8A)
                              : const Color(0xFF1E40AF))
                        : const Color(0xFF1E293B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (isCustom) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Tùy chọn',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  key: ValueKey('delete_custom_amenity_$name'),
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _removeCustomAmenity(name),
                ),
              ] else if (isSelected) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Đã chọn',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ] else ...[
                const Icon(Icons.add, size: 18, color: Color(0xFF94A3B8)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _authWarning() => const Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Text(
      'Cần đăng nhập tài khoản chủ nhà để đăng bài.',
      style: TextStyle(color: AppColors.danger),
    ),
  );
}
