import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';
import '../member/member_shell.dart';
import '../coach/coach_shell.dart';
import '../admin/admin_shell.dart';
import 'email_verification_screen.dart';
import 'forgot_password_sheet.dart';
import 'role_select_screen.dart';

/// AD-M1.1 / AD-M8.1 / AD-M11.1 — Login and Recovery.
///
/// Mobile and Windows desktop render a hero header over a full-bleed sheet.
/// Web (Admin/Staff) renders a desktop-width centred login card against a
/// branded split layout, per the design direction's platform note for
/// AD-M11.1.
class LoginScreen extends StatefulWidget {
  final AppRole role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  late final TextEditingController _email;
  final _name = TextEditingController();
  final _password = TextEditingController(text: 'demo1234');
  final _confirm = TextEditingController(text: 'demo1234');

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _registering = false;
  bool _agreeTerms = false;
  bool _submitting = false;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: _seedEmail);
  }

  String get _seedEmail {
    switch (widget.role) {
      case AppRole.member:
        return MockData.memberEmail;
      case AppRole.coach:
        return MockData.coachEmail;
      case AppRole.admin:
        return MockData.adminEmail;
    }
  }

  String get _roleLabel {
    switch (widget.role) {
      case AppRole.member:
        return 'Gym Member';
      case AppRole.coach:
        return 'Fitness Coach';
      case AppRole.admin:
        return 'Admin / Staff';
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }


  bool _validate() {
    final emailText = _email.text.trim();
    setState(() {
      _nameError = _registering && _name.text.trim().isEmpty ? 'Enter your full name.' : null;
      _emailError = emailText.isEmpty
          ? 'Enter your email address.'
          : !_emailRegex.hasMatch(emailText)
              ? 'Enter a valid email address.'
              : null;
      _passwordError = _password.text.isEmpty
          ? 'Enter your password.'
          : _registering && _password.text.length < 8
              ? 'Use at least 8 characters.'
              : null;
      _confirmError = _registering && _confirm.text != _password.text ? 'Passwords do not match.' : null;
    });
    if (_nameError != null || _emailError != null || _passwordError != null || _confirmError != null) {
      return false;
    }
    if (_registering && !_agreeTerms) {
      showToast(context, 'Agree to the Terms and Privacy Policy to continue.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _submitting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _submitting = false);

    // A brand-new Gym Member account verifies their email (SD-M1.4) then
    // walks through the step-by-step profile setup wizard before landing in
    // the app; every other path (signing in, or the coach/admin roles that
    // never self-register here) goes straight to its shell.
    if (widget.role == AppRole.member && _registering) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: _email.text.trim())),
      );
      return;
    }

    Widget destination;
    switch (widget.role) {
      case AppRole.member:
        destination = const MemberShell();
        break;
      case AppRole.coach:
        destination = const CoachShell();
        break;
      case AppRole.admin:
        destination = const AdminShell();
        break;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  void _recover() {
    showForgotPasswordSheet(context, initialEmail: _email.text.trim());
  }

  void _toggleMode() {
    setState(() {
      _registering = !_registering;
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdminWeb = kIsWeb && widget.role == AppRole.admin;
    if (isAdminWeb) return _buildAdmin(context);
    return _buildMobile(context);
  }

  Widget _buildAdmin(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final card = Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _formChildren(context, dense: true, inSheet: false),
                  ),
                ),
              ),
            ),
          );
          if (!isWide) {
            return Container(
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: card,
            );
          }
          return Row(
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  decoration: const BoxDecoration(gradient: AppColors.heroGradient),
                  padding: const EdgeInsets.all(56),
                  child: const _AdminBrandPanel(),
                ),
              ),
              Expanded(
                flex: 4,
                child: Container(color: AppColors.bg, child: card),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        children: [
          Container(
            height: 240,
            width: double.infinity,
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          ),
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (widget.role == AppRole.member)
                  const SizedBox(height: 20)
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 16, 0),
                    child: Row(
                      children: [
                        Material(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.pop(context),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                        ),
                        child: Icon(
                          widget.role == AppRole.coach ? Icons.sports_rounded : Icons.fitness_center_rounded,
                          color: AppColors.overlay,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _registering ? 'Create account' : 'Welcome\nback',
                          maxLines: _registering ? 1 : 2,
                          overflow: _registering ? TextOverflow.ellipsis : TextOverflow.visible,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                                fontSize: _registering ? 21 : 26,
                                height: 1.15,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                      children: _formChildren(context, dense: false, inSheet: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _formChildren(BuildContext context, {required bool dense, required bool inSheet}) {
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_rounded, size: 15, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(_roleLabel,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
        ),
      ),
      SizedBox(height: dense ? 18 : 20),
      if (!inSheet) ...[
        Text(_registering ? 'Set up your account' : 'Welcome back',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
      ],
      if (!_registering)
        Text(
          widget.role == AppRole.admin
              ? 'Sign in to manage users, content, and facility reporting.'
              : 'Sign in to pick up where you left off.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      SizedBox(height: dense ? 22 : 24),
      _animatedField(
        show: _registering,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Full name',
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
              errorText: _nameError,
            ),
          ),
        ),
      ),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: 'Email address',
          prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
          errorText: _emailError,
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _password,
        obscureText: _obscure,
        onChanged: _registering ? (_) => setState(() {}) : null,
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
          errorText: _passwordError,
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      _animatedField(
        show: _registering && _password.text.isNotEmpty,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: PasswordStrengthMeter(strength: passwordStrengthOf(_password.text)),
        ),
      ),
      _animatedField(
        show: _registering,
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: TextField(
            controller: _confirm,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              errorText: _confirmError,
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
          ),
        ),
      ),
      _animatedField(
        show: _registering,
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _agreeTerms = !_agreeTerms),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Checkbox(
                    value: _agreeTerms,
                    onChanged: (v) => setState(() => _agreeTerms = v ?? false),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text.rich(
                      TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                        children: const [
                          TextSpan(text: 'I agree to the '),
                          TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                          TextSpan(text: ' and '),
                          TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                          TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (!_registering) ...[
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: _recover, child: const Text('Forgot password?')),
        ),
      ],
      const SizedBox(height: 14),
      FilledButton(
        onPressed: _submitting ? null : () => _submit(),
        child: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Text(_registering ? 'Create account' : 'Sign in'),
      ),
      if (widget.role == AppRole.member) ...[
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or continue with', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                label: 'Google',
                onTap: () => showToast(context, 'Social sign-in is not part of this prototype.'),
                child: const Text('G',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SocialButton(
                label: 'Apple',
                onTap: () => showToast(context, 'Social sign-in is not part of this prototype.'),
                child: const Icon(Icons.apple_rounded, size: 20, color: AppColors.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: _toggleMode,
            child: Text(_registering ? 'I already have an account' : 'New here? Create an account'),
          ),
        ),
      ],
      if (widget.role == AppRole.coach) ...[
        const SizedBox(height: 20),
        Panel(
          background: AppColors.surfaceAlt,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.inkSoft),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Coach accounts are created by gym staff. Check your email '
                  'for an invitation if you have not set a password yet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _animatedField({required bool show, required Widget child}) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: show ? 1 : 0,
        child: show ? child : const SizedBox(width: double.infinity),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback onTap;
  const _SocialButton({required this.label, required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              child,
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminBrandPanel extends StatelessWidget {
  const _AdminBrandPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: const Icon(Icons.accessibility_new_rounded, color: AppColors.overlay, size: 26),
        ),
        const SizedBox(height: 28),
        Text('GainPath',
            style: TextStyle(
              fontFamily: Theme.of(context).textTheme.displaySmall?.fontFamily,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.6,
            )),
        const SizedBox(height: 10),
        Text('Admin Console',
            style: TextStyle(
              fontFamily: Theme.of(context).textTheme.displaySmall?.fontFamily,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.7),
              letterSpacing: -0.6,
            )),
        const SizedBox(height: 20),
        Text(
          'Manage members and coaches, govern platform content, and monitor '
          'facility-wide reporting and AI recommendation leads from one place.',
          style: TextStyle(
            fontSize: 15,
            height: 1.55,
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
        const SizedBox(height: 36),
        _bullet(context, Icons.groups_rounded, 'Provision, verify, and manage every account'),
        const SizedBox(height: 14),
        _bullet(context, Icons.insights_rounded, 'Facility dashboards and exportable reports'),
        const SizedBox(height: 14),
        _bullet(context, Icons.auto_awesome_rounded, 'AI-surfaced coaching and content leads'),
      ],
    );
  }

  Widget _bullet(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: Colors.white.withValues(alpha: 0.9)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.86), height: 1.4)),
        ),
      ],
    );
  }
}
