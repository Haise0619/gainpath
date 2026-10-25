import 'package:flutter/material.dart';

/// Presentation state supplied by the owning application's integration adapter.
class GoogleIntegrationPanelStatus {
  const GoogleIntegrationPanelStatus(
      {this.connectionStatus = 'disconnected',
      this.calendarStatus = 'not_created',
      this.syncStatus = 'not_synced',
      this.senderEmail,
      this.lastSyncedAtMillis,
      this.automationEnabled = false,
      this.automationStatus = 'not_started',
      this.emailSyncStatus = 'not_sent',
      this.revocationPending = false});
  final String connectionStatus, calendarStatus, syncStatus;
  final String? senderEmail;
  final int? lastSyncedAtMillis;
  final bool automationEnabled, revocationPending;
  final String automationStatus, emailSyncStatus;
  bool get connected => connectionStatus == 'connected';
}

/// UI callbacks only. Applications retain repositories, authority and transport.
class GoogleIntegrationPanelActions {
  const GoogleIntegrationPanelActions(
      {this.identity,
      required this.load,
      required this.beginConnect,
      required this.disconnect,
      required this.acknowledgeRevocation,
      required this.createCoachCalendar,
      required this.syncBooking});
  /// Keep stable while rebuilding callbacks for the same account repository.
  final Object? identity;
  Object get identityKey => identity ?? this;
  final Future<GoogleIntegrationPanelStatus> Function({String? coachId}) load;
  final Future<String> Function() beginConnect;
  final Future<void> Function() disconnect, acknowledgeRevocation;
  final Future<void> Function(String) createCoachCalendar;
  final Future<String> Function(String, {required bool email}) syncBooking;
}

/// One presentation; applications supply account-scoped integration callbacks.
class GoogleIntegrationPanel extends StatefulWidget {
  const GoogleIntegrationPanel(
      {super.key,
      required this.actions,
      this.admin = false,
      this.coachId,
      this.loadCoaches,
      this.openAuthorization,
      this.demo = false});
  final GoogleIntegrationPanelActions actions;
  final bool admin, demo;
  final String? coachId;
  final Future<Map<String, String>> Function()? loadCoaches;
  final Future<bool> Function(Uri)? openAuthorization;
  @override
  State<GoogleIntegrationPanel> createState() => _GoogleIntegrationPanelState();
}

class _GoogleIntegrationPanelState extends State<GoogleIntegrationPanel> {
  GoogleIntegrationPanelStatus? _status;
  String? _error, _message, _authorizationUrl, _coach;
  Map<String, String> _coaches = {};
  final _booking = TextEditingController();
  bool _busy = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _coach = widget.coachId;
    _load();
  }

  @override
  void didUpdateWidget(covariant GoogleIntegrationPanel old) {
    super.didUpdateWidget(old);
    if (old.actions.identityKey != widget.actions.identityKey ||
        old.coachId != widget.coachId) {
      _generation++;
      _status = null;
      _authorizationUrl = null;
      _coach = widget.coachId;
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    _booking.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final n = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final status = await widget.actions.load(coachId: _coach);
      final coaches =
          widget.loadCoaches == null ? _coaches : await widget.loadCoaches!();
      if (!mounted || n != _generation) return;
      setState(() {
        _status = status;
        _coaches = coaches;
        if (status.connected) _authorizationUrl = null;
        if (widget.admin && _coach != null && !coaches.containsKey(_coach)) {
          _coach = null;
        }
      });
    } catch (_) {
      if (mounted && n == _generation) {
        setState(() => _error =
            'Google integration is unavailable. Check deployment, account access and connection setup, then retry.');
      }
    } finally {
      if (mounted && n == _generation) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
          context: context,
          builder: (context) =>
              AlertDialog(title: Text(title), content: Text(body), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirm'))
              ])) ??
      false;
  Future<void> _act(Future<String?> Function() work) async {
    if (_busy) return;
    final n = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final message = await work();
      if (!mounted || n != _generation) return;
      setState(() => _message = message);
      await _load();
    } catch (_) {
      if (mounted && n == _generation) {
        setState(() {
          _authorizationUrl = null;
          _error =
              'The operation could not be confirmed. Refresh status before trying again. Do not repeat an uncertain email or calendar creation.';
        });
      }
    } finally {
      if (mounted && n == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _connect() async {
    if (_busy) return;
    final n = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _authorizationUrl = null;
    });
    try {
      final url = await widget.actions.beginConnect();
      if (!mounted || n != _generation) return;
      setState(() {
        _authorizationUrl = url;
        _message = 'Continue in Google, then return here and refresh status.';
      });
      await _load();
    } catch (_) {
      if (mounted && n == _generation) {
        setState(() => _error =
            'Google connection could not start. Check OAuth configuration and Admin access.');
      }
    } finally {
      if (mounted && n == _generation) setState(() => _busy = false);
    }
  }

  String _label(String value) => switch (value) {
        'connected' => 'Connected',
        'disconnected' => 'Not connected',
        'connecting' => 'Awaiting Google consent',
        'needs_reconnect' => 'Reconnect required',
        'ready' => 'Calendar ready',
        'not_created' => 'Calendar not created',
        'creating' => 'Calendar creation pending',
        'uncertain' => 'Outcome uncertain — Admin review required',
        'needs_review' => 'Admin review required',
        'delivered' => 'Synchronized',
        'sending' => 'Delivery pending',
        'reconciliation_required' => 'Booking changed — Admin review required',
        _ => 'Not synchronized',
      };
  Future<void> _sync(bool email) async {
    if (_booking.text.trim().isEmpty) {
      setState(
          () => _error = 'Enter the booking reference from Booking Details.');
      return;
    }
    if (!await _confirm(
        email ? 'Send booking confirmation?' : 'Synchronize this booking?',
        email
            ? 'Send one confirmation to the verified Member email for this paid, confirmed session. An uncertain previous attempt will not resend.'
            : 'Copy the current GainPath booking to its Coach calendar. A rescheduled session updates the event; a cancelled session removes it. GainPath remains authoritative.')) {
      return;
    }
    if (!mounted) return;
    await _act(() async => _label(
        await widget.actions.syncBooking(_booking.text.trim(), email: email)));
  }

  @override
  Widget build(BuildContext context) {
    final status = _status, enabled = !_busy && !widget.demo;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.sync_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text('Google Calendar & email',
                            style: Theme.of(context).textTheme.titleMedium)),
                    IconButton(
                        tooltip: 'Refresh Google status',
                        onPressed: _busy ? null : _load,
                        icon: const Icon(Icons.refresh))
                  ]),
                  const SizedBox(height: 8),
                  Text(widget.admin
                      ? 'One gym-owned Google account manages Coach calendars and booking emails.'
                      : 'Managed by your gym'),
                  const SizedBox(height: 8),
                  const Text(
                      'Availability and bookings stay in GainPath. Google Calendar is a synchronized copy.'),
                  if (widget.demo)
                    const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                            'Preview mode — external account actions are disabled.')),
                  if (_busy)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator()),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error))),
                  if (_message != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_message!)),
                  if (status != null) ...[
                    const SizedBox(height: 12),
                    Text('Gym connection: ${_label(status.connectionStatus)}'),
                    Text(status.automationEnabled
                        ? 'Automatic delivery: Enabled for approved test recipients'
                        : 'Automatic delivery: Disabled'),
                    if (['needs_review', 'email_needs_review']
                        .contains(status.automationStatus))
                      const Text(
                          'Automatic delivery needs Admin review. Check the delivery receipt before reconciliation; do not resend an uncertain email.'),
                    if (status.senderEmail != null)
                      Text('Booking sender: ${status.senderEmail}'),
                    if (status.revocationPending)
                      const Text(
                          'Local sync is stopped. Admin must check Google account permissions to finish revocation.'),
                    if (_coach != null) ...[
                      Text('Coach calendar: ${_label(status.calendarStatus)}'),
                      Text('Last sync: ${_label(status.syncStatus)}'),
                      Text('Email: ${_label(status.emailSyncStatus)}'),
                      if (status.lastSyncedAtMillis != null)
                        Text(
                            'Last successful sync: ${DateTime.fromMillisecondsSinceEpoch(status.lastSyncedAtMillis!).toLocal()}')
                    ],
                    if (!widget.admin)
                      const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                              'You do not need to connect a personal Google account. Contact Admin if synchronization needs attention.')),
                    if (widget.admin) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 12, runSpacing: 8, children: [
                        if (!status.connected &&
                            status.connectionStatus != 'connecting')
                          FilledButton.icon(
                              onPressed: enabled && !status.revocationPending
                                  ? _connect
                                  : null,
                              icon: const Icon(Icons.link),
                              label: const Text('Connect gym account')),
                        if (status.revocationPending)
                          OutlinedButton(
                              onPressed: enabled
                                  ? () async {
                                      if (await _confirm(
                                          'Confirm manual revocation?',
                                          'First remove GainPath access in the gym Google account permissions. Confirm only after doing so. This records your confirmation; GainPath cannot independently verify that manual action.')) {
                                        if (mounted) {
                                          await _act(() async {
                                            await widget.actions
                                                .acknowledgeRevocation();
                                            return 'Admin confirmed manual revocation. You can reconnect.';
                                          });
                                        }
                                      }
                                    }
                                  : null,
                              child: const Text('I revoked access in Google')),
                        if (status.connected ||
                            status.connectionStatus == 'connecting' ||
                            status.connectionStatus == 'needs_reconnect')
                          OutlinedButton(
                              onPressed: enabled
                                  ? () async {
                                      if (await _confirm(
                                          'Disconnect gym Google account?',
                                          'Stop Calendar and email synchronization for all Coaches. Existing GainPath bookings and Google calendars are kept.')) {
                                        if (mounted) {
                                          await _act(() async {
                                            await widget.actions.disconnect();
                                            _authorizationUrl = null;
                                            return 'Gym Google account disconnected.';
                                          });
                                        }
                                      }
                                    }
                                  : null,
                              child: const Text('Disconnect')),
                      ]),
                      if (_authorizationUrl != null) ...[
                        const SizedBox(height: 12),
                        if (widget.openAuthorization != null)
                          FilledButton(
                              onPressed: enabled
                                  ? () async {
                                      final opened =
                                          await widget.openAuthorization!(
                                              Uri.parse(_authorizationUrl!));
                                      if (!opened && mounted) {
                                        setState(() => _error =
                                            'Could not open Google. Copy the connection link into your browser.');
                                      }
                                    }
                                  : null,
                              child: const Text('Continue in Google')),
                        const Text('Connection link (valid for 10 minutes):'),
                        SelectableText(_authorizationUrl!),
                      ],
                      if (status.connected) ...[
                        const Divider(height: 32),
                        Text('Coach calendar',
                            style: Theme.of(context).textTheme.titleSmall),
                        if (_coaches.isEmpty)
                          const Text(
                              'No published Coaches are available. Refresh after publication.'),
                        if (_coaches.isNotEmpty)
                          DropdownButtonFormField<String>(
                              initialValue: _coach,
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(labelText: 'Coach'),
                              items: _coaches.entries
                                  .map((e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value,
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: enabled
                                  ? (value) {
                                      setState(() => _coach = value);
                                      _load();
                                    }
                                  : null),
                        const SizedBox(height: 8),
                        OutlinedButton(
                            onPressed: enabled &&
                                    _coach != null &&
                                    status.calendarStatus == 'not_created'
                                ? () async {
                                    if (await _confirm('Create Coach calendar?',
                                        'Create one secondary calendar owned by the gym Google account for this Coach.')) {
                                      if (mounted) {
                                        await _act(() async {
                                          await widget.actions
                                              .createCoachCalendar(_coach!);
                                          return 'Coach calendar created.';
                                        });
                                      }
                                    }
                                  }
                                : null,
                            child: const Text('Create Coach calendar')),
                        const Divider(height: 32),
                        Text('Booking delivery',
                            style: Theme.of(context).textTheme.titleSmall),
                        Text(status.automationEnabled
                            ? 'Confirmed paid bookings, reschedules and cancellations synchronize automatically for approved test recipients. Use manual Calendar reconciliation only when needed.'
                            : 'After confirmation, rescheduling or cancellation, reconcile the current booking here. No automatic background delivery is enabled.'),
                        const SizedBox(height: 12),
                        TextField(
                            controller: _booking,
                            enabled: enabled,
                            decoration: const InputDecoration(
                                labelText: 'Booking reference',
                                helperText:
                                    'Use the reference from Booking Details.')),
                        const SizedBox(height: 12),
                        Wrap(spacing: 12, runSpacing: 8, children: [
                          OutlinedButton(
                              onPressed: enabled ? () => _sync(false) : null,
                              child: const Text('Sync Calendar')),
                          FilledButton(
                              onPressed: enabled ? () => _sync(true) : null,
                              child: const Text('Send confirmation email'))
                        ]),
                      ],
                    ],
                  ],
                ])));
  }
}
