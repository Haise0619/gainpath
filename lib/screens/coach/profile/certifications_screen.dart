import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M8.3 — Upload & Manage Certification Documents. Reads and writes the
/// live `MockData.coachCertifications` list: "upload" appends a real
/// Pending entry (simulating a file pick) that immediately shows in the
/// list and bumps the count on the account hub. Verified / Pending /
/// Rejected each render distinctly, and a rejected doc surfaces its
/// reason so the coach knows what to fix.
class CertificationsScreen extends StatefulWidget {
  const CertificationsScreen({super.key});

  @override
  State<CertificationsScreen> createState() => _CertificationsScreenState();
}

class _CertificationsScreenState extends State<CertificationsScreen> {
  static const _sampleNames = [
    'CrossFit Level 1 Trainer',
    'Precision Nutrition L1',
    'Kettlebell Instructor Cert',
    'TRX Suspension Training',
    'Olympic Weightlifting Cert',
  ];

  void _upload() {
    // Stands in for a real file picker: pick the next sample name not
    // already in the list, add it as Pending review.
    final existing = MockData.coachCertifications.map((c) => c.name).toSet();
    final next = _sampleNames.firstWhere((n) => !existing.contains(n),
        orElse: () => 'New Certificate ${MockData.coachCertifications.length + 1}');
    setState(() {
      MockData.coachCertifications.add(
        CoachCertification(next, 'Pending review', DateTime.now()),
      );
    });
    showToast(context, 'Uploaded. Gym staff will review it shortly.');
  }

  @override
  Widget build(BuildContext context) {
    final certs = MockData.coachCertifications;
    return Scaffold(
      appBar: AppBar(title: const Text('Certifications')),
      body: PageBody(
        children: [
          Panel(
            background: AppColors.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Verified credentials build member trust. New uploads stay hidden from '
                    'members until gym staff have checked them.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...certs.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CertCard(cert: c),
              )),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _upload,
              icon: const Icon(Icons.upload_file_rounded, size: 19),
              label: const Text('Upload a certificate'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertCard extends StatelessWidget {
  final CoachCertification cert;
  const _CertCard({required this.cert});

  @override
  Widget build(BuildContext context) {
    final rejected = cert.status == 'Rejected';
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  rejected ? Icons.error_outline_rounded : Icons.description_outlined,
                  size: 19,
                  color: rejected ? AppColors.danger : AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cert.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('Uploaded ${_ago(cert.uploadedAt)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                  ],
                ),
              ),
              statusPill(cert.status),
            ],
          ),
          if (rejected && cert.rejectionReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.dangerTint, borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(cert.rejectionReason!,
                        style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.danger)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _ago(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 30) return '$days days ago';
    final months = (days / 30).floor();
    return '$months month${months == 1 ? '' : 's'} ago';
  }
}
