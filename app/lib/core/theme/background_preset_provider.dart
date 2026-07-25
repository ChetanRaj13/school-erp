import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'background_presets.dart';

const _prefsKey = 'selected_background_preset';

/// Holds the user's chosen background preset, persisted locally via SharedPreferences.
/// UPDATED: default changed to studyHall (the new real-image default) now that real
/// presets exist — the old placeholder enum values (sageMeadow etc.) no longer exist,
/// so a previously-saved preference using those old names will simply fail the lookup
/// below and safely fall back to the default rather than crash.
class BackgroundPresetNotifier extends StateNotifier<BackgroundPresetId> {
  BackgroundPresetNotifier() : super(BackgroundPresetId.studyHall) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null) {
        final match = BackgroundPresetId.values.where((e) => e.name == saved);
        if (match.isNotEmpty) state = match.first;
      }
    } catch (_) {
      // Persistence is a nice-to-have, not load-bearing.
    }
  }

  Future<void> select(BackgroundPresetId id) async {
    state = id;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, id.name);
    } catch (_) {
      // Selection still applies for this session even if saving fails.
    }
  }
}

final backgroundPresetProvider = StateNotifierProvider<BackgroundPresetNotifier, BackgroundPresetId>(
  (ref) => BackgroundPresetNotifier(),
);
