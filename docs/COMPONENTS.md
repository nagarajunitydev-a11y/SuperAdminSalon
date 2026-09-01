# Key Components: spacrm_super_admin

## Core Components

### State Management (Riverpod)
- `ProviderScope`: Root provider container
- Various `StateNotifierProvider`s and `FutureProvider`s for managing UI state
- Example: `dashboardController`, `salonsController`, `authController`

### Navigation (GoRouter)
- `router.dart`: Defines all app routes with type safety
- Protected routes requiring authentication
- Redirect logic for auth guards

### Theme System
- `theme.dart`: Defines light and dark themes
- Custom color schemes, typography, and component themes
- Theme mode persistence via Riverpod

### Firebase Services
- Authentication: Email/password sign-in
- Firestore: Real-time database with offline persistence
- Initialization: Firebase options for multiple platforms

## Feature Modules

### Authentication (`features/auth`)
- **Pages**: `LoginPage`
- **Controllers**: Auth state management
- **Repositories**: `AuthRepository` (Firebase Auth implementation)
- **Domain**: `AdminUser` entity

### Dashboard (`features/dashboard`)
- **Pages**: `DashboardPage`
- **Controllers**: Metrics data fetching and processing
- **Repositories**: `MetricsRepository`
- **Domain**: `PlatformMetrics` model
- **Widgets**: KPI cards, charts, date range picker

### Salon Management (`features/salons`)
- **Pages**: `SalonsPage` (list), `SalonDetailPage` (detail/edit)
- **Controllers**: Salon list and form state
- **Repositories**: `SalonRepository`
- **Domain**: `Salon` entity
- **Operations**: CRUD operations with Firestore

### Analytics (`features/analytics`)
- **Pages**: Various analytics views
- **Data Layer**: `CatalogRepository` for aggregated data
- **Visualization**: fl_chart integration for reports

### Audit (`features/audit`)
- **Pages**: `AuditPage` for viewing logs
- **Repositories**: `AuditRepository`
- **Operations**: Read-only access to audit trail

### Settings (`features/settings`)
- **Pages**: `SettingsPage`
- **Functionality**: User preferences, app configuration

## Shared UI Components (`core/widgets`)
- **States**: Loading, error, empty states
- **KPI Card**: Metric display component
- **Charts**: Reusable chart wrappers
- **Date Range Picker**: Custom date selection
- **Form Fields**: Consistent input components

## Constants & Utilities
- **Collections**: Firebase collection name constants (`core/constants/collections.dart`)
- **Formatters**: Currency, date, number formatting (`core/utils/formatters.dart`)
- **Date Range**: Helper for date range calculations (`core/utils/date_range.dart`)

## Responsive Design
- All UI components designed for web browser responsiveness
- Adaptive layouts for different screen sizes
- Platform-aware interactions (mouse/keyboard vs touch)

## Security Features
- Protected routes requiring authentication
- Firestore persistence for offline capabilities
- Secure token storage (via Firebase Auth)
- Input validation and sanitization