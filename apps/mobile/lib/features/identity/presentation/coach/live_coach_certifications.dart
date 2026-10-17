import 'coach_unsaved_changes_guard.dart';
import 'coach_account_session_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../infrastructure/firebase/firebase_coach_account_repository.dart';
import '../../../../infrastructure/local/coach_certification_picker.dart';

class LiveCoachCertifications extends StatefulWidget {
  const LiveCoachCertifications({super.key, required this.repository});
  final FirebaseCoachAccountRepository repository;
  @override
  State<LiveCoachCertifications> createState() =>
      _LiveCoachCertificationsState();
}

class _LiveCoachCertificationsState extends State<LiveCoachCertifications> {
  final title = TextEditingController(), issuer = TextEditingController();
  List<PrivateCoachCertification> certifications = [];
  CoachCertificationFile? selected;
  String? message, uploadId, uploadedPath, submitRequest;
  bool busy = false;
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

  Future<void> load() async {
    await run(() async {
      final result = await widget.repository.loadCertifications();
      if (mounted) setState(() => certifications = result);
    });
  }

  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } on FormatException catch (e) {
      if (mounted) setState(() => message = e.message.toString());
    } on CoachRepositoryException catch (e) {
      if (mounted) setState(() => message = e.message);
    } catch (_) {
      if (mounted) {
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
        uploadId ??= FirebaseCoachAccountRepository.randomId();
        submitRequest ??= FirebaseCoachAccountRepository.randomId();
        uploadedPath ??= await widget.repository.upload('coachCertifications',
            uploadId!, selected!.bytes, selected!.contentType);
        if (!mounted) return;
        await widget.repository.submitCertification(
            uploadId!,
            title.text.trim(),
            issuer.text.trim(),
            uploadedPath!,
            submitRequest!);
        final result = await widget.repository.loadCertifications();
        if (mounted) {
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
        final detail = await widget.repository.command(
            'getCoachCertificationsCommand', {'certificationId': cert.id});
        final selectedDetail =
            ((detail['certifications'] as List?)?.firstOrNull as Map?);
        final history = selectedDetail?['history'] as List? ?? [];
        final current = selectedDetail == null
            ? cert
            : PrivateCoachCertification.fromJson(
                Map<String, dynamic>.from(selectedDetail));
        final bytes = await widget.repository.read(current.storagePath);
        final file = CoachCertificationFile(bytes);
        List<Uint8List> pages = [];
        if (file.contentType == 'application/pdf') {
          final result = await const MethodChannel('gainpath/private_pdf')
              .invokeListMethod<Uint8List>('render', bytes);
          pages = result ?? [];
        } else {
          pages = [bytes];
        }
        widget.repository.check();
        if (!mounted) return;
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CoachAccountSessionGuard(
                    repository: widget.repository,
                    child: Scaffold(
                        appBar: AppBar(title: Text(cert.title)),
                        body: ListView(children: [
                          Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                  'Status: ${current.status}${current.reason == null ? '' : '\nReview reason: ${current.reason}'}')),
                          for (final event in history)
                            if (event is Map)
                              Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                                  child: Text(
                                      '${event['action'] ?? event['status'] ?? 'Review'} · ${event['atMillis'] ?? event['createdAtMillis'] ?? ''}${event['reason'] == null ? '' : '\n${event['reason']}'}')),
                          if (pages.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                    'PDF preview is unavailable on this platform. Evidence remains privately stored.')),
                          for (final page in pages)
                            Image.memory(page, fit: BoxFit.contain),
                        ])))));
        pages.clear();
      });
  @override
  Widget build(BuildContext context) => CoachUnsavedChangesGuard(
      dirty:
          title.text.isNotEmpty || issuer.text.isNotEmpty || selected != null,
      busy: busy,
      isCurrent: widget.repository.isCurrent,
      child: Scaffold(
          appBar: AppBar(title: const Text('Certifications'), actions: [
            IconButton(
                onPressed: busy ? null : load, icon: const Icon(Icons.refresh))
          ]),
          body: PageBody(children: [
            const Text(
                'Evidence is private to you and authorized Admins. Approval is required for professional verification.'),
            if (busy) const LinearProgressIndicator(),
            if (message != null) Text(message!),
            for (final cert in certifications)
              Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(cert.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(cert.issuer),
                    Text('Status: ${cert.status} · revision ${cert.revision}'),
                    if (cert.reason != null)
                      Text('Review reason: ${cert.reason}'),
                    TextButton(
                        onPressed: busy ? null : () => view(cert),
                        child: const Text('View private evidence')),
                    if (cert.status != 'archived')
                      TextButton(
                          onPressed: busy
                              ? null
                              : () async {
                                  final confirmed = await confirmSheet(context,
                                      title: 'Archive certification?',
                                      message:
                                          'Remove this reference from active credentials. Evidence and review history remain retained for audit.',
                                      confirmLabel: 'Archive',
                                      destructive: true);
                                  if (confirmed && mounted) {
                                    await run(() async {
                                      await widget.repository.archive(
                                          cert,
                                          FirebaseCoachAccountRepository
                                              .randomId());
                                      final result = await widget.repository
                                          .loadCertifications();
                                      if (mounted) {
                                        setState(() => certifications = result);
                                      }
                                    });
                                  }
                                },
                          child: const Text('Archive')),
                  ])),
            if (widget.repository.certificationCursor != null)
              TextButton(
                  onPressed: busy
                      ? null
                      : () => run(() async {
                            final result = await widget.repository
                                .loadCertifications(
                                    afterId:
                                        widget.repository.certificationCursor);
                            if (mounted) {
                              setState(() => certifications = [
                                    ...certifications,
                                    ...result
                                  ]);
                            }
                          }),
                  child: const Text('Load more certifications')),
            const SizedBox(height: 16),
            const Eyebrow('Upload certification'),
            TextField(
                controller: title,
                onChanged: (_) => setState(() {}),
                enabled: !busy && uploadedPath == null,
                maxLength: 120,
                decoration:
                    const InputDecoration(labelText: 'Certification title')),
            TextField(
                controller: issuer,
                onChanged: (_) => setState(() {}),
                enabled: !busy && uploadedPath == null,
                maxLength: 120,
                decoration:
                    const InputDecoration(labelText: 'Issuing organization')),
            OutlinedButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                          final file = await pickCoachCertification();
                          widget.repository.check();
                          if (file != null && mounted) {
                            setState(() {
                              selected = file;
                              uploadId = uploadedPath = submitRequest = null;
                            });
                          }
                        }),
                child: Text(selected == null
                    ? 'Choose PDF, JPEG or PNG (up to 5 MB)'
                    : 'Evidence selected · ${selected!.bytes.length} bytes')),
            FilledButton(
                onPressed: busy || selected == null ? null : submit,
                child: const Text('Submit for review')),
          ])));
}
