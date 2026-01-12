import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/location_provider.dart';
import 'providers/leave_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/splash_screen.dart';
import 'services/secure_storage_service.dart';
import 'services/notification_service.dart';

void main() async {
  debugPrint('=== APP START ===');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('Flutter binding initialized');
  
  try {
    await SecureStorageService().init();
    debugPrint('SecureStorageService initialized');
    
    await NotificationService().initialize();
    debugPrint('NotificationService initialized');
  } catch (e) {
    debugPrint('Error initializing services: $e');
  }
  
  debugPrint('Running app...');
  runApp(const MyApp());
  debugPrint('=== APP STARTED ===');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => LeaveProvider()),
      ],
      child: MaterialApp(
        title: 'Absen MNC University',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _splashShown = false;

  @override
  void initState() {
    super.initState();
    debugPrint('AuthWrapper initialized');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        debugPrint('AuthWrapper build - splashShown: $_splashShown, isAuthenticated: ${authProvider.isAuthenticated}');
        
        // Show splash screen only once at the start
        if (!_splashShown) {
          debugPrint('Showing splash screen');
          return SplashScreen(
            onComplete: () {
              debugPrint('Splash onComplete called');
              if (mounted) {
                setState(() {
                  _splashShown = true;
                });
                debugPrint('Splash completed, rebuilding with _splashShown = true');
              }
            },
          );
        }
        
        // After splash, show login or main screen based on auth state
        final screen = authProvider.isAuthenticated 
            ? const MainScreen() 
            : const LoginScreen();
        debugPrint('Showing ${authProvider.isAuthenticated ? "MainScreen" : "LoginScreen"}');
        return screen;
      },
    );
  }
}
