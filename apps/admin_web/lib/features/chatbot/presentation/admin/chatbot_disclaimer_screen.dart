import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/content.dart';

/// AD-M11.4 — organization-scoped disclaimer authoring and preview.
/// Mock mode retains the prototype; live mode saves versioned content only.
class ChatbotDisclaimerScreen extends StatefulWidget {
  const ChatbotDisclaimerScreen({super.key, this.live = false});
  final bool live;

  @override
  State<ChatbotDisclaimerScreen> createState() =>
      _ChatbotDisclaimerScreenState();
}

class _ChatbotDisclaimerScreenState extends State<ChatbotDisclaimerScreen> {
  ChatbotDisclaimerSnapshot? _snapshot;
  bool _loading = false;
  bool _saving = false;
  bool _blocked = false;
  bool _started = false;
  String? _error;
  bool _active = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.live && !_started) {
      _started = true;
      _controller.clear();
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _blocked = true;
    });
    try {
      final loaded = await context.read<ChatbotDisclaimerRepository>().load();
      if (!mounted) return;
      setState(() {
        _snapshot = loaded;
        _controller.text = loaded.current?.text ?? '';
        _active = loaded.current?.isActive ?? false;
        _blocked = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not load the disclaimer. Check access and retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_snapshot == null || _saving || _blocked) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await context
          .read<ChatbotDisclaimerRepository>()
          .save(_snapshot!, text: _controller.text, isActive: _active);
      if (!mounted) return;
      setState(() {
        _snapshot = saved;
        _controller.text = saved.current!.text;
      });
      showToast(context, 'Disclaimer v${saved.current!.revision} saved.');
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on ChatbotDisclaimerConflict {
      if (mounted) {
        setState(() {
          _blocked = true;
          _error = 'The disclaimer changed. Reload before saving again.';
        });
      }
    } on ChatbotDisclaimerSessionChanged {
      if (mounted) {
        setState(() {
          _blocked = true;
          _error = 'Account or permissions changed. Sign in again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _blocked = true;
          _error =
              'Save could not be verified. Reload to check the saved version.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static const _history = [
    ['v3', 'Current — added "stop and speak to a professional" guidance'],
    ['v2', 'Clarified this is not medical advice'],
    ['v1', 'Initial disclaimer at chatbot launch'],
  ];

  late final _controller = TextEditingController(
    text:
        'The AI coach gives general fitness and technique guidance only. It cannot diagnose '
        'injuries, prescribe treatment, or replace advice from a doctor or physiotherapist.\n\n'
        'If something hurts, stop and speak to a qualified professional.',
  )..addListener(_repaint);

  void _repaint() => setState(() {});

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _publish() {
    if (_controller.text.trim().isEmpty) {
      showToast(context, 'Disclaimer text cannot be empty.');
      return;
    }
    showToast(context, 'Disclaimer updated to v4.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      widget.live
                          ? 'Manage the safety notice. Chatbot use and member acknowledgement are unavailable.'
                          : 'Shown once per day before a member sends their first message.',
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
                if (widget.live)
                  IconButton(
                      tooltip: 'Reload disclaimer',
                      onPressed: _loading || _saving ? null : _load,
                      icon: const Icon(Icons.refresh)),
                statusPill(widget.live
                    ? _snapshot?.current == null
                        ? 'No saved notice'
                        : 'v${_snapshot!.current!.revision} ${_snapshot!.current!.isActive ? 'active' : 'inactive'}'
                    : 'v3 live'),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_error!)),
            if (widget.live &&
                !_loading &&
                _error == null &&
                _snapshot?.current == null)
              const Panel(
                  child: Text(
                      'No disclaimer has been saved. Enter text and save an inactive first version.')),
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final form = _form(context);
              final rail = _rail(context);
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: form),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: rail),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [form, const SizedBox(height: 20), rail]);
            }),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Disclaimer text'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                enabled: !widget.live || (!_loading && !_saving && !_blocked),
                maxLength: widget.live ? 4000 : null,
                maxLines: 8,
                decoration: const InputDecoration(
                    hintText: 'What members see before their first message'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${_controller.text.length} characters',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.inkSoft)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (widget.live)
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active notice'),
              subtitle: const Text(
                  'Save the first version inactive. Activation does not enable the chatbot.'),
              value: _active,
              onChanged:
                  _snapshot?.current == null || _loading || _saving || _blocked
                      ? null
                      : (value) => setState(() => _active = value)),
        FilledButton(
            onPressed: widget.live
                ? _loading || _saving || _blocked
                    ? null
                    : _save
                : _publish,
            child: Text(widget.live
                ? _saving
                    ? 'Saving…'
                    : 'Save new version'
                : 'Publish new version')),
      ],
    );
  }

  Widget _rail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Member preview'),
        Panel(
          background: AppColors.surfaceAlt,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                        gradient: AppColors.heroGradient,
                        shape: BoxShape.circle),
                    child: const Icon(Icons.smart_toy_rounded,
                        size: 15, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text('AI coach',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Text(
                  _controller.text.isEmpty
                      ? 'Nothing to preview yet.'
                      : _controller.text,
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          background: AppColors.primaryTint,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.live
                      ? 'Each save retains an immutable version. This preview does not record member consent or publish a legal agreement.'
                      : 'Publishing shows this to every member again on their next visit, even if they dismissed an earlier version today.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Eyebrow(
            widget.live ? 'Version history · latest 20' : 'Version history'),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(
                widget.live ? _snapshot?.history.length ?? 0 : _history.length,
                (i) {
              final saved = widget.live ? _snapshot!.history[i] : null;
              final h = saved == null
                  ? _history[i]
                  : [
                      'v${saved.revision}',
                      '${saved.isActive ? 'Active' : 'Inactive'} · ${saved.updatedAt.toLocal()}\n${saved.text}',
                    ];
              return Column(
                children: [
                  if (i > 0) const Divider(height: 1, indent: 16),
                  ListTile(
                    dense: true,
                    leading: statusPill(h[0]),
                    title: Text(h[1], style: const TextStyle(fontSize: 12.5)),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
