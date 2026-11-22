import 'package:flutter/material.dart';

import '../../tokens/app_theme.dart';
import 'panel.dart';

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.title,
    required this.message,
    required this.caption,
    this.icon = Icons.campaign_outlined,
    this.important = false,
    this.warmAccent = false,
    this.onReadMore,
  });

  final String title;
  final String message;
  final String caption;
  final IconData icon;
  final bool important;
  final bool warmAccent;
  final VoidCallback? onReadMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent =
        important || warmAccent ? AppColors.warning : theme.colorScheme.primary;
    return Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (important)
                  Text('Important',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: AppColors.accentDark)),
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(message, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(caption,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12)),
                if (onReadMore != null)
                  TextButton(
                    onPressed: onReadMore,
                    child: const Text('Read more'),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Read more',
                        style: TextStyle(color: theme.colorScheme.primary)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
