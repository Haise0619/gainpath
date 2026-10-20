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
                          body: ListView(children: [
                            Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                    'Status: ${coachCertificationStatus(currentCert.status)}${currentCert.reason == null ? '' : '\nReview reason: ${currentCert.reason}'}')),
                            for (final event in detail.history)
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  child: Text(_historyText(event))),
                            if (pages.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                      'PDF preview is unavailable on this platform. Evidence remains privately stored.')),
                            for (final page in pages)
                              Image.memory(page,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, error, stack) => const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                          'Evidence preview is unavailable.'))),
                          ])))));
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
          body: PageBody(children: [
            Panel(
                background: AppColors.surfaceAlt,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              'Verified credentials build member trust. New uploads stay hidden from members until gym staff have checked them. Evidence is private to you and authorized Admins.',
                              style: Theme.of(context).textTheme.bodyMedium)),
                    ])),
            const SizedBox(height: 16),
            if (busy) const LinearProgressIndicator(),
            if (message != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(message!)),
            if (!busy && certifications.isEmpty)
              const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                      'No certifications yet. Upload evidence for Admin review.')),
            for (final cert in certifications)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CertCard(
                      cert: cert,
                      onView: busy ? null : () => view(cert),
                      onArchive: busy || cert.status == 'archived'
                          ? null
                          : () => archive(cert))),
            if (widget.repository.certificationCursor != null)
              TextButton(
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
                  child: const Text('Load more certifications')),
            const SizedBox(height: 6),
            Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Eyebrow('Upload certification'),
                  const SizedBox(height: 12),
                  TextField(
                      controller: title,
                      onChanged: (_) => setState(() {}),
                      enabled: !busy && uploadedPath == null,
                      maxLength: 120,
                      decoration: const InputDecoration(
                          labelText: 'Certification title')),
                  TextField(
                      controller: issuer,
                      onChanged: (_) => setState(() {}),
                      enabled: !busy && uploadedPath == null,
                      maxLength: 120,
                      decoration: const InputDecoration(
                          labelText: 'Issuing organization')),
                  SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48)),
                          onPressed: busy
                              ? null
                              : () => run(() async {
                                    final file = await (widget.pickEvidence ??
                                        pickCoachCertification)();
                                    widget.repository.check();
                                    if (file != null && current) {
                                      setState(() {
                                        selected = file;
                                        uploadId =
                                            uploadedPath = submitRequest = null;
                                      });
                                    }
                                  }),
                          icon: const Icon(Icons.upload_file_rounded, size: 19),
                          label: Text(selected == null
                              ? 'Upload a certificate'
                              : 'Evidence selected · ${(selected!.bytes.length / 1024).ceil()} KB'))),
                  const Text('PDF, JPEG or PNG · up to 5 MB'),
                  FilledButton(
                      onPressed: busy || selected == null ? null : submit,
                      child: const Text('Submit for review')),
                ])),
          ])));
}

String _date(Object? value) {
  if (value is! int || value <= 0 || value > 8640000000000000) {
    return 'Date unavailable';
  }
  final date = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _CertCard extends StatelessWidget {
  const _CertCard({required this.cert, this.onView, this.onArchive});
  final PrivateCoachCertification cert;
  final VoidCallback? onView, onArchive;
  @override
  Widget build(BuildContext context) {
    final rejected = cert.status == 'rejected';
    return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(11)),
            child: Icon(
                rejected
                    ? Icons.error_outline_rounded
                    : Icons.description_outlined,
                size: 19,
                color: rejected ? AppColors.danger : AppColors.primary)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(cert.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text('${cert.issuer}\nUploaded ${_date(cert.createdAtMillis)}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 12.5))
        ])),
        const SizedBox(width: 8),
        Flexible(child: statusPill(coachCertificationStatus(cert.status))),
      ]),
      if (rejected && cert.reason != null) ...[
        const SizedBox(height: 12),
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.dangerTint,
                borderRadius: BorderRadius.circular(10)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(cert.reason!,
                      style: const TextStyle(
                          fontSize: 13, height: 1.4, color: AppColors.danger)))
            ]))
      ],
      Wrap(spacing: 8, children: [
        TextButton(
            onPressed: onView, child: const Text('View private evidence')),
        if (cert.status != 'archived')
          TextButton(onPressed: onArchive, child: const Text('Archive'))
      ]),
    ]));
  }
}
