import 'package:gainpath_ui/gainpath_ui.dart';

/// System/back-button protection. A confirmed save may still pop directly.
class Module1EditGuard extends UnsavedChangesGuard {
  const Module1EditGuard(
      {super.key,
      required super.dirty,
      required super.busy,
      required super.child});
}
