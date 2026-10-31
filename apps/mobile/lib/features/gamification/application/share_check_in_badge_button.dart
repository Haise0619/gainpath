import 'package:flutter/material.dart';
import '../../../infrastructure/platform/achievement_share.dart';
import '../domain/app_check_in.dart';

class ShareCheckInBadgeButton extends StatefulWidget {
  const ShareCheckInBadgeButton({super.key, required this.badge});
  final AppCheckInBadge badge;
  @override
  State<ShareCheckInBadgeButton> createState() =>
      _ShareCheckInBadgeButtonState();
}

class _ShareCheckInBadgeButtonState extends State<ShareCheckInBadgeButton> {
  bool _busy = false;
  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await NativeAchievementShare().badge(widget.badge);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sharing is unavailable. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.badge.unlockedAtMillis == null
      ? const SizedBox.shrink()
      : TextButton.icon(
          onPressed: _busy ? null : _share,
          icon: const Icon(Icons.share_outlined),
          label: Text(_busy ? 'Opening…' : 'Share badge'));
}
