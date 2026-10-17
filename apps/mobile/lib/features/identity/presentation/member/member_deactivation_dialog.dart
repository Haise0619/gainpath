import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';

/// Password-guarded request only. Local history and retained cloud data are kept.
class MemberDeactivationDialog extends StatefulWidget {
  const MemberDeactivationDialog({super.key, required this.repository});
  final MemberAccountLifecycleRepository repository;
  @override
  State<MemberDeactivationDialog> createState() =>
      _MemberDeactivationDialogState();
}

class _MemberDeactivationDialogState extends State<MemberDeactivationDialog> {
  final _password = TextEditingController();
  MemberAccountLifecycle? _original;
  bool _busy = false;
  bool _uncertain = false;
  String? _error;
  Future<void> _confirm() async {
    if (_busy) return;
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your current password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.verifyCurrentPassword(_password.text);
      final original = _original ??= await widget.repository.load();
      final result = original.isPendingDeletion
          ? original
          : await widget.repository.requestDeactivation(original);
      if (!mounted) return;
      if (!result.isPendingDeletion) {
        throw const MemberAccountLifecycleException(
            'Deactivation was not confirmed. Reload account status.');
      }
      _password.clear();
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is MemberAccountLifecycleException
              ? error.message
              : 'Could not confirm deactivation. Sign in again and check account status before retrying.';
          _uncertain =
              error is! MemberAccountLifecycleException || error.uncertain;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final current = await widget.repository.load();
      if (!mounted) return;
      if (current.isPendingDeletion) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _original = current;
          _uncertain = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is MemberAccountLifecycleException
            ? error.message
            : 'Could not reload account status. Sign out and sign in again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Deactivate your account?'),
        content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text(
                  'Account access stops immediately and you will be signed out. Your saved data is retained during the 30-day recovery window. A 65-minute security wait applies before reactivation.'),
              const SizedBox(height: 12),
              const Text(
                  'Automatic permanent deletion is not enabled. Unsaved changes will close. Your local workout history is retained.'),
              const SizedBox(height: 16),
              TextField(
                  key: const ValueKey('lifecycle-password'),
                  controller: _password,
                  obscureText: true,
                  enabled: !_busy,
                  autofillHints: const [AutofillHints.password],
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration:
                      const InputDecoration(labelText: 'Current password')),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
            ])),
        actions: [
          if (_error != null)
            TextButton(
                onPressed: _busy ? null : _reload,
                child: const Text('Reload account status')),
          if (_uncertain)
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, true),
                child: const Text('Sign out and check status')),
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _busy ? null : _confirm,
              child: const Text('Confirm deactivation'))
        ],
      ));
}
