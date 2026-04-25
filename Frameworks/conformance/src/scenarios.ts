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
const ownershipPerUserSpec = (): OdsSpec => loadSpec('ownershipPerUser')
const tabsInitialStateSpec = (): OdsSpec => loadSpec('tabsInitialState')
const chartConfigSpec = (): OdsSpec => loadSpec('chartConfig')
const kanbanDragSpec = (): OdsSpec => loadSpec('kanbanDrag')
const cascadeRenameSpec = (): OdsSpec => loadSpec('cascadeRename')
const themeConfigSpec = (): OdsSpec => loadSpec('themeConfig')

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

export const s16_ownership_scopes_list_to_current_user: Scenario = {
  name: 'ownership-enabled data source hides rows owned by other users',
  spec: ownershipPerUserSpec,
  capabilities: [
    'core',
    'action:submit',
    'auth:multiUser',
    'auth:selfRegistration',
    'auth:ownership',
  ],
  run: async (d) => {
    // Alice creates two tasks.
    await d.registerUser({ email: 'alice@example.com', password: 'pw-alice-1' })
    await d.login('alice@example.com', 'pw-alice-1')
    await d.fillField('title', 'Alice task 1')
    await d.clickButton('Save')
    await d.fillField('title', 'Alice task 2')
    await d.clickButton('Save')

    // Alice sees her own two rows in the list snapshot.
    const aliceView = await d.pageContent()
    const aliceList = aliceView.find((c) => c.kind === 'list')
    assertEqual(
      (aliceList as { rowCount: number }).rowCount,
      2,
      'Alice sees her two rows',
    )

    // Bob creates one task.
    await d.logout()
    await d.registerUser({ email: 'bob@example.com', password: 'pw-bob-1' })
    await d.login('bob@example.com', 'pw-bob-1')
    await d.fillField('title', 'Bob task 1')
    await d.clickButton('Save')

    // Bob sees only his own row — Alice's two are hidden.
    const bobView = await d.pageContent()
    const bobList = bobView.find((c) => c.kind === 'list')
    assertEqual(
      (bobList as { rowCount: number }).rowCount,
      1,
      'Bob sees only his own row, not Alice\'s',
    )

    // Swap back to Alice — she still sees exactly her two rows.
    await d.logout()
    await d.login('alice@example.com', 'pw-alice-1')
    const aliceAgain = await d.pageContent()
    const aliceList2 = aliceAgain.find((c) => c.kind === 'list')
    assertEqual(
      (aliceList2 as { rowCount: number }).rowCount,
      2,
      'Alice still sees her two rows after Bob logged in and out',
    )

    // God view (dataRows) sees everything regardless of session.
    const allRows = await d.dataRows('tasks')
    assertEqual(allRows.length, 3, 'dataRows is unfiltered — sees all 3 rows')
  },
}

export const s17_tabs_snapshot_exposes_labels_and_first_active: Scenario = {
  name: 'tabs component snapshot reports labels in order with the first tab active',
  spec: tabsInitialStateSpec,
  capabilities: ['core', 'tabs'],
  run: async (d) => {
    const content = await d.pageContent()
    const tabs = content.find((c) => c.kind === 'tabs')
    assertTrue(tabs != null, 'tabs component present on the page')

    const tabList = (tabs as { tabs: Array<{ label: string; active: boolean }> }).tabs
    assertEqual(tabList.length, 3, 'three tabs declared in the spec')
    assertEqual(tabList[0].label, 'Overview', 'tab 0 label')
    assertEqual(tabList[1].label, 'Details', 'tab 1 label')
    assertEqual(tabList[2].label, 'Settings', 'tab 2 label')

    const activeCount = tabList.filter((t) => t.active).length
    assertEqual(activeCount, 1, 'exactly one tab is active')
    assertEqual(tabList[0].active, true, 'first tab is the active one by default')
  },
}

export const s18_chart_snapshot_preserves_config: Scenario = {
  name: 'chart component snapshot preserves chartType, title, and dataSource',
  spec: chartConfigSpec,
  capabilities: ['core', 'chart'],
  run: async (d) => {
    const content = await d.pageContent()
    const chart = content.find((c) => c.kind === 'chart')
    assertTrue(chart != null, 'chart component present on the page')
    const c = chart as {
      chartType: string
      title: string | null
      dataSource: string
    }
    assertEqual(c.chartType, 'bar', 'chart type propagates from spec')
    assertEqual(c.title, 'Tasks by Status', 'chart title propagates from spec')
    assertEqual(c.dataSource, 'tasks', 'chart dataSource propagates from spec')
  },
}

export const s19_kanban_drag_updates_status: Scenario = {
  name: 'dragging a kanban card updates the row status field',
  spec: kanbanDragSpec,
  capabilities: ['core', 'action:submit', 'action:update', 'kanban'],
  run: async (d) => {
    // Create three rows in three different columns.
    for (const [title, status] of [
      ['Task todo', 'todo'],
      ['Task doing', 'doing'],
      ['Task done', 'done'],
    ] as const) {
      await d.fillField('title', title)
      await d.fillField('status', status)
      await d.clickButton('Save')
    }

    const rowsBefore = await d.dataRows('tasks')
    assertEqual(rowsBefore.length, 3, 'three rows inserted')

    // Snapshot: kanban component reports columns + counts.
    const before = await d.pageContent()
    const kBefore = before.find((c) => c.kind === 'kanban')
    assertTrue(kBefore != null, 'kanban component present')
    const colsBefore = (
      kBefore as { columns: Array<{ status: string; cardCount: number }> }
    ).columns
    const todoBefore = colsBefore.find((c) => c.status === 'todo')
    const doingBefore = colsBefore.find((c) => c.status === 'doing')
    assertEqual(todoBefore?.cardCount ?? 0, 1, 'todo column has 1 card before drag')
    assertEqual(doingBefore?.cardCount ?? 0, 1, 'doing column has 1 card before drag')

    // Drag the todo card into doing.
    const todoRow = rowsBefore.find((r) => r.title === 'Task todo')
    assertTrue(todoRow != null, 'todo row exists')
    await d.dragCard('tasks', String(todoRow!._id), 'doing')

    // Row status changed; kanban counts shift.
    const rowsAfter = await d.dataRows('tasks')
    const draggedAfter = rowsAfter.find((r) => r._id === todoRow!._id)
    assertEqual(draggedAfter?.status, 'doing', 'dragged row now has status=doing')

    const after = await d.pageContent()
    const kAfter = after.find((c) => c.kind === 'kanban')
    const colsAfter = (
      kAfter as { columns: Array<{ status: string; cardCount: number }> }
    ).columns
    const todoAfter = colsAfter.find((c) => c.status === 'todo')
    const doingAfter = colsAfter.find((c) => c.status === 'doing')
    assertEqual(todoAfter?.cardCount ?? 0, 0, 'todo column empty after drag')
    assertEqual(doingAfter?.cardCount ?? 0, 2, 'doing column has 2 cards after drag')
  },
}

export const s20_cascade_rename_propagates_to_children: Scenario = {
  name: 'cascade update renames matching children after renaming the parent',
  spec: cascadeRenameSpec,
  capabilities: ['core', 'action:update', 'cascadeRename'],
  run: async (d) => {
    // Seed data is applied during spec load; verify the starting state.
    const cats0 = await d.dataRows('categories')
    const tasks0 = await d.dataRows('tasks')
    assertEqual(cats0.length, 2, 'two categories seeded')
    assertEqual(tasks0.length, 3, 'three tasks seeded')
    const workCount0 = tasks0.filter((t) => t.category === 'Work').length
    assertEqual(workCount0, 2, 'two tasks start with category=Work')

    await d.clickButton('Rename Work to Projects')

    // Parent: the Work category is now Projects; Home untouched.
    const cats1 = await d.dataRows('categories')
    const names = cats1.map((c) => c.name).sort()
    assertEqual(
      JSON.stringify(names),
      JSON.stringify(['Home', 'Projects']),
      'parent rename: Work -> Projects, Home untouched',
    )

    // Children: both Work tasks now point at Projects; Home task untouched.
    const tasks1 = await d.dataRows('tasks')
    const projectsCount = tasks1.filter((t) => t.category === 'Projects').length
    const homeCount = tasks1.filter((t) => t.category === 'Home').length
    const workCount1 = tasks1.filter((t) => t.category === 'Work').length
    assertEqual(projectsCount, 2, 'both Work tasks cascaded to Projects')
    assertEqual(homeCount, 1, 'Home task untouched by cascade')
    assertEqual(workCount1, 0, 'no tasks still pointing at old Work name')
  },
}

export const s21_theme_config_round_trips: Scenario = {
  name: 'theme config round-trips through the framework parser (ADR-0002)',
  spec: themeConfigSpec,
  capabilities: ['core', 'theme'],
  run: async (d) => {
    const t = await d.themeConfig()
    assertEqual(t.base, 'nord', 'theme.base from spec')
    assertEqual(t.mode, 'dark', 'theme.mode from spec')
    assertEqual(t.headerStyle, 'solid', 'theme.headerStyle from spec')
    assertEqual(
      t.overrides['primary'],
      'oklch(50% 0.2 260)',
      'theme.overrides.primary from spec',
    )
    assertEqual(
      t.overrides['fontSans'],
      'Inter',
      'theme.overrides.fontSans from spec',
    )
    assertEqual(
      t.logo,
      'https://example.com/logo.png',
      'top-level logo lifted out of branding',
    )
    assertEqual(
      t.favicon,
      'https://example.com/favicon.ico',
      'top-level favicon lifted out of branding',
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
  s16_ownership_scopes_list_to_current_user,
  s17_tabs_snapshot_exposes_labels_and_first_active,
  s18_chart_snapshot_preserves_config,
  s19_kanban_drag_updates_status,
  s20_cascade_rename_propagates_to_children,
  s21_theme_config_round_trips,
]
