import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login_screen.dart';

/// L.U.C.K.Y — Personal AI sign up screen
/// Same auth logic as your original SignupScreen (AuthService, validation,
/// navigation to LoginScreen) wired up to the dark glowing HUD UI.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final AuthService _auth = AuthService();
  late final AnimationController _radarController;

  // ---- Palette ----------------------------------------------------------
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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ---- Your original auth logic, unchanged ------------------------------

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showMessage("Please fill all fields.");
      return;
    }

    if (password != confirm) {
      _showMessage("Passwords do not match.");
      return;
    }

    if (password.length < 6) {
      _showMessage("Password must be at least 6 characters.");
      return;
    }

    setState(() => _loading = true);

    final error = await _auth.signUp(email: email, password: password);

    setState(() => _loading = false);

    if (error == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created successfully!")),
      );

      Navigator.of(context).pop();
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- UI -----------------------------------------------------------------

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
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildRadarLogo(),
                  const SizedBox(height: 20),
                  _buildStatusRow(),
                  const SizedBox(height: 8),
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildTextField(
                    controller: _emailController,
                    hint: 'Email',
                    icon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordController,
                    hint: 'Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
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
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _confirmPasswordController,
                    hint: 'Confirm Password',
                    icon: Icons.lock_outline,
                    obscureText: _obscureConfirm,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: kCyan,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildSignUpButton(),
                  const SizedBox(height: 20),
                  _buildLoginRow(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Radar / logo ------------------------------------------------------

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

  // ---- Status row: "PERSONAL AI  [ONLINE]" -------------------------------

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

  // ---- Input field --------------------------------------------------------

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: const Color(0xFF061722),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kFieldBorder),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
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
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // ---- Sign up button ------------------------------------------------------

  Widget _buildSignUpButton() {
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
            onTap: _loading ? null : _signUp,
            child: Center(
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'SIGN UP',
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

  // ---- Bottom login link ---------------------------------------------------

  Widget _buildLoginRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(fontFamily: 'monospace', color: kHint, fontSize: 13),
        ),
        GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          child: const Text(
            'Log In',
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
/// accent arcs that make up the radar/HUD logo backdrop.
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
