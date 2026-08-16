import 'package:flutter/material.dart';
import '../app/theme.dart';

/// Simulated Billplz-style checkout: a fake browser chrome wrapping a
/// payment-method picker, standing in for the embedded WebView the design
/// direction specifies for every payment flow (membership purchase and
/// renewal, coach booking). Pushed as a full-screen route — deliberately
/// off-brand (neutral grey chrome, Billplz's own accent) so it reads as a
/// handoff to an external gateway rather than another GainPath screen,
/// matching "GainPath never sees or stores your card details."
///
/// Returns `true` via [Navigator.pop] once the simulated payment clears;
/// the caller is responsible for advancing to its own confirmation screen.
class BillplzCheckoutScreen extends StatefulWidget {
  final double amount;
  final String description;
  const BillplzCheckoutScreen({super.key, required this.amount, required this.description});

  @override
  State<BillplzCheckoutScreen> createState() => _BillplzCheckoutScreenState();
}

class _BillplzCheckoutScreenState extends State<BillplzCheckoutScreen> {
  static const _billplzBlue = Color(0xFF1B3A63);
  static const _billplzAccent = Color(0xFF00B4D8);

  static const _fpxBanks = [
    ['Maybank2u', Icons.account_balance_rounded],
    ['CIMB Clicks', Icons.account_balance_rounded],
    ['Public Bank', Icons.account_balance_rounded],
    ['RHB Now', Icons.account_balance_rounded],
  ];
  static const _ewallets = [
    ["Touch 'n Go eWallet", Icons.qr_code_2_rounded],
    ['GrabPay', Icons.qr_code_2_rounded],
    ['Boost', Icons.qr_code_2_rounded],
  ];

  int _tab = 0;
  String? _method;
  bool _processing = false;

  Future<void> _confirm() async {
    if (_method == null) return;
    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 1700));
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final methods = _tab == 0 ? _fpxBanks : _ewallets;
    return PopScope(
      canPop: !_processing,
      child: Scaffold(
        backgroundColor: const Color(0xFFEDEFF2),
        body: SafeArea(
          child: Column(
            children: [
              _browserChrome(context),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _processing ? _processingView() : _checkoutBody(context, methods),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _browserChrome(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            color: AppColors.inkSoft,
            onPressed: _processing ? null : () => Navigator.pop(context, false),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.lock_rounded, size: 13, color: AppColors.success),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'billplz.com/bill/checkout',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.inkSoft,
            onPressed: _processing ? null : () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }

  Widget _checkoutBody(BuildContext context, List<List<Object>> methods) {
    return SingleChildScrollView(
      key: const ValueKey('checkout'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: _billplzBlue, borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.bolt_rounded, color: _billplzAccent, size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Billplz',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _billplzBlue)),
              const Spacer(),
              const Icon(Icons.verified_user_rounded, size: 15, color: AppColors.success),
              const SizedBox(width: 4),
              const Text('Secure', style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount due', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text('RM ${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: _billplzBlue)),
                const SizedBox(height: 4),
                Text(widget.description, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Select payment method', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _tabButton('FPX Online Banking', 0)),
              const SizedBox(width: 8),
              Expanded(child: _tabButton('E-Wallet', 1)),
            ],
          ),
          const SizedBox(height: 14),
          ...methods.map((m) {
            final name = m[0] as String;
            final icon = m[1] as IconData;
            final selected = _method == name;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _method = name),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? _billplzBlue : const Color(0xFFE2E5E9), width: selected ? 1.6 : 1),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 19, color: AppColors.inkSoft),
                      const SizedBox(width: 12),
                      Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                      Icon(
                        selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: selected ? _billplzBlue : const Color(0xFFCBD0D6),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _billplzBlue, minimumSize: const Size(0, 52)),
              onPressed: _method == null ? null : _confirm,
              child: Text('Pay RM ${widget.amount.toStringAsFixed(2)}'),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.inkSoft),
              SizedBox(width: 6),
              Text('Encrypted end-to-end. GainPath does not see your bank details.',
                  style: TextStyle(fontSize: 11, color: AppColors.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _tab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() {
        _tab = index;
        _method = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _billplzBlue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? _billplzBlue : const Color(0xFFE2E5E9)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.inkSoft),
        ),
      ),
    );
  }

  Widget _processingView() {
    return Center(
      key: const ValueKey('processing'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3, color: _billplzBlue),
          ),
          SizedBox(height: 18),
          Text('Confirming your payment…',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _billplzBlue)),
          SizedBox(height: 6),
          Text('Do not close this window.',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}
