/// Dart mirror of Frameworks/conformance/src/contract.ts.
///
/// Per CONVENTIONS.md, the conformance contract is duplicated per framework
/// while things are still in flux — the TypeScript version in
/// Frameworks/conformance/ is authoritative; this file shadows it in Dart so
/// the Flutter framework can drive the same scenarios without a
/// cross-language runtime.
///
/// Keep in sync with the TS contract. Any shape change there needs a mirror
/// edit here (and vice versa for any Dart-side addition).
library;

// ---------------------------------------------------------------------------
// Value types that cross the driver boundary
// ---------------------------------------------------------------------------

/// Accepted primitive values for a form field.
/// - String: text, email, multiline, date, datetime, select
/// - num:    number
/// - bool:   checkbox
typedef FieldValue = Object;

/// Keep in sync with contract.ts `FieldType`.
const fieldTypes = <String>{
  'text',
  'email',
  'number',
  'date',
  'datetime',
  'multiline',
  'select',
  'checkbox',
};

typedef Row = Map<String, Object?>;

class Message {
  const Message({required this.text, required this.level});
  final String text;

  /// One of 'info' | 'success' | 'warning' | 'error'.
  final String level;
}

class UserSnapshot {
  const UserSnapshot({
    required this.id,
    required this.email,
    required this.displayName,
    required this.roles,
  });
  final String id;
  final String email;
  final String displayName;
  final List<String> roles;
}

/// Effective theme as a framework should expose it after parsing the
/// spec. Used by the theme conformance scenario to verify both
/// frameworks produce the same shape (per ADR-0002).
class ThemeConfig {
  const ThemeConfig({
    required this.base,
    required this.mode,
    required this.headerStyle,
    required this.overrides,
    required this.logo,
    required this.favicon,
  });
  final String base;

  /// 'light' | 'dark' | 'system'.
  final String mode;

  /// 'solid' | 'light' | 'transparent'.
  final String headerStyle;

  /// Token overrides; empty map when none are present.
  final Map<String, String> overrides;
  final String? logo;
  final String? favicon;
}

// ---------------------------------------------------------------------------
// ComponentSnapshot — framework-neutral view of what's on a page
// ---------------------------------------------------------------------------

sealed class ComponentSnapshot {
  const ComponentSnapshot({required this.visible});
  final bool visible;
  String get kind;
}

class TextSnapshot extends ComponentSnapshot {
  const TextSnapshot({required super.visible, required this.content});
  final String content;
  @override
  String get kind => 'text';
}

class FormFieldSnapshot {
  const FormFieldSnapshot({
    required this.name,
    required this.type,
    required this.label,
    required this.value,
    required this.required,
    required this.error,
  });
  final String name;
  final String type;
  final String label;
  final FieldValue? value;
  final bool required;
  final String? error;
}

class FormSnapshot extends ComponentSnapshot {
  const FormSnapshot({
    required super.visible,
    required this.id,
    required this.fields,
  });
  final String id;
  final List<FormFieldSnapshot> fields;
  @override
  String get kind => 'form';
}

class ListSnapshot extends ComponentSnapshot {
  const ListSnapshot({
    required super.visible,
    required this.dataSource,
    required this.columnFields,
    required this.rowCount,
    required this.sortField,
    required this.sortDir,
    required this.displayedRowIds,
  });
  final String dataSource;
  final List<String> columnFields;
  final int rowCount;
  final String? sortField;

  /// 'asc' | 'desc' | null.
  final String? sortDir;

  /// Row `_id`s in displayed order after the driver applies defaultSort.
  /// See contract.ts for the cross-language contract.
  final List<String> displayedRowIds;
  @override
  String get kind => 'list';
}

class ButtonSnapshot extends ComponentSnapshot {
  const ButtonSnapshot({
    required super.visible,
    required this.label,
    required this.enabled,
  });
  final String label;
  final bool enabled;
  @override
  String get kind => 'button';
}

class SummarySnapshot extends ComponentSnapshot {
  const SummarySnapshot({
    required super.visible,
    required this.label,
    required this.value,
  });
  final String label;
  final String value;
  @override
  String get kind => 'summary';
}

class TabsTab {
  const TabsTab({required this.label, required this.active});
  final String label;
  final bool active;
}

class TabsSnapshot extends ComponentSnapshot {
  const TabsSnapshot({required super.visible, required this.tabs});
  final List<TabsTab> tabs;
  @override
  String get kind => 'tabs';
}

class ChartSnapshot extends ComponentSnapshot {
  const ChartSnapshot({
    required super.visible,
    required this.dataSource,
    required this.chartType,
    required this.title,
    required this.seriesCount,
  });
  final String dataSource;

  /// 'bar' | 'line' | 'pie'.
  final String chartType;
  final String? title;
  final int seriesCount;
  @override
  String get kind => 'chart';
}

class KanbanColumn {
  const KanbanColumn({required this.status, required this.cardCount});
  final String status;
  final int cardCount;
}

class KanbanSnapshot extends ComponentSnapshot {
  const KanbanSnapshot({
    required super.visible,
    required this.dataSource,
    required this.statusField,
    required this.columns,
  });
  final String dataSource;
  final String statusField;
  final List<KanbanColumn> columns;
  @override
  String get kind => 'kanban';
}

class DetailFieldEntry {
  const DetailFieldEntry({
    required this.name,
    required this.label,
    required this.value,
  });
  final String name;
  final String label;
  final Object? value;
}

class DetailSnapshot extends ComponentSnapshot {
  const DetailSnapshot({
    required super.visible,
    required this.dataSource,
    required this.fields,
  });
  final String dataSource;
  final List<DetailFieldEntry> fields;
  @override
  String get kind => 'detail';
}

// ---------------------------------------------------------------------------
// The OdsDriver interface every renderer implements
// ---------------------------------------------------------------------------

/// ODS-shaped spec — every renderer parses it with its own parser.
typedef OdsSpec = Map<String, Object?>;

abstract class OdsDriver {
  /// Capabilities this driver implements. Read at construction.
  Set<String> get capabilities;

  // -- Lifecycle -------------------------------------------------------------

  /// Load a spec and reach the ready state (first page rendered).
  Future<void> mount(OdsSpec spec);

  /// Tear down. Safe to call after any failure.
  Future<void> unmount();

  /// Clear all app data but keep the spec loaded.
  Future<void> reset();

  // -- Input -----------------------------------------------------------------

  /// Set a value on a form field, addressed by the field's spec `name`.
  /// For forms that appear more than once on a page, `formId` is required.
  Future<void> fillField(String fieldName, FieldValue value, {String? formId});

  /// Click a button, addressed by its visible label.
  /// For duplicate labels, `occurrence` (0-based) selects the nth.
  Future<void> clickButton(String label, {int occurrence = 0});

  /// Click a row-level action in a list.
  Future<void> clickRowAction(
    String dataSource,
    String rowId,
    String actionLabel,
  );

  /// Drag a kanban card to a different status column. Effectively an
  /// update of the row's statusField to `toStatus`.
  Future<void> dragCard(
    String dataSource,
    String rowId,
    String toStatus,
  );

  /// Navigate via a menu item (matches ODS `menu[].label`).
  Future<void> clickMenuItem(String label);

  // -- Observation -----------------------------------------------------------

  /// Identity of the currently shown page.
  Future<({String id, String title})> currentPage();

  /// Structured snapshot of everything on the current page.
  Future<List<ComponentSnapshot>> pageContent();

  /// All rows in a data source, sorted by `_id` asc for determinism.
  Future<List<Row>> dataRows(String dataSource);

  /// Live form field values.
  Future<Map<String, FieldValue>> formValues(String formId);

  /// The most recent message (toast / banner / alert) emitted by an action.
  Future<Message?> lastMessage();

  // -- Auth ------------------------------------------------------------------

  /// Login with email + password. Returns true on success.
  Future<bool> login(String email, String password);

  /// Logout. Safe to call when already logged out.
  Future<void> logout();

  /// Create an account (for `selfRegistration` specs).
  /// Returns user id on success, null on failure.
  Future<String?> registerUser({
    required String email,
    required String password,
    String? displayName,
    String? role,
  });

  /// Current authenticated user, or null for a guest session.
  Future<UserSnapshot?> currentUser();

  // -- Theme -----------------------------------------------------------------

  /// The effective theme + identity fields after parsing the spec. Used
  /// by the theme conformance scenario to verify both frameworks produce
  /// the same parse shape per ADR-0002. Drivers without the `theme`
  /// capability may throw.
  Future<ThemeConfig> themeConfig();

  // -- Determinism -----------------------------------------------------------

  /// Fix "now" for default-value resolution (CURRENTDATE, NOW, +7d).
  Future<void> setClock(String isoTimestamp);

  /// Seed the RNG used for generated IDs / slugs.
  Future<void> setSeed(int seed);
}
