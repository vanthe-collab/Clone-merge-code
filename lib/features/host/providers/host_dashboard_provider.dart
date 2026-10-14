export 'host_amenity_provider.dart';
export 'host_home_provider.dart';
export 'host_location_provider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/roommate_post_model.dart';
import '../../auth/providers/auth_provider.dart';
import 'host_home_provider.dart';

// Alias for backwards compatibility
typedef HostDashboardSort = HostHomeSort;

class HostDashboardFilterOptions {
  const HostDashboardFilterOptions({
    this.locations = const [],
    this.requirements = const [],
  });

  final List<String> locations;
  final List<String> requirements;
}

class HostDashboardFilter {
  const HostDashboardFilter({
    this.locations = const [],
    this.requirements = const [],
    this.minPrice,
    this.maxPrice,
    this.sort = HostDashboardSort.newest,
    this.searchQuery = '',
  });

  final List<String> locations;
  final List<String> requirements;
  final double? minPrice;
  final double? maxPrice;
  final HostDashboardSort sort;
  final String searchQuery;
}

final hostDashboardPostsProvider = StreamProvider.autoDispose
    .family<List<RoommatePostModel>, HostDashboardFilter>((ref, filter) {
  if (Firebase.apps.isEmpty) return Stream.value(const []);

  final currentHostId = ref.watch(currentUserProvider)?.uid ?? '';
  return FirebaseFirestore.instance.collection('posts').snapshots().map((
    snapshot,
  ) {
    final posts = <RoommatePostModel>[];
    for (final document in snapshot.docs) {
      try {
        final post = RoommatePostModel.fromFirestore(document);
        if (post.status != 'deleted' &&
            post.status != 'closed' &&
            post.authorId != currentHostId) {
          posts.add(post);
        }
      } catch (_) {}
    }
    return posts;
  });
});

final hostDashboardFilterOptionsProvider =
    StreamProvider.autoDispose<HostDashboardFilterOptions>((ref) {
  if (Firebase.apps.isEmpty) {
    return Stream.value(const HostDashboardFilterOptions());
  }

  return FirebaseFirestore.instance.collection('posts').snapshots().map((
    snapshot,
  ) {
    final locations = <String>{};
    final requirements = <String>{};
    for (final document in snapshot.docs) {
      final data = document.data();
      final city = (data['city'] ?? data['thanhPho'] ?? '').toString().trim();
      final district =
          (data['district'] ?? data['quanHuyen'] ?? '').toString().trim();
      if (city.isNotEmpty) locations.add(city);
      if (district.isNotEmpty) locations.add(district);
    }
    return HostDashboardFilterOptions(
      locations: locations.toList()..sort(),
      requirements: requirements.toList()..sort(),
    );
  });
});
