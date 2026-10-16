import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AuthSession;
import 'package:gainpath_ui/gainpath_ui.dart';

/// App composition exposes only workflows with connected repositories.
abstract final class AdminFeatureAvailability {
  static const connected = {
    'Members',
    'Exercise Tutorials',
    'Routine Templates',
    'Coaches',
    'Announcements',
    'AI Chatbot Disclaimer',
    'System Settings',
    'Equipment Catalog'
  };
  static Widget page(String feature, AuthSession session) =>
      PageBody(children: [
        Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              feature == 'Dashboard'
                  ? 'Connected account'
                  : '$feature unavailable',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(session.displayName ?? session.email),
          Text(session.email),
          Text('Organization: ${session.organizationId}'),
          Text('Role: ${session.role.name}'),
          Text(
              'Branches: ${session.branchIds.isEmpty ? 'None assigned' : session.branchIds.join(', ')}'),
          const SizedBox(height: 12),
          Text(feature == 'Dashboard'
              ? 'Exercise Tutorials, Routine Templates, Coach Directory and Announcements are connected. Other operational modules are unavailable.'
              : 'This module is not connected to Firebase yet.'),
        ])),
      ]);
}
