import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class CoachAccountData {
  const CoachAccountData(
      {required this.name,
      required this.specialty,
      this.photo,
      this.verified = false,
      this.published = false,
      required this.directoryLabel,
      this.branch,
      this.rating,
      this.sessions,
      this.experience,
      this.reviews,
      this.approvedCertifications,
      this.pendingCertifications,
      this.publicationMessage,
      this.publicationStatus,
      this.bio,
      this.tags = const [],
      this.fee});
  final String name, specialty, directoryLabel;
  final String? branch,
      rating,
      sessions,
      experience,
      reviews,
      publicationMessage,
      publicationStatus,
      bio,
      fee;
  final ImageProvider? photo;
  final bool verified, published;
  final int? approvedCertifications, pendingCertifications;
  final List<String> tags;
}

class CoachAccountPresentation extends StatelessWidget {
  const CoachAccountPresentation(
      {super.key,
      required this.data,
      required this.onSignOut,
      this.onPreview,
      this.onEdit,
      this.onCertifications,
      this.onPhoto,
      this.onSettings,
      this.onRefresh,
      this.loading = false,
      this.message});
  final CoachAccountData data;
  final VoidCallback onSignOut;
  final VoidCallback? onPreview,
      onEdit,
      onCertifications,
      onPhoto,
      onSettings,
      onRefresh;
  final bool loading;
  final String? message;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My account'), actions: [
        if (onRefresh != null)
          IconButton(
              tooltip: 'Refresh profile',
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh))
      ]),
      body: PageBody(
        children: [
          if (loading) const LinearProgressIndicator(),
          if (message != null) Text(message!),
          CoachProfessionalHeader(data: data),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: StatTile(data.rating ?? '-', 'Rating',
                      valueColor: AppColors.accent)),
              const SizedBox(width: 10),
              Expanded(child: StatTile(data.sessions ?? '-', 'Sessions')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(data.experience ?? '-', 'Experience')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: onPreview,
              icon: const Icon(Icons.visibility_outlined, size: 19),
              label: const Text('Preview public profile'),
            ),
          ),
          const SizedBox(height: 22),
          const Eyebrow('Professional profile'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(
                  context,
                  Icons.edit_note_rounded,
                  'Bio & specialties',
                  'What members see in the directory',
                  onEdit,
                ),
                const Divider(height: 1, indent: 62),
                _row(
                  context,
                  Icons.workspace_premium_rounded,
                  'Certifications',
                  '${data.approvedCertifications ?? '-'} verified${data.pendingCertifications == null ? ', - pending review' : data.pendingCertifications! > 0 ? ', ${data.pendingCertifications} pending review' : ''}',
                  onCertifications,
                ),
                const Divider(height: 1, indent: 62),
                _row(
                  context,
                  Icons.photo_camera_rounded,
                  'Profile photo',
                  'Update your directory picture',
                  onPhoto,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Account'),
          Panel(
            padding: EdgeInsets.zero,
            child: _row(
              context,
              Icons.settings_outlined,
              'Settings',
              'Contact details, notifications, security',
              onSettings,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 19),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 20),
          CoachProfessionalDetails(data: data),
          if (data.publicationStatus != null ||
              data.publicationMessage != null) ...[
            const SizedBox(height: 16),
            Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  if (data.publicationStatus != null)
                    Text(data.publicationStatus!),
                  if (data.publicationMessage != null)
                    Text(data.publicationMessage!)
                ]))
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback? onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: AppColors.primary),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle,
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
    );
  }
}

class CoachProfessionalHeader extends StatelessWidget {
  final CoachAccountData data;
  const CoachProfessionalHeader({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('coach-professional-header'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                    width: 68,
                    height: 68,
                    child: data.photo == null
                        ? const Icon(Icons.person,
                            color: Colors.white70, size: 36)
                        : Image(
                            image: data.photo!,
                            gaplessPlayback: false,
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stack) => const Icon(
                                Icons.person,
                                color: Colors.white70,
                                size: 36))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(data.name,
                              style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                        if (data.verified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded,
                              size: 18, color: Colors.white),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(data.specialty,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13.5)),
                    const SizedBox(height: 3),
                    Text(data.branch ?? '-',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color:
                          data.published ? AppColors.success : AppColors.accent,
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(data.directoryLabel,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5)),
                ),
                Text('${data.reviews ?? '-'} reviews',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CoachProfessionalDetails extends StatelessWidget {
  const CoachProfessionalDetails({super.key, required this.data});
  final CoachAccountData data;
  @override
  Widget build(BuildContext context) => Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('Professional details'),
        const SizedBox(height: 8),
        Text(data.bio?.trim().isNotEmpty == true ? data.bio! : '-'),
        if (data.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [for (final tag in data.tags) Chip(label: Text(tag))])
        ] else ...[
          const SizedBox(height: 8),
          const Text('-')
        ],
        const SizedBox(height: 8),
        Text('Consultation fee: ${data.fee ?? '-'}'),
      ]));
}

/// Owner-only preview reuses the same card and fields as the account hub.
class CoachAccountProfilePreview extends StatelessWidget {
  const CoachAccountProfilePreview(
      {super.key, required this.data, required this.label, this.draft});
  final CoachAccountData data;
  final String label;
  final CoachAccountData? draft;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Profile preview')),
      body: PageBody(children: [
        Text(label),
        const SizedBox(height: 12),
        CoachProfessionalHeader(data: data),
        const SizedBox(height: 16),
        CoachProfessionalDetails(data: data),
        if (draft != null) ...[
          const SizedBox(height: 20),
          const Text('Owner draft preview — pending Admin publication'),
          const SizedBox(height: 12),
          CoachProfessionalHeader(data: draft!),
          const SizedBox(height: 16),
          CoachProfessionalDetails(data: draft!)
        ],
      ]));
}
