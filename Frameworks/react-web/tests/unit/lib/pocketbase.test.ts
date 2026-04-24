import { describe, it, expect } from 'vitest'
import fs from 'node:fs'
import path from 'node:path'

// ---------------------------------------------------------------------------
// pocketbase module init guard
//
// A previous version of src/lib/pocketbase.ts called pb.authStore.clear()
// at module-init time. That clobbered the superadmin session on every page
// load, breaking E2E auth and the normal "admin stays signed in across
// navigation" UX. The fix (Batch 8) was to delete the line.
//
// This test pins the fix: the module must not clear authStore as a side
// effect of being imported. Intentional clears (logout, auth-service
// reset, admin dashboard logout button) live elsewhere.
// ---------------------------------------------------------------------------

describe('lib/pocketbase module-init guard', () => {
  const src = fs.readFileSync(
    path.resolve(__dirname, '../../../src/lib/pocketbase.ts'),
    'utf-8',
  )

  it('does not clear pb.authStore during module init', () => {
    expect(src).not.toMatch(/\bauthStore\s*\.\s*clear\s*\(/)
  })

  it('does not call any method named "logout" on pb during module init', () => {
    // Belt-and-suspenders: PocketBase has no pb.logout(), but guard against
    // a future SDK variant or a hand-rolled clear helper being added here.
    expect(src).not.toMatch(/\bpb\s*\.\s*logout\s*\(/)
  })
})
