import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

typedef MemberComplianceCall = Future<Map<String, dynamic>> Function(
    String action, Map<String, dynamic> input);

const _names = {
  'terms': 'Terms & Conditions',
  'privacy': 'Privacy Policy',
  'health': 'Health Disclaimer',
};

class MemberComplianceGate extends StatefulWidget {
  const MemberComplianceGate({
    super.key,
    required this.call,
    required this.child,
    required this.accountSettings,
    required this.onSignOut,
  });

  final MemberComplianceCall call;
  final Widget child;
  final WidgetBuilder accountSettings;
  final VoidCallback onSignOut;

  @override
  State<MemberComplianceGate> createState() => _MemberComplianceGateState();
}

class _MemberComplianceGateState extends State<MemberComplianceGate>
    with WidgetsBindingObserver {
  late final _controller = _LegalController(widget.call)..load();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          if (_controller.loaded && !_controller.hasRequired) {
            return widget.child;
          }
          if (!_controller.loaded && _controller.error == null) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Checking policy status',
                ),
              ),
            );
          }
          return _LegalPage(
            controller: _controller,
            requiredOnly: true,
            accountSettings: widget.accountSettings,
            onSignOut: widget.onSignOut,
          );
        },
      );
}

class MemberLegalPrivacyPage extends StatefulWidget {
  const MemberLegalPrivacyPage({super.key, required this.call});

  final MemberComplianceCall call;

  @override
  State<MemberLegalPrivacyPage> createState() => _MemberLegalPrivacyPageState();
}

class _MemberLegalPrivacyPageState extends State<MemberLegalPrivacyPage> {
  late final _controller = _LegalController(widget.call)..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => _LegalPage(controller: _controller),
      );
}

class _LegalController extends ChangeNotifier {
  _LegalController(this.call);

  final MemberComplianceCall call;
  List<Map<String, dynamic>> documents = const [];
  bool loaded = false, busy = false, _disposed = false;
  String? error;

  bool get hasRequired =>
      documents.any((doc) => doc['requiresConsent'] == true);

  Future<void> load() => _run(_fetch);

  Future<void> accept(Map<String, dynamic> doc) => _run(() async {
        await call('accept', {
          'agreed': true,
          'documents': [
            {'kind': doc['kind'], 'revision': doc['revision']}
          ]
        });
        await _fetch();
      });

  Future<void> _fetch() async {
    final response = await call('memberOverview', {});
    if (_disposed) return;
    documents = (response['documents'] as List)
        .map((doc) => Map<String, dynamic>.from(doc as Map))
        .toList(growable: false);
    loaded = true;
  }

  Future<void> _run(Future<void> Function() work) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await work();
    } catch (_) {
      error = 'Could not verify your documents. Refresh before trying again.';
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _LegalPage extends StatelessWidget {
  const _LegalPage({
    required this.controller,
    this.requiredOnly = false,
    this.accountSettings,
    this.onSignOut,
  });

  final _LegalController controller;
  final bool requiredOnly;
  final WidgetBuilder? accountSettings;
  final VoidCallback? onSignOut;

  Future<void> _review(BuildContext context, Map<String, dynamic> doc) async {
    final canAccept = doc['requiresConsent'] == true ||
        doc['acceptedVersion'] != doc['version'];
    final agreed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => _LegalReview(doc: doc, canAccept: canAccept)),
    );
    if (agreed == true && context.mounted) await controller.accept(doc);
  }

  @override
  Widget build(BuildContext context) {
    final checkUnavailable = requiredOnly && !controller.loaded;
    final visible = controller.documents
        .where((doc) => !requiredOnly || doc['requiresConsent'] == true);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(checkUnavailable
            ? 'Policy check unavailable'
            : requiredOnly
                ? 'Review policies'
                : 'Legal & Privacy'),
        automaticallyImplyLeading: !requiredOnly,
        actions: [
          if (!checkUnavailable)
            IconButton(
              tooltip: 'Refresh documents',
              onPressed: controller.busy ? null : controller.load,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                if (controller.busy) const LinearProgressIndicator(),
                if (requiredOnly && controller.hasRequired)
                  Panel(
                    background: AppColors.primaryTint,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.policy_outlined,
                            color: AppColors.primary),
                        const SizedBox(height: 10),
                        Text('Review and agree to continue',
                            style: theme.textTheme.titleLarge),
                        const SizedBox(height: 6),
                        const Text(
                            'Open each required document and confirm your choice.'),
                      ],
                    ),
                  ),
                if (controller.error case final error?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(error,
                        style: TextStyle(color: theme.colorScheme.error)),
                  ),
                if (checkUnavailable)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: controller.load,
                      child: const Text('Retry policy check'),
                    ),
                  ),
                if (controller.loaded && visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No published documents to review.'),
                  ),
                for (final doc in visible)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: const Icon(Icons.description_outlined),
                        title: Text(_names[doc['kind']] ?? 'Policy'),
                        subtitle: Text([
                          'Current version: ${doc['version']}',
                          if (doc['acceptedVersion'] != null)
                            'Agreed version: ${doc['acceptedVersion']}',
                          if (doc['requiresConsent'] == true) 'Action required',
                        ].join('\n')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: controller.busy
                            ? null
                            : () => _review(context, doc),
                      ),
                    ),
                  ),
                if (accountSettings != null || onSignOut != null) ...[
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (accountSettings != null)
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: accountSettings!),
                          ),
                          child: const Text('Account settings'),
                        ),
                      if (onSignOut != null)
                        TextButton(
                            onPressed: onSignOut,
                            child: const Text('Sign out')),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalReview extends StatefulWidget {
  const _LegalReview({required this.doc, required this.canAccept});

  final Map<String, dynamic> doc;
  final bool canAccept;

  @override
  State<_LegalReview> createState() => _LegalReviewState();
}

class _LegalReviewState extends State<_LegalReview> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final title = _names[widget.doc['kind']] ?? 'Policy';
    return Scaffold(
      appBar: AppBar(title: const Text('Document')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Version ${widget.doc['version']}'),
                const SizedBox(height: 18),
                Panel(
                  child: SelectableText(
                    widget.doc['text'] as String,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ),
                if (widget.canAccept) ...[
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _checked,
                    onChanged: (value) =>
                        setState(() => _checked = value == true),
                    title: Text(
                        'I have read and agree to $title ${widget.doc['version']}.'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed:
                        _checked ? () => Navigator.pop(context, true) : null,
                    child: const Text('Confirm agreement'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
