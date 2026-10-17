import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../../../infrastructure/firebase/firebase_coach_account_repository.dart';

/// Auth changes replace the entire route subtree, disposing transient evidence.
class CoachAccountSessionGuard extends StatelessWidget {
  const CoachAccountSessionGuard(
      {super.key, required this.repository, required this.child});
  final FirebaseCoachAccountRepository repository;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
        try {
          repository.check();
          return child;
        } catch (_) {
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted &&
                ModalRoute.of(context)?.isCurrent == true &&
                Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
          return const Scaffold(
              body: Center(
                  child: Text(
                      'This Coach session has ended. Close this screen and sign in again.')));
        }
      });
}
