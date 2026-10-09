import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'pages/dashboard_page.dart';
import 'pages/med_page.dart';
import 'pages/schedule_page.dart';
import 'pages/log_page.dart';
import 'pages/camera_page.dart';
import 'pages/settings_page.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/senior_main_page.dart';
import 'screens/senior_select_screen.dart';
import 'screens/profile_select_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';

// ── 전역 상태 저장소 ──
class AppState {
  static String? accessToken;
  static String? username;
  static String? nickname;
  static String role = '';
  static int userId = 0;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase 설정 파일이 없는 로컬 시뮬레이터에서도 UI를 확인할 수 있게
  // 초기화 실패가 앱 시작을 막지 않도록 한다.
  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('Firebase 초기화를 건너뜁니다: $error');
  }
  await dotenv.load(fileName: ".env");
  KakaoSdk.init(nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY'] ?? '');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OASIS',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6FEB)),
        useMaterial3: true,
        // 버튼은 그림자 없이 평평하게 (토스 스타일)
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(elevation: 0, shadowColor: Colors.transparent),
        ),
        fontFamily: 'SF Pro',
      ),
      home: const _DebugHome(), // TODO: restore to LoginScreen for production
    );
  }
}

// ── 디버그 전용 홈 (토큰 자동 세팅 후 화면 이동) ──
class _DebugHome extends StatefulWidget {
  const _DebugHome();
  @override
  State<_DebugHome> createState() => _DebugHomeState();
}

class _DebugHomeState extends State<_DebugHome> {
  @override
  void initState() {
    super.initState();
    // 첫 프레임 이후 네비게이션 (Navigator 준비 완료 후)
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoLogin());
  }

  void _autoLogin() {
    // 디버그 전용: AppState 직접 세팅 (네트워크 없이)
    AppState.accessToken = 'debug_token';
    AppState.username = 'gurdian1';
    AppState.nickname = '김다혜';
    AppState.role = 'guardian';
    AppState.userId = 5;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ProfileSelectScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  bool _isLoading = false;
  String _errorMsg = '';

  void _login() {
    setState(() => _isLoading = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_idController.text == 'admin' && _pwController.text == '1234') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainPage()));
      } else {
        setState(() {
          _errorMsg = '아이디 또는 비밀번호가 올바르지 않습니다.';
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF4FC3F7), Color(0xFF6366F1)]).createShader(bounds),
                    child: const Icon(Icons.health_and_safety_rounded, size: 64, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF4FC3F7), Color(0xFF6366F1)]).createShader(bounds),
                    child: const Text('OASIS', textAlign: TextAlign.center, style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
                  ),
                  const SizedBox(height: 48),
                  const Text('아이디', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  TextField(controller: _idController, decoration: InputDecoration(hintText: 'admin', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))))),
                  const SizedBox(height: 16),
                  const Text('비밀번호', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  const SizedBox(height: 8),
                  TextField(controller: _pwController, obscureText: true, decoration: InputDecoration(hintText: '••••••••', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))))),
                  const SizedBox(height: 24),
                  if (_errorMsg.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(_errorMsg, style: const TextStyle(color: Colors.red, fontSize: 12))),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('로그인'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  void _onTabChange(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardPage(onTabChange: _onTabChange),
      const MedPage(),
      const SchedulePage(),
      const LogPage(),
      const CameraPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF4FC3F7), Color(0xFF6366F1)]).createShader(bounds),
          child: const Text('OASIS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Colors.white)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF94A3B8)),
            onPressed: () {
              AppState.accessToken = null;
              AppState.username = null;
              AppState.nickname = null;
              AppState.role = '';
              AppState.userId = 0;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (r) => false,
              );
            },
          )
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: const Color(0xFF94A3B8),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: '대시보드'),
          BottomNavigationBarItem(icon: Icon(Icons.medication_rounded), label: '복약'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_rounded), label: '일정'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_rounded), label: '대화'),
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '홈캠'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: '설정'),
        ],
      ),
    );
  }
}
