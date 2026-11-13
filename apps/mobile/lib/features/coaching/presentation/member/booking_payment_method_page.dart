import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class BookingPaymentMethodPage extends StatefulWidget {
  const BookingPaymentMethodPage(
      {super.key,
      required this.data,
      required this.selected,
      required this.loading,
      required this.message,
      required this.onSelect,
      required this.onContinue,
      required this.onRetry,
      this.reviewedQuote});
  final BookingPaymentMethods? data;
  final BookingPaymentQuote? reviewedQuote;
  final String? selected, message;
  final bool loading;
  final ValueChanged<String> onSelect;
  final VoidCallback? onContinue;
  final VoidCallback onRetry;
  @override
  State<BookingPaymentMethodPage> createState() =>
      _BookingPaymentMethodPageState();
}

class _BookingPaymentMethodPageState extends State<BookingPaymentMethodPage> {
  bool _details = false, _moreBanks = false;
  Duration get _motion => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 180);
  Widget _expand(Widget child) => MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(
          duration: _motion, alignment: Alignment.topCenter, child: child);
  List<BookingPaymentChoice> get _choices =>
      widget.data?.selectionMethods.isNotEmpty == true
          ? widget.data!.selectionMethods
          : [
              for (final m
                  in widget.data?.methods ?? const <BookingPaymentMethod>[])
                BookingPaymentChoice(
                    m.category == 'fpx' ? 'fpx' : 'other',
                    m.code,
                    m.category == 'fpx' ? m.name : 'Online payment',
                    'bank')
            ];
  @override
  Widget build(BuildContext context) {
    final quote = widget.reviewedQuote ?? widget.data?.quote;
    final chosen = _choices.where((m) => m.code == widget.selected).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
              decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.hairline))),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (quote != null)
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          children: [
                            const Text('Total to pay'),
                            Text(quote.formattedAmount,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(color: AppColors.primary))
                          ]),
                    const SizedBox(height: 10),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            foregroundColor: Colors.white,
                            disabledForegroundColor: AppColors.inkSoft,
                            animationDuration: _motion),
                        onPressed: widget.loading ? null : widget.onContinue,
                        child: const Text('Continue')),
                    const SizedBox(height: 8),
                    const Text('Your payment will be securely processed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'Barlow',
                            fontSize: 12,
                            color: AppColors.inkSoft)),
                  ]))),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const Text('2 of 3 · Payment',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
            const SizedBox(height: 8),
            Text('Choose a payment method',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: AppColors.ink)),
            const SizedBox(height: 16),
            if (quote != null) _summary(quote),
            const SizedBox(height: 20),
            if (widget.loading) ...[
              LinearProgressIndicator(
                  value: MediaQuery.disableAnimationsOf(context) ? 0.6 : null),
              const SizedBox(height: 12),
              const Text('Getting your payment ready…')
            ],
            if (!widget.loading && widget.message != null) ...[
              Text(widget.message!),
              TextButton(
                  onPressed: widget.onRetry, child: const Text('Try again'))
            ],
            for (final category in ['fpx', 'ewallet', 'card', 'other'])
              if (_choices.any((m) => m.category == category)) ...[
                _groupHeading(category),
                const SizedBox(height: 10),
                if (category == 'fpx') ...[
                  for (final m in _choices
                      .where((m) => m.category == category)
                      .take(_moreBanks ? 100 : 6))
                    _card(m),
                  if (_choices.where((m) => m.category == category).length > 6)
                    TextButton.icon(
                        onPressed: () =>
                            setState(() => _moreBanks = !_moreBanks),
                        icon: Icon(
                            _moreBanks ? Icons.expand_less : Icons.expand_more),
                        label: Text(_moreBanks ? 'Fewer banks' : 'More banks')),
                ] else
                  for (final m in _choices.where((m) => m.category == category))
                    _card(m),
                const SizedBox(height: 16),
              ],
            if (!widget.loading &&
                widget.message == null &&
                widget.data != null &&
                _choices.isEmpty) ...[
              const Text(
                  'Payment is temporarily unavailable. Please try again.'),
              TextButton(
                  onPressed: widget.onRetry, child: const Text('Try again'))
            ],
            if (chosen != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('Selected: ${chosen.name}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600))),
            const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lock_outline_rounded,
                  size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'Final payment options are shown at secure checkout. Your booking is confirmed after payment is verified.',
                      style: TextStyle(fontSize: 12, color: AppColors.inkSoft)))
            ]),
          ]),
    );
  }

  Widget _summary(BookingPaymentQuote quote) => Material(
      color: AppColors.primaryTint,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: () => setState(() => _details = !_details),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.fitness_center_rounded,
                          color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(quote.coachName,
                              style: Theme.of(context).textTheme.titleLarge)),
                      Icon(_details ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.primary)
                    ]),
                    const SizedBox(height: 8),
                    Text('${quote.durationMinutes}-minute coaching session'),
                    if (widget.data?.localDate != null)
                      Text(
                          '${widget.data!.localDate} · ${widget.data!.startLabel} – ${widget.data!.endLabel}'),
                    _expand(_details
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(quote.branchName),
                                  if (quote.voucherApplied)
                                    const Text('Premium Coach voucher included')
                                ]))
                        : const SizedBox.shrink()),
                  ]))));
  Widget _groupHeading(String category) => Row(children: [
        Icon(
            switch (category) {
              'fpx' => Icons.account_balance_outlined,
              'ewallet' => Icons.account_balance_wallet_outlined,
              'card' => Icons.credit_card_rounded,
              _ => Icons.shield_outlined
            },
            size: 20,
            color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
                switch (category) {
                  'fpx' => 'Online Banking / FPX',
                  'ewallet' => 'E-Wallet',
                  'card' => 'Cards',
                  _ => 'Secure payment'
                },
                style: Theme.of(context).textTheme.titleMedium))
      ]);
  Widget _card(BookingPaymentChoice choice) {
    final selected = widget.selected == choice.code;
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Semantics(
            button: true,
            selected: selected,
            child: AnimatedContainer(
                duration: _motion,
                decoration: BoxDecoration(
                    color: selected ? AppColors.primaryTint : AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color:
                            selected ? AppColors.primary : AppColors.hairline,
                        width: selected ? 1.5 : 1)),
                child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                        onTap: widget.loading
                            ? null
                            : () => widget.onSelect(choice.code),
                        child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              PaymentMethodIcon(iconKey: choice.iconKey),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(choice.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 2),
                                    Text(
                                        switch (choice.category) {
                                          'fpx' => 'Pay through your bank',
                                          'ewallet' =>
                                            'Your preferred e-wallet',
                                          'card' => 'Credit or debit card',
                                          _ => 'Secure online payment'
                                        },
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.inkSoft))
                                  ])),
                              const SizedBox(width: 8),
                              Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.inkSoft)
                            ])))))));
  }
}
