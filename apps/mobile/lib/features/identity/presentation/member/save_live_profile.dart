import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

Future<void> saveLiveProfile(
  BuildContext context,
  FitnessProfileCubit cubit,
  FitnessProfile profile,
) async {
  try {
    await cubit.save(profile);
    if (context.mounted) Navigator.pop(context);
  } catch (error) {
    if (context.mounted) {
      showToast(
          context,
          error is FitnessProfileException
              ? error.message
              : 'Could not save your profile. Please retry.');
    }
  }
}
