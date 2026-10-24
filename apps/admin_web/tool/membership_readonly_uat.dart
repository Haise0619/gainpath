// Local UAT entry point only. Not imported by the product or deployed to Hosting.
import 'package:cloud_functions/cloud_functions.dart'
    show FirebaseFunctionsException;
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_function_transport.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_admin_web/features/identity/presentation/admin/member_membership_verification_panel.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_member_directory_repository.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_bootstrap.dart';

const targetMember = String.fromEnvironment('MEMBERSHIP_UAT_TARGET');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(targetMember)) {
    throw StateError('Exact existing UAT target is required.');
  }
  await initializeGainPathFirebase();
  runApp(MaterialApp(
    title: 'GainPath Membership — read-only UAT',
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      appBar:
          AppBar(title: const Text('Membership verification — read-only UAT')),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snapshot.data;
          if (user == null) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'No existing Admin session. Sign in through your usual '
                  'GainPath Admin page at this same origin, then reload this view. '
                  'Do not create an account or change any role.'),
            );
          }
          if (!user.emailVerified) {
            return const Text(
                'Current account is not email-verified. UAT blocked.');
          }
          return _ScopedVerification(key: ValueKey(user.uid), user: user);
        },
      ),
    ),
  ));
}

class _ScopedVerification extends StatefulWidget {
  const _ScopedVerification({super.key, required this.user});
  final User user;
  @override
  State<_ScopedVerification> createState() => _ScopedVerificationState();
}

class _ScopedVerificationState extends State<_ScopedVerification> {
  late final FirebaseAdminMemberDirectoryRepository repository;
  String result = 'Not requested';
  int requests = 0;
  @override
  void initState() {
    super.initState();
    repository = FirebaseAdminMemberDirectoryRepository(
      scope: SessionScope(userId: widget.user.uid, organizationId: 'gainpath'),
      isCurrent: () =>
          mounted && FirebaseAuth.instance.currentUser?.uid == widget.user.uid,
      membershipCall: (name, input) async {
        if (name != 'verifyMemberMembershipCommand' ||
            input.length != 3 ||
            input['schemaVersion'] != 1 ||
            input['organizationId'] != 'gainpath' ||
            input['memberId'] != targetMember ||
            ++requests > 3) {
          throw StateError('Read-only UAT allowlist rejected the request.');
        }
        try {
          final response =
              (await firebaseCallable(name).call<Map<String, dynamic>>(input))
                  .data;
          if (mounted) {
            setState(() => result = 'Server result: ${response['status']}');
          }
          return response;
        } on FirebaseFunctionsException catch (error) {
          if (mounted) {
            setState(() => result = 'Server rejection: ${error.code}');
          }
          rethrow;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
              'Existing session only. The server must authorize the Admin role. '
              'Only the previously approved Member fixture can be verified. '
              'No directory search, payment, account or policy mutation is available.'),
          Text(
              'Signed-in account: ${widget.user.email ?? 'Email unavailable'}'),
          Text(result),
          MemberMembershipVerificationPanel(
              memberId: targetMember, repository: repository),
        ]),
      );
}
