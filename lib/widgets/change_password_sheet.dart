import 'package:flutter/material.dart';
import '../app/theme.dart';
import 'shared.dart';

/// Shared "Change Password" sub-flow used by every Manage Settings screen
/// (Gym Member 1.2, Fitness Coach 8.2, Admin / Staff 11.2): a looped
/// current-password confirmation gate, then a new-password step, committed
/// together as one save. Built once here so the pattern — and its
/// look-and-feel — never drifts between roles.
Future<void> showChangePasswordSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ChangePasswordSheet(),
  );
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  // Matches the demo credential seeded everywhere else in this prototype.
  static const _actualPassword = 'demo1234';

  int _step = 0;
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  String? _currentError;
  String? _nextError;
  String? _confirmError;
  bool _checking = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _confirmCurrent() async {
    if (_current.text.isEmpty) {
      setState(() => _currentError = 'Enter your current password.');
      return;
    }
    setState(() {
      _checking = true;
      _currentError = null;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (_current.text != _actualPassword) {
      setState(() {
        _checking = false;
        _currentError = 'That password is incorrect. Try again.';
      });
      return;
    }
    setState(() {
      _checking = false;
      _step = 1;
    });
  }

  void _save() {
    setState(() {
      _nextError = _next.text.length < 8 ? 'Use at least 8 characters.' : null;
      _confirmError = _confirm.text != _next.text ? 'Passwords do not match.' : null;
    });
    if (_nextError != null || _confirmError != null) return;
    Navigator.pop(context);
    showToast(context, 'Password updated.');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration:
                      BoxDecoration(color: AppColors.hairline, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              Row(
                children: [
                  Icon(
                    _step == 0 ? Icons.lock_outline_rounded : Icons.password_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text('Step ${_step + 1} of 2',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft)),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SizeTransition(sizeFactor: anim, axisAlignment: -1, child: child),
                ),
                child: _step == 0 ? _currentStep(context) : _newStep(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _currentStep(BuildContext context) {
    return Column(
      key: const ValueKey('current'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Confirm your current password', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
        const SizedBox(height: 6),
        Text('This confirms it is really you before we let you set a new one.',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 18),
        TextField(
          controller: _current,
          obscureText: true,
          autofocus: true,
          onSubmitted: (_) => _confirmCurrent(),
          decoration: InputDecoration(
            labelText: 'Current password',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            errorText: _currentError,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _checking ? null : _confirmCurrent,
          child: _checking
              ? const SizedBox(
                  width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : const Text('Confirm'),
        ),
      ],
    );
  }

  Widget _newStep(BuildContext context) {
    return Column(
      key: const ValueKey('new'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Set a new password', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
        const SizedBox(height: 6),
        Text('Choose something you have not used before.', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 18),
        TextField(
          controller: _next,
          obscureText: true,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'New password',
            prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
            errorText: _nextError,
          ),
        ),
        if (_next.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: PasswordStrengthMeter(strength: passwordStrengthOf(_next.text)),
          ),
        const SizedBox(height: 14),
        TextField(
          controller: _confirm,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Confirm new password',
            prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
            errorText: _confirmError,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _save,
          child: const Text('Save new password'),
        ),
      ],
    );
  }
}
