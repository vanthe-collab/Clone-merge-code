import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Danh sách tiện ích mặc định từ cơ sở dữ liệu nếu Firestore chưa có dữ liệu
const List<String> defaultHostAmenities = [
  'Wifi',
  'Máy lạnh',
  'Tủ lạnh',
  'Máy giặt',
  'Gác lửng',
  'Ban công',
  'Bảo vệ 24/7',
  'Chỗ để xe',
  'Bếp nấu ăn',
  'Camera an ninh',
  'Giờ giấc tự do',
  'Thang máy',
  'Nội thất đầy đủ',
];

/// Provider đọc danh mục tiện ích từ Firestore collection 'amenities'
final hostAmenitiesProvider =
    StreamProvider.autoDispose<List<Map<String, String>>>((ref) {
  if (Firebase.apps.isEmpty) {
    return Stream.value(
      defaultHostAmenities
          .map((name) => {'id': name.toLowerCase(), 'name': name})
          .toList(),
    );
  }

  return FirebaseFirestore.instance.collection('amenities').snapshots().map(
    (snapshot) {
      if (snapshot.docs.isEmpty) {
        return defaultHostAmenities
            .map((name) => {'id': name.toLowerCase(), 'name': name})
            .toList();
      }

      final items = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final name = (data['name'] ??
                    data['ten'] ??
                    data['label'] ??
                    data['tenTienIch'] ??
                    '')
                .toString()
                .trim();
            return {'id': doc.id, 'name': name};
          })
          .where((item) => item['name']!.isNotEmpty)
          .toList();

      if (items.isEmpty) {
        return defaultHostAmenities
            .map((name) => {'id': name.toLowerCase(), 'name': name})
            .toList();
      }
      return items;
    },
  );
});

/// Provider danh sách tên tiện ích đơn giản
final hostAmenityNamesProvider = Provider.autoDispose<List<String>>((ref) {
  final asyncVal = ref.watch(hostAmenitiesProvider);
  return asyncVal.when(
    data: (list) => list.map((item) => item['name']!).toList(),
    loading: () => defaultHostAmenities,
    error: (error, stack) => defaultHostAmenities,
  );
});
