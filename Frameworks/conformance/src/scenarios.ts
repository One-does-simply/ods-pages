import type { Capability } from './capabilities.ts'
import type { OdsDriver, OdsSpec } from './contract.ts'

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
// Spec helpers — keep specs readable inline, but factor out the common
// shape so scenarios stay terse.
// ---------------------------------------------------------------------------

function miniTodoSpec(): OdsSpec {
  return {
    appName: 'Mini Todo',
    startPage: 'home',
    pages: {
      home: {
        component: 'page',
        title: 'Home',
        content: [
          {
            component: 'form',
            id: 'addForm',
            dataSource: 'tasks',
            fields: [
              { name: 'title', type: 'text', label: 'Title', required: true },
              { name: 'done', type: 'checkbox', label: 'Done' },
            ],
          },
          {
            component: 'button',
            label: 'Save',
            onClick: [
              { action: 'submit', dataSource: 'tasks', target: 'addForm' },
              { action: 'showMessage', message: 'Saved!', level: 'success' },
            ],
          },
          {
            component: 'list',
            dataSource: 'tasks',
            columns: [
              { field: 'title', label: 'Title' },
              { field: 'done', label: 'Done' },
            ],
          },
        ],
      },
    },
    dataSources: {
      tasks: {
        url: 'local://tasks',
        method: 'POST',
        fields: [
          { name: 'title', type: 'text' },
          { name: 'done', type: 'checkbox' },
        ],
      },
    },
  }
}

function twoPageSpec(): OdsSpec {
  return {
    appName: 'Two Page',
    startPage: 'home',
    menu: [
      { label: 'Home', mapsTo: 'home' },
      { label: 'Second', mapsTo: 'second' },
    ],
    pages: {
      home: {
        component: 'page',
        title: 'Home',
        content: [
          { component: 'text', content: 'Welcome home' },
          {
            component: 'button',
            label: 'Go Second',
            onClick: [{ action: 'navigate', target: 'second' }],
          },
        ],
      },
      second: {
        component: 'page',
        title: 'Second',
        content: [
          { component: 'text', content: 'On the second page' },
        ],
      },
    },
    dataSources: {},
  }
}

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

function miniTodoWithDeleteSpec(): OdsSpec {
  return {
    appName: 'Mini Todo Delete',
    startPage: 'home',
    pages: {
      home: {
        component: 'page',
        title: 'Home',
        content: [
          {
            component: 'form',
            id: 'addForm',
            dataSource: 'tasks',
            fields: [
              { name: 'title', type: 'text', label: 'Title', required: true },
            ],
          },
          {
            component: 'button',
            label: 'Save',
            onClick: [
              { action: 'submit', dataSource: 'tasks', target: 'addForm' },
            ],
          },
          {
            component: 'list',
            dataSource: 'tasks',
            columns: [{ field: 'title', label: 'Title' }],
            rowActions: [
              {
                label: 'Delete',
                action: 'delete',
                dataSource: 'tasks',
                matchField: '_id',
              },
            ],
          },
        ],
      },
    },
    dataSources: {
      tasks: {
        url: 'local://tasks',
        method: 'POST',
        fields: [{ name: 'title', type: 'text' }],
      },
    },
  }
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

function visibleWhenFieldSpec(): OdsSpec {
  return {
    appName: 'VisibleWhen Field',
    startPage: 'home',
    pages: {
      home: {
        component: 'page',
        title: 'Home',
        content: [
          {
            component: 'form',
            id: 'gateForm',
            fields: [
              {
                name: 'mode',
                type: 'select',
                label: 'Mode',
                options: ['basic', 'advanced'],
              },
            ],
          },
          {
            component: 'text',
            content: 'Advanced-only details',
            visibleWhen: { form: 'gateForm', field: 'mode', equals: 'advanced' },
          },
        ],
      },
    },
    dataSources: {},
  }
}

function visibleWhenDataSpec(): OdsSpec {
  return {
    appName: 'VisibleWhen Data',
    startPage: 'home',
    pages: {
      home: {
        component: 'page',
        title: 'Home',
        content: [
          {
            component: 'form',
            id: 'addForm',
            dataSource: 'items',
            fields: [
              { name: 'title', type: 'text', label: 'Title', required: true },
            ],
          },
          {
            component: 'button',
            label: 'Save',
            onClick: [{ action: 'submit', dataSource: 'items', target: 'addForm' }],
          },
          {
            component: 'text',
            content: 'No items yet — add one above.',
            visibleWhen: { source: 'items', countEquals: 0 },
          },
          {
            component: 'list',
            dataSource: 'items',
            columns: [{ field: 'title', label: 'Title' }],
            visibleWhen: { source: 'items', countMin: 1 },
          },
        ],
      },
    },
    dataSources: {
      items: {
        url: 'local://items',
        method: 'POST',
        fields: [{ name: 'title', type: 'text' }],
      },
    },
  }
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

function currentDateDefaultSpec(): OdsSpec {
  return {
    appName: 'CURRENTDATE default',
    startPage: 'home',
    pages: {
      home: {
        component: 'page',
        title: 'Home',
        content: [
          {
            component: 'form',
            id: 'editForm',
            fields: [
              { name: 'title', type: 'text', label: 'Title' },
              {
                name: 'createdAt',
                type: 'date',
                label: 'Created',
                default: 'CURRENTDATE',
              },
            ],
          },
        ],
      },
    },
    dataSources: {},
  }
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
]
