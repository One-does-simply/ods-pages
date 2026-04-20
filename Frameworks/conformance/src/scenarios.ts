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
    // NOTE: asserting message *level* is deferred — the current OdsAction
    // parser doesn't preserve `level` from the spec. Track the parser
    // gap on TODO.md before adding a level-aware scenario.
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

/** Full list of scenarios the runner should execute. */
export const allScenarios: ReadonlyArray<Scenario> = [
  s01_spec_loads,
  s02_form_submit_inserts_row,
  s03_show_message_after_submit,
  s04_list_reflects_submitted_rows,
  s05_navigate_action_switches_page,
]
