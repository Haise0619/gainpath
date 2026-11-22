import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

import '../../../../infrastructure/firebase/firebase_function_transport.dart';

typedef RecoveryCommand = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> input);

Future<Map<String, dynamic>> sendRecoveryCommand(
    Map<String, dynamic> input) async {
  final result = await firebaseCallable('passwordRecovery').call(input);
  return Map<String, dynamic>.from(result.data as Map);
}

enum _Step { email, code, password, success }

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({
    super.key,
    required this.initialEmail,
    required this.onEmailLink,
    this.command = sendRecoveryCommand,
  });

  final String initialEmail;
  final VoidCallback onEmailLink;
  final RecoveryCommand command;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _codeFocus = FocusNode();
  final _form = GlobalKey<FormState>();
  _Step _step = _Step.email;
  bool _busy = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  String? _error;
  String? _challenge;
  String? _token;
  Timer? _timer;
  DateTime? _resendAt;

  int get _remaining {
    final milliseconds =
        _resendAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    return milliseconds > 0 ? (milliseconds + 999) ~/ 1000 : 0;
  }

  CredentialErrors get _validation => const CredentialsPolicy().validate(
        email: _email.text,
        name: 'GainPath',
        password: _password.text,
        confirm: _confirm.text,
        registering: true,
      );

  @override
  void dispose() {
    _timer?.cancel();
    _codeFocus.dispose();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _changeEmail() {
    if (_busy) return;
    _timer?.cancel();
    setState(() {
      _step = _Step.email;
      _error = null;
      _challenge = null;
      _token = null;
      _resendAt = null;
      _code.clear();
      _password.clear();
      _confirm.clear();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = switch (error.code) {
          'failed-precondition' => _step == _Step.code
              ? 'Invalid or expired code. Check the code or request another.'
              : 'This reset session has expired. Request another code.',
          'unavailable' when _step == _Step.password =>
            'Could not confirm the reset. Try signing in with the new password or request another code.',
          _ => 'Password recovery is temporarily unavailable. Try again.',
        };
        if (_step == _Step.password && error.code != 'invalid-argument') {
          _token = null;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_step == _Step.email && !_form.currentState!.validate()) return;
    await _run(() async {
      final data = await widget.command({
        'operation': 'requestPasswordResetOtp',
        'email': _email.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _challenge = data['challengeId'] as String;
        _code.clear();
        _step = _Step.code;
        _resendAt = DateTime.now().add(
          Duration(seconds: data['resendAfterSeconds'] as int),
        );
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {});
        if (_remaining == 0) timer.cancel();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _step == _Step.code) _codeFocus.requestFocus();
      });
    });
  }

  Future<void> _verify() => _run(() async {
        final data = await widget.command({
          'operation': 'verifyPasswordResetOtp',
          'email': _email.text.trim(),
          'challengeId': _challenge,
          'code': _code.text,
        });
        if (!mounted) return;
        _timer?.cancel();
        setState(() {
          _token = data['resetToken'] as String;
          _code.clear();
          _step = _Step.password;
        });
      });

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      final data = await widget.command({
        'operation': 'completePasswordReset',
        'email': _email.text.trim(),
        'challengeId': _challenge,
        'resetToken': _token,
        'password': _password.text,
      });
      if (!mounted) return;
      if (data['success'] != true) throw StateError('Reset unconfirmed');
      FocusScope.of(context).unfocus();
      setState(() {
        _password.clear();
        _confirm.clear();
        _token = null;
        _step = _Step.success;
      });
    });
  }

  String get _maskedEmail {
    final parts = _email.text.trim().split('@');
    return '${parts.first.characters.first}•••@${parts.last}';
  }

  Widget _codeInput() => ListenableBuilder(
        listenable: Listenable.merge([_code, _codeFocus]),
        builder: (context, _) {
          final colors = Theme.of(context).colorScheme;
          return Stack(
            alignment: Alignment.center,
            children: [
              ExcludeSemantics(
                child: Row(
                  children: List.generate(6, (index) {
                    final active = _codeFocus.hasFocus &&
                        index ==
                            (_code.text.length == 6 ? 5 : _code.text.length);
                    return Expanded(
                      child: Container(
                        height: 52,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                active ? colors.primary : colors.outlineVariant,
                            width: active ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          index < _code.text.length ? _code.text[index] : '',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Positioned.fill(
                child: TextField(
                  key: const Key('recovery-code'),
                  controller: _code,
                  focusNode: _codeFocus,
                  enabled: !_busy,
                  style: const TextStyle(color: Colors.transparent),
                  cursorColor: Colors.transparent,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    labelText: 'Six-digit verification code',
                    labelStyle: TextStyle(color: Colors.transparent),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    filled: false,
                  ),
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (_code.text.length == 6) _verify();
                  },
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
            ],
          );
        },
      );

  Widget _passwordField({required bool confirmation}) {
    final shown = confirmation ? _showConfirm : _showPassword;
    final label = confirmation ? 'Confirm password' : 'New password';
    return TextFormField(
      controller: confirmation ? _confirm : _password,
      enabled: !_busy,
      obscureText: !shown,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.newPassword],
      validator: (_) =>
          confirmation ? _validation.confirm : _validation.password,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: '${shown ? 'Hide' : 'Show'} ${label.toLowerCase()}',
          icon: Icon(shown ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() {
            if (confirmation) {
              _showConfirm = !shown;
            } else {
              _showPassword = !shown;
            }
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, title, subtitle) = switch (_step) {
      _Step.email => (
          Icons.lock_outline,
          'Forgot password?',
          'Enter your registered email to receive a verification code.'
        ),
      _Step.code => (
          Icons.verified_user_outlined,
          'Verify your email',
          'If the account is eligible, a six-digit code was sent to $_maskedEmail.'
        ),
      _Step.password => (
          Icons.lock_outline,
          'Create new password',
          'Use at least ${CredentialsPolicy.minPasswordLength} characters.'
        ),
      _Step.success => (
          Icons.check_circle_outline,
          'Password reset successful',
          'Sign in with your new password.'
        ),
    };
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
            onPressed: _busy
                ? () {}
                : () {
                    if (_step == _Step.code || _step == _Step.password) {
                      _changeEmail();
                    } else {
                      Navigator.of(context).pop();
                    }
                  }),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(icon, size: 38, color: theme.colorScheme.primary),
                      const SizedBox(height: 20),
                      Text(title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text(subtitle, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      if (_step == _Step.email)
                        TextFormField(
                          controller: _email,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            border: OutlineInputBorder(),
                          ),
                          validator: (_) => _validation.email,
                          onFieldSubmitted: (_) => _send(),
                        ),
                      if (_step == _Step.code) _codeInput(),
                      if (_step == _Step.password) ...[
                        _passwordField(confirmation: false),
                        const SizedBox(height: 12),
                        _passwordField(confirmation: true),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                            liveRegion: true,
                            child: Text(_error!,
                                style:
                                    TextStyle(color: theme.colorScheme.error))),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : switch (_step) {
                                _Step.email => _send,
                                _Step.code =>
                                  _code.text.length == 6 ? _verify : null,
                                _Step.password =>
                                  _token == null ? _changeEmail : _reset,
                                _Step.success => () =>
                                    Navigator.of(context).pop(),
                              },
                        child: _busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text(switch (_step) {
                                _Step.email => 'Send verification code',
                                _Step.code => 'Verify code',
                                _Step.password => _token == null
                                    ? 'Request another code'
                                    : 'Reset password',
                                _Step.success => 'Back to Sign In',
                              }),
                      ),
                      if (_step == _Step.code) ...[
                        TextButton(
                          onPressed: _busy || _remaining > 0 ? null : _send,
                          child: Text(_remaining > 0
                              ? 'Resend code in 00:${_remaining.toString().padLeft(2, '0')}'
                              : 'Resend code'),
                        ),
                        TextButton(
                            onPressed: _busy ? null : _changeEmail,
                            child: const Text('Change email address')),
                      ],
                      if (_step == _Step.email) ...[
                        TextButton(
                            onPressed: _busy ? null : widget.onEmailLink,
                            child: const Text('Use an email link instead')),
                        TextButton(
                          onPressed:
                              _busy ? null : () => Navigator.of(context).pop(),
                          child: const Text('Back to Sign In'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
