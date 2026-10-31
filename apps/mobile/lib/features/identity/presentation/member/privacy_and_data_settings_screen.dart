import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Hosts member privacy controls, specifically posture and camera data sharing
/// under Profile > Settings > Privacy & Data > Posture & Camera Data.
class PrivacyAndDataSettingsScreen extends StatefulWidget {
  const PrivacyAndDataSettingsScreen({
    super.key,
    this.repository,
    required this.isCurrent,
  });

  final Module9Repository? repository;
  final bool Function() isCurrent;

  @override
  State<PrivacyAndDataSettingsScreen> createState() =>
      _PrivacyAndDataSettingsScreenState();
}

class _PrivacyAndDataSettingsScreenState
    extends State<PrivacyAndDataSettingsScreen> {
  CoachSharing? _sharing;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _current => mounted && widget.isCurrent();

  Future<void> _load() async {
    if (!_current) return;
    if (widget.repository == null) {
      setState(() {
        _sharing = const CoachSharing(false, 0);
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.repository!.loadSharing();
      if (!_current) return;
      setState(() {
        _sharing = result;
        _loading = false;
      });
    } catch (_) {
      if (_current) {
        setState(() {
          _error = 'Could not load privacy settings. Please retry.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _setSharing(bool enabled) async {
    if (!_current || _saving || _sharing == null) return;
    if (widget.repository == null) {
      setState(() {
        _sharing = CoachSharing(enabled, _sharing!.revision + 1);
      });
      return;
    }
    setState(() => _saving = true);
    try {
      final result =
          await widget.repository!.saveSharing(enabled, _sharing!.revision);
      if (_current) {
        setState(() => _sharing = result);
      }
    } catch (_) {
      if (_current) {
        showToast(context,
            'Could not verify this change. Reload before trying again.');
        await _load();
      }
    } finally {
      if (_current) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent()) {
      return const Scaffold(
        body: Center(child: Text('Session changed. Return to sign in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Data'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading || _saving ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Eyebrow('Posture & Camera Data'),
            const SizedBox(height: 8),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your posture privacy',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Allow your assigned Coaches to view uploaded workout form scores and session dates. This does not upload workouts or share camera footage. You can turn access off at any time.',
                  ),
                  const SizedBox(height: 12),
                  if (_loading)
                    const LinearProgressIndicator()
                  else if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ] else ...[
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Share posture history with my Coaches'),
                      value: _sharing?.enabled ?? false,
                      onChanged: _sharing == null || _saving || _loading
                          ? null
                          : _setSharing,
                    ),
                    if (_saving) const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Eyebrow('Data Protection'),
            const SizedBox(height: 8),
            const Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device-Only Camera Processing',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Pose estimation executes in real time on your device hardware. Camera video frames are never saved to cloud storage or transmitted over the network without explicit consent.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
