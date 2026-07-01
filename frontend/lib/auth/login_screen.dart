import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'signup_screen.dart';

/// L.U.C.K.Y — Personal AI login screen
/// Same auth logic as your original LoginScreen (AuthService.login,
/// validators, forgot-password reset) — restyled to match signup_screen.dart.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _auth = AuthService();

  bool _obscurePassword = true;
  bool _isLoading = false;
  late final AnimationController _radarController;

  // ---- Palette (matches signup_screen.dart) ------------------------------
  static const Color kBackground = Color(0xFF040912);
  static const Color kBackgroundVignette = Color(0xFF061422);
  static const Color kCyan = Color(0xFF3FD9FF);
  static const Color kBlue = Color(0xFF2E8FFF);
  static const Color kDimBlue = Color(0xFF1B4A73);
  static const Color kFieldBorder = Color(0xFF1E5C8C);
  static const Color kHint = Color(0xFF5F93B8);

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---- Your original validators & auth logic, unchanged -------------------

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your username';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final error = await _auth.login(
      email: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (error != null) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));

      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = false);
  }

  // ---- UI -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          // Ambient vignette glow behind the radar
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 420,
                height: 420,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [kBackgroundVignette, kBackground],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _buildRadarLogo(),
                    const SizedBox(height: 20),
                    _buildStatusRow(),
                    const SizedBox(height: 28),

                    // ---- Username field (validators unchanged) ------------
                    _buildTextField(
                      controller: _usernameController,
                      hint: 'Username',
                      icon: Icons.person_outline,
                      validator: _validateUsername,
                    ),
                    const SizedBox(height: 16),

                    // ---- Password field (validators unchanged) ------------
                    _buildTextField(
                      controller: _passwordController,
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      validator: _validatePassword,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: kCyan,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ---- Forgot password (logic unchanged) ------------------
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          final error = await _auth.resetPassword(
                            _usernameController.text.trim(),
                          );

                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error ??
                                    "Password reset email sent successfully.",
                              ),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: kCyan,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            decorationColor: kCyan,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ---- Login button (onPressed logic unchanged) ---------
                    _buildLoginButton(),
                    const SizedBox(height: 20),

                    // ---- Sign up row (navigation unchanged) ----------------
                    _buildSignUpRow(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Radar / logo (matches signup_screen.dart) --------------------------

  Widget _buildRadarLogo() {
    return SizedBox(
      height: 260,
      width: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _radarController,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(260, 260),
                painter: _RadarPainter(
                  progress: _radarController.value,
                  cyan: kCyan,
                  blue: kBlue,
                  dim: kDimBlue,
                ),
              );
            },
          ),
          _buildGlowingTitle(),
        ],
      ),
    );
  }

  Widget _buildGlowingTitle() {
    const letters = 'L.U.C.K.Y';
    return Text.rich(
      TextSpan(
        children: [
          for (int i = 0; i < letters.length; i++)
            TextSpan(
              text: letters[i],
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 36,
                fontWeight: FontWeight.w700,
                letterSpacing: letters[i] == '.' ? 0 : 2,
                color: Colors.white,
                shadows: const [
                  Shadow(color: kCyan, blurRadius: 18),
                  Shadow(color: kCyan, blurRadius: 36),
                  Shadow(color: kBlue, blurRadius: 60),
                ],
              ),
            ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStatusRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'P E R S O N A L   A I',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            letterSpacing: 1,
            color: kHint,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: kCyan.withOpacity(0.8)),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: kCyan.withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: const Text(
            'ONLINE',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: kCyan,
            ),
          ),
        ),
      ],
    );
  }

  // ---- Input field (matches signup_screen.dart, with validator support) ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF061722),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kFieldBorder),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'monospace',
        ),
        cursorColor: kCyan,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: kCyan, size: 20),
          suffixIcon: suffix,
          hintText: hint,
          hintStyle: TextStyle(
            color: kHint,
            fontFamily: 'monospace',
            fontSize: 15,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 4,
          ),
          errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      ),
    );
  }

  // ---- Login button (onPressed = _handleLogin, logic unchanged) -----------

  Widget _buildLoginButton() {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xFF1B4A73), Color(0xFF2E8FFF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: kCyan.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: kBlue.withOpacity(0.55),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: _isLoading ? null : _handleLogin,
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'LOGIN',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- Sign up row (navigation unchanged) ----------------------------------

  Widget _buildSignUpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(fontFamily: 'monospace', color: kHint, fontSize: 13),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignupScreen()),
            );
          },
          child: const Text(
            'Sign Up',
            style: TextStyle(
              fontFamily: 'monospace',
              color: kCyan,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints the concentric rings, tick marks, dotted arcs and sweeping
/// accent arcs — identical to the one used in signup_screen.dart so both
/// screens share the same animated backdrop.
class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.progress,
    required this.cyan,
    required this.blue,
    required this.dim,
  });

  final double progress;
  final Color cyan;
  final Color blue;
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = dim.withOpacity(0.5);

    for (final r in [0.45, 0.62, 0.78, 0.95]) {
      canvas.drawCircle(center, maxRadius * r, ringPaint);
    }

    _drawDottedCircle(canvas, center, maxRadius * 0.95, dim.withOpacity(0.6));
    _drawTicks(canvas, center, maxRadius * 0.78, dim.withOpacity(0.7));

    _drawGlowArc(
      canvas,
      center,
      maxRadius * 0.95,
      startAngle: progress * 2 * math.pi,
      sweep: 0.9,
      color: cyan,
    );
    _drawGlowArc(
      canvas,
      center,
      maxRadius * 0.62,
      startAngle: -progress * 2 * math.pi * 1.4 + math.pi,
      sweep: 0.6,
      color: blue,
    );
    _drawGlowArc(
      canvas,
      center,
      maxRadius * 0.45,
      startAngle: progress * 2 * math.pi * 0.8 + math.pi / 2,
      sweep: 1.1,
      color: cyan.withOpacity(0.8),
    );

    final rnd = math.Random(7);
    final dotPaint = Paint()..color = cyan.withOpacity(0.5);
    for (int i = 0; i < 18; i++) {
      final angle = rnd.nextDouble() * 2 * math.pi;
      final radius = maxRadius * (0.3 + rnd.nextDouble() * 0.68);
      final p = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(p, rnd.nextDouble() * 1.4 + 0.4, dotPaint);
    }
  }

  void _drawDottedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final paint = Paint()..color = color;
    const dashCount = 90;
    for (int i = 0; i < dashCount; i++) {
      final angle = (i / dashCount) * 2 * math.pi;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(p, 0.8, paint);
    }
  }

  void _drawTicks(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    const tickCount = 40;
    for (int i = 0; i < tickCount; i++) {
      final angle = (i / tickCount) * 2 * math.pi;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final inner = center + dir * (radius - 5);
      final outer = center + dir * (radius + 5);
      canvas.drawLine(inner, outer, paint);
    }
  }

  void _drawGlowArc(
    Canvas canvas,
    Offset center,
    double radius, {
    required double startAngle,
    required double sweep,
    required Color color,
  }) {
    final rect = Rect.fromCircle(center: center, radius: radius);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(rect, startAngle, sweep, false, glowPaint);

    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, startAngle, sweep, false, corePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
