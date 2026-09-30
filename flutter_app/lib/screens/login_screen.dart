import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../main.dart';
import 'senior_main_page.dart';
import 'senior_select_screen.dart';

final String _serverUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';

// ── 디자인 토큰 (메인 앱과 동일) ──
const _bg       = Color(0xFFF7F8FA);
const _surface  = Colors.white;
const _line     = Color(0xFFEAECEF);
const _text1    = Color(0xFF191F28);
const _text2    = Color(0xFF4E5968);
const _text3    = Color(0xFF8B95A1);
const _brand    = Color(0xFF3182F6);
const _brandSoft= Color(0xFFE8F2FE);
const _danger   = Color(0xFFF04452);

// 로그인 후 역할에 따라 화면 분기
Future<void> _routeAfterLogin(BuildContext ctx, String token, String username) async {
  AppState.accessToken = token;
  AppState.username = username;
  try {
    final res = await http.get(
      Uri.parse('$_serverUrl/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) {
      final d = jsonDecode(res.body);
      AppState.role     = (d['role'] as String?) ?? '';
      AppState.userId   = (d['id'] as int?) ?? 0;
      AppState.nickname = (d['nickname'] as String?) ?? username;
    }
  } catch (_) {}

  if (!ctx.mounted) return;
  Widget dest;
  dest = const SeniorMainPage();
  Navigator.of(ctx).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => dest), (r) => false,
  );
}

// ════════════════════════════════════════════
//  로그인 화면
// ════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading  = false;
  bool _pwHidden = true;

  @override
  void dispose() { _idCtrl.dispose(); _pwCtrl.dispose(); super.dispose(); }

  void _onLogin() async {
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text.trim();
    if (id.isEmpty || pw.isEmpty) {
      _snack('아이디와 비밀번호를 입력해주세요'); return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('$_serverUrl/auth/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'username=$id&password=$pw',
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) await _routeAfterLogin(context, data['access_token'], id);
      } else {
        _snack('아이디 또는 비밀번호가 틀렸어요', error: true);
      }
    } catch (_) {
      _snack('서버에 연결할 수 없어요', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 14)),
      backgroundColor: error ? _danger : _text1,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  Future<void> _kakaoLogin() async {
    try {
      setState(() => _loading = true);
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
      final res = await http.post(
        Uri.parse('$_serverUrl/auth/kakao/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': token.accessToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) await _routeAfterLogin(context, data['access_token'], data['username'] ?? 'kakao_user');
      } else {
        _snack('카카오 로그인 실패', error: true);
      }
    } catch (_) {
      _snack('카카오 로그인 실패', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    try {
      setState(() => _loading = true);
      final account = await GoogleSignIn().signIn();
      if (account == null) { if (mounted) setState(() => _loading = false); return; }
      final auth = await account.authentication;
      final res = await http.post(
        Uri.parse('$_serverUrl/auth/google/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'access_token': auth.accessToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) await _routeAfterLogin(context, data['access_token'], data['username'] ?? 'google_user');
      } else {
        _snack('구글 로그인 실패', error: true);
      }
    } catch (_) {
      _snack('구글 로그인 실패', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),

              // ── 로고 ──
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: _brandSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text('🏠', style: TextStyle(fontSize: 36)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text('OASIS',
                  style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w800,
                    color: _brand, letterSpacing: 3,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text('노인 케어 보호자 앱',
                  style: TextStyle(fontSize: 14, color: _text3, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 40),

              // ── 입력 카드 ──
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('로그인', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _text1)),
                    const SizedBox(height: 20),

                    // 아이디
                    _FieldLabel('아이디'),
                    const SizedBox(height: 6),
                    _TextField(
                      ctrl: _idCtrl,
                      hint: '아이디를 입력하세요',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 14),

                    // 비밀번호
                    _FieldLabel('비밀번호'),
                    const SizedBox(height: 6),
                    _TextField(
                      ctrl: _pwCtrl,
                      hint: '비밀번호를 입력하세요',
                      icon: Icons.lock_outline_rounded,
                      obscure: _pwHidden,
                      suffix: GestureDetector(
                        onTap: () => setState(() => _pwHidden = !_pwHidden),
                        child: Icon(_pwHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: _text3, size: 20),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 로그인 버튼
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _onLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          disabledBackgroundColor: _brand.withOpacity(0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('로그인',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── 회원가입 버튼 ──
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _line, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: _surface,
                  ),
                  child: const Text('회원가입',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _text2)),
                ),
              ),
              const SizedBox(height: 24),

              // ── 소셜 로그인 ──
              Row(children: [
                Expanded(child: Divider(color: _line)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('소셜 로그인', style: TextStyle(fontSize: 12, color: _text3)),
                ),
                Expanded(child: Divider(color: _line)),
              ]),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialBtn(color: const Color(0xFFFEE500), child: const _KakaoLogo(), onTap: _kakaoLogin),
                  const SizedBox(width: 14),
                  _SocialBtn(color: Colors.white, border: true, child: const _GoogleLogo(), onTap: _googleLogin),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
//  회원가입 화면
// ════════════════════════════════════════════
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _idCtrl       = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _pwCtrl       = TextEditingController();
  final _pwConfirmCtrl= TextEditingController();
  bool   _loading         = false;
  bool   _pwHidden        = true;
  bool   _pwConfirmHidden = true;
  String _selectedRole    = 'guardian';
  String _pwStrength      = '';

  @override
  void dispose() {
    _idCtrl.dispose(); _nicknameCtrl.dispose();
    _pwCtrl.dispose(); _pwConfirmCtrl.dispose();
    super.dispose();
  }

  String _checkStrength(String pw) {
    if (pw.isEmpty) return '';
    if (pw.length < 4) return 'weak';
    if (pw.length < 8) return 'medium';
    return 'strong';
  }

  Color get _strengthColor {
    switch (_pwStrength) {
      case 'weak':   return const Color(0xFFF04452);
      case 'medium': return const Color(0xFFFF8A00);
      case 'strong': return const Color(0xFF00B96B);
      default:       return Colors.transparent;
    }
  }

  String get _strengthText {
    switch (_pwStrength) {
      case 'weak':   return '약함';
      case 'medium': return '보통';
      case 'strong': return '강함';
      default:       return '';
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 14)),
      backgroundColor: error ? _danger : _text1,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  void _onRegister() async {
    final id       = _idCtrl.text.trim();
    final pw       = _pwCtrl.text.trim();
    final pwCon    = _pwConfirmCtrl.text.trim();
    final nickname = _nicknameCtrl.text.trim();
    if (id.isEmpty || pw.isEmpty || pwCon.isEmpty) { _snack('필수 항목을 모두 입력해주세요'); return; }
    if (pw != pwCon) { _snack('비밀번호가 일치하지 않아요', error: true); return; }
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('$_serverUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': id, 'password': pw,
          'nickname': nickname.isEmpty ? id : nickname,
          'role': _selectedRole,
        }),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200 || res.statusCode == 201) {
        _snack('회원가입 완료! 로그인해주세요');
        if (mounted) Navigator.of(context).pop();
      } else {
        final body = jsonDecode(res.body);
        _snack(body['detail'] ?? '회원가입 실패', error: true);
      }
    } catch (_) {
      _snack('서버에 연결할 수 없어요', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── 상단 헤더 ──
            Container(
              color: _surface,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.arrow_back_ios_rounded, size: 16, color: _text2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('회원가입',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _text1)),
                ],
              ),
            ),

            // ── 폼 ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // 역할 선택
                    _SectionCard(
                      title: '역할 선택',
                      child: Row(
                        children: [
                          Expanded(child: _RoleCard(
                            emoji: '👨‍👩‍👧', label: '보호자',
                            desc: '어르신을 돌보는 가족',
                            selected: _selectedRole == 'guardian',
                            onTap: () => setState(() => _selectedRole = 'guardian'),
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _RoleCard(
                            emoji: '👴', label: '어르신',
                            desc: '케어를 받는 분',
                            selected: _selectedRole == 'senior',
                            onTap: () => setState(() => _selectedRole = 'senior'),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 기본 정보
                    _SectionCard(
                      title: '기본 정보',
                      child: Column(
                        children: [
                          _FieldLabel('아이디', required: true),
                          const SizedBox(height: 6),
                          _TextField(ctrl: _idCtrl, hint: '아이디를 입력하세요', icon: Icons.person_outline_rounded),
                          const SizedBox(height: 14),
                          _FieldLabel('닉네임'),
                          const SizedBox(height: 6),
                          _TextField(ctrl: _nicknameCtrl, hint: '표시될 이름 (선택)', icon: Icons.badge_outlined),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 비밀번호
                    _SectionCard(
                      title: '비밀번호',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FieldLabel('비밀번호', required: true),
                          const SizedBox(height: 6),
                          _TextField(
                            ctrl: _pwCtrl,
                            hint: '비밀번호를 입력하세요',
                            icon: Icons.lock_outline_rounded,
                            obscure: _pwHidden,
                            onChanged: (v) => setState(() => _pwStrength = _checkStrength(v)),
                            suffix: GestureDetector(
                              onTap: () => setState(() => _pwHidden = !_pwHidden),
                              child: Icon(_pwHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: _text3, size: 20),
                            ),
                          ),
                          if (_pwStrength.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ...['weak','medium','strong'].map((lv) {
                                  final active = ['weak','medium','strong'].indexOf(lv) <=
                                      ['weak','medium','strong'].indexOf(_pwStrength);
                                  return Expanded(child: Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: active ? _strengthColor : _line,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ));
                                }),
                                const SizedBox(width: 8),
                                Text(_strengthText,
                                  style: TextStyle(fontSize: 11, color: _strengthColor, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                          _FieldLabel('비밀번호 확인', required: true),
                          const SizedBox(height: 6),
                          _TextField(
                            ctrl: _pwConfirmCtrl,
                            hint: '비밀번호를 다시 입력하세요',
                            icon: Icons.lock_outline_rounded,
                            obscure: _pwConfirmHidden,
                            suffix: GestureDetector(
                              onTap: () => setState(() => _pwConfirmHidden = !_pwConfirmHidden),
                              child: Icon(_pwConfirmHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: _text3, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 가입 버튼
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _onRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          disabledBackgroundColor: _brand.withOpacity(0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _loading
                          ? const SizedBox(width: 20, height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('가입 완료',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                              ],
                            ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('이미 계정이 있으신가요? ',
                          style: TextStyle(fontSize: 13, color: _text3)),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Text('로그인',
                            style: TextStyle(fontSize: 13, color: _brand, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 카카오 추가 정보 (간소화) ──
class KakaoSignupAdditionalInfoScreen extends StatefulWidget {
  final String kakaoToken;
  final String tempUserId;
  const KakaoSignupAdditionalInfoScreen({super.key, required this.kakaoToken, required this.tempUserId});
  @override
  State<KakaoSignupAdditionalInfoScreen> createState() => _KakaoSignupAdditionalInfoScreenState();
}
class _KakaoSignupAdditionalInfoScreenState extends State<KakaoSignupAdditionalInfoScreen> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _role;
  bool _loading = false;

  Future<void> _complete() async {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty || _role == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('모든 항목을 입력해주세요'))); return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('$_serverUrl/auth/kakao/complete-signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'temp_user_id': widget.tempUserId, 'name': _nameCtrl.text.trim(), 'phone': _phoneCtrl.text.trim(), 'role': _role}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) await _routeAfterLogin(context, data['access_token'], data['username'] ?? _nameCtrl.text.trim());
      }
    } catch (_) {} finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(backgroundColor: _surface, elevation: 0, foregroundColor: _text1,
      title: const Text('추가 정보 입력', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _text1))),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _SectionCard(title: '기본 정보', child: Column(children: [
          _TextField(ctrl: _nameCtrl, hint: '이름', icon: Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _TextField(ctrl: _phoneCtrl, hint: '010-0000-0000', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
        ])),
        const SizedBox(height: 12),
        _SectionCard(title: '역할', child: Row(children: [
          Expanded(child: _RoleCard(emoji: '👨‍👩‍👧', label: '보호자', desc: '', selected: _role == 'guardian', onTap: () => setState(() => _role = 'guardian'))),
          const SizedBox(width: 12),
          Expanded(child: _RoleCard(emoji: '👴', label: '어르신', desc: '', selected: _role == 'senior', onTap: () => setState(() => _role = 'senior'))),
        ])),
        const Spacer(),
        SizedBox(height: 54, child: ElevatedButton(
          onPressed: _loading ? null : _complete,
          style: ElevatedButton.styleFrom(backgroundColor: _brand, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('가입 완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        )),
      ]),
    ),
  );
}

class GoogleSignupAdditionalInfoScreen extends StatefulWidget {
  final String googleToken;
  final String tempUserId;
  const GoogleSignupAdditionalInfoScreen({super.key, required this.googleToken, required this.tempUserId});
  @override
  State<GoogleSignupAdditionalInfoScreen> createState() => _GoogleSignupAdditionalInfoScreenState();
}
class _GoogleSignupAdditionalInfoScreenState extends State<GoogleSignupAdditionalInfoScreen> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _role;
  bool _loading = false;

  Future<void> _complete() async {
    if (_nameCtrl.text.isEmpty || _phoneCtrl.text.isEmpty || _role == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('모든 항목을 입력해주세요'))); return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('$_serverUrl/auth/google/complete-signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'temp_user_id': widget.tempUserId, 'name': _nameCtrl.text.trim(), 'phone': _phoneCtrl.text.trim(), 'role': _role}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) await _routeAfterLogin(context, data['access_token'], data['username'] ?? _nameCtrl.text.trim());
      }
    } catch (_) {} finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(backgroundColor: _surface, elevation: 0, foregroundColor: _text1,
      title: const Text('추가 정보 입력', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _text1))),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _SectionCard(title: '기본 정보', child: Column(children: [
          _TextField(ctrl: _nameCtrl, hint: '이름', icon: Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _TextField(ctrl: _phoneCtrl, hint: '010-0000-0000', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
        ])),
        const SizedBox(height: 12),
        _SectionCard(title: '역할', child: Row(children: [
          Expanded(child: _RoleCard(emoji: '👨‍👩‍👧', label: '보호자', desc: '', selected: _role == 'guardian', onTap: () => setState(() => _role = 'guardian'))),
          const SizedBox(width: 12),
          Expanded(child: _RoleCard(emoji: '👴', label: '어르신', desc: '', selected: _role == 'senior', onTap: () => setState(() => _role = 'senior'))),
        ])),
        const Spacer(),
        SizedBox(height: 54, child: ElevatedButton(
          onPressed: _loading ? null : _complete,
          style: ElevatedButton.styleFrom(backgroundColor: _brand, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('가입 완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        )),
      ]),
    ),
  );
}

// ════════════════════════════════════════════
//  공용 위젯
// ════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _text2)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String emoji, label, desc;
  final bool selected;
  final VoidCallback onTap;
  const _RoleCard({required this.emoji, required this.label, required this.desc, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? _brandSoft : _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _brand : _line, width: 1.5),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: selected ? _brand : _text1)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(desc, style: const TextStyle(fontSize: 11, color: _text3), textAlign: TextAlign.center),
          ],
        ]),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _text2)),
      if (required) const Text(' *', style: TextStyle(fontSize: 13, color: _danger, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  const _TextField({required this.ctrl, required this.hint, required this.icon,
    this.obscure = false, this.suffix, this.onChanged, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      onChanged: onChanged,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: _text1),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _text3, fontSize: 14),
        prefixIcon: Icon(icon, color: _text3, size: 20),
        suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix) : null,
        suffixIconConstraints: const BoxConstraints(),
        filled: true,
        fillColor: _bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand, width: 2)),
      ),
    );
  }
}

class _SocialBtn extends StatelessWidget {
  final Color color;
  final Widget child;
  final VoidCallback onTap;
  final bool border;
  const _SocialBtn({required this.color, required this.child, required this.onTap, this.border = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54, height: 54,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: border ? Border.all(color: _line, width: 1.5) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _KakaoLogo extends StatelessWidget {
  const _KakaoLogo();
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 26, height: 26, child: CustomPaint(painter: _KakaoPainter()));
}

class _KakaoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = const Color(0xFF3C1E1E);
    canvas.drawOval(Rect.fromLTWH(0, s.height * 0.05, s.width, s.height * 0.75), p);
    final tail = Path()
      ..moveTo(s.width * 0.28, s.height * 0.70)
      ..lineTo(s.width * 0.15, s.height * 0.98)
      ..lineTo(s.width * 0.45, s.height * 0.78)
      ..close();
    canvas.drawPath(tail, p);
  }
  @override
  bool shouldRepaint(_) => false;
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (b) => const LinearGradient(
        colors: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC04), Color(0xFFEA4335)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ).createShader(b),
      child: const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}
