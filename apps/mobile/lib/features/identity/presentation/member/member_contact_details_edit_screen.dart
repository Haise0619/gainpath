import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'member_contact_details_panel.dart';

/// Focused edit screen for member display name and contact information.
class MemberContactDetailsEditScreen extends StatelessWidget {
  const MemberContactDetailsEditScreen({
    super.key,
    this.session,
    this.repository,
    this.onDisplayNameSaved,
  });

  final AuthSession? session;
  final MemberContactDetailsRepository? repository;
  final ValueChanged<String>? onDisplayNameSaved;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile & Contact'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: MemberContactDetailsPanel(
            session: session,
            repository: repository,
            onDisplayNameSaved: onDisplayNameSaved,
          ),
        ),
      ),
    );
  }
}
