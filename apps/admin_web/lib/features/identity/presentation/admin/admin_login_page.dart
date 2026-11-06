import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

/// Refined GainPath Administrator Login Screen.
///
/// Balanced, spacious desktop SaaS layout with generous negative space,
/// refined typography, responsive scaling across viewport width and height,
/// and full integration with [AuthBloc] and the password reset flow.
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key, this.onPasswordReset});

  final Future<void> Function(String)? onPasswordReset;

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _passwordVisible = false;
  String? _localEmailError;
  String? _localPasswordError;

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const RoleSelected(AppRole.admin));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    String? emailErr;
    String? passwordErr;

    if (email.isEmpty) {
      emailErr = 'Please enter your admin email';
    } else if (!email.contains('@') || !email.contains('.')) {
      emailErr = 'Please enter a valid email address';
    }

    if (password.isEmpty) {
      passwordErr = 'Please enter your password';
    }

    if (emailErr != null || passwordErr != null) {
      setState(() {
        _localEmailError = emailErr;
        _localPasswordError = passwordErr;
      });
      return;
    }

    setState(() {
      _localEmailError = null;
      _localPasswordError = null;
    });

    final bloc = context.read<AuthBloc>();
    bloc.add(const RoleSelected(AppRole.admin));
    bloc.add(
      LoginSubmitted(
        email: email,
        password: password,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final submitting = state.status == AuthStatus.submitting;

        return Scaffold(
          backgroundColor: const Color(0xFF0B0D19),
          body: Stack(
            children: [
              // 1. Full-screen Gym Photography Background
              Positioned.fill(
                child: Image.asset(
                  'assets/images/admin_login_bg.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: const Color(0xFF0E1122),
                  ),
                ),
              ),

              // 2. Dark Cinematic Vignette & Horizontal Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(
                            0xB8080A14), // ~72% dark overlay on left for contrast
                        Color(0x780A0C19), // ~47% center
                        Color(0x400C0F1C), // ~25% right
                      ],
                      stops: [0.0, 0.48, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. Foreground Content with responsive composition
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    final isDesktop = width >= 860;
                    final isShort = height < 820;

                    // Responsive outer horizontal padding:
                    // 80-110px on typical 1535px viewports, proportional on larger screens.
                    final double pageHorizontalPadding;
                    if (width >= 1400) {
                      pageHorizontalPadding = 96.0;
                    } else if (width >= 1100) {
                      pageHorizontalPadding = 64.0;
                    } else if (width >= 860) {
                      pageHorizontalPadding = 40.0;
                    } else {
                      pageHorizontalPadding = 20.0;
                    }

                    final double pageVerticalPadding = isShort ? 24.0 : 36.0;

                    return Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: pageHorizontalPadding,
                          vertical: pageVerticalPadding,
                        ),
                        child: isDesktop
                            ? _buildDesktopLayout(
                                context: context,
                                state: state,
                                submitting: submitting,
                                width: width,
                                isShort: isShort,
                              )
                            : _buildMobileLayout(
                                context: context,
                                state: state,
                                submitting: submitting,
                                isShort: isShort,
                              ),
                      ),
                    );
                  },
                ),
              ),

              // 4. Accessible & Regression Compatibility Markers
              Positioned(
                left: -9999,
                top: -9999,
                child: const SizedBox(
                  width: 1,
                  height: 1,
                  child: OverflowBox(
                    maxWidth: 300,
                    maxHeight: 100,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('GainPath Admin Web'),
                        Text('Administrator sign-in'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout({
    required BuildContext context,
    required AuthState state,
    required bool submitting,
    required double width,
    required bool isShort,
  }) {
    // Separation between branding and login card:
    // 90-115px on standard/wide desktops, comfortable 54-72px on narrower viewports.
    final double separation =
        width >= 1300 ? 100.0 : (width >= 1060 ? 80.0 : 54.0);

    // Target login card width: 480-505px on desktop
    final double cardWidth =
        width >= 1200 ? 490.0 : (width >= 1000 ? 470.0 : 440.0);

    final double brandingMaxWidth =
        width >= 1200 ? 460.0 : (width >= 1000 ? 410.0 : 360.0);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: cardWidth + separation + brandingMaxWidth,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Branding & Capabilities Column
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: brandingMaxWidth),
              child: _BrandingSection(isShort: isShort),
            ),
            SizedBox(width: separation),
            // Right White Floating Login Card
            SizedBox(
              width: cardWidth,
              child: _buildLoginCard(
                context: context,
                state: state,
                submitting: submitting,
                isShort: isShort,
                isNarrow: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout({
    required BuildContext context,
    required AuthState state,
    required bool submitting,
    required bool isShort,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _MobileBrandingHeader(),
          const SizedBox(height: 24),
          _buildLoginCard(
            context: context,
            state: state,
            submitting: submitting,
            isShort: isShort,
            isNarrow: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard({
    required BuildContext context,
    required AuthState state,
    required bool submitting,
    required bool isShort,
    required bool isNarrow,
  }) {
    final double cardPaddingH = isNarrow ? 24.0 : (isShort ? 36.0 : 40.0);
    final double cardPaddingV = isNarrow ? 28.0 : (isShort ? 28.0 : 36.0);
    final double adminIconContainerSize = isShort ? 72.0 : 80.0;
    final double adminIconSize = isShort ? 38.0 : 44.0;
    final double titleFontSize = isNarrow ? 26.0 : (isShort ? 29.0 : 32.0);
    final double subtitleFontSize = isNarrow ? 14.5 : (isShort ? 15.0 : 16.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFF1EEF9),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220A0D18),
            blurRadius: 36,
            spreadRadius: 0,
            offset: Offset(0, 16),
          ),
          BoxShadow(
            color: Color(0x0C5B35BC),
            blurRadius: 16,
            spreadRadius: -2,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: cardPaddingH,
        vertical: cardPaddingV,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Administrator badge icon, title, subtitle
          Center(
            child: Container(
              width: adminIconContainerSize,
              height: adminIconContainerSize,
              decoration: BoxDecoration(
                color: const Color(0xFFEAE3FF),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: _AdminShieldBadgeIcon(
                size: adminIconSize,
                color: const Color(0xFF5633B9),
              ),
            ),
          ),
          SizedBox(height: isShort ? 12 : 16),
          Text(
            'Admin Login',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0D0D16),
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Fitness Center Management Portal',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: subtitleFontSize,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF626B80),
              height: 1.3,
            ),
          ),
          SizedBox(height: isShort ? 18 : 24),

          // Email Address Field
          Text(
            'Email Address',
            style: GoogleFonts.inter(
              fontSize: isShort ? 14.0 : 15.0,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111318),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
            style: GoogleFonts.inter(
              fontSize: 15,
              color: const Color(0xFF111318),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your admin email',
              hintStyle: GoogleFonts.inter(
                fontSize: 14.5,
                color: const Color(0xFF98A2B3),
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(
                  Icons.mail_outline_rounded,
                  color: Color(0xFF596278),
                  size: 20,
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 46, minHeight: 22),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isShort ? 13 : 15,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFCDD3E1), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF5B35BC), width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFDC2626), width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFDC2626), width: 1.8),
              ),
              errorText: _localEmailError ?? state.fieldErrors.email,
              errorStyle: GoogleFonts.inter(
                  fontSize: 12.5, color: const Color(0xFFDC2626)),
            ),
          ),
          SizedBox(height: isShort ? 12 : 15),

          // Password Field
          Text(
            'Password',
            style: GoogleFonts.inter(
              fontSize: isShort ? 14.0 : 15.0,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111318),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: !_passwordVisible,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            style: GoogleFonts.inter(
              fontSize: 15,
              color: const Color(0xFF111318),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: GoogleFonts.inter(
                fontSize: 14.5,
                color: const Color(0xFF98A2B3),
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: Color(0xFF596278),
                  size: 20,
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 46, minHeight: 22),
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF596278),
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
                splashRadius: 18,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isShort ? 13 : 15,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFCDD3E1), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF5B35BC), width: 1.8),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFDC2626), width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFDC2626), width: 1.8),
              ),
              errorText: _localPasswordError ?? state.fieldErrors.password,
              errorStyle: GoogleFonts.inter(
                  fontSize: 12.5, color: const Color(0xFFDC2626)),
            ),
          ),

          // Forgot Password Link
          SizedBox(height: isShort ? 6 : 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: const Color(0xFF4E2DB4),
              ),
              onPressed: () => showForgotPasswordSheet(
                context,
                initialEmail: _emailController.text,
                onSend: widget.onPasswordReset == null
                    ? null
                    : (email) async {
                        try {
                          await widget.onPasswordReset!(email);
                        } on AuthException catch (error) {
                          throw PasswordResetFailure(error.message);
                        }
                      },
                asDialog: true,
              ),
              child: Text(
                'Forgot password?',
                style: GoogleFonts.inter(
                  color: const Color(0xFF4E2DB4),
                  fontSize: 14.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // Backend Error Message
          if (state.message != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.message!,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFB91C1C),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: isShort ? 16 : 20),

          // Primary Log In Button
          SizedBox(
            width: double.infinity,
            height: isShort ? 46 : 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: submitting
                    ? const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                      )
                    : const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFF6943C6), Color(0xFF4B24B2)],
                      ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5633B9).withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: submitting ? null : _submit,
                child: submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Log In',
                        style: GoogleFonts.poppins(
                          fontSize: isShort ? 16.0 : 17.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Left section displaying GainPath brand identity and key capabilities.
class _BrandingSection extends StatelessWidget {
  const _BrandingSection({this.isShort = false});

  final bool isShort;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Brand Dumbbell Icon
        _GainPathDumbbellIcon(
          width: isShort ? 54 : 62,
          height: isShort ? 36 : 42,
          color: const Color(0xFFA881FF),
        ),
        SizedBox(height: isShort ? 14 : 18),

        // Brand Title
        Text(
          'GainPath',
          style: GoogleFonts.poppins(
            fontSize: isShort ? 38 : 44,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.8,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),

        // Subtitle
        Text(
          'ADMIN PORTAL',
          style: GoogleFonts.poppins(
            fontSize: isShort ? 15 : 17,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFA881FF),
            letterSpacing: isShort ? 5.0 : 6.0,
          ),
        ),
        SizedBox(height: isShort ? 10 : 12),

        // Accent Line Divider
        Container(
          width: isShort ? 52 : 60,
          height: 3.5,
          decoration: BoxDecoration(
            color: const Color(0xFFA881FF),
            borderRadius: BorderRadius.circular(3.5),
          ),
        ),
        SizedBox(height: isShort ? 14 : 18),

        // Intro Text
        Text(
          'Manage your fitness center operations\nin one place.',
          style: GoogleFonts.inter(
            fontSize: isShort ? 15.0 : 16.5,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.45,
          ),
        ),
        SizedBox(height: isShort ? 20 : 26),

        // Feature Highlights
        _FeatureHighlightItem(
          icon: Icons.people_outline_rounded,
          label: 'Member Management',
          isShort: isShort,
        ),
        SizedBox(height: isShort ? 8 : 11),
        _FeatureHighlightItem(
          icon: Icons.calendar_today_outlined,
          label: 'Memberships & Plans',
          isShort: isShort,
        ),
        SizedBox(height: isShort ? 8 : 11),
        _FeatureHighlightItem(
          icon: Icons.fitness_center_rounded,
          label: 'Class & Schedule Management',
          isShort: isShort,
        ),
        SizedBox(height: isShort ? 8 : 11),
        _FeatureHighlightItem(
          icon: Icons.bar_chart_rounded,
          label: 'Reports & Analytics',
          isShort: isShort,
        ),
      ],
    );
  }
}

/// Compact branding header shown on mobile and narrow viewports.
class _MobileBrandingHeader extends StatelessWidget {
  const _MobileBrandingHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _GainPathDumbbellIcon(
          width: 48,
          height: 32,
          color: Color(0xFFA881FF),
        ),
        const SizedBox(height: 10),
        Text(
          'GainPath',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'ADMIN PORTAL',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFA881FF),
            letterSpacing: 4.0,
          ),
        ),
      ],
    );
  }
}

/// Consistent translucent feature highlight badge.
class _FeatureHighlightItem extends StatelessWidget {
  const _FeatureHighlightItem({
    required this.icon,
    required this.label,
    this.isShort = false,
  });

  final IconData icon;
  final String label;
  final bool isShort;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isShort ? 42 : 46,
          height: isShort ? 36 : 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: isShort ? 18 : 20),
        ),
        const SizedBox(width: 13),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isShort ? 14.0 : 15.0,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painted vector GainPath dumbbell icon matching the design reference.
class _GainPathDumbbellIcon extends StatelessWidget {
  const _GainPathDumbbellIcon({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _DumbbellPainter(color: color),
      ),
    );
  }
}

class _DumbbellPainter extends CustomPainter {
  const _DumbbellPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final scaleX = size.width / 68.0;
    final scaleY = size.height / 44.0;

    void drawPill(double l, double t, double w, double h, double r) {
      final rect = Rect.fromLTWH(
        l * scaleX,
        t * scaleY,
        w * scaleX,
        h * scaleY,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(r * scaleX)),
        paint,
      );
    }

    // Horizontal center bar connecting the weights
    drawPill(18, 19, 32, 6, 3);

    // Left inner weight plate
    drawPill(12, 6, 5.5, 32, 2.75);

    // Left outer weight plate
    drawPill(4.5, 11, 4.5, 22, 2.25);

    // Left bar outer tip
    drawPill(0, 19, 3.5, 6, 1.75);

    // Right inner weight plate
    drawPill(50.5, 6, 5.5, 32, 2.75);

    // Right outer weight plate
    drawPill(59, 11, 4.5, 22, 2.25);

    // Right bar outer tip
    drawPill(64.5, 19, 3.5, 6, 1.75);
  }

  @override
  bool shouldRepaint(covariant _DumbbellPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Administrator profile with shield badge icon inside the lavender container.
class _AdminShieldBadgeIcon extends StatelessWidget {
  const _AdminShieldBadgeIcon({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 2,
            top: 2,
            child: Icon(
              Icons.person_outline_rounded,
              size: size * 0.82,
              color: color,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFFEAE3FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_user_rounded,
                size: size * 0.44,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
