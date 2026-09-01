# Project Architecture: spacrm_super_admin

## Overview
This Flutter application is a super admin dashboard for managing salon businesses. It follows a layered architecture with separation of concerns using Riverpod for state management and GoRouter for navigation.

## Project Structure
```
lib/
├── app/                    # Application-level configurations
│   ├── router.dart         # App routing configuration
│   ├── theme.dart          # Theme definitions (light/dark)
│   └── shell.dart          # App shell/layout
├── core/                   # Shared utilities, widgets, and constants
│   ├── constants/          # Firebase collection names and other constants
│   ├── state/              # Reusable state controllers
│   ├── utils/              # Helper functions (formatters, date ranges)
│   └── widgets/            # Reusable UI components (KPI cards, charts, etc.)
├── features/               # Feature modules (each follows domain/data/presentation)
│   ├── auth/               # Authentication feature
│   │   ├── data/           # Data layer (repositories, Firebase implementations)
│   │   ├── domain/         # Business logic (entities, use cases)
│   │   └── presentation/   # UI layer (pages, controllers, widgets)
│   ├── dashboard/          # Dashboard with metrics and analytics
│   ├── salons/             # Salon management
│   ├── analytics/          # Analytics and reporting
│   ├── audit/              # Audit trail and logs
│   └── settings/           # Application settings
├── firebase_options.dart   # Firebase configuration for different platforms
└── main.dart               # App entry point
```

## Key Architectural Decisions
1. **State Management**: Flutter Riverpod chosen for its performance, testability, and scalability
2. **Navigation**: GoRouter for declarative, type-safe routing
3. **Firebase Integration**: Firestore for real-time data with persistence enabled
4. **Feature Modularization**: Each feature is self-contained with clear separation of concerns
5. **Web-First Design**: Optimized for browser deployment with responsive layouts

## Data Flow
1. UI layer (presentation) interacts with state controllers (providers)
2. Controllers communicate with repository interfaces (domain layer)
3. Repository implementations handle data operations (data layer)
4. Data layer interfaces with Firebase services (Firestore, Auth)
5. Real-time updates stream back through the same layers

## Security Considerations
- Firebase Authentication with email/password
- Firestore security rules (should be defined separately)
- Sensitive data handling follows best practices
- Web-specific considerations for CSRF and XSS prevention

## Deployment Targets
- Primary: Web browser (Chrome, Edge, Safari)
- Secondary: Potential for PWA deployment
- Build command: `flutter build web`