import type { Capability } from './capabilities.ts'

// ---------------------------------------------------------------------------
// Value types that cross the driver boundary
// ---------------------------------------------------------------------------

/**
 * Accepted primitive values for a form field.
 * - string: text, email, multiline, date, datetime, select
 * - number: number
 * - boolean: checkbox
 */
export type FieldValue = string | number | boolean

export type FieldType =
  | 'text'
  | 'email'
  | 'number'
  | 'date'
  | 'datetime'
  | 'multiline'
  | 'select'
  | 'checkbox'

export type Row = Record<string, unknown> & { _id: string }

export interface Message {
  text: string
  level: 'info' | 'success' | 'warning' | 'error'
}

export interface UserSnapshot {
  id: string
  email: string
  displayName: string
  roles: ReadonlyArray<string>
}

// ---------------------------------------------------------------------------
// ComponentSnapshot — framework-neutral view of what's on a page
// ---------------------------------------------------------------------------

interface BaseSnapshot {
  /** Honors visibleWhen, role gates, and any other ODS visibility rules. */
  visible: boolean
}

export interface TextSnapshot extends BaseSnapshot {
  kind: 'text'
  /** Formula-resolved final string. */
  content: string
}

export interface FormFieldSnapshot {
  name: string
  type: FieldType
  label: string
  value: FieldValue | null
  required: boolean
  /** Validation error attached to this field, if any. */
  error: string | null
}

export interface FormSnapshot extends BaseSnapshot {
  kind: 'form'
  id: string
  fields: FormFieldSnapshot[]
}

export interface ListSnapshot extends BaseSnapshot {
  kind: 'list'
  dataSource: string
  columnFields: string[]
  rowCount: number
  sortField: string | null
  sortDir: 'asc' | 'desc' | null
}

export interface KanbanSnapshot extends BaseSnapshot {
  kind: 'kanban'
  dataSource: string
  statusField: string
  columns: Array<{ status: string; cardCount: number }>
}

export interface ChartSnapshot extends BaseSnapshot {
  kind: 'chart'
  dataSource: string
  chartType: 'bar' | 'line' | 'pie'
  title: string | null
  seriesCount: number
}

export interface ButtonSnapshot extends BaseSnapshot {
  kind: 'button'
  label: string
  enabled: boolean
}

export interface SummarySnapshot extends BaseSnapshot {
  kind: 'summary'
  label: string
  value: string
}

export interface TabsSnapshot extends BaseSnapshot {
  kind: 'tabs'
  tabs: Array<{ label: string; active: boolean }>
}

export interface DetailSnapshot extends BaseSnapshot {
  kind: 'detail'
  dataSource: string
  fields: Array<{ name: string; label: string; value: unknown }>
}

export type ComponentSnapshot =
  | TextSnapshot
  | FormSnapshot
  | ListSnapshot
  | KanbanSnapshot
  | ChartSnapshot
  | ButtonSnapshot
  | SummarySnapshot
  | TabsSnapshot
  | DetailSnapshot

// ---------------------------------------------------------------------------
// The OdsDriver interface every renderer implements
// ---------------------------------------------------------------------------

/**
 * ODS-shaped spec — we accept `object` at the boundary because each
 * framework has its own internal model type. The driver is responsible
 * for parsing via its framework's parser.
 */
export type OdsSpec = Record<string, unknown>

export interface OdsDriver {
  /** Capabilities this driver implements. Read at construction. */
  readonly capabilities: ReadonlySet<Capability>

  // -- Lifecycle -------------------------------------------------------------

  /** Load a spec and reach the ready state (first page rendered). */
  mount(spec: OdsSpec): Promise<void>

  /** Tear down. Safe to call after any failure. */
  unmount(): Promise<void>

  /**
   * Clear all app data but keep the spec loaded. Faster than
   * unmount + mount. Called between scenario steps by the runner.
   */
  reset(): Promise<void>

  // -- Input -----------------------------------------------------------------

  /**
   * Set a value on a form field, addressed by the field's spec `name`.
   * For forms that appear more than once on a page, `formId` is
   * required; otherwise the single form on the page is implied.
   */
  fillField(fieldName: string, value: FieldValue, formId?: string): Promise<void>

  /**
   * Click a button, addressed by its visible label. For duplicate
   * labels, the nth occurrence (0-based) is selected.
   */
  clickButton(label: string, occurrence?: number): Promise<void>

  /** Click a row-level action in a list. */
  clickRowAction(
    dataSource: string,
    rowId: string,
    actionLabel: string,
  ): Promise<void>

  /**
   * Drag a kanban card to a different status column. Effectively an
   * update of the row's statusField to `toStatus`.
   */
  dragCard(
    dataSource: string,
    rowId: string,
    toStatus: string,
  ): Promise<void>

  /** Navigate via a menu item (matches ODS menu[].label). */
  clickMenuItem(label: string): Promise<void>

  // -- Observation -----------------------------------------------------------

  /** Identity of the currently shown page. */
  currentPage(): Promise<{ id: string; title: string }>

  /**
   * Structured snapshot of everything on the current page.
   * Preserves the spec's `content[]` order.
   */
  pageContent(): Promise<ComponentSnapshot[]>

  /**
   * All rows in a data source, sorted by `_id` asc for determinism.
   * Filters/sorts currently applied in a list component are NOT
   * reflected here — this is the authoritative data, not UI state.
   */
  dataRows(dataSource: string): Promise<Row[]>

  /**
   * Live form field values (what would be submitted if you clicked
   * submit right now).
   */
  formValues(formId: string): Promise<Record<string, FieldValue>>

  /**
   * The most recent message (toast / banner / alert) emitted by an
   * action. Null if nothing has been emitted since last reset/mount.
   */
  lastMessage(): Promise<Message | null>

  // -- Auth ------------------------------------------------------------------

  /** Login with email + password. Returns true on success. */
  login(email: string, password: string): Promise<boolean>

  /** Logout. Safe to call when already logged out. */
  logout(): Promise<void>

  /**
   * Create an account (for selfRegistration specs). Returns user id on
   * success, null on failure.
   */
  registerUser(params: {
    email: string
    password: string
    displayName?: string
    role?: string
  }): Promise<string | null>

  /** Current authenticated user, or null for a guest session. */
  currentUser(): Promise<UserSnapshot | null>

  // -- Determinism -----------------------------------------------------------

  /** Fix "now" for default-value resolution (CURRENTDATE, NOW, +7d). */
  setClock(isoTimestamp: string): Promise<void>

  /** Seed the RNG used for generated IDs / slugs. */
  setSeed(seed: number): Promise<void>
}
