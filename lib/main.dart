import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/appwrite_service.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/profile_screen.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");
  runApp(const MindfulChatbotApp());
}

class MindfulChatbotApp extends StatelessWidget {
  const MindfulChatbotApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Appwrite Ai',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF305b5c),
          primary: const Color(0xFF305b5c),
        ),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF305b5c),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF305b5c),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF305b5c)),
          ),
        ),
      ),
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
      initialRoute: '/',
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AppwriteService _appwriteService = AppwriteService();
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _appwriteService.initialize();
    _checkAuthStatusAndLoadData();
  }

  Future<void> _checkAuthStatusAndLoadData() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isOnboarded = prefs.getBool('isOnboarded') ?? false;

    // Wait a bit to show splash screen
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // First check if user completed onboarding
    if (!isOnboarded) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    // Then check if user is authenticated and load user data
    try {
      final user = await _appwriteService.getCurrentUser();
      if (user != null) {
        // Preload user profile data
        try {
          final userProfile = await _appwriteService.getUserProfile();
          if (userProfile != null) {
            _userName = userProfile.name;
            await prefs.setString('name', _userName);
          }
        } catch (e) {
          debugPrint('Error loading user profile: $e');
          // Try to get from SharedPreferences as fallback
          final name = prefs.getString('name');
          if (name != null && name.isNotEmpty) {
            _userName = name;
          }
        }
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            SizedBox(
              width: 100,
              height: 100,
              child: Image(image: AssetImage('assets/logo.png')),
            ),
            const SizedBox(height: 20),
            // App name
            const Text(
              'Appwrite Ai',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF10A37F),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}