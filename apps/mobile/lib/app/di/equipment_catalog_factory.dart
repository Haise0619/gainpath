import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../infrastructure/firebase/firebase_equipment_reader.dart';
import '../../features/workout/presentation/member/equipment_browse_screen.dart';
import '../../features/workout/presentation/member/equipment_scanner_screen.dart';

typedef EquipmentReaderFactory = EquipmentReader Function(
    SessionScope, SessionScope? Function());

Widget buildMemberEquipmentCatalog(AuthSession expected,
        {EquipmentReaderFactory? factory}) =>
    Builder(builder: (context) {
      final auth = context.read<AuthBloc>();
      SessionScope? active() => context.mounted &&
              auth.state.session?.scope == expected.scope &&
              AuthRolePolicy.canEnter(auth.state,
                  allowed: const {AppRole.member})
          ? expected.scope
          : null;
      final reader = factory?.call(expected.scope, active) ??
          FirebaseEquipmentReader(scope: expected.scope, activeScope: active);
      return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => active() == expected.scope
              ? EquipmentBrowseScreen(reader: reader)
              : const Scaffold(
                  body: Center(
                      child:
                          Text('Equipment is unavailable for this account.'))));
    });

Widget buildMemberEquipmentScanner(AuthSession expected,
        {EquipmentReaderFactory? factory, VoidCallback? onBrowse}) =>
    Builder(builder: (context) {
      final auth = context.read<AuthBloc>();
      SessionScope? active() => context.mounted &&
              auth.state.session?.scope == expected.scope &&
              AuthRolePolicy.canEnter(auth.state,
                  allowed: const {AppRole.member})
          ? expected.scope
          : null;
      final reader = factory?.call(expected.scope, active) ??
          FirebaseEquipmentReader(scope: expected.scope, activeScope: active);
      return BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => active() == expected.scope
              ? EquipmentScannerScreen(
                  connected: true,
                  organizationId: expected.scope.organizationId,
                  reader: reader,
                  onBrowse: onBrowse ??
                      () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  EquipmentBrowseScreen(reader: reader))),
                )
              : const Scaffold(
                  body: Center(
                      child:
                          Text('Scanner is unavailable for this account.'))));
    });
