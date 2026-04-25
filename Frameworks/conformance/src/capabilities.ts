/**
 * Capability tags a driver can declare support for. Scenarios tag
 * themselves with required capabilities; the runner skips (not fails)
 * scenarios whose requirements exceed the driver's declared set.
 *
 * Keep this list flat and feature-oriented. See
 * docs/adr/0001-conformance-driver-contract.md §6 for versioning
 * semantics and naming conventions.
 */
export type Capability =
  // Baseline — every conforming driver must support this set. It
  // covers pages, text, form, button, list, navigate, submit, and
  // showMessage.
  | 'core'

  // Feature packs.
  | 'kanban'
  | 'chart'
  | 'tabs'
  | 'detail'
  | 'summary'
  | 'formulas'
  | 'rowActions'
  | 'cascadeRename'
  | 'theme'

  // Auth.
  | 'auth:multiUser'
  | 'auth:selfRegistration'
  | 'auth:ownership'

  // Action-variant granularity for scenarios that specifically test
  // one kind of action.
  | 'action:submit'
  | 'action:update'
  | 'action:delete'
  | 'action:navigate'
  | 'action:showMessage'
  | 'action:recordNav'
