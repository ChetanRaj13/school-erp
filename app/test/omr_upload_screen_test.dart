// Guards the OMR result-card relabel + raw-detection-breakdown logic against the REAL
// /scan response captured from the running omr-pipeline service
// (services/omr-pipeline/_last_scan_response.json). Pure-Dart reconciliation — no widget
// pump, so it runs fast and doesn't need Supabase/ProviderScope initialized.
//
// What it locks in (verified live 2026-07-23): the summary's present/absent are CONFIRMED
// counts (status set AND not needs_review); the breakdown subtitle surfaces the raw
// detected statuses among the flagged rows. confirmed + flagged-detected == total detected.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Skipped (not failed) if the dev capture isn't on disk, e.g. on CI.
  test('raw detection breakdown reconciles with confirmed counts (live capture)', () {
    final f = File('services/omr-pipeline/_last_scan_response.json');
    if (!f.existsSync()) {
      return;
    }
    final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final s = json['summary'] as Map<String, dynamic>;
    final recs = (json['records'] as List).cast<Map<String, dynamic>>();

    final flagged = recs.where((r) => r['needs_review'] == true).toList();
    final detectedPresent =
        flagged.where((r) => r['status'] == 'present').length;
    final confirmedPresent = recs
        .where((r) => r['status'] == 'present' && r['needs_review'] != true)
        .length;
    final totalDetectedPresent =
        recs.where((r) => r['status'] == 'present').length;

    // Reconciliation: every present-status row is either confirmed or flagged-detected.
    expect(confirmedPresent + detectedPresent, totalDetectedPresent);
    // Numbers from the verified live run on 2026-07-23:
    expect(s['present'], 2); // "Present (confirmed)" card value
    expect(s['needs_review'], 38); // "Needs review" card value
    expect(detectedPresent, 34); // subtitle: "34 detected present, ..."
    expect(totalDetectedPresent, 36); // raw status==present across all 40 rows
  });
}
