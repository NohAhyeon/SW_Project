import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _iconCtrl, _textCtrl, _dotsCtrl;
  late Animation<double> _iconScale, _iconOpacity, _textOpacity;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _iconCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _dotsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _iconScale = Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut));
    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _iconCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));
    _run();
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _iconCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 550));
    _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _dotsCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const LoginScreen(),
          transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  void dispose() { _iconCtrl.dispose(); _textCtrl.dispose(); _dotsCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F7),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _iconScale,
              child: FadeTransition(
                opacity: _iconOpacity,
                child: const Icon(Icons.health_and_safety_rounded, size: 72, color: Color(0xFF5B8DEF)),
              ),
            ),
            const SizedBox(height: 18),
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textOpacity,
                child: const Text('OASIS', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: Color(0xFF5B8DEF), letterSpacing: 6)),
              ),
            ),
            const SizedBox(height: 4),
            FadeTransition(opacity: _textOpacity, child: const Text('CareBot Admin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF6C63E0)))),
            const SizedBox(height: 3),
            FadeTransition(opacity: _textOpacity, child: const Text('노인 케어 챗봇 관리자 시스템', style: TextStyle(fontSize: 13, color: Color(0xFFA0AABC)))),
            const SizedBox(height: 56),
            FadeTransition(opacity: _dotsCtrl, child: const _DotLoader()),
          ],
        ),
      ),
    );
  }
}

class _DotLoader extends StatefulWidget {
  const _DotLoader();
  @override
  State<_DotLoader> createState() => _DotLoaderState();
}

class _DotLoaderState extends State<_DotLoader> with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(3, (i) {
      final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
      Future.delayed(Duration(milliseconds: i * 200), () { if (mounted) c.repeat(reverse: true); });
      return c;
    });
  }

  @override
  void dispose() { for (final c in _ctrls) {
    c.dispose();
  } super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedBuilder(
          animation: _ctrls[i],
          builder: (_, _) => Opacity(
            opacity: 0.3 + _ctrls[i].value * 0.7,
            child: Transform.scale(
              scale: 0.8 + _ctrls[i].value * 0.2,
              child: Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF5B8DEF))),
            ),
          ),
        ),
      )),
    );
  }
}
