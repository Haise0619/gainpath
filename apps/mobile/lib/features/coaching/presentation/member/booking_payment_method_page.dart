import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

const _bankPreviewCount = 4;

class BookingPaymentMethodPage extends StatefulWidget {
  const BookingPaymentMethodPage({
    super.key,
    required this.data,
    required this.selected,
    required this.loading,
    required this.message,
    required this.onSelect,
    required this.onContinue,
    required this.onRetry,
    this.reviewedQuote,
  });

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
  bool _details = false;
  String? _activeCategory;

  Duration get _motion => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 180);

  Widget _resize(Widget child) {
    if (_motion == Duration.zero) return child;
    return AnimatedSize(
      duration: _motion,
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: child,
    );
  }

  List<BookingPaymentChoice> get _choices =>
      widget.data?.selectionMethods.isNotEmpty == true
          ? widget.data!.selectionMethods
          : [
              for (final method
                  in widget.data?.methods ?? const <BookingPaymentMethod>[])
                BookingPaymentChoice(
                    method.category == 'fpx' ? 'fpx' : 'other',
                    method.code,
                    method.category == 'fpx' ? method.name : 'Online payment',
                    'bank'),
            ];

  Future<void> _moreBanks(List<BookingPaymentChoice> banks) async {
    final code = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      sheetAnimationStyle:
          _motion == Duration.zero ? AnimationStyle.noAnimation : null,
      builder: (_) => _BankPicker(banks: banks, selected: widget.selected),
    );
    if (mounted && !widget.loading && code != null) widget.onSelect(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final quote = widget.reviewedQuote ?? widget.data?.quote;
    final choices = _choices;
    final chosen = choices.where((m) => m.code == widget.selected).firstOrNull;
    final active =
        _activeCategory ?? chosen?.category ?? choices.firstOrNull?.category;
    final unavailable =
        !widget.loading && widget.data != null && choices.isEmpty;
    final message = widget.message ??
        (unavailable
            ? 'Payment is temporarily unavailable. Please try again.'
            : null);
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      bottomNavigationBar: ColoredBox(
        color: AppColors.surface,
        child: SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (quote != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text('Total to Pay', style: theme.bodyMedium),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            quote.formattedAmount,
                            textAlign: TextAlign.end,
                            style: theme.titleLarge?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    style: FilledButton.styleFrom(animationDuration: _motion),
                    onPressed: !widget.loading && chosen?.category == active
                        ? widget.onContinue
                        : null,
                    child: const Text('Continue to Payment',
                        textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          children: [
            if (quote != null) ...[
              _summary(quote),
              const SizedBox(height: 16),
            ],
            Text('Choose a payment method',
                style: theme.titleLarge
                    ?.copyWith(fontSize: 23, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              widget.data?.selectionMethods.isNotEmpty == true
                  ? 'Billplz shows available options at checkout.'
                  : 'Continue to secure checkout with Billplz.',
              style: theme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            if (widget.loading) ...[
              LinearProgressIndicator(
                  value: _motion == Duration.zero ? 0.6 : null),
              const SizedBox(height: 8),
              const Text('Getting your payment ready…'),
            ],
            if (!widget.loading && message != null) ...[
              Text(message),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                    onPressed: widget.onRetry, child: const Text('Try again')),
              ),
            ],
            for (final category in ['fpx', 'ewallet', 'card', 'other'])
              if (choices.any((choice) => choice.category == category))
                _category(
                  category,
                  choices
                      .where((choice) => choice.category == category)
                      .toList(),
                  expanded: active == category,
                ),
          ],
        ),
      ),
    );
  }

  Widget _summary(BookingPaymentQuote quote) {
    final theme = Theme.of(context).textTheme;
    final data = widget.data;
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            expanded: _details,
            button: true,
            child: InkWell(
              onTap: () => setState(() => _details = !_details),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    const _CategoryIcon(Icons.event_note_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Booking summary',
                              style: theme.titleMedium?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w700)),
                          Text(
                              '${quote.coachName} · ${quote.durationMinutes} min',
                              style: theme.bodyMedium
                                  ?.copyWith(color: AppColors.inkSoft)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _chevron(_details),
                  ],
                ),
              ),
            ),
          ),
          _resize(
            !_details
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (data?.localDate != null)
                          Text(
                              '${data!.localDate} · ${data.startLabel} – ${data.endLabel}'),
                        Text(quote.branchName),
                        if (quote.voucherApplied)
                          const Text('Premium Coach voucher included'),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chevron(bool expanded) => ExcludeSemantics(
        child: AnimatedRotation(
          turns: expanded ? .5 : 0,
          duration: _motion,
          child:
              const Icon(Icons.expand_more, size: 20, color: AppColors.inkSoft),
        ),
      );

  Widget _category(String category, List<BookingPaymentChoice> choices,
      {required bool expanded}) {
    final (title, icon) = switch (category) {
      'fpx' => ('Online Banking / FPX', Icons.account_balance_outlined),
      'ewallet' => ('E-Wallet', Icons.account_balance_wallet_outlined),
      'card' => ('Credit / Debit Card', Icons.credit_card_outlined),
      _ => ('Secure payment', Icons.lock_outline_rounded),
    };
    final hasMoreBanks =
        category == 'fpx' && choices.length > _bankPreviewCount;
    final preview =
        hasMoreBanks ? choices.take(_bankPreviewCount).toList() : choices;
    final extra = hasMoreBanks
        ? choices
            .skip(_bankPreviewCount)
            .where((bank) => bank.code == widget.selected)
            .firstOrNull
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: expanded ? AppColors.primaryTint : AppColors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: expanded,
              child: InkWell(
                onTap: widget.loading
                    ? null
                    : () => setState(() => _activeCategory = category),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        _CategoryIcon(icon),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: expanded
                                        ? AppColors.primaryDark
                                        : AppColors.ink,
                                    fontWeight: FontWeight.w700,
                                  )),
                        ),
                        const SizedBox(width: 8),
                        _chevron(expanded),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _resize(
              !expanded
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Divider(height: 1, color: AppColors.hairline),
                          for (final choice in [
                            ...preview,
                            if (extra != null) extra
                          ])
                            _PaymentChoiceRow(
                              choice: choice,
                              selected: widget.selected == choice.code,
                              onTap: widget.loading
                                  ? null
                                  : () => widget.onSelect(choice.code),
                            ),
                          if (hasMoreBanks)
                            TextButton(
                              onPressed: widget.loading
                                  ? null
                                  : () => _moreBanks(choices),
                              child: const Row(
                                children: [
                                  Expanded(child: Text('More Banks')),
                                  Icon(Icons.chevron_right, size: 20),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox.square(
            dimension: 34,
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
        ),
      );
}

class _PaymentChoiceRow extends StatelessWidget {
  const _PaymentChoiceRow(
      {required this.choice, required this.selected, this.onTap});

  final BookingPaymentChoice choice;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: true,
        child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryTint : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      PaymentMethodIcon(iconKey: choice.iconKey, size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(choice.name,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: selected
                                          ? AppColors.primaryDark
                                          : AppColors.ink,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    )),
                      ),
                      const SizedBox(width: 8),
                      ExcludeSemantics(
                        child: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 20,
                          color:
                              selected ? AppColors.primary : AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _BankPicker extends StatefulWidget {
  const _BankPicker({required this.banks, required this.selected});

  final List<BookingPaymentChoice> banks;
  final String? selected;

  @override
  State<_BankPicker> createState() => _BankPickerState();
}

class _BankPickerState extends State<_BankPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final banks = widget.banks
        .where((bank) => bank.name.toLowerCase().contains(_query))
        .toList();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: keyboard > 0 ? 1 : .74,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('More Banks',
                            style: Theme.of(context).textTheme.headlineMedium),
                      ),
                      IconButton(
                        tooltip: 'Close bank list',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search banks',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (text) =>
                          setState(() => _query = text.trim().toLowerCase()),
                    ),
                  ),
                ),
                if (banks.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No banks match your search.'),
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: banks.length,
                    itemBuilder: (_, index) {
                      final bank = banks[index];
                      return _PaymentChoiceRow(
                        choice: bank,
                        selected: bank.code == widget.selected,
                        onTap: () => Navigator.pop(context, bank.code),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
