import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import type { OdsSpec } from './contract.ts'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

/**
 * Load a named spec from the shared `specs/` directory. Each call
 * returns a fresh object (no caching) so scenarios can't leak state
 * between runs.
 *
 * The Dart runner mirrors this helper — both sides read the exact
 * same JSON bytes, which is the whole point of the central directory.
 */
export function loadSpec(name: string): OdsSpec {
  const filepath = path.join(__dirname, '..', 'specs', `${name}.json`)
  const contents = fs.readFileSync(filepath, 'utf-8')
  return JSON.parse(contents) as OdsSpec
}
