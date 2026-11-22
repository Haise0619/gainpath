import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import 'package:gainpath_domain/gainpath_domain.dart' show AuthException;
import 'onboarding_screen.dart';
import 'password_recovery_screen.dart';

/// AD-M1.1 / AD-M8.1 / AD-M11.1 — Login and Recovery.
///
/// Mobile and Windows desktop render a hero header over a full-bleed sheet.
/// Web (Admin/Staff) renders a desktop-width centred login card against a
/// branded split layout, per the design direction's platform note for
/// AD-M11.1.
class LoginScreen extends StatefulWidget {
  final AppRole? role;
  const LoginScreen(
      {super.key,
      this.role,
      this.initiallyRegistering = false,
      this.initialEmail = '',
      this.onPasswordReset,
      this.prefillDemoPassword = false});
  final bool initiallyRegistering;
  final String initialEmail;
  final bool prefillDemoPassword;
  final Future<void> Function(String)? onPasswordReset;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _email;
  final _name = TextEditingController();
  late final TextEditingController _password;
  late final TextEditingController _confirm;

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _registering = false;
  bool _agreeTerms = false;
  bool _submitting = false;
  bool _googleAttempt = false;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  String? _message;

  @override
  void initState() {
    super.initState();
    _registering = widget.initiallyRegistering;
    _email = TextEditingController(text: widget.initialEmail);
    final demoPassword = widget.prefillDemoPassword ? 'demo1234' : '';
    _password = TextEditingController(text: demoPassword);
    _confirm = TextEditingController(text: demoPassword);
    if (widget.role != null) {
      context.read<AuthBloc>().add(RoleSelected(widget.role!));
    }
  }

  String get _roleLabel {
    switch (widget.role) {
      case null:
        return 'Member or coach';
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

  void _submit() {
    if (_submitting) return;
    setState(() => _message = null);
    context.read<AuthBloc>().add(LoginSubmitted(
          email: _email.text,
          password: _password.text,
          name: _name.text,
          confirm: _confirm.text,
          registering: _registering,
          agreedTerms: _agreeTerms,
        ));
  }

  void _onAuthChanged(BuildContext context, AuthState auth) {
    if (_submitting &&
        !_googleAttempt &&
        auth.status == AuthStatus.signedOut &&
        auth.message != null &&
        auth.fieldErrors.isValid) {
      _password.clear();
      _confirm.clear();
    }
    setState(() {
      _submitting = auth.status == AuthStatus.submitting;
      if (!_submitting) _googleAttempt = false;
      _nameError = auth.fieldErrors.name;
      _emailError = auth.fieldErrors.email;
      _passwordError = auth.fieldErrors.password;
      _confirmError = auth.fieldErrors.confirm;
      _message = auth.message;
    });
    // The session-scoped application root owns authenticated navigation.
  }

  void _recover() async {
    if (const bool.fromEnvironment('ENABLE_PASSWORD_RECOVERY_OTP') &&
        widget.onPasswordReset != null && widget.role != AppRole.admin) {
      final useLink = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (routeContext) => PasswordRecoveryScreen(
          initialEmail: _email.text.trim(),
          onEmailLink: () => Navigator.of(routeContext).pop(true),
        )),
      );
      if (!mounted || useLink != true) return;
    }
    _recoverWithEmailLink();
  }

  void _recoverWithEmailLink() {
    showForgotPasswordSheet(context,
        initialEmail: _email.text.trim(),
        onSend: widget.onPasswordReset == null
            ? null
            : (email) async {
                try {
                  await widget.onPasswordReset!(email);
                } on AuthException catch (error) {
                  throw PasswordResetFailure(error.message);
                }
              },
        asDialog: kIsWeb && widget.role == AppRole.admin);
  }

  void _toggleMode() {
    setState(() {
      _registering = !_registering;
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: _onAuthChanged,
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
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
                    children:
                        _formChildren(context, dense: true, inSheet: false),
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
                  decoration:
                      const BoxDecoration(gradient: AppColors.heroGradient),
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
      backgroundColor: const Color(0xFF23034E),
      body: Stack(
        children: [
          // Background decoration with purple gradient, ambient orbs and orange swoosh
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 420,
            child: const CustomPaint(
              painter: _LoginHeaderBackgroundPainter(),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top header content (back button, GainPath sticker logo, Welcome back, orange smile accent)
                _buildHeader(context),
                // Floating White Card
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 24,
                          offset: Offset(0, -6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(32)),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 30, 24, 32),
                        children:
                            _formChildren(context, dense: false, inSheet: true),
                      ),
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

  Widget _buildHeader(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.role == AppRole.coach || Navigator.canPop(context))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 18),
        // GainPath Sticker Logo with runner silhouette and white outline
        Image.asset(
          'assets/images/gainpath_logo_sticker.png',
          height: 72,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 10),
        // Welcome back title
        Text(
          _registering ? 'Create account' : 'Welcome back',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 7),
        // Warm orange curved smile accent stroke
        const _OrangeSmileAccent(),
        const SizedBox(height: 26),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required Widget prefixIcon,
    Widget? suffixIcon,
    String? errorText,
    required bool inSheet,
  }) {
    if (!inSheet) {
      return InputDecoration(
        labelText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        errorText: errorText,
      );
    }
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      errorText: errorText,
      filled: true,
      fillColor: const Color(0xFFF7F6FC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEDE9FE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEDE9FE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF6D28D9), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    );
  }

  List<Widget> _formChildren(BuildContext context,
      {required bool dense, required bool inSheet}) {
    return [
      if (!inSheet) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _roleLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 1.1,
                ),
          ),
        ),
        const SizedBox(height: 12),
        Text(_registering ? 'Set up your account' : 'Welcome back',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          widget.role == AppRole.admin
              ? 'Sign in to manage users, content, and facility reporting.'
              : 'Sign in to pick up where you left off.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        SizedBox(height: dense ? 22 : 24),
      ] else if (_registering) ...[
        const Text(
          'Fill in your details to create an account.',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF4B5563),
          ),
        ),
        const SizedBox(height: 18),
      ],
      _animatedField(
        show: _registering,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: _fieldDecoration(
              hint: 'Full name',
              prefixIcon: const Icon(Icons.person_outline_rounded,
                  size: 20, color: Color(0xFF4B5563)),
              errorText: _nameError,
              inSheet: inSheet,
            ),
          ),
        ),
      ),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: _fieldDecoration(
          hint: 'Email address',
          prefixIcon: const Icon(Icons.mail_outline_rounded,
              size: 20, color: Color(0xFF4B5563)),
          errorText: _emailError,
          inSheet: inSheet,
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _password,
        obscureText: _obscure,
        onChanged: _registering ? (_) => setState(() {}) : null,
        decoration: _fieldDecoration(
          hint: 'Password',
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              size: 20, color: Color(0xFF4B5563)),
          errorText: _passwordError,
          inSheet: inSheet,
          suffixIcon: IconButton(
            icon: Icon(
              _obscure
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 20,
              color: const Color(0xFF1F2937),
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      _animatedField(
        show: _registering && _password.text.isNotEmpty,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: PasswordStrengthMeter(
              strength: passwordStrengthOf(_password.text)),
        ),
      ),
      _animatedField(
        show: _registering,
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: TextField(
            controller: _confirm,
            obscureText: _obscureConfirm,
            decoration: _fieldDecoration(
              hint: 'Confirm password',
              prefixIcon: const Icon(Icons.lock_outline_rounded,
                  size: 20, color: Color(0xFF4B5563)),
              errorText: _confirmError,
              inSheet: inSheet,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                  color: const Color(0xFF1F2937),
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
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
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontSize: 12.5),
                        children: const [
                          TextSpan(text: 'I agree to the '),
                          TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                          TextSpan(text: ' and '),
                          TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
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
          child: TextButton(
            onPressed: _recover,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Forgot password?',
              style: TextStyle(
                color: Color(0xFF6D28D9),
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ],
      SizedBox(height: inSheet ? 18 : 16),
      if (_message != null) ...[
        Semantics(
          liveRegion: true,
          child: Text(_message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        const SizedBox(height: 12),
      ],
      Container(
        width: double.infinity,
        height: inSheet ? 54 : 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: inSheet
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF5B16B8),
                    Color(0xFF6D28D9),
                    Color(0xFF8B2FC9),
                    Color(0xFFF97316),
                  ],
                  stops: [0.0, 0.45, 0.8, 1.0],
                )
              : null,
          color: inSheet ? null : AppColors.primary,
          boxShadow: inSheet
              ? [
                  BoxShadow(
                    color: const Color(0xFF6D28D9).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          onPressed: _submitting ? null : () => _submit(),
          child: _submitting && !_googleAttempt
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : inSheet
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        Text(
                          _registering ? 'Create account' : 'Sign in',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ],
                    )
                  : Text(_registering ? 'Create account' : 'Sign in'),
        ),
      ),
      if ((widget.role == null || widget.role == AppRole.member) &&
          context.read<AuthBloc>().supportsGoogleSignIn) ...[
        if (inSheet) ...[
          const SizedBox(height: 24),
          const Row(
            children: [
              Expanded(
                child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'or continue with',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ] else ...[
          const SizedBox(height: 12),
        ],
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, inSheet ? 52 : 50),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1F2937),
            side: const BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: _submitting
              ? null
              : () {
                  FocusScope.of(context).unfocus();
                  setState(() => _googleAttempt = true);
                  context.read<AuthBloc>().add(GoogleLoginSubmitted(
                        registering: _registering,
                        agreedTerms: _agreeTerms,
                      ));
                },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/google_sign_in_mark.png',
                width: 20,
                height: 20,
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 12),
              Text(
                _submitting && _googleAttempt
                    ? 'Connecting to Google…'
                    : _registering
                        ? 'Sign up with Google'
                        : 'Continue with Google',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ],
      if (widget.role == null || widget.role == AppRole.member) ...[
        SizedBox(height: inSheet ? 22 : 18),
        Center(
          child: InkWell(
            onTap: _submitting ? null : _toggleMode,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text.rich(
                TextSpan(
                  text:
                      _registering ? 'Already have an account? ' : 'New here? ',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF4B5563),
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(
                      text: _registering ? 'Sign in' : 'Create an account',
                      style: const TextStyle(
                        color: Color(0xFF6D28D9),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      if (!inSheet &&
          (widget.role == null || widget.role == AppRole.coach)) ...[
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 20, color: Color(0xFF6D28D9)),
              const SizedBox(width: 12),
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
      if (widget.role == null) ...[
        SizedBox(height: inSheet ? 16 : 14),
        Center(
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const OnboardingScreen(),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View introduction',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6D28D9),
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded,
                    size: 16, color: Color(0xFF6D28D9)),
              ],
            ),
          ),
        ),
      ],
      if (inSheet) ...[
        const SizedBox(height: 32),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_outlined,
                    size: 13, color: Color(0xFF9CA3AF)),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Protected by GainPath · Terms & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
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
          child: const Icon(Icons.accessibility_new_rounded,
              color: AppColors.overlay, size: 26),
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
        _bullet(context, Icons.groups_rounded,
            'Provision, verify, and manage every account'),
        const SizedBox(height: 14),
        _bullet(context, Icons.insights_rounded,
            'Facility dashboards and exportable reports'),
        const SizedBox(height: 14),
        _bullet(context, Icons.auto_awesome_rounded,
            'AI-surfaced coaching and content leads'),
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
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.86),
                  height: 1.4)),
        ),
      ],
    );
  }
}

class _OrangeSmileAccent extends StatelessWidget {
  const _OrangeSmileAccent();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(64, 8),
      painter: _SmilePainter(),
    );
  }
}

class _SmilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF8A00)
      ..strokeWidth = 3.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(4, 2)
      ..quadraticBezierTo(size.width / 2, size.height + 1, size.width - 4, 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginHeaderBackgroundPainter extends CustomPainter {
  const _LoginHeaderBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Rich multi-stop deep purple gradient base
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment(-0.85, -1.0),
        end: Alignment(0.9, 1.0),
        colors: [
          Color(0xFF38066D),
          Color(0xFF2B0352),
          Color(0xFF1D013B),
          Color(0xFF120026),
        ],
        stops: [0.0, 0.35, 0.72, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Tactile Micro-Dot Matrix Texture Grid (Tech athletic texture)
    final dotPaint = Paint()..style = PaintingStyle.fill;
    const dotSpacing = 20.0;
    final focalPoint = Offset(size.width * 0.5, size.height * 0.28);

    for (double x = 8.0; x < size.width; x += dotSpacing) {
      for (double y = 8.0; y < size.height; y += dotSpacing) {
        final dist = (Offset(x, y) - focalPoint).distance;
        final factor = (1.0 - (dist / (size.width * 0.85))).clamp(0.0, 1.0);
        final alpha = 0.04 + 0.10 * factor;
        dotPaint.color = Color.fromRGBO(233, 213, 255, alpha);
        final radius = 1.0 + 0.5 * factor;
        canvas.drawCircle(Offset(x, y), radius, dotPaint);
      }
    }

    // 3. Layered Sculptural Wave Ribbons / Folds (from GainPath brand artwork)
    // Wave Ridge 1: Upper flowing diagonal ridge
    final wave1Path = Path()
      ..moveTo(0, size.height * 0.08)
      ..cubicTo(
        size.width * 0.30,
        size.height * 0.02,
        size.width * 0.65,
        size.height * 0.22,
        size.width,
        size.height * 0.12,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();

    final wave1Paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF7E22CE).withValues(alpha: 0.36),
          const Color(0xFF9333EA).withValues(alpha: 0.18),
          const Color(0xFF7E22CE).withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawPath(wave1Path, wave1Paint);

    // Wave Ridge 2: Center sweeping dynamic flow
    final wave2Path = Path()
      ..moveTo(0, size.height * 0.38)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.24,
        size.width * 0.64,
        size.height * 0.46,
        size.width,
        size.height * 0.30,
      )
      ..lineTo(size.width, size.height * 0.55)
      ..lineTo(0, size.height * 0.55)
      ..close();

    final wave2Paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          const Color(0xFF6B21A8).withValues(alpha: 0.40),
          const Color(0xFF4C1D95).withValues(alpha: 0.24),
          const Color(0xFF3B0764).withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawPath(wave2Path, wave2Paint);

    // 4. Athletic Speed / Trajectory Lines (Running tracks & fitness curves)
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final line1 = Path()
      ..moveTo(-20, size.height * 0.24)
      ..cubicTo(
        size.width * 0.28,
        size.height * 0.14,
        size.width * 0.68,
        size.height * 0.34,
        size.width + 20,
        size.height * 0.20,
      );
    linePaint
      ..strokeWidth = 1.4
      ..shader = const LinearGradient(
        colors: [
          Color(0x00C084FC),
          Color(0x52C084FC),
          Color(0x80E9D5FF),
          Color(0x1AC084FC),
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawPath(line1, linePaint);

    final line2 = Path()
      ..moveTo(-20, size.height * 0.30)
      ..cubicTo(
        size.width * 0.30,
        size.height * 0.19,
        size.width * 0.70,
        size.height * 0.40,
        size.width + 20,
        size.height * 0.26,
      );
    linePaint
      ..strokeWidth = 1.0
      ..shader = const LinearGradient(
        colors: [
          Color(0x00A855F7),
          Color(0x40A855F7),
          Color(0x66C084FC),
          Color(0x00A855F7),
        ],
        stops: [0.0, 0.3, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawPath(line2, linePaint);

    // 5. Specular Halo Glow directly behind GainPath logo
    final logoGlowCenter = Offset(size.width * 0.5, size.height * 0.24);
    final logoGlowRadius = size.width * 0.44;
    final logoGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFA855F7).withValues(alpha: 0.38),
          const Color(0xFF7E22CE).withValues(alpha: 0.18),
          const Color(0xFF581C87).withValues(alpha: 0.0),
        ],
      ).createShader(
          Rect.fromCircle(center: logoGlowCenter, radius: logoGlowRadius));
    canvas.drawCircle(logoGlowCenter, logoGlowRadius, logoGlowPaint);

    // 6. Upper-Right Ambient Glassmorphism Orbs
    final orb1Center = Offset(size.width * 0.92, size.height * 0.10);
    final orb1Radius = size.width * 0.34;
    final orb1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFC084FC).withValues(alpha: 0.30),
          const Color(0xFF9333EA).withValues(alpha: 0.05),
          const Color(0xFF7E22CE).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: orb1Center, radius: orb1Radius));
    canvas.drawCircle(orb1Center, orb1Radius, orb1Paint);

    final orb1Ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFE9D5FF).withValues(alpha: 0.14);
    canvas.drawCircle(orb1Center, orb1Radius * 0.75, orb1Ring);

    final orb2Center = Offset(size.width * 0.78, size.height * 0.04);
    final orb2Radius = size.width * 0.22;
    final orb2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFA855F7).withValues(alpha: 0.24),
          const Color(0xFF7E22CE).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: orb2Center, radius: orb2Radius));
    canvas.drawCircle(orb2Center, orb2Radius, orb2Paint);

    // 7. Warm Orange Curved Energy Swoosh Ribbon (Vibrant brand highlight)
    final orangePath = Path()
      ..moveTo(size.width, size.height * 0.22)
      ..cubicTo(
        size.width * 0.88,
        size.height * 0.32,
        size.width * 0.76,
        size.height * 0.46,
        size.width * 0.58,
        size.height * 0.52,
      )
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.54,
        size.width * 0.88,
        size.height * 0.44,
        size.width,
        size.height * 0.34,
      )
      ..close();

    final orangePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Color(0x00FF8A00),
          Color(0x99FF8A00),
          Color(0xFFFF7A00),
          Color(0xFFFFA500),
        ],
        stops: [0.0, 0.35, 0.70, 1.0],
      ).createShader(rect);
    canvas.drawPath(orangePath, orangePaint);

    // 8. Thin Luminous Orange Light Streak Edge
    final streakPath = Path()
      ..moveTo(size.width, size.height * 0.20)
      ..cubicTo(
        size.width * 0.86,
        size.height * 0.30,
        size.width * 0.74,
        size.height * 0.44,
        size.width * 0.56,
        size.height * 0.50,
      );

    final streakPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Color(0x00FFD180),
          Color(0x99FFD180),
          Color(0xFFFFE082),
        ],
      ).createShader(rect);
    canvas.drawPath(streakPath, streakPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
