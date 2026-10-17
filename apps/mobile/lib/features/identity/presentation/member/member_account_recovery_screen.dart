import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Narrow pending-account route. Protected app access requires a fresh restore.
class MemberAccountRecoveryScreen extends StatefulWidget {
  const MemberAccountRecoveryScreen(
      {super.key,
      required this.repository,
      required this.onSignedOut,
      required this.onRestored});
  final MemberAccountLifecycleRepository repository;
  final VoidCallback onSignedOut, onRestored;
  @override
  State<MemberAccountRecoveryScreen> createState() =>
      _MemberAccountRecoveryScreenState();
}

class _MemberAccountRecoveryScreenState
    extends State<MemberAccountRecoveryScreen> {
  final _password = TextEditingController();
  MemberAccountLifecycle? _status;
  bool _busy = false, _reloadRequired = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await widget.repository.load();
      if (mounted) {
        setState(() {
          _status = value;
          _reloadRequired = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _message(error);
          _reloadRequired = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) => error is MemberAccountLifecycleException
      ? error.message
      : 'Account status unavailable. Check your connection and try again.';
  Future<void> _restore() async {
    final original = _status;
    if (_busy ||
        _reloadRequired ||
        original == null ||
        !original.reactivationAllowed) {
      return;
    }
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
      final saved = await widget.repository.cancelDeactivation(original);
      if (!mounted) return;
      if (saved.isPendingDeletion) {
        throw const MemberAccountLifecycleException(
            'Reactivation was not confirmed. Reload account status.');
      }
      _password.clear();
      widget.onRestored();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _message(error);
          _reloadRequired = true;
        });
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
  Widget build(BuildContext context) {
    final status = _status;
    final deadline = status?.retentionEndsAtMillis;
    final wait = status == null || status.reactivationAvailableAtMillis == null
        ? 0
        : ((status.reactivationAvailableAtMillis! - status.currentTimeMillis) /
                60000)
            .ceil()
            .clamp(0, 100000);
    return PopScope(
        canPop: false,
        child: Scaffold(
            appBar: AppBar(
                title: const Text('Account recovery'),
                automaticallyImplyLeading: false),
            body: PageBody(children: [
              Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        status != null && !status.isPendingDeletion
                            ? 'Your account is active'
                            : 'Your account is deactivated',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    if (status == null)
                      const Text('Loading your current account status.'),
                    if (status?.isPendingDeletion == true) ...[
                      const Text(
                          'Profile and workout access is paused. Your saved data remains retained. Automatic permanent deletion is not enabled.'),
                      const SizedBox(height: 12),
                      if (deadline != null)
                        Text(
                            'Recovery deadline: ${DateTime.fromMillisecondsSinceEpoch(deadline, isUtc: true).toLocal()}'),
                      if (status!.policy == 'pendingApproval')
                        const Text(
                            'Recovery policy is awaiting approval. Please contact support.'),
                      if (status.sessionRevocationPending)
                        const Text(
                            'Session cleanup is still pending. Refresh account status to retry safely.'),
                      if (wait > 0)
                        Text(
                            'A 65-minute security wait lets previous sessions expire. About $wait minutes remain. Refresh account status afterward.'),
                      if (deadline != null &&
                          status.currentTimeMillis >= deadline)
                        const Text(
                            'The recovery window has ended. Contact support for account assistance.'),
                      const SizedBox(height: 16),
                      TextField(
                          key: const ValueKey('lifecycle-password'),
                          controller: _password,
                          obscureText: true,
                          enabled: !_busy &&
                              !_reloadRequired &&
                              status.reactivationAllowed,
                          autofillHints: const [AutofillHints.password],
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: const InputDecoration(
                              labelText: 'Current password')),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _busy ||
                                  _reloadRequired ||
                                  !status.reactivationAllowed
                              ? null
                              : _restore,
                          child: const Text('Keep my account')),
                    ],
                    if (status != null && !status.isPendingDeletion)
                      FilledButton(
                          onPressed: _busy ? null : widget.onRestored,
                          child: const Text('Continue to sign in')),
                    if (_busy) const LinearProgressIndicator(),
                    if (_error != null)
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                    TextButton(
                        onPressed: _busy ? null : _load,
                        child: const Text('Refresh account status')),
                    TextButton(
                        onPressed: _busy ? null : widget.onSignedOut,
                        child: const Text('Sign out')),
                  ])),
            ])));
  }
}
