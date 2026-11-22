import 'package:flutter/material.dart';
import '../../tokens/app_theme.dart';

/// Modal bottom sheet allowing gym members to quickly switch their active
/// selected gym branch, view their home branch, or navigate to full discovery.
class GymBranchSwitcherSheet extends StatelessWidget {
  const GymBranchSwitcherSheet({
    super.key,
    required this.branches,
    this.selectedBranchId,
    this.homeBranchId,
    required this.onSelectBranch,
    required this.onExploreAll,
  });

  final List<Map<String, dynamic>> branches;
  final String? selectedBranchId;
  final String? homeBranchId;
  final ValueChanged<String> onSelectBranch;
  final VoidCallback onExploreAll;

  @override
  Widget build(BuildContext context) {
    final activeBranches = branches
        .where((b) => b['status'] == null || b['status'] == 'active')
        .toList();
    final inactiveBranches = branches
        .where((b) => b['status'] != null && b['status'] != 'active')
        .toList();
    final allDisplayBranches = [...activeBranches, ...inactiveBranches];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose your gym',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: AppColors.ink,
                              ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Select the gym you want to use.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.hairline),

            // Branch List
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.52,
              ),
              child: allDisplayBranches.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      child: Center(
                        child: Text(
                          'No gym branches are currently available.',
                          style: TextStyle(color: AppColors.inkSoft),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: allDisplayBranches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final branch = allDisplayBranches[index];
                        final id = branch['branchId'] as String? ?? '';
                        final name =
                            branch['displayName'] as String? ?? 'GainPath Gym';
                        final address = branch['address'] as String? ?? '';
                        final coverUrl = branch['coverUrl'] as String?;
                        final isSelected = id == selectedBranchId;
                        final isHome = id == homeBranchId;
                        final isActive = branch['status'] != 'inactive';

                        return Material(
                          color: isSelected
                              ? AppColors.primaryTint.withValues(alpha: 0.5)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: isActive ? () => onSelectBranch(id) : null,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.hairline,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Thumbnail
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: coverUrl != null &&
                                              coverUrl.isNotEmpty
                                          ? Image.network(
                                              coverUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stack) =>
                                                      _thumbnailFallback(),
                                            )
                                          : _thumbnailFallback(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14.5,
                                                  color: isActive
                                                      ? AppColors.ink
                                                      : AppColors.inkSoft,
                                                ),
                                              ),
                                            ),
                                            if (isHome) ...[
                                              const SizedBox(width: 6),
                                              _pillBadge(
                                                'Home',
                                                AppColors.primary,
                                                AppColors.primaryTint,
                                              ),
                                            ],
                                            if (!isActive) ...[
                                              const SizedBox(width: 6),
                                              _pillBadge(
                                                'Closed',
                                                AppColors.danger,
                                                AppColors.dangerTint,
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (address.isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.inkSoft,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Checkmark indicator
                                  if (isSelected)
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.hairline,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const Divider(height: 1, color: AppColors.hairline),

            // Bottom action: Explore All Gyms
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: OutlinedButton.icon(
                onPressed: onExploreAll,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primarySoft),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 48),
                ),
                icon: const Icon(Icons.explore_outlined, size: 19),
                label: const Text(
                  'Explore All Gyms',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnailFallback() {
    return Container(
      color: AppColors.primaryTint,
      child: const Center(
        child: Icon(
          Icons.fitness_center_rounded,
          size: 22,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _pillBadge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
