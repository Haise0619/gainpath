import 'package:flutter/material.dart';
import 'package:gainpath/app/theme/theme.dart';

void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
}
