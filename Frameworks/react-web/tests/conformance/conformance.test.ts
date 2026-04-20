import { describe, it, afterEach } from 'vitest'

import { allScenarios } from '../../../conformance/src/index.ts'
import { ReactDriver } from './react-driver.ts'

// ---------------------------------------------------------------------------
// Conformance runner — each scenario becomes a vitest case. The runner
// skips (via `it.skip`) scenarios whose required capabilities aren't all
// supported by the driver. Any throw inside `scenario.run` becomes a
// test failure.
// ---------------------------------------------------------------------------

describe('ODS conformance (ReactDriver)', () => {
  let driver: ReactDriver | null = null

  afterEach(async () => {
    if (driver) {
      await driver.unmount()
      driver = null
    }
  })

  for (const scenario of allScenarios) {
    const supported = scenario.capabilities.every((c) =>
      new ReactDriver().capabilities.has(c),
    )
    const runner = supported ? it : it.skip

    runner(scenario.name, async () => {
      driver = new ReactDriver()
      await driver.mount(scenario.spec())
      await driver.setSeed(0)
      await driver.setClock('2026-01-01T00:00:00Z')
      await scenario.run(driver)
    })
  }
})
