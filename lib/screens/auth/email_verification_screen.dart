import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../widgets/shared.dart';
import 'profile_setup_screen.dart';

/// SD-M1.4 — Verify Email Address. Triggered automatically right after
/// account creation in the registration flow; not independently navigable.
/// A valid token normally proceeds automatically with no screen for the
/// member to dismiss — since this prototype has no real mail client to
/// hand off to, the "I've verified" action stands in for that silent
/// token check, clearly labelled as such rather than pretending to be a
/// real deep link.
class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  int _cooldown = 0;
  Timer? _timer;
  bool _justResent = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _startCooldown();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  void _resend() {
    setState(() => _justResent = true);
    _startCooldown();
    showToast(context, 'Verification link re-sent to ${widget.email}.');
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _justResent = false);
    });
  }

  void _continue() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Center(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    final scale = 1.0 + (_pulse.value * 0.06);
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.mark_email_unread_rounded, color: Colors.white, size: 42),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Text('Check your inbox', style: Theme.of(context).textTheme.headlineMedium),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                    children: [
                      const TextSpan(text: 'We sent a verification link to '),
                      TextSpan(
                          text: widget.email,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                      const TextSpan(text: '. Open it on this device to confirm your account.'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _justResent
                    ? Container(
                        key: const ValueKey('resent'),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.successTint,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success),
                            SizedBox(width: 10),
                            Flexible(
                              child: Text('Link re-sent. Check your inbox again.',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success)),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(key: ValueKey('empty'), height: 0),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: _cooldown > 0 ? null : _resend,
                child: Text(_cooldown > 0 ? 'Resend link in ${_cooldown}s' : 'Resend verification link'),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _continue,
                child: const Text("I've verified my email"),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Prototype shortcut — a real build detects the link automatically.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
