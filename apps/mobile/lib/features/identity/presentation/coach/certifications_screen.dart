import 'coach_unsaved_changes_guard.dart';
import 'coach_account_session_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/coach_account_gateway.dart';
import '../../../../infrastructure/local/coach_certification_picker.dart';

/// Canonical certification management for every data source.
class CertificationsScreen extends StatefulWidget {
  const CertificationsScreen(
      {super.key, required this.repository, this.pickEvidence});
  final CoachAccountGateway repository;
  final Future<CoachCertificationFile?> Function()? pickEvidence;
  @override
  State<CertificationsScreen> createState() => _CertificationsScreenState();
}

class _CertificationsScreenState extends State<CertificationsScreen> {
  final title = TextEditingController(), issuer = TextEditingController();
  List<PrivateCoachCertification> certifications = [];
  CoachCertificationFile? selected;
  String? message, uploadId, uploadedPath, submitRequest;
  bool busy = false;
  bool get current => mounted && widget.repository.isCurrent();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    selected = null;
    certifications = [];
    title.dispose();
    issuer.dispose();
    super.dispose();
  }

  Future<void> load() => run(() async {
        final result = await widget.repository.loadCertifications();
        if (current) setState(() => certifications = result);
      });

  Future<void> run(Future<void> Function() action) async {
    if (busy || !current) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      widget.repository.check();
      await action();
    } on FormatException catch (e) {
      if (current) setState(() => message = e.message.toString());
    } on CoachRepositoryException catch (e) {
      if (current) setState(() => message = e.message);
    } catch (_) {
      if (current) {
        setState(() =>
            message = 'Could not complete the operation. Retry or refresh.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() => run(() async {
        if (title.text.trim().isEmpty ||
            issuer.text.trim().isEmpty ||
            selected == null) {
          throw const FormatException(
              'Enter a title and issuer, and select evidence.');
        }
        uploadId ??= newCoachRequestId();
        submitRequest ??= newCoachRequestId();
        uploadedPath ??= await widget.repository.upload('coachCertifications',
            uploadId!, selected!.bytes, selected!.contentType);
        if (!current) return;
        widget.repository.check();
        await widget.repository.submitCertification(
            uploadId!,
            title.text.trim(),
            issuer.text.trim(),
            uploadedPath!,
            submitRequest!);
        final result = await widget.repository.loadCertifications();
        if (current) {
          setState(() {
            certifications = result;
            selected = null;
            uploadId = uploadedPath = submitRequest = null;
            title.clear();
            issuer.clear();
            message = 'Submitted for Admin review.';
          });
        }
      });

  Future<void> view(PrivateCoachCertification cert) => run(() async {
        final detail = await widget.repository.loadCertificationDetail(cert.id);
        final currentCert = detail.certification;
        final bytes = await widget.repository.read(currentCert.storagePath);
        final file = CoachCertificationFile(bytes);
        List<Uint8List> pages = [];
        try {
          if (file.contentType == 'application/pdf') {
            pages = await const MethodChannel('gainpath/private_pdf')
                    .invokeListMethod<Uint8List>('render', bytes) ??
                [];
          } else {
            pages = [bytes];
          }
          widget.repository.check();
          if (!current) return;
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => CoachAccountSessionGuard(
                      repository: widget.repository,
                      child: Scaffold(
                          appBar: AppBar(title: Text(currentCert.title)),
                          body: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.hairline),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Status',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14),
                                        ),
                                        statusPill(coachCertificationStatus(
                                            currentCert.status)),
                                      ],
                                    ),
                                    if (currentCert.reason != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.dangerTint,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Review reason: ${currentCert.reason}',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.danger),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (detail.history.isNotEmpty) ...[
                                const Text('Review History',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
                                const SizedBox(height: 8),
                                for (final event in detail.history)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 6),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(_historyText(event),
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              color: AppColors.inkSoft)),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                              ],
                              const Text('Document Evidence',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              const SizedBox(height: 8),
                              if (pages.isEmpty)
                                const ContainerWithBorder(
                                  child: Text(
                                      'PDF preview is unavailable on this platform. Evidence remains privately stored.'),
                                ),
                              for (final page in pages)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: AppColors.hairline),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      page,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, error, stack) =>
                                          const Padding(
                                        padding: EdgeInsets.all(24),
                                        child: Text(
                                            'Evidence preview is unavailable.'),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )))));
        } finally {
          for (final page in pages) {
            await MemoryImage(page).evict();
          }
          pages.clear();
        }
      });

  String _historyText(Map<String, dynamic> event) {
    final status = coachCertificationStatus(
            event['status'] is String ? event['status'] as String : ''),
        at = event['updatedAtMillis'] ??
            event['atMillis'] ??
            event['createdAtMillis'];
    return '$status · ${_date(at)}${event['actorId'] is String ? '\nReviewed or submitted by ${event['actorId']}' : ''}${event['reason'] is String ? '\n${event['reason']}' : ''}';
  }

  Future<void> archive(PrivateCoachCertification cert) async {
    final confirmed = await confirmSheet(context,
        title: 'Archive certification?',
        message:
            'Remove this reference from active credentials. Evidence and review history remain retained for audit.',
        confirmLabel: 'Archive',
        destructive: true);
    if (!confirmed || !current) return;
    await run(() async {
      await widget.repository.archive(cert, newCoachRequestId());
      final result = await widget.repository.loadCertifications();
      if (current) setState(() => certifications = result);
    });
  }

  @override
  Widget build(BuildContext context) => CoachUnsavedChangesGuard(
      dirty:
          title.text.isNotEmpty || issuer.text.isNotEmpty || selected != null,
      busy: busy,
      isCurrent: widget.repository.isCurrent,
      child: Scaffold(
          appBar: AppBar(title: const Text('Certifications'), actions: [
            IconButton(
                tooltip: 'Refresh certifications',
                onPressed: busy ? null : load,
                icon: const Icon(Icons.refresh))
          ]),
          body: RefreshIndicator(
            onRefresh: load,
            color: AppColors.primary,
            child: PageBody(children: [
              // Notice Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shield_outlined,
                          size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verified Credentials',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Verified credentials build member trust. New uploads stay hidden from members until gym staff have checked them. Evidence is private to you and authorized Admins.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 12.5,
                                  color: AppColors.inkSoft,
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (busy) const LinearProgressIndicator(),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message == 'Submitted for Admin review.'
                          ? AppColors.successTint
                          : AppColors.dangerTint,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: message == 'Submitted for Admin review.'
                            ? AppColors.success.withValues(alpha: 0.3)
                            : AppColors.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          message == 'Submitted for Admin review.'
                              ? Icons.check_circle_outline_rounded
                              : Icons.info_outline_rounded,
                          size: 18,
                          color: message == 'Submitted for Admin review.'
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: message == 'Submitted for Admin review.'
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!busy && certifications.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.workspace_premium_outlined,
                            size: 40, color: AppColors.inkSoft),
                        SizedBox(height: 8),
                        Text(
                          'No certifications yet. Upload evidence for Admin review.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ),
              for (final cert in certifications)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CertCard(
                    cert: cert,
                    onView: busy ? null : () => view(cert),
                    onArchive: busy || cert.status == 'archived'
                        ? null
                        : () => archive(cert),
                  ),
                ),
              if (widget.repository.certificationCursor != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                              final result = await widget.repository
                                  .loadCertifications(
                                      afterId:
                                          widget.repository.certificationCursor);
                              if (current) {
                                setState(() => certifications = [
                                      ...certifications,
                                      ...result
                                    ]);
                              }
                            }),
                    child: const Text('Load more certifications'),
                  ),
                ),
              const SizedBox(height: 6),
              // Upload Form Card
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.cloud_upload_outlined,
                              size: 18, color: AppColors.primary),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(child: Eyebrow('Upload certification')),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: title,
                      onChanged: (_) => setState(() {}),
                      enabled: !busy && uploadedPath == null,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: 'Certification title',
                        prefixIcon: const Icon(Icons.card_membership_rounded,
                            size: 18, color: AppColors.inkSoft),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: issuer,
                      onChanged: (_) => setState(() {}),
                      enabled: !busy && uploadedPath == null,
                      maxLength: 120,
                      decoration: InputDecoration(
                        labelText: 'Issuing organization',
                        prefixIcon: const Icon(Icons.business_rounded,
                            size: 18, color: AppColors.inkSoft),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected == null
                            ? AppColors.surfaceAlt
                            : AppColors.successTint.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected == null
                              ? AppColors.hairline
                              : AppColors.success.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                backgroundColor: AppColors.surface,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: busy
                                  ? null
                                  : () => run(() async {
                                        final file =
                                            await (widget.pickEvidence ??
                                                pickCoachCertification)();
                                        widget.repository.check();
                                        if (file != null && current) {
                                          setState(() {
                                            selected = file;
                                            uploadId = uploadedPath =
                                                submitRequest = null;
                                          });
                                        }
                                      }),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      selected == null
                                          ? Icons.upload_file_rounded
                                          : Icons.check_circle_outline_rounded,
                                      size: 20,
                                      color: selected == null
                                          ? AppColors.primary
                                          : AppColors.success,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      selected == null
                                          ? 'Upload a certificate'
                                          : 'Evidence selected · ${(selected!.bytes.length / 1024).ceil()} KB',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: selected == null
                                            ? AppColors.primary
                                            : AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'PDF, JPEG or PNG · up to 5 MB',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.inkSoft),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed:
                            busy || selected == null ? null : submit,
                        child: busy
                            ? const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Submitting…'),
                                  ],
                                ),
                              )
                            : const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Submit for review',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          )));
}

String _date(Object? value) {
  if (value is! int || value <= 0 || value > 8640000000000000) {
    return 'Date unavailable';
  }
  final date = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class ContainerWithBorder extends StatelessWidget {
  const ContainerWithBorder({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.hairline),
        ),
        child: child,
      );
}

class _CertCard extends StatelessWidget {
  const _CertCard({required this.cert, this.onView, this.onArchive});
  final PrivateCoachCertification cert;
  final VoidCallback? onView, onArchive;
  @override
  Widget build(BuildContext context) {
    final rejected = cert.status == 'rejected';
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: rejected ? AppColors.dangerTint : AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  rejected
                      ? Icons.error_outline_rounded
                      : Icons.workspace_premium_outlined,
                  size: 20,
                  color: rejected ? AppColors.danger : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cert.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${cert.issuer}\nUploaded ${_date(cert.createdAtMillis)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 12.5,
                            color: AppColors.inkSoft,
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 8),
                    statusPill(coachCertificationStatus(cert.status)),
                  ],
                ),
              ),
            ],
          ),
          if (rejected && cert.reason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerTint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cert.reason!,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: constraints.maxWidth),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        side: const BorderSide(color: AppColors.hairline),
                      ),
                      onPressed: onView,
                      child: const Text(
                        'View private evidence',
                        style: TextStyle(fontSize: 12.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (cert.status != 'archived')
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.inkSoft,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                      onPressed: onArchive,
                      child: const Text('Archive',
                          style: TextStyle(fontSize: 12.5)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
