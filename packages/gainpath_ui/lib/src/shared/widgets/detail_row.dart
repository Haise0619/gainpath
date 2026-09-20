import 'package:flutter/material.dart';

/// Row of label and value, used inside detail panels.
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const DetailRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
