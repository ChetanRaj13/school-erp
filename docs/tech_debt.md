# Technical Debt & Retired Code Tracking

## Retired Features & Cleanups

### [2026-08-14] Background Preset Photo System Removal
- **Files Deleted**:
  - `app/lib/core/theme/background_presets.dart`
  - `app/lib/core/theme/background_preset_provider.dart`
- **Rationale**: The previous "nature matte glass" theme and its photo-backdrop preset picker (mountain trail, study hall, library) have been retired in favor of the clean, high-contrast flat design system ("Contra wireframe kit" style). `settings_screen.dart` and `warm_backdrop.dart` have been migrated to the flat solid canvas, making these two files dead code.
- **Verification**: Verified zero remaining imports across the codebase prior to deletion.

### [2026-08-14] Redundant / Unrouted Dashboards (Candidates for Future Cleanup)
- `app/lib/features/dashboard/teacher/teacher_dashboard.dart`
- `app/lib/features/dashboard/student/student_dashboard.dart`
- `app/lib/features/dashboard/parent/parent_dashboard.dart`
*Note: These files were the older single-scroll dashboard implementations prior to the StatefulShellRoute / RoleShell transition and are currently unrouted.*
