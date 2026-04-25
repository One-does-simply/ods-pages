import { describe, it, expect } from 'vitest'
import * as fc from 'fast-check'
import { parseSpec, isOk } from '@/parser/spec-parser.ts'

// =========================================================================
// Property-based tests for the spec parser. These assert invariants that
// should hold for *all* inputs, not just hand-picked examples. fast-check
// generates random inputs (including pathological strings) and shrinks
// any failure to a minimal repro automatically.
//
// What we're pinning here:
//   - Totality:    parseSpec never throws, never returns undefined
//   - Soundness:   missing required fields are always detected
//   - Robustness:  any minimal-valid spec parses without errors
// =========================================================================

describe('parseSpec — totality', () => {
  it('never throws on arbitrary string input', () => {
    fc.assert(
      fc.property(fc.string(), (s) => {
        const result = parseSpec(s)
        // Always returns a structured ParseResult; either parseError or
        // validation is populated, but it never throws.
        expect(result).toBeDefined()
        expect(result.validation).toBeDefined()
      }),
      { numRuns: 200 },
    )
  })

  it('never throws on arbitrary JSON input (object/array/primitives)', () => {
    fc.assert(
      fc.property(fc.jsonValue(), (v) => {
        const result = parseSpec(JSON.stringify(v))
        expect(result).toBeDefined()
        expect(typeof result.validation.hasErrors).toBe('boolean')
      }),
      { numRuns: 200 },
    )
  })
})

describe('parseSpec — soundness on missing required fields', () => {
  it('flags missing appName as a validation error', () => {
    fc.assert(
      fc.property(
        fc.record({
          startPage: fc.constant('home'),
          pages: fc.constant({ home: { component: 'page', title: 'Home', content: [] } }),
        }),
        (specWithoutAppName) => {
          const result = parseSpec(JSON.stringify(specWithoutAppName))
          // Either the parser refuses with a parseError, or validation has errors.
          expect(
            result.parseError != null || result.validation.hasErrors,
          ).toBe(true)
        },
      ),
      { numRuns: 50 },
    )
  })

  it('flags missing startPage as a validation error', () => {
    fc.assert(
      fc.property(
        fc.record({
          appName: fc.string({ minLength: 1, maxLength: 50 }),
          pages: fc.constant({ home: { component: 'page', title: 'Home', content: [] } }),
        }),
        (specWithoutStartPage) => {
          const result = parseSpec(JSON.stringify(specWithoutStartPage))
          expect(
            result.parseError != null || result.validation.hasErrors,
          ).toBe(true)
        },
      ),
      { numRuns: 50 },
    )
  })
})

describe('parseSpec — minimal-valid spec always parses', () => {
  it('any (appName, startPage, pages) triple with the matching page produces a parsed app', () => {
    fc.assert(
      fc.property(
        fc.string({ minLength: 1, maxLength: 50 }),
        fc.stringMatching(/^[a-zA-Z][a-zA-Z0-9]{0,20}$/),
        fc.string({ minLength: 1, maxLength: 30 }),
        (appName, pageId, pageTitle) => {
          const spec = {
            appName,
            startPage: pageId,
            pages: {
              [pageId]: {
                component: 'page',
                title: pageTitle,
                content: [],
              },
            },
          }
          const result = parseSpec(JSON.stringify(spec))
          // Parser should produce an OdsApp regardless of these surface values.
          expect(isOk(result)).toBe(true)
          expect(result.app).not.toBeNull()
          expect(result.app!.appName).toBe(appName)
          expect(result.app!.startPage).toBe(pageId)
        },
      ),
      { numRuns: 100 },
    )
  })
})
