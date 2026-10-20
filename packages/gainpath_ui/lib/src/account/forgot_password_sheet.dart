import 'dart:async';
import 'package:flutter/material.dart';
import '../tokens/app_theme.dart';

/// Presentation-safe error supplied by the caller, without a backend dependency.
class PasswordResetFailure implements Exception {
  const PasswordResetFailure(this.message);
  final String message;
}

/// AD-M1.1 forgot-password sub-flow. A dedicated, self-contained sheet
/// rather than the generic confirm-sheet pattern: it takes the email
/// inline, shows a real sending state, and swaps to a success view (with a
/// resend cooldown) without ever closing and losing context.
///
/// [asDialog] renders the same flow inside a centered desktop `Dialog`
/// instead of a bottom sheet, for the admin web console; member and coach
/// (mobile) keep the sheet by leaving it unset.
Future<void> showForgotPasswordSheet(BuildContext context,
    {required String initialEmail,
    bool asDialog = false,
    Future<void> Function(String)? onSend}) {
  if (asDialog) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _ForgotPasswordSheet(
              initialEmail: initialEmail, asDialog: true, onSend: onSend),
        ),
      ),
    );
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _ForgotPasswordSheet(initialEmail: initialEmail, onSend: onSend),
  );
}

class _ForgotPasswordSheet extends StatefulWidget {
  final String initialEmail;
  final bool asDialog;
  final Future<void> Function(String)? onSend;
  const _ForgotPasswordSheet(
      {required this.initialEmail, this.asDialog = false, this.onSend});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  late final TextEditingController _email =
      TextEditingController(text: widget.initialEmail);
  String? _error;
  bool _sending = false;
  bool _sent = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _email.text.trim();
    if (text.isEmpty || !_emailRegex.hasMatch(text)) {
      setState(() => _error = text.isEmpty
          ? 'Enter your email address.'
          : 'Enter a valid email address.');
      return;
    }
    setState(() {
      _error = null;
      _sending = true;
    });
    try {
      if (widget.onSend == null) {
        await Future.delayed(const Duration(milliseconds: 900));
      } else {
        await widget.onSend!(text);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = false;
        _error = error is PasswordResetFailure
            ? error.message
            : 'Could not request a reset email. Please try again.';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = true;
    });
    _startCooldown();
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

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: widget.asDialog
          ? const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.all(Radius.circular(20)))
          : const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.asDialog)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(999)),
              ),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SizeTransition(
                  sizeFactor: anim, axisAlignment: -1, child: child),
            ),
            child: _sent ? _successView(context) : _formView(context),
          ),
        ],
      ),
    );

    if (widget.asDialog) return content;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(top: false, child: content),
    );
  }

  Widget _formView(BuildContext context) {
    return Column(
      key: const ValueKey('form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.lock_reset_rounded,
              color: Colors.white, size: 26),
        ),
        const SizedBox(height: 16),
        Text('Reset your password',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Enter the email on your account and we will send a secure link to reset it.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        TextField(
          enabled: !_sending,
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            labelText: 'Email address',
            prefixIcon: const Icon(Icons.mail_outline_rounded, size: 20),
            errorText: _error,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _sending ? null : _send,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white),
                  )
                : const Text('Send reset link'),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
        ),
      ],
    );
  }

  Widget _successView(BuildContext context) {
    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
              color: AppColors.successTint,
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.mark_email_read_rounded,
              color: AppColors.success, size: 26),
        ),
        const SizedBox(height: 16),
        Text('Check your email',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            style: Theme.of(context).textTheme.bodyLarge,
            children: [
              TextSpan(
                  text: widget.onSend == null
                      ? 'Demo only: no email was sent.'
                      : 'If an account exists for this email, a reset link has been requested. Check your inbox and spam folder.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _sending || _cooldown > 0 ? null : _send,
            child: Text(_sending
                ? 'Sending…'
                : _cooldown > 0
                    ? 'Resend in ${_cooldown}s'
                    : "Didn't get it? Resend"),
          ),
        ),
      ],
    );
  }
}
