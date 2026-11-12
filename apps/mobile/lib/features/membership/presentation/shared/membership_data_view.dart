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
        IconButton(
            tooltip: 'Refresh membership',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh))
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
                child: PageBody(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      if (snapshot.data!['cached'] == true)
                        const Panel(
                            child: Text(
                                'Offline cached records. Membership status may have changed. Refresh online before payment or refund decisions.')),
                      Semantics(
                          liveRegion: true,
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                  color: AppColors.accentTint,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                  widget.repository.sandbox
                                      ? 'Billplz Sandbox · Test payments only'
                                      : 'Mock preview · Simulated payments',
                                  style: const TextStyle(
                                      color: AppColors.accentDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)))),
                      const SizedBox(height: 12),
                      ...widget.builder(context, snapshot.data!, _refresh)
                    ]));
          }));
}

String membershipDate(Object? millis) {
  if (millis is! num || millis <= 0) return 'No paid expiry';
  final d = DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true)
      .add(const Duration(hours: 8));
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} MYT';
}

List<Map<String, dynamic>> membershipRows(Object? value) =>
    (value as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
String membershipPaymentLabel(Map<String, dynamic> p) {
  final refund = p['refundStatus'];
  if (refund != null) {
    return switch (refund) {
      'pending_review' => 'Refund requested · Under review',
      'approved' => 'Refund approved · Transfer not confirmed',
      'rejected' => 'Refund request declined',
      'processing' => 'Refund processing',
      'completed' => 'Refunded',
      _ => 'Refund status needs verification',
    };
  }
  if (p['paymentStatus'] == 'cleared' && p['fulfilmentStatus'] == 'confirmed') {
    return 'Paid · Membership activated';
  }
  return switch (p['fulfilmentStatus']) {
    'creating' => 'Preparing your payment',
    'awaiting_payment' => 'Payment not completed',
    'expired' => 'Payment window ended',
    'failed' => 'Payment unsuccessful',
    'reconciliation_required' => p['paymentStatus'] == 'cleared'
        ? 'Payment received · Review required'
        : 'Payment needs review',
    _ => 'Payment verification pending',
  };
}

List<String> membershipProductBenefits(String tier) => tier == 'free'
    ? const [
        'AI workouts, tutorials and training programs',
        'History, progress, reports and PDF export',
        'Daily check-in and saved reward points'
      ]
    : const [
        'Gym entry across GainPath branches',
        'Coach browsing and booking',
        'Mini Games',
        'Eligible regular physical rewards'
      ];

String membershipPlanPositioning(String tier) => switch (tier) {
      'basic' => 'Gym Membership',
      'premium' => 'VIP Membership',
      _ => 'Digital Fitness',
    };
