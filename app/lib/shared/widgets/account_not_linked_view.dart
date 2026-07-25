import 'package:flutter/material.dart';

/// Shown instead of fabricated or wrong data whenever a screen needs to know "which
/// staff/student row belongs to this logged-in user" and can't, because that linkage
/// doesn't exist yet in the schema (see core/auth/self_record_provider.dart and the
/// README for the full explanation + the migration that fixes this).
///
/// Deliberately not a silent empty state — it explains WHY nothing is showing, since
/// an unexplained blank screen looks like a bug rather than a known, documented gap.
class AccountNotLinkedView extends StatelessWidget {
  const AccountNotLinkedView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off, size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              message ?? "Your account isn't linked to a school record yet.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask an admin to link your account, then check back here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
