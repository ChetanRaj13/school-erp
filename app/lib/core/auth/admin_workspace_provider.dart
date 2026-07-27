import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Admin's active workspace: HR or Finance. Controls which sidebar sections
/// are visible plus which overview screen renders at /admin.
enum AdminWorkspace { hr, finance }

/// Notifier so the sidebar's SegmentedButton can call .state = ... directly.
class AdminWorkspaceNotifier extends StateNotifier<AdminWorkspace> {
  AdminWorkspaceNotifier() : super(AdminWorkspace.finance);

  void setWorkspace(AdminWorkspace ws) => state = ws;
}

final adminWorkspaceProvider =
    StateNotifierProvider<AdminWorkspaceNotifier, AdminWorkspace>((ref) {
  return AdminWorkspaceNotifier();
});
