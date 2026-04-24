import { useAppStore } from '../../src/engine/app-store.ts'
import { AuthService } from '../../src/engine/auth-service.ts'
import type { OdsAction } from '../../src/models/ods-action.ts'
import type { OdsApp } from '../../src/models/ods-app.ts'
import type {
  OdsComponent,
  OdsFormComponent,
  OdsButtonComponent,
  OdsListComponent,
  OdsKanbanComponent,
  OdsChartComponent,
  OdsSummaryComponent,
  OdsTabsComponent,
  OdsDetailComponent,
  OdsTextComponent,
} from '../../src/models/ods-component.ts'
import { tableName } from '../../src/models/ods-data-source.ts'
import { FakeDataService } from '../helpers/fake-data-service.ts'

import type {
  Capability,
  ComponentSnapshot,
  FieldType,
  FieldValue,
  Message,
  OdsDriver,
  OdsSpec,
  Row,
  UserSnapshot,
} from '../../../conformance/src/index.ts'

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function mockPb(): unknown {
  return {
    authStore: { isValid: false, record: null },
    collection: () => ({
      listAuthMethods: async () => ({ oauth2: { providers: [] } }),
    }),
  }
}

/** Find the OdsApp page model the store is currently on. */
function currentPageModel(app: OdsApp, pageId: string | null) {
  if (!pageId) return null
  return app.pages[pageId] ?? null
}

/** Shallow scan: buttons are expected at top-level page content for MVP scenarios. */
function findTopLevelButtons(
  components: ReadonlyArray<OdsComponent>,
  label: string,
): OdsButtonComponent[] {
  return components.filter(
    (c): c is OdsButtonComponent =>
      c.component === 'button' && (c as OdsButtonComponent).label === label,
  )
}

/** Find the single form component on the current page, or throw for ambiguity. */
function findSoleForm(
  components: ReadonlyArray<OdsComponent>,
): OdsFormComponent | null {
  const forms = components.filter(
    (c): c is OdsFormComponent => c.component === 'form',
  )
  if (forms.length === 0) return null
  if (forms.length > 1) {
    throw new Error(
      `fillField without formId is ambiguous: current page has ${forms.length} forms — pass formId explicitly`,
    )
  }
  return forms[0]
}

// ---------------------------------------------------------------------------
// ReactDriver
// ---------------------------------------------------------------------------

export class ReactDriver implements OdsDriver {
  readonly capabilities: ReadonlySet<Capability> = new Set<Capability>([
    'core',
    'kanban',
    'chart',
    'tabs',
    'detail',
    'summary',
    'formulas',
    'rowActions',
    'cascadeRename',
    'auth:multiUser',
    'auth:selfRegistration',
    'auth:ownership',
    'action:submit',
    'action:update',
    'action:delete',
    'action:navigate',
    'action:showMessage',
  ])

  private dataService: FakeDataService | null = null
  private authService: AuthService | null = null
  /** Mirrors the most recent showMessage action's message + level from the spec. */
  private _lastMessage: Message | null = null

  // -- Lifecycle -------------------------------------------------------------

  async mount(spec: OdsSpec): Promise<void> {
    const ds = new FakeDataService()
    const appNameRaw = (spec as { appName?: string }).appName
    ds.initialize(typeof appNameRaw === 'string' ? appNameRaw : 'conformance')
    this.dataService = ds

    const auth = new AuthService(mockPb() as never)
    this.authService = auth

    // Reset the Zustand singleton fully.
    useAppStore.getState().reset()
    this._lastMessage = null

    const ok = await useAppStore
      .getState()
      .loadSpec(JSON.stringify(spec), ds as never, auth)
    if (!ok) {
      const err = useAppStore.getState().loadError
      throw new Error(`loadSpec failed: ${err ?? '(no error message)'}`)
    }
  }

  async unmount(): Promise<void> {
    useAppStore.getState().reset()
    this.dataService = null
    this.authService = null
    this._lastMessage = null
  }

  async reset(): Promise<void> {
    // Keep the loaded spec + services but clear state. FakeDataService
    // doesn't expose a clear(), so re-initialize it with the same prefix.
    if (this.dataService) {
      const app = useAppStore.getState().app
      this.dataService.initialize(app?.appName ?? 'conformance')
    }
    useAppStore.setState({
      formStates: {},
      lastMessage: null,
      lastActionError: null,
    })
    this._lastMessage = null
  }

  // -- Input -----------------------------------------------------------------

  async fillField(
    fieldName: string,
    value: FieldValue,
    formId?: string,
  ): Promise<void> {
    const app = this.requireApp()
    const page = currentPageModel(app, useAppStore.getState().currentPageId)
    if (!page) throw new Error('fillField: no current page')

    let targetFormId = formId
    if (!targetFormId) {
      const form = findSoleForm(page.content)
      if (!form) throw new Error(`fillField: no form on current page`)
      targetFormId = form.id
    }

    useAppStore.getState().updateFormField(targetFormId, fieldName, String(value))
  }

  async clickButton(label: string, occurrence = 0): Promise<void> {
    const app = this.requireApp()
    const page = currentPageModel(app, useAppStore.getState().currentPageId)
    if (!page) throw new Error('clickButton: no current page')

    const matches = findTopLevelButtons(page.content, label)
    const button = matches[occurrence]
    if (!button) {
      throw new Error(
        `clickButton: no button with label="${label}" (occurrence ${occurrence}); found ${matches.length} matches`,
      )
    }

    // Capture the most recent showMessage in this action chain before
    // dispatching — the store only records the final `lastMessage`
    // string, not the declared level.
    const lastShowMsg = [...button.onClick]
      .reverse()
      .find((a: OdsAction) => a.action === 'showMessage')
    if (lastShowMsg?.message) {
      this._lastMessage = {
        text: lastShowMsg.message,
        level: lastShowMsg.level ?? 'info',
      }
    }

    await useAppStore.getState().executeActions(button.onClick)
  }

  async clickRowAction(
    _dataSource: string,
    _rowId: string,
    _actionLabel: string,
  ): Promise<void> {
    throw new Error('clickRowAction: not yet implemented in the MVP driver')
  }

  async clickMenuItem(label: string): Promise<void> {
    const app = this.requireApp()
    const item = app.menu.find((m) => m.label === label)
    if (!item) throw new Error(`clickMenuItem: no menu item "${label}"`)
    useAppStore.getState().navigateTo(item.mapsTo)
  }

  // -- Observation -----------------------------------------------------------

  async currentPage(): Promise<{ id: string; title: string }> {
    const app = this.requireApp()
    const id = useAppStore.getState().currentPageId ?? app.startPage
    const page = app.pages[id]
    return { id, title: page?.title ?? '' }
  }

  async pageContent(): Promise<ComponentSnapshot[]> {
    const app = this.requireApp()
    const pageId = useAppStore.getState().currentPageId
    const page = currentPageModel(app, pageId)
    if (!page) return []

    const snapshots: ComponentSnapshot[] = []
    for (const c of page.content) {
      const snap = await this.snapshotComponent(c)
      if (snap) snapshots.push(snap)
    }
    return snapshots
  }

  async dataRows(dataSource: string): Promise<Row[]> {
    const app = this.requireApp()
    const ds = app.dataSources[dataSource]
    if (!ds) throw new Error(`dataRows: unknown data source "${dataSource}"`)
    const rows = (await this.dataService!.query(tableName(ds))) as Row[]
    return [...rows].sort((a, b) =>
      String(a._id ?? '').localeCompare(String(b._id ?? '')),
    )
  }

  async formValues(formId: string): Promise<Record<string, FieldValue>> {
    const raw = useAppStore.getState().getFormState(formId)
    // FormValues are stored as strings; coerce checkboxes / numbers per spec.
    return { ...raw }
  }

  async lastMessage(): Promise<Message | null> {
    // Prefer the driver-tracked level; fall back to the store's string if
    // no action-level message was captured (e.g. showMessage dispatched
    // from somewhere the driver didn't mediate).
    if (this._lastMessage) return this._lastMessage
    const text = useAppStore.getState().lastMessage
    return text ? { text, level: 'info' } : null
  }

  // -- Auth ------------------------------------------------------------------

  async login(_email: string, _password: string): Promise<boolean> {
    throw new Error('login: not yet implemented (MVP driver)')
  }

  async logout(): Promise<void> {
    this.authService?.logout()
  }

  async registerUser(): Promise<string | null> {
    throw new Error('registerUser: not yet implemented (MVP driver)')
  }

  async currentUser(): Promise<UserSnapshot | null> {
    if (!this.authService || !this.authService.isLoggedIn) return null
    return {
      id: this.authService.currentUserId ?? '',
      email: this.authService.currentEmail ?? '',
      displayName: this.authService.currentDisplayName,
      roles: this.authService.currentRoles,
    }
  }

  // -- Determinism -----------------------------------------------------------

  async setClock(_iso: string): Promise<void> {
    // Not implemented for MVP — relative dates aren't exercised by the
    // first batch of scenarios. Follow-up work.
  }

  async setSeed(_seed: number): Promise<void> {
    // FakeDataService uses a counter; deterministic by construction.
  }

  // -- Internals -------------------------------------------------------------

  private requireApp(): OdsApp {
    const app = useAppStore.getState().app
    if (!app) throw new Error('driver not mounted — call mount(spec) first')
    return app
  }

  private async snapshotComponent(
    c: OdsComponent,
  ): Promise<ComponentSnapshot | null> {
    // visibleWhen evaluation — MVP treats "no visibleWhen" as visible.
    // Full evaluation would consult form state + record context.
    const visible = true

    switch (c.component) {
      case 'text': {
        const t = c as OdsTextComponent
        return { kind: 'text', visible, content: String(t.content ?? '') }
      }
      case 'form': {
        const f = c as OdsFormComponent
        const values = useAppStore.getState().getFormState(f.id)
        return {
          kind: 'form',
          visible,
          id: f.id,
          fields: f.fields.map((field) => ({
            name: field.name,
            type: field.type as FieldType,
            label: field.label ?? field.name,
            value: values[field.name] ?? null,
            required: !!field.required,
            error: null,
          })),
        }
      }
      case 'list': {
        const l = c as OdsListComponent
        const ds = this.requireApp().dataSources[l.dataSource]
        const rows = ds
          ? await this.dataService!.query(tableName(ds))
          : []
        return {
          kind: 'list',
          visible,
          dataSource: l.dataSource,
          columnFields: l.columns.map((col) => col.field),
          rowCount: rows.length,
          sortField: l.defaultSort?.field ?? null,
          sortDir:
            (l.defaultSort?.direction as 'asc' | 'desc' | undefined) ?? null,
        }
      }
      case 'kanban': {
        const k = c as OdsKanbanComponent
        const ds = this.requireApp().dataSources[k.dataSource]
        const rows = ds
          ? await this.dataService!.query(tableName(ds))
          : []
        const counts: Record<string, number> = {}
        for (const row of rows) {
          const status = String(row[k.statusField] ?? '')
          counts[status] = (counts[status] ?? 0) + 1
        }
        return {
          kind: 'kanban',
          visible,
          dataSource: k.dataSource,
          statusField: k.statusField,
          columns: Object.entries(counts).map(([status, cardCount]) => ({
            status,
            cardCount,
          })),
        }
      }
      case 'chart': {
        const ch = c as OdsChartComponent
        return {
          kind: 'chart',
          visible,
          dataSource: ch.dataSource,
          chartType: ch.chartType as 'bar' | 'line' | 'pie',
          title: ch.title ?? null,
          seriesCount: 1,
        }
      }
      case 'button': {
        const b = c as OdsButtonComponent
        return { kind: 'button', visible, label: b.label, enabled: true }
      }
      case 'summary': {
        const s = c as OdsSummaryComponent
        return {
          kind: 'summary',
          visible,
          label: s.label,
          value: String(s.defaultValue ?? ''),
        }
      }
      case 'tabs': {
        const t = c as OdsTabsComponent
        return {
          kind: 'tabs',
          visible,
          tabs: t.tabs.map((tab, i) => ({ label: tab.label, active: i === 0 })),
        }
      }
      case 'detail': {
        const d = c as OdsDetailComponent
        return {
          kind: 'detail',
          visible,
          dataSource: d.dataSource,
          fields: [],
        }
      }
      case 'unknown':
        return null
      default:
        return null
    }
  }
}
