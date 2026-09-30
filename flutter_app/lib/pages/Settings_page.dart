import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../data/mock_data.dart';
import '../data/api_service.dart';
import '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _alertEnabled = true;
  bool _emergencyAlert = true;
  bool _medAlert = true;
  bool _inactiveAlert = true;

  String _userName = '관리자';
  String _chatbotName = '오아시스야';
  String _userRole = 'user';
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final token = AppState.accessToken;
    if (token == null) {
      setState(() => _isLoadingUser = false);
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _userName = data['nickname'] ?? data['username'] ?? '관리자';
          _userRole = data['role'] ?? 'user';
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingUser = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 프로필 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _showUserNameDialog(context),
                  child: Stack(
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: const Icon(Icons.person_rounded, color: Colors.white, size: 36),
                      ),
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 20, height: 20,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.edit_rounded, size: 12, color: Color(0xFF6366F1)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _isLoadingUser
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _showUserNameDialog(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('편집', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppState.username ?? 'admin',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _userRole == 'admin' ? '관리자' : '일반 사용자',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 사용자 설정
          _SectionTitle(title: '사용자 설정'),
          _SettingsGroup(children: [
            _NavTile(
              icon: Icons.person_outline_rounded,
              iconColor: const Color(0xFF0EA5E9),
              title: '사용자 이름',
              subtitle: _userName,
              onTap: () => _showUserNameDialog(context),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.record_voice_over_rounded,
              iconColor: const Color(0xFF6366F1),
              title: '챗봇 이름',
              subtitle: _chatbotName,
              onTap: () => _showChatbotNameDialog(context),
            ),
          ]),

          const SizedBox(height: 24),

          // 챗봇 설정
          _SectionTitle(title: '챗봇 설정'),
          _SettingsGroup(children: [
            _NavTile(
              icon: Icons.speed_rounded,
              iconColor: const Color(0xFF0EA5E9),
              title: '음성 속도',
              subtitle: '보통',
              onTap: () => _showSpeedDialog(context),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.volume_up_rounded,
              iconColor: const Color(0xFF10B981),
              title: '음성 볼륨',
              subtitle: '80%',
              onTap: () {},
            ),
          ]),

          const SizedBox(height: 24),

          // 알림 설정
          _SectionTitle(title: '알림 설정'),
          _SettingsGroup(children: [
            _SwitchTile(
              icon: Icons.notifications_rounded,
              iconColor: const Color(0xFF6366F1),
              title: '전체 알림',
              subtitle: '모든 알림을 켜거나 끕니다',
              value: _alertEnabled,
              onChanged: (v) => setState(() => _alertEnabled = v),
            ),
            _Divider(),
            _SwitchTile(
              icon: Icons.emergency_rounded,
              iconColor: const Color(0xFFEF4444),
              title: '긴급 알림',
              subtitle: '긴급 호출 발생 시 즉시 알림',
              value: _emergencyAlert,
              onChanged: (v) => setState(() => _emergencyAlert = v),
            ),
            _Divider(),
            _SwitchTile(
              icon: Icons.medication_rounded,
              iconColor: const Color(0xFF10B981),
              title: '복약 알림',
              subtitle: '복약 시간 미완료 시 알림',
              value: _medAlert,
              onChanged: (v) => setState(() => _medAlert = v),
            ),
            _Divider(),
            _SwitchTile(
              icon: Icons.accessibility_new_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: '비활동 감지 알림',
              subtitle: '장시간 움직임 없을 시 알림',
              value: _inactiveAlert,
              onChanged: (v) => setState(() => _inactiveAlert = v),
            ),
          ]),

          const SizedBox(height: 24),

          // 장치 연결
          _SectionTitle(title: '장치 연결'),
          _SettingsGroup(children: [
            _NavTile(
              icon: Icons.speaker_rounded,
              iconColor: const Color(0xFF6366F1),
              title: '연결된 장치',
              subtitle: 'Raspberry Pi · 테스트 모드',
              onTap: () {},
            ),
            _Divider(),
            _StatusTile(icon: Icons.mic_rounded, iconColor: const Color(0xFF10B981), title: '마이크', value: mockStatus["mic"] as String),
            _Divider(),
            _StatusTile(icon: Icons.volume_up_rounded, iconColor: const Color(0xFF10B981), title: '스피커', value: mockStatus["speaker"] as String),
            _Divider(),
            _StatusTile(icon: Icons.wifi_rounded, iconColor: const Color(0xFF10B981), title: '네트워크', value: mockStatus["network"] as String),
          ]),

          const SizedBox(height: 24),

          // 계정
          _SectionTitle(title: '계정'),
          _SettingsGroup(children: [
            _NavTile(
              icon: Icons.lock_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: '비밀번호 변경',
              subtitle: '',
              onTap: () => _showPasswordDialog(context),
            ),
          ]),

          const SizedBox(height: 24),

          // 앱 정보
          _SectionTitle(title: '앱 정보'),
          _SettingsGroup(children: [
            _NavTile(
              icon: Icons.info_rounded,
              iconColor: const Color(0xFF4FC3F7),
              title: '버전 정보',
              subtitle: 'v1.0.0',
              onTap: () {},
            ),
            _Divider(),
            _NavTile(
              icon: Icons.description_rounded,
              iconColor: const Color(0xFF94A3B8),
              title: '개인정보 처리방침',
              subtitle: '',
              onTap: () {},
            ),
          ]),

          const SizedBox(height: 24),

          // 로그아웃
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => _showLogoutDialog(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('로그아웃', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showUserNameDialog(BuildContext context) {
    final controller = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('사용자 이름', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('앱에 표시될 이름을 입력해주세요', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '예: 홍길동',
                prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF6366F1)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final token = AppState.accessToken;
                if (token != null) {
                  try {
                    await http.patch(
                      Uri.parse('$baseUrl/auth/users/me'),
                      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                      body: jsonEncode({'nickname': controller.text.trim()}),
                    ).timeout(const Duration(seconds: 5));
                  } catch (_) {}
                }
                setState(() => _userName = controller.text.trim());
              }
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            child: const Text('저장', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChatbotNameDialog(BuildContext context) {
    final controller = TextEditingController(text: _chatbotName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('챗봇 이름', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('노인이 챗봇을 부를 때 사용할 이름이에요', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '예: 오아시스야',
                prefixIcon: const Icon(Icons.smart_toy_rounded, color: Color(0xFF6366F1)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF6366F1)),
                  SizedBox(width: 8),
                  Expanded(child: Text('라즈베리파이 설정에서도 같이 변경해주세요', style: TextStyle(fontSize: 11, color: Color(0xFF6366F1)))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) setState(() => _chatbotName = controller.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            child: const Text('저장', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSpeedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('음성 속도', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['느리게', '보통', '빠르게'].map((s) => ListTile(
            title: Text(s),
            trailing: s == '보통' ? const Icon(Icons.check_rounded, color: Color(0xFF6366F1)) : null,
            onTap: () => Navigator.pop(context),
          )).toList(),
        ),
      ),
    );
  }

  void _showPasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('비밀번호 변경', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(obscureText: true, decoration: InputDecoration(labelText: '현재 비밀번호', border: OutlineInputBorder())),
            SizedBox(height: 12),
            TextField(obscureText: true, decoration: InputDecoration(labelText: '새 비밀번호', border: OutlineInputBorder())),
            SizedBox(height: 12),
            TextField(obscureText: true, decoration: InputDecoration(labelText: '새 비밀번호 확인', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Color(0xFF94A3B8)))),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('변경', style: TextStyle(color: Color(0xFF6366F1)))),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Color(0xFF94A3B8)))),
          TextButton(
            onPressed: () {
              AppState.accessToken = null;
              AppState.username = null;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            child: const Text('로그아웃', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 20, bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
  );
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
    child: Column(children: children),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(height: 1, indent: 56, color: Color(0xFFE2E8F0));
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
      ])),
      CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: const Color(0xFF6366F1)),
    ]),
  );
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
        if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
      ]),
    ),
  );
}

class _StatusTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, value;
  const _StatusTile({required this.icon, required this.iconColor, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final ok = value == "정상" || value == "연결됨";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1E293B)))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: ok ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20)),
          child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
        ),
      ]),
    );
  }
}