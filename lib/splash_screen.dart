import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'role_selection_screen.dart';
import 'customer_dashboard.dart';
import 'shopkeeper_dashboard.dart';
import 'admin_dashboard.dart';
 
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}
 
class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── brand colors ─────────────────────────────────────────
  static const Color kOrange = Color(0xFFF4511E);
  static const Color kNavy   = Color(0xFF0D1B3E);
  static const Color kBg     = Color(0xFFF5F6FA);
 
  // ── controllers ──────────────────────────────────────────
  late AnimationController _pinDropCtrl;
  late AnimationController _contentCtrl;
  late AnimationController _pinBobCtrl;
  late AnimationController _barCtrl;
 
  late Animation<double> _pinY;
  late Animation<double> _pinFade;
  late Animation<double> _shadowScale;
  late Animation<double> _contentFade;
  late Animation<Offset>  _contentSlide;
  late Animation<double>  _dividerAnim;
  late Animation<double>  _bob;
  late Animation<double>  _bar;
 
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
 
    // controllers
    _pinDropCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 950));
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _pinBobCtrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1900))
      ..repeat(reverse: true);
    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
 
    // ── pin drop: falls from -220 then bounces ──
    _pinY = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: -220.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 55),
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -24.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 16),
      TweenSequenceItem(
          tween: Tween(begin: -24.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 13),
      TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -10.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 8),
      TweenSequenceItem(
          tween: Tween(begin: -10.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 8),
    ]).animate(_pinDropCtrl);
 
    _pinFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pinDropCtrl,
            curve: const Interval(0.0, 0.22)));
 
    _shadowScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pinDropCtrl,
            curve: const Interval(0.50, 0.78, curve: Curves.easeOut)));
 
    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _contentCtrl,
            curve: const Interval(0.0, 0.65)));
 
    _contentSlide = Tween<Offset>(
            begin: const Offset(0, 0.22), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _contentCtrl, curve: Curves.easeOutCubic));
 
    _dividerAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _contentCtrl,
            curve: const Interval(0.45, 1.0, curve: Curves.easeOut)));
 
    _bob = Tween<double>(begin: 0.0, end: 7.0).animate(
        CurvedAnimation(parent: _pinBobCtrl, curve: Curves.easeInOut));
 
    _bar = Tween<double>(begin: 0.0, end: 1.0).animate(_barCtrl);
 
    // sequence
    _pinDropCtrl.forward().then((_) => _contentCtrl.forward());
 
    // navigate after 3.6 s
    Timer(const Duration(milliseconds: 3700), _checkAutoLogin);
  }
 
  Future<void> _checkAutoLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _go(const RoleSelectionScreen()); return; }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();
      if (!mounted) return;
      if (!doc.exists) { _go(const RoleSelectionScreen()); return; }
      final role = doc['role'] ?? '';
      if      (role == 'Customer')   _go(const CustomerDashboard());
      else if (role == 'Shopkeeper') _go(const ShopkeeperDashboard());
      else if (role == 'Admin')      _go(const AdminDashboard());
      else _go(const RoleSelectionScreen());
    } catch (_) { _go(const RoleSelectionScreen()); }
  }
 
  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => screen,
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ));
  }
 
  @override
  void dispose() {
    _pinDropCtrl.dispose();
    _contentCtrl.dispose();
    _pinBobCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(children: [
 
        // ── 1. dot grid — top-left ──────────────────────────
        Positioned(
          top: 0, left: 0,
          child: CustomPaint(
            size: Size(size.width * 0.36, size.height * 0.22),
            painter: _DotGridPainter(
              color: const Color(0xFFD8DAE8),
              spacing: 18,
              radius: 1.8,
            ),
          ),
        ),
 
        // ── 2. orange blob circles — top-right ─────────────
        Positioned(
          top: -60, right: -60,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kOrange.withOpacity(0.09),
            ),
          ),
        ),
        Positioned(
          top: 4, right: 4,
          child: Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kOrange.withOpacity(0.07),
            ),
          ),
        ),
 
        // ── 3. city skyline + ghost pins — bottom ──────────
        Positioned(
          bottom: 42, left: 0, right: 0,
          child: SizedBox(
            height: 150,
            child: Stack(children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.08,
                  child: CustomPaint(
                    painter: _SkylinePainter(color: kNavy),
                  ),
                ),
              ),
              Positioned(
                bottom: 54, left: size.width * 0.24,
                child: Opacity(
                  opacity: 0.18,
                  child: _buildGhostPin(24),
                ),
              ),
              Positioned(
                bottom: 70, right: size.width * 0.20,
                child: Opacity(
                  opacity: 0.14,
                  child: _buildGhostPin(18),
                ),
              ),
              Positioned(
                bottom: 44, right: size.width * 0.38,
                child: Opacity(
                  opacity: 0.10,
                  child: _buildGhostPin(14),
                ),
              ),
            ]),
          ),
        ),
 
        // ── 4. main content ─────────────────────────────────
        SafeArea(
          child: Column(children: [
            const Spacer(flex: 2),
 
            // ── animated pin ──
            AnimatedBuilder(
              animation: Listenable.merge([_pinDropCtrl, _pinBobCtrl]),
              builder: (_, __) {
                final bobOffset =
                    _pinDropCtrl.isCompleted ? -_bob.value : 0.0;
                return Transform.translate(
                  offset: Offset(0, _pinY.value + bobOffset),
                  child: FadeTransition(
                    opacity: _pinFade,
                    child: SizedBox(
                      width: 150,
                      height: 170,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
 
                          // ── oval drop-shadow on ground ──
                          Positioned(
                            bottom: 2,
                            child: ScaleTransition(
                              scale: _shadowScale,
                              child: Container(
                                width: 58, height: 14,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kNavy.withOpacity(0.14),
                                      blurRadius: 18,
                                      spreadRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
 
                          // ── logo inside pin (no background circle) ──
                          // Replace 'assets/appLogo.png' with your logo path.
                          // Also declare it in pubspec.yaml under flutter > assets.
                          Positioned(
                            top: 25,
                            child: ClipOval(
                              child: Image.asset(
                                'assets/appLogo.png',
                                width: 180,
                                height: 180,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
 
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
 
            const SizedBox(height: 24),
 
            // ── NearBuy text + divider + tagline ──
            SlideTransition(
              position: _contentSlide,
              child: FadeTransition(
                opacity: _contentFade,
                child: Column(children: [
 
                  // brand name
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Near',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: kNavy,
                          height: 1.0,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text('Buy',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: kOrange,
                          height: 1.0,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
 
                  const SizedBox(height: 10),
 
                  // divider: line — dot — line
                  AnimatedBuilder(
                    animation: _dividerAnim,
                    builder: (_, __) {
                      final w = _dividerAnim.value * 62;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: w, height: 1.5,
                            decoration: BoxDecoration(
                              color: kOrange.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kOrange,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            width: w, height: 1.5,
                            decoration: BoxDecoration(
                              color: kOrange.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
 
                  const SizedBox(height: 10),
 
                  // tagline
                  Text(
                    'Find shops near you.',
                    style: TextStyle(
                      fontSize: 15,
                      color: kNavy.withOpacity(0.42),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.1,
                    ),
                  ),
 
                ]),
              ),
            ),
 
            const Spacer(flex: 4),
 
            // ── 5. premium moving bottom line ──────────────
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedBuilder(
                animation: _bar,
                builder: (_, __) {
                  return Stack(
                    children: [
                      // background line
                      Container(
                        height: 3,
                        width: double.infinity,
                        color: kOrange.withOpacity(0.08),
                      ),
                      // moving glow line
                      Positioned(
                        left: MediaQuery.of(context).size.width -
                            (_bar.value *
                                (MediaQuery.of(context).size.width + 140)),
                        child: Container(
                          width: 140,
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.transparent,
                                kOrange.withOpacity(0.25),
                                kOrange,
                                kOrange.withOpacity(0.25),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: kOrange.withOpacity(0.55),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
 
          ]),
        ),
      ]),
    );
  }
 
  // ghost pin — sirf shape, koi icon nahi andar
  Widget _buildGhostPin(double size) {
    return CustomPaint(
      size: Size(size, size * 1.3),
      painter: _PinPainter(color: kOrange),
    );
  }
}
 
// ════════════════════════════════════════════════════════════
// Painters
// ════════════════════════════════════════════════════════════
 
class _PinPainter extends CustomPainter {
  final Color color;
  _PinPainter({required this.color});
 
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final w  = size.width;
    final h  = size.height;
    final cx = w / 2;
    final r  = w / 2;
    final cy = r;
 
    // soft glow shadow
    final shadowPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(cx, cy), r, shadowPaint);
 
    // orange circle (top of pin)
    canvas.drawCircle(Offset(cx, cy), r, paint);
 
    // triangle tail (bottom of pin)
    final path = Path()
      ..moveTo(cx - r * 0.46, cy + r * 0.68)
      ..lineTo(cx, h)
      ..lineTo(cx + r * 0.46, cy + r * 0.68)
      ..close();
    canvas.drawPath(path, paint);
    // NOTE: No white circle — logo sits directly on orange
  }
 
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
 
class _DotGridPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double radius;
  _DotGridPainter({
    required this.color,
    this.spacing = 20,
    this.radius  = 1.8,
  });
 
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double x = spacing / 2; x < size.width;  x += spacing)
      for (double y = spacing / 2; y < size.height; y += spacing)
        canvas.drawCircle(Offset(x, y), radius, paint);
  }
 
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
 
class _SkylinePainter extends CustomPainter {
  final Color color;
  _SkylinePainter({required this.color});
 
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
 
    final buildings = [
      [0.00, 0.07, 0.42],
      [0.07, 0.05, 0.58],
      [0.12, 0.06, 0.36],
      [0.18, 0.05, 0.72],
      [0.23, 0.05, 0.52],
      [0.28, 0.08, 0.84],
      [0.36, 0.05, 0.56],
      [0.42, 0.09, 1.00],
      [0.51, 0.06, 0.66],
      [0.57, 0.07, 0.44],
      [0.64, 0.05, 0.70],
      [0.69, 0.06, 0.40],
      [0.75, 0.07, 0.60],
      [0.82, 0.06, 0.34],
      [0.88, 0.06, 0.48],
      [0.94, 0.06, 0.38],
    ];
 
    final path = Path()..moveTo(0, h);
    for (final b in buildings) {
      final bx = b[0] * w;
      final bw = b[1] * w;
      final bh = b[2] * h * 0.82;
      path.lineTo(bx, h - bh);
      if (b[2] > 0.78) {
        final mid = bx + bw / 2;
        path.lineTo(mid - 1.5, h - bh);
        path.lineTo(mid - 1.5, h - bh - 8);
        path.lineTo(mid + 1.5, h - bh - 8);
        path.lineTo(mid + 1.5, h - bh);
      }
      path.lineTo(bx + bw, h - bh);
      path.lineTo(bx + bw, h);
    }
    path..lineTo(w, h)..close();
    canvas.drawPath(path, paint);
  }
 
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
 
class _RTLBarPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RTLBarPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // moving bar width
    final barWidth = size.width * 0.25;

    // right → left movement
    final x = size.width - (progress * (size.width + barWidth));

    // gradient effect
    final rect = Rect.fromLTWH(x, 0, barWidth, size.height);

    paint.shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        color.withOpacity(0.0),
        color.withOpacity(0.4),
        color,
        color.withOpacity(0.4),
        color.withOpacity(0.0),
      ],
    ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        const Radius.circular(10),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}