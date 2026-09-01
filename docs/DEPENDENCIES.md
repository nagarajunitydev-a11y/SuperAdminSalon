# Dependencies: spacrm_super_admin

## Production Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| flutter | SDK | Flutter framework |
| cupertino_icons | ^1.0.8 | iOS-style icons |
| firebase_core | ^4.14.0 | Firebase core functionality |
| firebase_auth | ^6.6.0 | Firebase Authentication |
| cloud_firestore | ^6.9.0 | Firestore database |
| flutter_riverpod | ^3.4.2 | State management |
| go_router | ^17.5.0 | Declarative routing |
| fl_chart | ^1.2.0 | Charts and graphs |
| intl | ^0.20.3 | Internationalization and localization |

## Development Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| flutter_test | SDK | Flutter testing framework |
| flutter_lints | ^6.0.0 | Recommended lints for Flutter/Dart |

## Dependency Notes
- All Firebase packages are aligned to compatible versions
- Riverpod chosen for its compile-time safety and scalability
- GoRouter provides type-safe navigation with deep linking support
- fl_chart enables data visualization for analytics dashboard
- intl supports localization for global deployment

## Outdated Dependencies
As of the last check, several packages have newer versions available but are constrained by version compatibility requirements. Consider running `flutter pub upgrade --major-versions` after testing for breaking changes.

## Installation
Run `flutter pub get` to install all dependencies.