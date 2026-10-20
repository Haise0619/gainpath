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
      required this.discardGuard});
  final String coachId;
  final CoachProfileAdminRepository repository;
  final CoachReviewDiscardGuard discardGuard;
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

  Future<void> review(Map<String, dynamic> cert, String decision) async {
    final reason = reasons[cert['id']]?.text.trim() ?? '';
    if (decision == 'reject' && reason.isEmpty) {
      setState(() => message = 'Enter a reason before rejecting.');
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
        setState(() => message = 'Review saved.');
      }
    } catch (_) {
      if (mounted)
        setState(() => message =
            'Review was not confirmed. Retry the same decision or refresh for the latest revision.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(),
        Row(children: [
          const Expanded(
              child: Text('Certification review',
                  style: TextStyle(fontWeight: FontWeight.bold))),
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
                    final reason =
                        reasons.putIfAbsent(id, TextEditingController.new);
                    return Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${cert['title']} · ${cert['issuer']}'),
                                  Text(
                                      'Status: ${cert['status']} · Revision: ${cert['revision']}'),
                                  if (cert['reason'] is String &&
                                      (cert['reason'] as String).isNotEmpty)
                                    Text('Review reason: ${cert['reason']}'),
                                  TextButton.icon(
                                      onPressed:
                                          busy ? null : () => preview(cert),
                                      icon: const Icon(
                                          Icons.description_outlined),
                                      label:
                                          const Text('View private document')),
                                  if (cert['status'] != 'archived') ...[
                                    TextField(
                                        controller: reason,
                                        enabled: !busy,
                                        maxLength: 1000,
                                        decoration: const InputDecoration(
                                            labelText:
                                                'Review reason (required for rejection)')),
                                    Wrap(spacing: 12, children: [
                                      FilledButton(
                                          onPressed: busy
                                              ? null
                                              : () => review(cert, 'approve'),
                                          child: const Text('Approve')),
                                      OutlinedButton(
                                          onPressed: busy
                                              ? null
                                              : () => review(cert, 'reject'),
                                          child: const Text('Reject'))
                                    ]),
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
