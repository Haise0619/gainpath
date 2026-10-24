import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class MembershipDataView extends StatefulWidget {
  const MembershipDataView(
      {super.key,
      required this.repository,
      required this.title,
      required this.builder});
  final MembershipCommerceRepository repository;
  final String title;
  final List<Widget> Function(BuildContext, Map<String, dynamic>, VoidCallback)
      builder;
  @override
  State<MembershipDataView> createState() => _MembershipDataViewState();
}

class _MembershipDataViewState extends State<MembershipDataView>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>> _data;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _data = widget.repository.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.repository.current) {
      _refresh();
    }
  }

  void _refresh() {
    final next = widget.repository.load();
    setState(() {
      _data = next;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh))
      ]),
      body: FutureBuilder<Map<String, dynamic>>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text(
                            'Membership could not be loaded. Check your connection and verified account, then retry.'),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed: _refresh, child: const Text('Retry'))
                      ])));
            }
            return RefreshIndicator(
                onRefresh: () async {
                  _refresh();
                  await _data;
                },
                child: PageBody(children: [
                  if (snapshot.data!['cached'] == true)
                    const Panel(
                        child: Text(
                            'Offline cached records. Membership status may have changed. Refresh online before payment or refund decisions.')),
                  Text(
                      widget.repository.sandbox
                          ? 'Billplz Sandbox · Test payments only'
                          : 'Mock preview · Simulated payments',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  ...widget.builder(context, snapshot.data!, _refresh)
                ]));
          }));
}

String membershipDate(Object? millis) => millis is num && millis > 0
    ? DateTime.fromMillisecondsSinceEpoch(millis.toInt())
        .toLocal()
        .toString()
        .split(' ')
        .first
    : 'No paid expiry';
List<Map<String, dynamic>> membershipRows(Object? value) =>
    (value as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
String membershipPaymentLabel(Map<String, dynamic> p) {
  final refund = p['refundStatus'];
  if (refund != null) {
    return 'Refund: ${refund.toString().replaceAll('_', ' ')}';
  }
  if (p['paymentStatus'] == 'cleared' && p['fulfilmentStatus'] == 'confirmed') {
    return 'Paid · Membership activated';
  }
  return p['fulfilmentStatus'].toString().replaceAll('_', ' ');
}
