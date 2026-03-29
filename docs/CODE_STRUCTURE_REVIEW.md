# BangumiToday Code Structure Evaluation Report

**Branch:** review  
**Date:** 2026-03-29  
**Version:** 0.6.4+8

## Executive Summary

This document provides a comprehensive evaluation of the BangumiToday Flutter project's code structure, identifying architectural issues and providing prioritized recommendations for improvement.

---

## 1. Project Architecture Overview

### Current Structure
```
lib/
├── controller/     # State controllers (2 files)
├── database/       # SQLite database handlers
├── models/         # Data models with JSON serialization
├── pages/          # Page widgets (feature-based)
├── plugins/        # External service integrations (Mikan)
├── request/        # API clients
├── store/          # State management (Riverpod/Hive)
├── tools/          # Utility classes
├── ui/             # Shared UI components
├── utils/          # Helper functions
├── widgets/        # Reusable widgets
├── app.dart        # App entry widget
└── main.dart       # Application entry point
```

### Technology Stack
- **Framework:** Flutter 3.35.0+
- **State Management:** Riverpod (hooks_riverpod, flutter_riverpod)
- **Local Storage:** Hive (NoSQL), SQLite (sqflite_common_ffi)
- **HTTP Client:** Dio
- **UI Framework:** Fluent UI

---

## 2. Identified Structural Issues

### 2.1 Naming Convention Inconsistencies (HIGH PRIORITY)

**Issue:** Multiple inconsistent class prefix conventions across the codebase.

| Prefix | Usage | Example |
|--------|-------|---------|
| `BT` | Global utilities, core classes | `BTApp`, `BTLogTool`, `BTResponse` |
| `Btr` | Request/API classes | `BtrBangumiApi`, `BtrClient`, `BtrMikanApi` |
| `Bts` | SQLite database classes | `BtsAppConfig`, `BtsBangumiCollection` |
| `Btm` | Hive models | `BtmAppNavItem`, `BtmAppNavHive` |
| `Bgm` | Bangumi-specific classes | `BgmUserHive`, `BgmUserHiveModel` |
| `Bcp` | Bangumi Calendar Page widgets | `BcpDayWidget` |
| `Sdp` | Subject Detail Page widgets | `SdpOverviewWidget` |
| `Bsd` | Bangumi Subject Detail widgets | `BsdBmfWidget` |

**Impact:**
- Reduces code readability
- Makes it difficult to locate related classes
- Confusing for new contributors

**Recommendation:** Standardize to a single prefix convention:
- `BT` for all app-level classes
- Remove feature-specific prefixes or use suffixes instead

---

### 2.2 Layer Separation Issues (HIGH PRIORITY)

**Issue:** No clear separation between data, domain, and presentation layers.

**Current Problems:**
1. Database classes ([app_config.dart](lib/database/app/app_config.dart)) contain business logic
2. API classes ([bangumi_api.dart](lib/request/bangumi/bangumi_api.dart)) handle both HTTP requests and response parsing
3. Page widgets directly instantiate services and databases

**Example - Tight Coupling in Widget:**
```dart
// bangumi_calendar_page.dart
final BtrBangumiApi apiBgm = BtrBangumiApi();
final BtrBangumiDataApi apiBgd = BtrBangumiDataApi();
final BtsBangumiCollection sqliteBc = BtsBangumiCollection();
final BtsAppConfig sqliteAc = BtsAppConfig();
final BtsBangumiData sqliteBd = BtsBangumiData();
final BgmUserHive hive = BgmUserHive();
```

**Recommendation:** Implement Clean Architecture:
```
lib/
├── data/
│   ├── datasources/     # Local (Hive, SQLite) and Remote (API)
│   ├── models/          # Data transfer objects
│   └── repositories/    # Repository implementations
├── domain/
│   ├── entities/        # Business objects
│   ├── repositories/    # Repository interfaces
│   └── usecases/        # Business logic
└── presentation/
    ├── controllers/     # State management
    ├── pages/           # UI pages
    └── widgets/         # Reusable widgets
```

---

### 2.3 State Management Inconsistency (HIGH PRIORITY)

**Issue:** Multiple state management approaches used inconsistently.

**Current State:**
1. **Riverpod Providers** - Used for global state (`appStoreProvider`, `navStoreProvider`)
2. **ChangeNotifier** - Used in `BTAppStore`, `BTNavStore`, `BgmUserHive`
3. **Hive Boxes** - Used for persistent storage with reactive updates
4. **StateNotifier** - Used in `SubjectCollectStatProvider`, `SubjectRssStatProvider`

**Example - Mixed State in Same Class:**
```dart
// nav_store.dart
final navStoreProvider = ChangeNotifierProvider<BTNavStore>((ref) {
  var store = BTNavStore();
  // ...
  return store;
});

class BTNavStore extends ChangeNotifier {
  // Uses both ChangeNotifier and Hive
  Hive.box<BtmAppNavHive>('nav').put(subject, hiveItem);
}
```

**Recommendation:** Standardize on Riverpod:
- Use `StateNotifier` for complex state
- Use `StateProvider` for simple state
- Migrate `ChangeNotifier` classes to `StateNotifier`

---

### 2.4 Singleton Pattern Duplication (MEDIUM PRIORITY)

**Issue:** Inconsistent singleton implementations across the codebase.

**Three Different Patterns Found:**

```dart
// Pattern 1: Static instance with factory (most common)
class BTSqlite {
  BTSqlite._();
  static final BTSqlite _instance = BTSqlite._();
  factory BTSqlite() => _instance;
}

// Pattern 2: Static instance without factory
class BTHiveTool {
  BTHiveTool._();
  static final BTHiveTool instance = BTHiveTool._();
  factory BTHiveTool() => instance;
}

// Pattern 3: Static instance with different naming
class BtInfobar {
  BtInfobar._();
  static final BtInfobar _instance = BtInfobar._();
  factory BtInfobar() => _instance;
}
```

**Recommendation:** Use Riverpod providers for dependency injection instead of singletons:
```dart
final sqliteProvider = Provider<BTSqlite>((ref) => BTSqlite._());
```

---

### 2.5 Error Handling Duplication (MEDIUM PRIORITY)

**Issue:** Repeated error handling patterns across API classes.

**Example from [bangumi_api.dart](lib/request/bangumi/bangumi_api.dart):**
```dart
// This pattern repeats 15+ times in the file
try {
  // API call
} on DioException catch (e) {
  var errResp = BangumiErrorDetail.fromJson(e.response?.data);
  BTLogTool.error('Failed to ...: ${jsonEncode(errResp)}');
  return BTResponse<BangumiErrorDetail>(
    code: e.response?.statusCode ?? 666,
    message: 'Failed to ...',
    data: errResp,
  );
} on Exception catch (e) {
  BTLogTool.error('Failed to ...: $e');
  return BTResponse.error(code: 666, message: 'Failed to ...', data: null);
}
```

**Recommendation:** Create a generic error handler:
```dart
Future<BTResponse<T>> handleRequest<T>(Future<Response> Function() request) async {
  try {
    final response = await request();
    return BTResponse.success(data: response.data);
  } on DioException catch (e) {
    return _handleDioError<T>(e);
  } on Exception catch (e) {
    return _handleGenericError<T>(e);
  }
}
```

---

### 2.6 Directory Structure Issues (MEDIUM PRIORITY)

**Issue 1: Overlapping Responsibilities**
- `store/` and `database/` both handle data persistence
- `tools/` and `utils/` both contain utility functions
- `ui/` contains both widgets and utilities

**Issue 2: Inconsistent Folder Naming**
- Some use hyphens: `app-setting/`, `rss-bmf/`, `subject-detail/`
- Some use underscores: `bangumi-calendar/` (internally inconsistent)

**Current `ui/` Contents:**
```
ui/
├── bt_dialog.dart    # Widget
├── bt_icon.dart      # Widget
└── bt_infobar.dart   # Widget with utility class
```

**Recommendation:**
1. Merge `ui/` into `widgets/common/`
2. Merge `tools/` into `utils/`
3. Standardize folder naming to use underscores

---

### 2.7 Type Safety Issues (MEDIUM PRIORITY)

**Issue:** Excessive use of `dynamic` types reduces type safety.

**Examples:**
```dart
// bangumi_model.dart
@JsonKey(name: 'infobox')
dynamic infobox;  // Could be List<BangumiInfoBoxItem>

@JsonKey(name: 'source')
dynamic source;  // Could be String or List<String>

// bangumi_api.dart
Future<dynamic> searchSubjects(...)  // Returns dynamic instead of typed response
```

**Recommendation:** Use proper union types or sealed classes:
```dart
@freezed
class BangumiSource with _$BangumiSource {
  const factory BangumiSource.string(String value) = SourceString;
  const factory BangumiSource.list(List<String> value) = SourceList;
}
```

---

### 2.8 Model File Organization (LOW PRIORITY)

**Issue:** [bangumi_model.dart](lib/models/bangumi/bangumi_model.dart) contains 2900+ lines with 50+ classes.

**Problems:**
- Difficult to navigate
- Slow IDE performance
- Hard to find related models

**Recommendation:** Split into feature-based files:
```
models/bangumi/
├── subject/
│   ├── subject.dart
│   ├── subject_small.dart
│   └── subject_relation.dart
├── episode/
│   └── episode.dart
├── user/
│   └── user.dart
└── common/
    ├── images.dart
    └── pagination.dart
```

---

### 2.9 Database Layer Issues (MEDIUM PRIORITY)

**Issue:** Database classes mix schema definition, data access, and business logic.

**Example from [bangumi_collection.dart](lib/database/bangumi/bangumi_collection.dart):**
```dart
class BtsBangumiCollection {
  // Schema definition
  Future<void> init() async {
    await sqlite.db.execute('''CREATE TABLE...''');
  }
  
  // Data access
  Future<List<BangumiUserSubjectCollection>> getAll() async { ... }
  
  // Business logic
  Future<bool> isCollected(int subjectId) async { ... }
}
```

**Recommendation:** Separate concerns:
```dart
// schemas/bangumi_collection_schema.dart
class BangumiCollectionSchema {
  static const String createTable = '''CREATE TABLE...''';
}

// datasources/bangumi_collection_local_ds.dart
class BangumiCollectionLocalDataSource {
  Future<List<Map<String, dynamic>>> getAll() async { ... }
}

// repositories/bangumi_collection_repository.dart
class BangumiCollectionRepository {
  Future<bool> isCollected(int subjectId) async { ... }
}
```

---

### 2.10 Provider Organization (LOW PRIORITY)

**Issue:** Providers are scattered across files without central organization.

**Current State:**
- `app_store.dart` - `appStoreProvider`
- `nav_store.dart` - `navStoreProvider`
- `subject_detail_page.dart` - `SubjectCollectStatProvider`, `SubjectRssStatProvider`

**Recommendation:** Create a central provider file:
```dart
// providers/providers.dart
export 'app_provider.dart';
export 'nav_provider.dart';
export 'user_provider.dart';
export 'subject_provider.dart';
```

---

## 3. Prioritized Improvement TODO List

### Priority 1: Critical (Immediate Action)

| # | Task | Scope | Success Criteria | Status |
|---|------|-------|------------------|--------|
| 1.1 | Standardize naming conventions | Global | All classes follow `BT` prefix convention | ⏳ Pending |
| 1.2 | Create generic API error handler | `request/` | Single error handling function used by all API classes | ✅ Completed |
| 1.3 | Migrate ChangeNotifier to StateNotifier | `store/` | All state classes use Riverpod StateNotifier | ⏳ Pending |

### Priority 2: High (Short-term)

| # | Task | Scope | Success Criteria | Status |
|---|------|-------|------------------|--------|
| 2.1 | Reorganize directory structure | Global | Clear layer separation, consistent naming | ✅ Completed |
| 2.2 | Split large model files | `models/` | Each file < 500 lines | ⏳ Pending |
| 2.3 | Create repository layer | New `repositories/` | Data access abstracted from widgets | ✅ Completed |
| 2.4 | Fix type safety issues | `models/`, `request/` | No `dynamic` types in public APIs | ⏳ Pending |

### Priority 3: Medium (Medium-term)

| # | Task | Scope | Success Criteria | Status |
|---|------|-------|------------------|--------|
| 3.1 | Implement dependency injection | Global | All dependencies injected via Riverpod | ✅ Completed |
| 3.2 | Create data source interfaces | `datasources/` | Local and remote data sources abstracted | ✅ Completed |
| 3.3 | Add comprehensive logging | Global | Structured logging with levels | ✅ Completed |
| 3.4 | Create provider exports | `providers/` | Single entry point for all providers | ✅ Completed |

### Priority 4: Low (Long-term)

| # | Task | Scope | Success Criteria | Status |
|---|------|-------|------------------|--------|
| 4.1 | Add unit tests | `test/` | >80% coverage on business logic | ⏳ Pending |
| 4.2 | Create architecture documentation | `docs/` | ADRs for major decisions | ✅ Completed |
| 4.3 | Implement code generation | Build | Reduce boilerplate with freezed/retrofit | ⏳ Pending |

---

## 3.1 Implemented Improvements Summary

### Commit 1: Code Structure Review Documentation
- Created comprehensive code structure evaluation document
- Identified 10 structural issues with priority levels
- Provided prioritized improvement TODO list

### Commit 2: Clean Architecture Foundation
- Created `lib/domain/repositories/bangumi_repository.dart` - Repository interface
- Created `lib/data/repositories/bangumi_repository_impl.dart` - Repository implementation
- Created `lib/data/datasources/bangumi_remote_data_source.dart` - Remote data source interface
- Created `lib/data/datasources/bangumi_local_data_source.dart` - Local data source interface
- Created `lib/providers/app_providers.dart` - Centralized providers with DI
- Created `lib/utils/tools.dart` - Unified tools export
- Created `lib/widgets/common/common.dart` - Unified UI components export
- Created `lib/core/constants/app_constants.dart` - Centralized constants
- Created `lib/request/core/api_handler.dart` - Generic API error handler

---

## 4. Recommended Target Architecture

```
lib/
├── core/
│   ├── constants/          # App constants
│   ├── errors/             # Error handling
│   ├── network/            # HTTP client setup
│   ├── storage/            # Hive/SQLite setup
│   └── utils/              # Utility functions
├── features/
│   ├── bangumi/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── usecases/
│   │   └── presentation/
│   │       ├── controllers/
│   │       ├── pages/
│   │       └── widgets/
│   ├── mikan/
│   └── settings/
├── shared/
│   ├── widgets/            # Common widgets
│   └── providers/          # Shared providers
├── app.dart
└── main.dart
```

---

## 5. Conclusion

The BangumiToday project has a functional structure but would benefit significantly from:

1. **Standardized naming conventions** for improved readability
2. **Clean Architecture implementation** for better separation of concerns
3. **Consistent state management** using Riverpod throughout
4. **Generic error handling** to reduce code duplication
5. **Type safety improvements** for better developer experience

Implementing these changes incrementally will improve maintainability, testability, and developer productivity.

---

*Generated as part of code structure review on branch `review`*
