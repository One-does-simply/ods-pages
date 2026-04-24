import type { Capability } from './capabilities.ts'
import type { OdsDriver, OdsSpec } from './contract.ts'
import { loadSpec } from './load-spec.ts'

/**
 * A parity scenario is a single (name, spec, capabilities, run) tuple.
 * The runner constructs a driver, calls `mount(spec)`, invokes `run`,
 * then `unmount()`. Assertions inside `run` throw on failure; the
 * runner maps throws to test failures in its host framework.
 */
export interface Scenario {
  /** Human-readable name — used as the test case name in vitest etc. */
  name: string

  /**
   * Fresh spec for each run. Functions rather than literals so
   * scenarios can parameterize by timestamp / random / etc. without
   * leaking state across runs.
   */
  spec: () => OdsSpec

  /**
   * Capabilities the scenario exercises. Runner skips (doesn't fail)
   * a scenario whose capabilities aren't all in the driver's
   * `capabilities` set.
   */
  capabilities: ReadonlyArray<Capability>

  /**
   * The scenario body. Drivers are fresh on entry (mount already
   * called); runners call unmount after return or throw.
   */
  run: (driver: OdsDriver) => Promise<void>
}

// ---------------------------------------------------------------------------
// Tiny assertion helpers — scenarios should be framework-agnostic, so we
// can't use vitest's expect here. These throw plain Errors which the
// runner catches and re-raises as test failures.
// ---------------------------------------------------------------------------

function assertEqual<T>(actual: T, expected: T, msg?: string): void {
  if (actual !== expected) {
    throw new Error(
      `${msg ?? 'assertion failed'}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    )
  }
}

function assertTrue(value: unknown, msg: string): void {
  if (!value) throw new Error(msg)
}

// ---------------------------------------------------------------------------
// Spec helpers — each spec lives in specs/<name>.json and is loaded on
// demand. Factories wrap loadSpec() so scenario tables can reference
// them by name and the Dart runner mirrors the same `<name>.json` keys.
// ---------------------------------------------------------------------------

const miniTodoSpec = (): OdsSpec => loadSpec('miniTodo')
const twoPageSpec = (): OdsSpec => loadSpec('twoPage')
const miniTodoWithDeleteSpec = (): OdsSpec => loadSpec('miniTodoWithDelete')
const visibleWhenFieldSpec = (): OdsSpec => loadSpec('visibleWhenField')
const visibleWhenDataSpec = (): OdsSpec => loadSpec('visibleWhenData')
const currentDateDefaultSpec = (): OdsSpec => loadSpec('currentDateDefault')
const multiUserAppSpec = (): OdsSpec => loadSpec('multiUserApp')
const submitThenNavigateSpec = (): OdsSpec => loadSpec('submitThenNavigate')
const rowActionUpdateSpec = (): OdsSpec => loadSpec('rowActionUpdate')
const formulaComputeSpec = (): OdsSpec => loadSpec('formulaCompute')
const summaryAggregateSpec = (): OdsSpec => loadSpec('summaryAggregate')

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------

export const s01_spec_loads: Scenario = {
  name: 'spec loads and start page renders',
  spec: miniTodoSpec,
  capabilities: ['core'],
  run: async (d) => {
    const page = await d.currentPage()
    assertEqual(page.id, 'home', 'current page id')
    assertEqual(page.title, 'Home', 'current page title')
  },
}

export const s02_form_submit_inserts_row: Scenario = {
  name: 'form submit inserts a row into the data source',
  spec: miniTodoSpec,
  capabilities: ['core', 'action:submit'],
  run: async (d) => {
    await d.fillField('title', 'Buy milk')
    await d.clickButton('Save')
    const rows = await d.dataRows('tasks')
    assertEqual(rows.length, 1, 'row count after submit')
    assertEqual(rows[0].title, 'Buy milk', 'row title')
  },
}

export const s03_show_message_after_submit: Scenario = {
  name: 'showMessage after submit surfaces a message',
  spec: miniTodoSpec,
  capabilities: ['core', 'action:submit', 'action:showMessage'],
  run: async (d) => {
    await d.fillField('title', 'Eat lunch')
    await d.clickButton('Save')
    const msg = await d.lastMessage()
    assertTrue(msg != null, 'expected a message after Save')
    assertEqual(msg!.text, 'Saved!', 'message text')
    assertEqual(msg!.level, 'success', 'message level')
  },
}

export const s04_list_reflects_submitted_rows: Scenario = {
  name: 'list component row count tracks submitted rows',
  spec: miniTodoSpec,
  capabilities: ['core', 'action:submit'],
  run: async (d) => {
    await d.fillField('title', 'Row one')
    await d.clickButton('Save')
    await d.fillField('title', 'Row two')
    await d.clickButton('Save')

    const content = await d.pageContent()
    const list = content.find((c) => c.kind === 'list')
    assertTrue(list != null, 'list component present on the page')
    assertEqual((list as { rowCount: number }).rowCount, 2, 'list row count')
  },
}

export const s05_navigate_action_switches_page: Scenario = {
  name: 'navigate action moves to the target page',
  spec: twoPageSpec,
  capabilities: ['core', 'action:navigate'],
  run: async (d) => {
    const before = await d.currentPage()
    assertEqual(before.id, 'home', 'start page')

    await d.clickButton('Go Second')

    const after = await d.currentPage()
    assertEqual(after.id, 'second', 'page after navigate')
    assertEqual(after.title, 'Second', 'title after navigate')
  },
}

export const s06_row_action_delete_removes_row: Scenario = {
  name: 'rowAction delete removes the matching row from the data source',
  spec: miniTodoWithDeleteSpec,
  capabilities: ['core', 'action:submit', 'action:delete', 'rowActions'],
  run: async (d) => {
    await d.fillField('title', 'Keep me')
    await d.clickButton('Save')
    await d.fillField('title', 'Delete me')
    await d.clickButton('Save')

    const before = await d.dataRows('tasks')
    assertEqual(before.length, 2, 'two rows before delete')

    const target = before.find((r) => r.title === 'Delete me')
    assertTrue(target != null, 'expected "Delete me" row to exist')
    await d.clickRowAction('tasks', String(target!._id), 'Delete')

    const after = await d.dataRows('tasks')
    assertEqual(after.length, 1, 'one row after delete')
    assertEqual(after[0].title, 'Keep me', 'surviving row is the one we kept')
  },
}

export const s07_visible_when_field_condition: Scenario = {
  name: 'visibleWhen field-based condition hides/shows components with form state',
  spec: visibleWhenFieldSpec,
  capabilities: ['core'],
  run: async (d) => {
    // Initially `mode` is blank — the advanced text should be hidden.
    const before = await d.pageContent()
    const textBefore = before.find((c) => c.kind === 'text')
    assertTrue(textBefore != null, 'text component present')
    assertEqual(textBefore!.visible, false, 'advanced text hidden before mode is set')

    await d.fillField('mode', 'advanced')

    const after = await d.pageContent()
    const textAfter = after.find((c) => c.kind === 'text')
    assertTrue(textAfter != null, 'text component still present')
    assertEqual(textAfter!.visible, true, 'advanced text visible after mode=advanced')

    await d.fillField('mode', 'basic')
    const later = await d.pageContent()
    const textLater = later.find((c) => c.kind === 'text')
    assertEqual(textLater!.visible, false, 'advanced text hidden again after mode=basic')
  },
}

export const s08_visible_when_data_count: Scenario = {
  name: 'visibleWhen data-source count condition tracks row additions',
  spec: visibleWhenDataSpec,
  capabilities: ['core', 'action:submit'],
  run: async (d) => {
    // Zero rows → "No items yet" visible, list hidden.
    const before = await d.pageContent()
    const emptyText = before.find((c) => c.kind === 'text')
    const list = before.find((c) => c.kind === 'list')
    assertTrue(emptyText != null, 'empty-state text present')
    assertTrue(list != null, 'list present (snapshot emitted even when hidden)')
    assertEqual(emptyText!.visible, true, 'empty-state text visible at 0 rows')
    assertEqual(list!.visible, false, 'list hidden at 0 rows')

    await d.fillField('title', 'First item')
    await d.clickButton('Save')

    const after = await d.pageContent()
    const emptyTextAfter = after.find((c) => c.kind === 'text')
    const listAfter = after.find((c) => c.kind === 'list')
    assertEqual(emptyTextAfter!.visible, false, 'empty-state text hidden after 1 row')
    assertEqual(listAfter!.visible, true, 'list visible after 1 row')
  },
}

export const s09_current_date_default_honors_clock: Scenario = {
  name: 'CURRENTDATE default value resolves using the driver clock',
  spec: currentDateDefaultSpec,
  capabilities: ['core'],
  run: async (d) => {
    // The harness already set the clock to 2026-01-01T00:00:00Z before run.
    const initial = await d.formValues('editForm')
    assertEqual(
      initial.createdAt,
      '2026-01-01',
      'CURRENTDATE resolved using the clock set by the harness',
    )

    // Move the clock; the default should pick up the new "now" lazily.
    await d.setClock('2026-06-15T12:00:00Z')
    const later = await d.formValues('editForm')
    assertEqual(
      later.createdAt,
      '2026-06-15',
      'CURRENTDATE reflects the updated clock on the next formValues call',
    )

    // Explicitly setting a field overrides the magic default.
    await d.fillField('createdAt', '2020-12-25')
    const overridden = await d.formValues('editForm')
    assertEqual(
      overridden.createdAt,
      '2020-12-25',
      'explicit fillField overrides the magic default',
    )
  },
}

export const s10_register_then_login_flow: Scenario = {
  name: 'registerUser creates an account; subsequent login authenticates that user',
  spec: multiUserAppSpec,
  capabilities: ['core', 'auth:multiUser', 'auth:selfRegistration'],
  run: async (d) => {
    // No user, no session.
    const beforeAny = await d.currentUser()
    assertEqual(beforeAny, null, 'no user before registration')

    // Register — AuthService.registerUser does NOT auto-login, so the
    // session should still be empty immediately after.
    const newId = await d.registerUser({
      email: 'alice@example.com',
      password: 'secret-password',
      displayName: 'Alice',
    })
    assertTrue(newId != null, 'registerUser should return a non-null id')

    const afterRegister = await d.currentUser()
    assertEqual(afterRegister, null, 'registerUser does not auto-login')

    // Login with the new credentials.
    const ok = await d.login('alice@example.com', 'secret-password')
    assertEqual(ok, true, 'login with correct credentials succeeds')

    const loggedIn = await d.currentUser()
    assertTrue(loggedIn != null, 'currentUser non-null after login')
    assertEqual(loggedIn!.email, 'alice@example.com', 'currentUser email')
    assertEqual(loggedIn!.displayName, 'Alice', 'currentUser displayName')
    assertTrue(
      loggedIn!.roles.includes('user'),
      `currentUser roles include default "user" (got ${JSON.stringify(loggedIn!.roles)})`,
    )

    // Logout returns to guest state.
    await d.logout()
    const afterLogout = await d.currentUser()
    assertEqual(afterLogout, null, 'currentUser null after logout')
  },
}

export const s11_login_with_wrong_password_fails: Scenario = {
  name: 'login with wrong password returns false and leaves session unchanged',
  spec: multiUserAppSpec,
  capabilities: ['core', 'auth:multiUser', 'auth:selfRegistration'],
  run: async (d) => {
    await d.registerUser({
      email: 'bob@example.com',
      password: 'correct-password',
    })

    const bad = await d.login('bob@example.com', 'wrong-password')
    assertEqual(bad, false, 'login with wrong password should return false')

    const user = await d.currentUser()
    assertEqual(user, null, 'no session after failed login')

    const good = await d.login('bob@example.com', 'correct-password')
    assertEqual(good, true, 'subsequent login with correct password succeeds')
  },
}

export const s12_submit_on_end_navigate: Scenario = {
  name: 'submit action with onEnd navigate lands on the target page after insert',
  spec: submitThenNavigateSpec,
  capabilities: ['core', 'action:submit', 'action:navigate'],
  run: async (d) => {
    const before = await d.currentPage()
    assertEqual(before.id, 'home', 'start on home page')

    await d.fillField('title', 'Go-to task')
    await d.clickButton('Save')

    const after = await d.currentPage()
    assertEqual(after.id, 'list', 'onEnd navigate lands us on the list page')
    assertEqual(after.title, 'All Tasks', 'page title reflects destination')

    // And the row was actually inserted — onEnd shouldn't skip the submit.
    const rows = await d.dataRows('tasks')
    assertEqual(rows.length, 1, 'submit inserted a row before firing onEnd')
    assertEqual(rows[0].title, 'Go-to task', 'inserted row matches fillField')
  },
}

export const s13_row_action_update_changes_field: Scenario = {
  name: 'rowAction update writes new field values to the matched row',
  spec: rowActionUpdateSpec,
  capabilities: ['core', 'action:submit', 'action:update', 'rowActions'],
  run: async (d) => {
    await d.fillField('title', 'Test task')
    await d.fillField('status', 'todo')
    await d.clickButton('Save')

    const before = await d.dataRows('tasks')
    assertEqual(before.length, 1, 'one row after submit')
    assertEqual(before[0].status, 'todo', 'row starts with status=todo')

    await d.clickRowAction('tasks', String(before[0]._id), 'Mark Done')

    const after = await d.dataRows('tasks')
    assertEqual(after.length, 1, 'update preserves row count')
    assertEqual(after[0].status, 'done', 'update set status=done')
    assertEqual(after[0].title, 'Test task', 'update leaves other fields alone')
  },
}

export const s14_formula_fields_compute_from_dependencies: Scenario = {
  name: 'formula fields compute from their dependencies and update on change',
  spec: formulaComputeSpec,
  capabilities: ['core', 'formulas'],
  run: async (d) => {
    // Formulas with any missing dependency resolve to "" — both the
    // number formula (math can't evaluate) and the text formula (string
    // interpolation guard on any empty ref).
    const empty = await d.formValues('orderForm')
    assertEqual(empty.total, '', 'total empty before dependencies filled')
    assertEqual(empty.fullName, '', 'fullName empty when any dependency is blank')

    await d.fillField('quantity', '5')
    await d.fillField('unitPrice', '10')
    const math = await d.formValues('orderForm')
    assertEqual(math.total, '50', 'total = quantity * unitPrice')

    await d.fillField('quantity', '6')
    const updated = await d.formValues('orderForm')
    assertEqual(updated.total, '60', 'total updates when a dependency changes')

    await d.fillField('firstName', 'Ada')
    await d.fillField('lastName', 'Lovelace')
    const text = await d.formValues('orderForm')
    assertEqual(
      text.fullName,
      'Ada Lovelace',
      'text formula interpolates field values',
    )
  },
}

export const s15_summary_aggregate_counts_rows: Scenario = {
  name: 'summary component value resolves aggregate expressions against data',
  spec: summaryAggregateSpec,
  capabilities: ['core', 'action:submit', 'summary'],
  run: async (d) => {
    const before = await d.pageContent()
    const sBefore = before.find((c) => c.kind === 'summary')
    assertTrue(sBefore != null, 'summary component present in snapshot')
    assertEqual(sBefore!.kind, 'summary', 'snapshot kind is summary')
    assertEqual(
      (sBefore as { value: string }).value,
      '0',
      'COUNT(tasks) is 0 with no rows',
    )

    for (const title of ['a', 'b', 'c']) {
      await d.fillField('title', title)
      await d.clickButton('Save')
    }

    const after = await d.pageContent()
    const sAfter = after.find((c) => c.kind === 'summary')
    assertEqual(
      (sAfter as { value: string }).value,
      '3',
      'COUNT(tasks) reflects three submissions',
    )
    assertEqual(
      (sAfter as { label: string }).label,
      'Total Tasks',
      'summary label is passed through from the spec',
    )
  },
}

/** Full list of scenarios the runner should execute. */
export const allScenarios: ReadonlyArray<Scenario> = [
  s01_spec_loads,
  s02_form_submit_inserts_row,
  s03_show_message_after_submit,
  s04_list_reflects_submitted_rows,
  s05_navigate_action_switches_page,
  s06_row_action_delete_removes_row,
  s07_visible_when_field_condition,
  s08_visible_when_data_count,
  s09_current_date_default_honors_clock,
  s10_register_then_login_flow,
  s11_login_with_wrong_password_fails,
  s12_submit_on_end_navigate,
  s13_row_action_update_changes_field,
  s14_formula_fields_compute_from_dependencies,
  s15_summary_aggregate_counts_rows,
]
