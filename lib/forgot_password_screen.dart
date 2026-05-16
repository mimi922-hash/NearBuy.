import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
 
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}
 
class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
 
  // ── Brand Colors ──
  static const Color primaryNavy  = Color(0xFF0E2A47);
  static const Color accentOrange = Color(0xFFFF6A1A);
 
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(_animController);
    _animController.forward();
  }
 
  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    super.dispose();
  }
 
  // ✅ Reset password logic — unchanged
  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showSnack("Please enter your email.", Colors.red); return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      setState(() => _emailSent = true);
      _showSnack("Password reset link sent to your email.", Colors.green);
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? "Failed to send reset link.", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
 
  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Navy header (same theme as login/signup) ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 55, bottom: 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryNavy, Color(0xFF1A3A5C)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(50),
                bottomRight: Radius.circular(50),
              ),
            ),
            child: Column(
              children: [
                // Lock icon in circle
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4), width: 2),
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      size: 52, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text('Forgot Password?',
                    style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold,
                      color: Colors.white, letterSpacing: 0.4,
                    )),
                const SizedBox(height: 6),
                // ✅ Orange accent dot separator
                Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("No worries, we'll send you a reset link",
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _emailSent ? _successWidget() : _formWidget(),
              ),
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _formWidget() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 16, offset: const Offset(0, 4),
            )],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reset Your Password',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: primaryNavy,
                  )),
              const SizedBox(height: 6),
              Text(
                "Enter your registered email and we'll send you a password reset link.",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 22),
              // Email field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Enter your registered email',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: Color(0xFF64748B)),
                  filled: true, fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: accentOrange, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // ✅ Orange send button
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentOrange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isLoading ? const SizedBox.shrink()
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  label: _isLoading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Send Reset Link',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,
                          )),
                  onPressed: _isLoading ? null : _resetPassword,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded,
              color: Color(0xFF0E2A47), size: 18),
          label: const Text('Back to Login',
              style: TextStyle(
                color: Color(0xFF0E2A47),
                fontWeight: FontWeight.w500, fontSize: 15,
              )),
        ),
      ],
    );
  }
 
  Widget _successWidget() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 16, offset: const Offset(0, 4),
            )],
          ),
          child: Column(
            children: [
              // ✅ Orange check circle (matches brand)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF6A1A).withOpacity(0.1),
                  border: Border.all(color: const Color(0xFFFF6A1A), width: 2),
                ),
                child: const Icon(Icons.mark_email_read_rounded,
                    color: Color(0xFFFF6A1A), size: 52),
              ),
              const SizedBox(height: 20),
              const Text('Email Sent!',
                  style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold,
                    color: Color(0xFF0E2A47),
                  )),
              const SizedBox(height: 12),
              Text(
                "We've sent a password reset link to:\n\${_emailController.text.trim()}",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text('Please check your inbox (and spam folder).',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 50,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF0E2A47), width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.arrow_back_rounded,
                color: Color(0xFF0E2A47)),
            label: const Text('Back to Login',
                style: TextStyle(
                  color: Color(0xFF0E2A47),
                  fontWeight: FontWeight.w600, fontSize: 15,
                )),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }
}
