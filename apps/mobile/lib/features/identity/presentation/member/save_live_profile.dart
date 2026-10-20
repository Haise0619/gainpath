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
      if (error is FitnessProfileException && error.reloadRequired) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${error.message} Reload discards this form.'),
          action: SnackBarAction(
              label: 'Reload',
              onPressed: () async {
                await cubit.load();
                if (context.mounted &&
                    {FitnessProfileStatus.ready, FitnessProfileStatus.missing}
                        .contains(cubit.state.status)) {
                  Navigator.pop(context);
                }
              }),
        ));
        return;
      }
      showToast(
          context,
          error is FitnessProfileException
              ? error.message
              : 'Could not save your profile. Please retry.');
    }
  }
}
