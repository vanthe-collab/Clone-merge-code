import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/renter/screens/renter_main_screen.dart';
import 'features/host/screens/host_main_screen.dart';
import 'features/host/notifications/screens/host_notifications_screen.dart';
import 'features/auth/providers/user_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Chủ trọ - Chạy thử Dashboard - Luồng đi: Windows hoặc tham số
  // HOST_PREVIEW=true mở Dashboard mẫu trực tiếp; các lần chạy bình thường
  // trên Android/iOS/web vẫn khởi tạo Firebase và đi qua đăng nhập.
  if (!isWindowsHostPreview) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const ProviderScope(child: MyApp()));
}

// Chủ trọ - Xác định chế độ xem thử - Luồng đi: Windows hoặc tham số
// HOST_PREVIEW=true dùng Dashboard mẫu không cần dữ liệu Firebase thật.
bool get isWindowsHostPreview =>
    const bool.fromEnvironment('HOST_PREVIEW') ||
    (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeShare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Chủ trọ - Xem thử Dashboard - Luồng đi: Route /host-preview mở
      // giao diện chủ trọ mẫu để kiểm tra trước khi nối các màn hình Sprint 1.
      routes: {
        '/host-preview': (_) => const HostMainScreen(),
        '/host/notifications': (_) => const HostNotificationsScreen(),
      },
      home: isWindowsHostPreview ? const HostMainScreen() : const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user != null) {
          // Chủ trọ - Mở giao diện theo tài khoản - Luồng đi: Sau đăng nhập,
          // đọc vai trò từ hồ sơ; host mở Dashboard chủ trọ, renter mở luồng người thuê.
          return ref
              .watch(userProfileProvider)
              .when(
                data: (profile) => profile?.role == 'host'
                    ? const HostMainScreen()
                    : const RenterMainScreen(),
                loading: () => const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
                error: (error, stack) => Scaffold(
                  body: Center(child: Text('Không thể tải hồ sơ: $error')),
                ),
              );
        }
        return const LoginScreen();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text('Lỗi xác thực: $error'))),
    );
  }
}
