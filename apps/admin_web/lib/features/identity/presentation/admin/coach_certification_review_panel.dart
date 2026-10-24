import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import 'coach_certification_admin_adapter.dart';
import 'private_document_preview.dart';
import 'coach_review_discard_guard.dart';

class CoachCertificationReviewPanel extends StatefulWidget {
  const CoachCertificationReviewPanel(
      {super.key,
      required this.coachId,
      required this.repository,
      required this.discardGuard,
      this.onReviewed});
  final String coachId;
  final CoachProfileAdminRepository repository;
  final CoachReviewDiscardGuard discardGuard;
  final VoidCallback? onReviewed;
  @override
  State<CoachCertificationReviewPanel> createState() => _ReviewState();
}

class _ReviewState extends State<CoachCertificationReviewPanel> {
  late final adapter = CoachCertificationAdminAdapter(widget.repository);
  late Future<Map<String, dynamic>> future = adapter.load(widget.coachId);
  final reasons = <String, TextEditingController>{};
  final requestIds = <String, String>{};
  final histories = <String, Future<Map<String, dynamic>>>{};
  bool busy = false;
  String? message;
  late final Future<bool> Function() discardCheck = confirmDiscard;
  @override
  void initState() {
    super.initState();
    widget.discardGuard.confirm = discardCheck;
  }

  Future<bool> confirmDiscard() async {
    if (busy) return false;
    if (!reasons.values.any((c) => c.text.trim().isNotEmpty)) return true;
    if (!await confirmCoachReviewDiscard(context) || !mounted) return false;
    for (final controller in reasons.values) {
      controller.clear();
    }
    return true;
  }

  @override
  void dispose() {
    if (widget.discardGuard.confirm == discardCheck)
      widget.discardGuard.confirm = null;
    for (final controller in reasons.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void reload() => setState(() {
        histories.clear();
        future = adapter.load(widget.coachId);
      });
  Future<void> preview(Map<String, dynamic> cert) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final bytes = await adapter.bytes(widget.coachId, cert);
      if (!mounted) return;
      final pdf =
          bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-';
      await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
              child: SizedBox(
                  width: 900,
                  height: 700,
                  child: Column(children: [
                    Row(children: [
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(cert['title'] as String? ??
                                  'Certification'))),
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close))
                    ]),
                    Expanded(
                        child: pdf
                            ? privatePdfPreview(bytes)
                            : Image.memory(bytes,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Center(
                                    child: Text(
                                        'Unsupported document preview.')))),
                  ]))));
    } catch (_) {
      if (mounted)
        setState(() =>
            message = 'Could not load private document. Refresh and retry.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> review(Map<String, dynamic> cert, String decision,
      {String? overrideReason}) async {
    final reason = overrideReason ?? (reasons[cert['id']]?.text.trim() ?? '');
    if (decision == 'reject' && reason.isEmpty) {
      setState(() => message =
          'A reason is required to reject or revoke a certification.');
      return;
    }
    final key = '${cert['id']}:${cert['revision']}:$decision:$reason';
    final requestId = requestIds.putIfAbsent(
        key,
        () => List.generate(
            16,
            (_) => Random.secure()
                .nextInt(256)
                .toRadixString(16)
                .padLeft(2, '0')).join());
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await adapter.review(
          coachId: widget.coachId,
          certification: cert,
          decision: decision,
          reason: reason,
          requestId: requestId);
      if (mounted) {
        reasons[cert['id']]?.clear();
        reload();
        setState(() => message = decision == 'approve'
            ? 'Certification approved.'
            : 'Certification rejected / approval revoked.');
        widget.onReviewed?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = safeCoachErrorMessage(e,
            fallback:
                'Review was not confirmed. Retry or refresh for the latest revision.'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> promptRevoke(Map<String, dynamic> cert) async {
    final controller = TextEditingController();
    String? localError;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Revoke Certification Approval'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revoking approval for "${cert['title']}" will mark this certification as rejected and deduct it from verified credentials.',
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'If this is the coach\'s only approved certification, their directory profile will automatically become inactive under BR-5.',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  maxLength: 1000,
                  maxLines: 2,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Reason for revocation (required)',
                    errorText: localError,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.isEmpty) {
                  setDialogState(() => localError =
                      'A reason is required to revoke an approval.');
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Confirm Revocation'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final reason = controller.text.trim();
      await review(cert, 'reject', overrideReason: reason);
    }
    controller.dispose();
  }

  Future<void> promptReviseToApprove(Map<String, dynamic> cert) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green),
            SizedBox(width: 8),
            Text('Revise Decision: Approve'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to approve "${cert['title']}"? This will restore this certification to verified status and count toward BR-5 directory eligibility.',
                style: const TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLength: 1000,
                maxLines: 2,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Correction note (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm Approval'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final reason = controller.text.trim();
      await review(cert, 'approve',
          overrideReason: reason.isNotEmpty ? reason : null);
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(),
        Row(children: [
          const Expanded(
              child: Text('3. Certification review',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          IconButton(
              onPressed: busy ? null : reload,
              tooltip: 'Refresh certifications',
              icon: const Icon(Icons.refresh))
        ]),
        const Text(
            'Documents are private. Approval records verification; directory publication remains a separate action.'),
        if (busy) const LinearProgressIndicator(),
        if (message != null) Text(message!),
        FutureBuilder<Map<String, dynamic>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const Text(
                    'Could not load certifications. Refresh to retry.');
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final certs =
                  (snapshot.data!['certifications'] as List? ?? []).cast<Map>();
              if (certs.isEmpty)
                return const Text('No uploaded certifications.');
              return Column(children: [
                for (final raw in certs)
                  Builder(builder: (context) {
                    final cert = Map<String, dynamic>.from(raw);
                    final id = cert['id'] as String;
                    final status = cert['status'] as String? ?? 'pending';
                    final isPending = status == 'pending';
                    final isApproved = status == 'approved';
                    final isRejected = status == 'rejected';
                    final reason =
                        reasons.putIfAbsent(id, TextEditingController.new);
                    return Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${cert['title']} · ${cert['issuer']}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15),
                                        ),
                                      ),
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          status.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isApproved
                                                ? Colors.green.shade800
                                                : isRejected
                                                    ? Colors.red.shade800
                                                    : isPending
                                                        ? Colors.orange.shade800
                                                        : Colors.grey.shade700,
                                          ),
                                        ),
                                        backgroundColor: isApproved
                                            ? Colors.green.shade50
                                            : isRejected
                                                ? Colors.red.shade50
                                                : isPending
                                                    ? Colors.orange.shade50
                                                    : Colors.grey.shade100,
                                        side: BorderSide(
                                          color: isApproved
                                              ? Colors.green.shade300
                                              : isRejected
                                                  ? Colors.red.shade300
                                                  : isPending
                                                      ? Colors.orange.shade300
                                                      : Colors.grey.shade300,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Revision: ${cert['revision']}'),
                                  Text(
                                      'Updated: ${_timestamp(cert['updatedAtMillis'])}'),
                                  if (cert['reason'] is String &&
                                      (cert['reason'] as String).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Text(
                                        'Review reason: ${cert['reason']}',
                                        style: const TextStyle(
                                            fontStyle: FontStyle.italic),
                                      ),
                                    ),
                                  TextButton.icon(
                                      onPressed:
                                          busy ? null : () => preview(cert),
                                      icon: const Icon(
                                          Icons.description_outlined),
                                      label:
                                          const Text('View private document')),
                                  if (isPending) ...[
                                    TextField(
                                        controller: reason,
                                        enabled: !busy,
                                        maxLength: 1000,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Review reason (required for rejection, optional for approval)')),
                                    const SizedBox(height: 8),
                                    Wrap(spacing: 12, children: [
                                      FilledButton.icon(
                                          onPressed: busy
                                              ? null
                                              : () => review(cert, 'approve'),
                                          icon: const Icon(
                                              Icons.check_circle_outline,
                                              size: 16),
                                          label: const Text('Approve')),
                                      OutlinedButton.icon(
                                          onPressed: busy
                                              ? null
                                              : () => review(cert, 'reject'),
                                          icon: const Icon(
                                              Icons.cancel_outlined,
                                              size: 16),
                                          label: const Text('Reject'))
                                    ]),
                                  ] else if (isApproved) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      child: Row(
                                        children: [
                                          Icon(Icons.verified,
                                              size: 16,
                                              color: Colors.green.shade700),
                                          const SizedBox(width: 6),
                                          Flexible(
                                              child: Text(
                                            'Certification verified and approved.',
                                            style: TextStyle(
                                              color: Colors.green.shade800,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          )),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    OutlinedButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () => promptRevoke(cert),
                                      icon: const Icon(
                                          Icons.remove_circle_outline,
                                          size: 16,
                                          color: Colors.red),
                                      label: const Text('Revoke approval',
                                          style: TextStyle(color: Colors.red)),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                            color: Colors.red.shade300),
                                      ),
                                    ),
                                  ] else if (isRejected) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      child: Row(
                                        children: [
                                          Icon(Icons.block,
                                              size: 16,
                                              color: Colors.red.shade700),
                                          const SizedBox(width: 6),
                                          Flexible(
                                              child: Text(
                                            'Certification rejected.',
                                            style: TextStyle(
                                              color: Colors.red.shade800,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          )),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    OutlinedButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () => promptReviseToApprove(cert),
                                      icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 16,
                                          color: Colors.green),
                                      label: const Text(
                                          'Revise decision (Approve)',
                                          style:
                                              TextStyle(color: Colors.green)),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                            color: Colors.green.shade300),
                                      ),
                                    ),
                                  ] else if (status == 'archived') ...[
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 6),
                                      child: Text(
                                        'Archived certification cannot be modified.',
                                        style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                  ExpansionTile(
                                    title: const Text('Review history'),
                                    onExpansionChanged: (open) {
                                      if (open && !histories.containsKey(id))
                                        setState(() {
                                          histories[id] = adapter.load(
                                              widget.coachId,
                                              certificationId: id);
                                        });
                                    },
                                    children: [
                                      FutureBuilder<Map<String, dynamic>>(
                                          future: histories[id],
                                          builder: (context, history) {
                                            if (history.hasError)
                                              return const ListTile(
                                                  title: Text(
                                                      'History unavailable. Refresh to retry.'));
                                            if (!history.hasData)
                                              return const LinearProgressIndicator();
                                            final records =
                                                history.data!['certifications']
                                                        as List? ??
                                                    [];
                                            final audits = records.isEmpty
                                                ? []
                                                : (records.first['history']
                                                        as List? ??
                                                    []);
                                            return Column(children: [
                                              for (final audit in audits)
                                                ListTile(
                                                    title: Text(
                                                        '${audit['status']} · revision ${audit['revision']}'),
                                                    subtitle: Text(
                                                        '${audit['reason'] ?? ''}\nReviewer: ${audit['actorId'] ?? '—'} · ${_timestamp(audit['updatedAtMillis'])}')),
                                              if (audits.isEmpty)
                                                const ListTile(
                                                    title: Text(
                                                        'No review history.')),
                                            ]);
                                          })
                                    ],
                                  ),
                                ])));
                  }),
                if (snapshot.data!['nextCursor'] is String)
                  TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              final previous = snapshot.data!;
                              setState(() {
                                future = adapter
                                    .load(widget.coachId,
                                        afterId:
                                            previous['nextCursor'] as String)
                                    .then((page) => {
                                          ...page,
                                          'certifications': [
                                            ...certs,
                                            ...(page['certifications']
                                                    as List? ??
                                                [])
                                          ]
                                        });
                              });
                            },
                      child: const Text('Load more certifications')),
              ]);
            }),
      ]);
}

String _timestamp(Object? value) => value is int
    ? DateTime.fromMillisecondsSinceEpoch(value).toLocal().toString()
    : '—';
