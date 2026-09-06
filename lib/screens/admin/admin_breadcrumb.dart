import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// One segment of an in-page breadcrumb — the local counterpart to the
/// shell-level `Home > Section` trail in the top bar, for a second drill
/// -down level a page manages itself (e.g. a list ↔ full-page create/edit
/// form), such as "Exercise Tutorials › Create Tutorial". `onTap` is null
/// for the current (last) segment.
class PageCrumb {
  final String label;
  final VoidCallback? onTap;
  const PageCrumb(this.label, [this.onTap]);
}

/// Renders a row of [PageCrumb]s — used at the top of a full-page
/// create/edit view so the admin always sees where they are and can
/// click back up the chain instead of relying on a browser back button.
class PageBreadcrumb extends StatelessWidget {
  final List<PageCrumb> crumbs;
  const PageBreadcrumb({super.key, required this.crumbs});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < crumbs.length; i++) ...[
          if (i > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.inkSoft),
            ),
          _Segment(crumb: crumbs[i]),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  final PageCrumb crumb;
  const _Segment({required this.crumb});

  @override
  Widget build(BuildContext context) {
    final current = crumb.onTap == null;
    final text = Text(
      crumb.label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: current ? FontWeight.w700 : FontWeight.w600,
        color: current ? AppColors.ink : AppColors.primary,
      ),
    );
    if (current) return text;
    return InkWell(borderRadius: BorderRadius.circular(6), onTap: crumb.onTap, child: text);
  }
}
