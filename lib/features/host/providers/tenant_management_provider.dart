import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/tenant_repository.dart';
import 'host_management_provider.dart';

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return TenantRepository();
});

/// Stream danh sách người thuê của chủ trọ hiện tại
final hostTenantsProvider = StreamProvider<List<TenantItem>>((ref) {
  final uid = ref.watch(hostSessionProvider).value;
  if (uid == null || uid.isEmpty) {
    return Stream.value([]);
  }
  return ref.watch(tenantRepositoryProvider).watchHostTenants(uid);
});

/// Stream số liệu thống kê: số cơ sở, số người đang thuê, số phòng đang sử dụng
final hostTenantStatsProvider = StreamProvider<TenantStats>((ref) {
  final uid = ref.watch(hostSessionProvider).value;
  if (uid == null || uid.isEmpty) {
    return Stream.value(const TenantStats());
  }
  return ref.watch(tenantRepositoryProvider).watchTenantStats(uid);
});
