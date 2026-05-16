import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
 
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});
 
  @override
  Widget build(BuildContext context) {
    // ✅ NearBuy brand colors (matches image exactly)
    const Color primaryNavy  = Color(0xFF0E2A47);
    const Color accentOrange = Color(0xFFFF6A1A);
    const Color lightNavy    = Color(0xFF1565C0);
    const Color bgColor      = Color(0xFFF8FAFC);
 
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header: Navy gradient with curved bottom ──
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryNavy, Color(0xFF1A3A5C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(55),
                    bottomRight: Radius.circular(55),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo circle — white bg circle with store icon
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: accentOrange.withOpacity(0.3),
                            blurRadius: 30, offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/logo002.jpeg',
                          height: 90, width: 90, fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 38, fontWeight: FontWeight.bold, letterSpacing: 1.5,
                        ),
                        children: [
                          TextSpan(text: 'Near',
                              style: TextStyle(color: Colors.white)),
                          TextSpan(text: 'Buy',
                              style: TextStyle(color: accentOrange)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Smart Way to Discover Nearby Shops',
                      style: TextStyle(
                        fontSize: 13, color: Colors.white70, letterSpacing: 0.4,
                      ),
                    ),
                    // ✅ Orange accent bar at bottom of header (matches image)
                    const SizedBox(height: 16),
                    Container(
                      width: 60, height: 4,
                      decoration: BoxDecoration(
                        color: accentOrange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
 
            // ── Body ──
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  children: [
                    // ── Already have account card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.07),
                            blurRadius: 16, offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Arrow-in-box icon (matches image)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade100,
                            ),
                            child: const Icon(Icons.login_rounded,
                                color: Color(0xFF0E2A47), size: 30),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Already have an account?',
                            style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Login with your email & password.\n'
                            "We'll take you directly to your dashboard.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // ✅ Solid orange button (matches image exactly)
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentOrange,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.login, color: Colors.white),
                              label: const Text(
                                'Login to My Account',
                                style: TextStyle(
                                  color: Colors.white, fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const LoginScreen())),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('New here? Create Account',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 12)),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select your role to sign up:',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ✅ Customer card — orange icon bg (matches image)
                    _buildSignupRoleCard(context,
                      title: 'Customer',
                      subtitle: 'Browse & order from nearby shops',
                      icon: Icons.person_rounded,
                      iconBgColor: const Color(0xFFFFEEE6),
                      iconColor: accentOrange,
                      arrowColor: accentOrange,
                      role: 'Customer',
                    ),
                    const SizedBox(height: 12),
                    // ✅ Shopkeeper card — navy icon bg (matches image)
                    _buildSignupRoleCard(context,
                      title: 'Shopkeeper',
                      subtitle: 'Register your shop & manage orders',
                      icon: Icons.storefront_rounded,
                      iconBgColor: const Color(0xFFE6EEF8),
                      iconColor: primaryNavy,
                      arrowColor: primaryNavy,
                      role: 'Shopkeeper',
                    ),
                    const SizedBox(height: 28),
                    Text(
                      '© 2025 NearBuy | Smart Location Finder',
                      style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _buildSignupRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required Color arrowColor,
    required String role,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => SignupScreen(role: role))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15, color: iconColor,
                      )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: arrowColor, size: 16),
          ],
        ),
      ),
    );
  }
}
