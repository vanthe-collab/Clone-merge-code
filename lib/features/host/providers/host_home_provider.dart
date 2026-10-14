import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/vietnamese_utils.dart';
import '../../../data/models/host_post_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/host_post_repository.dart';

/// Các kiểu sắp xếp bảng tin chủ trọ
enum HostHomeSort {
  newest,
  mostInterested,
  priceAscending,
  priceDescending,
}

/// Kiểu sắp xếp theo giá (Radio: chỉ chọn 1 trong 2 hoặc null)
enum HostPriceSort {
  ascending,
  descending,
}

/// Trạng thái bộ lọc và tìm kiếm bảng tin chủ trọ
class HostHomeFilterState {
  final String searchQuery;
  final Set<String> selectedLocations;
  final double? minPrice;
  final double? maxPrice;
  final Set<String> selectedAmenities;
  final List<String> customRequirements;
  final bool sortNewest;
  final bool sortMostInterested;
  final HostPriceSort? priceSort;
  final HostHomeSort sort;

  const HostHomeFilterState({
    this.searchQuery = '',
    this.selectedLocations = const {},
    this.minPrice,
    this.maxPrice,
    this.selectedAmenities = const {},
    this.customRequirements = const [],
    this.sortNewest = true,
    this.sortMostInterested = false,
    this.priceSort,
    this.sort = HostHomeSort.newest,
  });

  HostHomeFilterState copyWith({
    String? searchQuery,
    Set<String>? selectedLocations,
    double? minPrice,
    double? maxPrice,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
    Set<String>? selectedAmenities,
    List<String>? customRequirements,
    bool? sortNewest,
    bool? sortMostInterested,
    HostPriceSort? priceSort,
    bool clearPriceSort = false,
    HostHomeSort? sort,
  }) {
    return HostHomeFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedLocations: selectedLocations ?? this.selectedLocations,
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      selectedAmenities: selectedAmenities ?? this.selectedAmenities,
      customRequirements: customRequirements ?? this.customRequirements,
      sortNewest: sortNewest ?? this.sortNewest,
      sortMostInterested: sortMostInterested ?? this.sortMostInterested,
      priceSort: clearPriceSort ? null : (priceSort ?? this.priceSort),
      sort: sort ?? this.sort,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HostHomeFilterState &&
          searchQuery == other.searchQuery &&
          setEquals(selectedLocations, other.selectedLocations) &&
          minPrice == other.minPrice &&
          maxPrice == other.maxPrice &&
          setEquals(selectedAmenities, other.selectedAmenities) &&
          listEquals(customRequirements, other.customRequirements) &&
          sortNewest == other.sortNewest &&
          sortMostInterested == other.sortMostInterested &&
          priceSort == other.priceSort &&
          sort == other.sort;

  @override
  int get hashCode => Object.hash(
        searchQuery,
        Object.hashAll(selectedLocations),
        minPrice,
        maxPrice,
        Object.hashAll(selectedAmenities),
        Object.hashAll(customRequirements),
        sortNewest,
        sortMostInterested,
        priceSort,
        sort,
      );
}

/// Notifier quản lý tương tác bộ lọc và tìm kiếm
class HostHomeFilterNotifier extends Notifier<HostHomeFilterState> {
  @override
  HostHomeFilterState build() => const HostHomeFilterState();

  void setSearchQuery(String query) {
    if (state.searchQuery != query) {
      state = state.copyWith(searchQuery: query);
    }
  }

  void toggleLocation(String location) {
    final updated = Set<String>.from(state.selectedLocations);
    if (updated.contains(location)) {
      updated.remove(location);
    } else {
      updated.add(location);
    }
    state = state.copyWith(selectedLocations: updated);
  }

  void setSelectedLocations(Set<String> locations) {
    state = state.copyWith(selectedLocations: Set.from(locations));
  }

  void clearLocations() {
    state = state.copyWith(selectedLocations: {});
  }

  void setPriceRange(double? min, double? max) {
    state = state.copyWith(
      minPrice: min,
      maxPrice: max,
      clearMinPrice: min == null,
      clearMaxPrice: max == null,
    );
  }

  void toggleAmenity(String amenity) {
    final updated = Set<String>.from(state.selectedAmenities);
    if (updated.contains(amenity)) {
      updated.remove(amenity);
    } else {
      updated.add(amenity);
    }
    state = state.copyWith(selectedAmenities: updated);
  }

  void addCustomRequirement(String req) {
    final trimmed = req.trim();
    if (trimmed.isEmpty) return;
    if (!state.customRequirements.contains(trimmed)) {
      state = state.copyWith(
        customRequirements: [...state.customRequirements, trimmed],
      );
    }
  }

  void removeCustomRequirement(String req) {
    state = state.copyWith(
      customRequirements:
          state.customRequirements.where((r) => r != req).toList(),
    );
  }

  void setSort(HostHomeSort sort) {
    state = state.copyWith(sort: sort);
  }

  void applyAllFilters({
    Set<String>? selectedLocations,
    double? minPrice,
    double? maxPrice,
    Set<String>? selectedAmenities,
    List<String>? customRequirements,
    bool? sortNewest,
    bool? sortMostInterested,
    HostPriceSort? priceSort,
    bool clearPriceSort = false,
    HostHomeSort? sort,
  }) {
    state = state.copyWith(
      selectedLocations: selectedLocations != null ? Set.from(selectedLocations) : null,
      minPrice: minPrice,
      maxPrice: maxPrice,
      clearMinPrice: minPrice == null,
      clearMaxPrice: maxPrice == null,
      selectedAmenities: selectedAmenities != null ? Set.from(selectedAmenities) : null,
      customRequirements: customRequirements != null ? List.from(customRequirements) : null,
      sortNewest: sortNewest,
      sortMostInterested: sortMostInterested,
      priceSort: clearPriceSort ? null : (priceSort ?? state.priceSort),
      clearPriceSort: clearPriceSort,
      sort: sort,
    );
  }

  void resetFilters() {
    state = const HostHomeFilterState();
  }
}

final hostHomeFilterProvider =
    NotifierProvider<HostHomeFilterNotifier, HostHomeFilterState>(
  HostHomeFilterNotifier.new,
);

/// StreamProvider chính cung cấp danh sách bài đăng realtime đã lọc & sắp xếp
final hostHomePostsProvider =
    StreamProvider.autoDispose<List<HostPostModel>>((ref) {
  final currentUserId = ref.watch(currentUserProvider)?.uid ?? '';
  final repository = ref.watch(hostPostRepositoryProvider);
  final filter = ref.watch(hostHomeFilterProvider);

  // Đọc tất cả bài đăng công khai đang hoạt động (của cả chủ trọ khác và của chính mình)
  return repository
      .watchActivePosts(
        currentUserId: currentUserId,
      )
      .map((posts) {
    var result = posts.where((post) {
      // 1. Tìm kiếm theo: Tiêu đề, mô tả, tên chủ trọ, tên nhà trọ, địa chỉ, tỉnh/thành, quận/huyện, tiện ích
      if (filter.searchQuery.isNotEmpty) {
        final q = filter.searchQuery.toLowerCase();
        final matchTitle = post.tieuDe.toLowerCase().contains(q);
        final matchDesc = post.moTa.toLowerCase().contains(q);
        final matchHost = post.authorName.toLowerCase().contains(q);
        final matchProp = post.propertyName.toLowerCase().contains(q);
        final matchAddr = post.address.toLowerCase().contains(q);
        final matchCity = post.city.toLowerCase().contains(q);
        final matchDist = post.district.toLowerCase().contains(q);
        final matchAmenities =
            post.amenities.any((a) => a.toLowerCase().contains(q));

        if (!matchTitle &&
            !matchDesc &&
            !matchHost &&
            !matchProp &&
            !matchAddr &&
            !matchCity &&
            !matchDist &&
            !matchAmenities) {
          return false;
        }
      }

      // 2. Lọc khu vực đối chiếu với Firebase
      if (filter.selectedLocations.isNotEmpty) {
        final hasAllNationwide = filter.selectedLocations.any((loc) {
          final l = loc.toLowerCase();
          return l.contains('toàn quốc') || l.contains('tất cả');
        });

        if (!hasAllNationwide) {
          final locText =
              '${post.city} ${post.district} ${post.address} ${post.propertyName}'
                  .toLowerCase();
          final matchesLocation = filter.selectedLocations.any((loc) {
            final clean = loc.toLowerCase().trim();
            if (clean.isEmpty) return true;
            if (locText.contains(clean)) return true;

            final stripped = clean
                .replaceAll('tp.', '')
                .replaceAll('tp ', '')
                .replaceAll('thành phố', '')
                .replaceAll('tỉnh', '')
                .trim();
            if (stripped.isNotEmpty && locText.contains(stripped)) {
              return true;
            }

            if (clean.contains('hồ chí minh') || clean.contains('hcm')) {
              if (locText.contains('hồ chí minh') ||
                  locText.contains('hcm') ||
                  locText.contains('sài gòn') ||
                  locText.contains('sai gon')) {
                return true;
              }
            }

            if (clean.contains('hà nội')) {
              if (locText.contains('hà nội') ||
                  locText.contains('ha noi') ||
                  locText.contains('hn')) {
                return true;
              }
            }

            if (clean.contains('vũng tàu')) {
              if (locText.contains('vũng tàu') || locText.contains('bà rịa')) {
                return true;
              }
            }

            return false;
          });

          if (!matchesLocation) return false;
        }
      }

      // 3. Lọc giá thuê
      if (filter.minPrice != null && post.giaThue < filter.minPrice!) {
        return false;
      }
      if (filter.maxPrice != null && post.giaThue > filter.maxPrice!) {
        return false;
      }

      // 4. Lọc tiện ích và yêu cầu (so khớp thông minh: không phân biệt hoa thường, dấu tiếng Việt, khoảng trắng và fallback nội dung bài đăng)
      if (filter.selectedAmenities.isNotEmpty) {
        final postAmenities = post.amenities;
        final postFullText =
            '${post.tieuDe} ${post.moTa} ${post.amenities.join(' ')}';

        for (final req in filter.selectedAmenities) {
          final reqNorm = normalizeVietnameseComparison(req);
          final reqCompact = reqNorm.replaceAll(' ', '');

          final matchInAmenities = postAmenities.any((a) {
            final aNorm = normalizeVietnameseComparison(a);
            final aCompact = aNorm.replaceAll(' ', '');
            return aNorm == reqNorm ||
                aCompact == reqCompact ||
                aNorm.contains(reqNorm) ||
                reqNorm.contains(aNorm);
          });

          if (!matchInAmenities) {
            // Fallback: Tìm trong tiêu đề hoặc mô tả bài đăng
            final postTextNorm = normalizeVietnameseComparison(postFullText);
            if (!postTextNorm.contains(reqNorm) &&
                !postTextNorm.replaceAll(' ', '').contains(reqCompact)) {
              return false;
            }
          }
        }
      }

      if (filter.customRequirements.isNotEmpty) {
        final fullContent = normalizeVietnameseComparison(
            '${post.tieuDe} ${post.moTa} ${post.amenities.join(' ')}');
        for (final customReq in filter.customRequirements) {
          final reqNorm = normalizeVietnameseComparison(customReq);
          final reqCompact = reqNorm.replaceAll(' ', '');
          if (!fullContent.contains(reqNorm) &&
              !fullContent.replaceAll(' ', '').contains(reqCompact)) {
            return false;
          }
        }
      }

      return true;
    }).toList();

    // Sắp xếp theo đa tiêu chí: Checkbox (Mới nhất, Quan tâm nhất) & Radio (Giá)
    result.sort((a, b) {
      // 1. Nếu có chọn Radio giá (Giá thấp đến cao hoặc Giá cao đến thấp)
      if (filter.priceSort != null) {
        final cmpPrice = filter.priceSort == HostPriceSort.ascending
            ? a.giaThue.compareTo(b.giaThue)
            : b.giaThue.compareTo(a.giaThue);
        if (cmpPrice != 0) return cmpPrice;
      }

      // 2. Nếu chọn cùng lúc cả Checkbox "Được quan tâm nhất" và "Mới nhất":
      if (filter.sortMostInterested && filter.sortNewest) {
        final cmpInterest = b.interestedCount.compareTo(a.interestedCount);
        if (cmpInterest != 0) return cmpInterest;
        return b.ngayDang.compareTo(a.ngayDang);
      }

      // 3. Nếu chỉ chọn Checkbox "Được quan tâm nhất":
      if (filter.sortMostInterested) {
        final cmpInterest = b.interestedCount.compareTo(a.interestedCount);
        if (cmpInterest != 0) return cmpInterest;
      }

      // 4. Nếu chỉ chọn Checkbox "Mới nhất":
      if (filter.sortNewest) {
        final cmpDate = b.ngayDang.compareTo(a.ngayDang);
        if (cmpDate != 0) return cmpDate;
      }

      // 5. Mặc định fallback về sort cũ nếu có
      switch (filter.sort) {
        case HostHomeSort.newest:
          return b.ngayDang.compareTo(a.ngayDang);
        case HostHomeSort.mostInterested:
          final cmp = b.interestedCount.compareTo(a.interestedCount);
          return cmp != 0 ? cmp : b.ngayDang.compareTo(a.ngayDang);
        case HostHomeSort.priceAscending:
          return a.giaThue.compareTo(b.giaThue);
        case HostHomeSort.priceDescending:
          return b.giaThue.compareTo(a.giaThue);
      }
    });

    return result;
  });
});
