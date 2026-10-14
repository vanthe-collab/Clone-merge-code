import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/vietnam_locations.dart';

/// Provider danh sách khu vực / tỉnh thành từ Firestore và VietnamLocations
final hostLocationsProvider =
    StreamProvider.autoDispose<List<String>>((ref) {
  if (Firebase.apps.isEmpty) {
    return Stream.value(VietnamLocations.provinces);
  }

  // Kết hợp từ collection 'locations' và danh mục địa điểm hệ thống
  return FirebaseFirestore.instance.collection('locations').snapshots().map(
    (snapshot) {
      final firestoreLocations = <String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = (data['name'] ??
                data['ten'] ??
                data['city'] ??
                data['thanhPho'] ??
                data['province'] ??
                '')
            .toString()
            .trim();
        if (name.isNotEmpty) firestoreLocations.add(name);
      }

      final combined = <String>{
        ...firestoreLocations,
        ...VietnamLocations.provinces,
      }.toList();

      combined.sort();
      return combined;
    },
  ).handleError((_) => VietnamLocations.provinces);
});

class HostLocationSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String q) => state = q;
}

/// State lưu query tìm nhanh trong panel khu vực
final hostLocationSearchQueryProvider =
    NotifierProvider.autoDispose<HostLocationSearchNotifier, String>(
  HostLocationSearchNotifier.new,
);

/// Provider lọc danh sách khu vực theo từ khoá tìm nhanh
final hostFilteredLocationsProvider = Provider.autoDispose<List<String>>((ref) {
  final query = ref.watch(hostLocationSearchQueryProvider).trim().toLowerCase();
  final locationsAsync = ref.watch(hostLocationsProvider);
  final allLocations = locationsAsync.value ?? VietnamLocations.provinces;

  if (query.isEmpty) return allLocations;
  return allLocations.where((loc) => loc.toLowerCase().contains(query)).toList();
});
