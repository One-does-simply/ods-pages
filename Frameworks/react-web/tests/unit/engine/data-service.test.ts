import { describe, it, expect, vi } from 'vitest'
import { FakeDataService } from '../../helpers/fake-data-service.ts'
import { DataService } from '../../../src/engine/data-service.ts'

describe('FakeDataService (mirrors DataService interface)', () => {
  let ds: FakeDataService

  beforeEach(() => {
    ds = new FakeDataService()
    ds.initialize('testApp')
  })

  describe('insert', () => {
    it('inserts a row and returns an ID', async () => {
      const id = await ds.insert('tasks', { name: 'Buy milk', status: 'open' })
      expect(id).toBeTruthy()
    })

    it('inserted row appears in query', async () => {
      await ds.insert('tasks', { name: 'Buy milk' })
      const rows = await ds.query('tasks')
      expect(rows).toHaveLength(1)
      expect(rows[0]['name']).toBe('Buy milk')
    })

    it('auto-adds _id and _createdAt', async () => {
      await ds.insert('tasks', { name: 'Test' })
      const rows = await ds.query('tasks')
      expect(rows[0]['_id']).toBeTruthy()
      expect(rows[0]['_createdAt']).toBeTruthy()
    })
  })

  describe('update', () => {
    it('updates matching rows', async () => {
      await ds.insert('tasks', { name: 'Task1', status: 'open' })
      const count = await ds.update('tasks', { status: 'done' }, 'name', 'Task1')
      expect(count).toBe(1)

      const rows = await ds.query('tasks')
      expect(rows[0]['status']).toBe('done')
    })

    it('returns 0 for no matches', async () => {
      await ds.insert('tasks', { name: 'Task1' })
      const count = await ds.update('tasks', { status: 'done' }, 'name', 'Missing')
      expect(count).toBe(0)
    })
  })

  describe('delete', () => {
    it('deletes matching rows', async () => {
      await ds.insert('tasks', { name: 'Task1' })
      await ds.insert('tasks', { name: 'Task2' })
      const count = await ds.delete('tasks', 'name', 'Task1')
      expect(count).toBe(1)

      const rows = await ds.query('tasks')
      expect(rows).toHaveLength(1)
      expect(rows[0]['name']).toBe('Task2')
    })
  })

  describe('query', () => {
    it('returns empty array for unknown table', async () => {
      const rows = await ds.query('nonexistent')
      expect(rows).toEqual([])
    })

    it('returns rows in reverse insertion order (newest first)', async () => {
      await ds.insert('tasks', { name: 'First' })
      await ds.insert('tasks', { name: 'Second' })
      const rows = await ds.query('tasks')
      expect(rows[0]['name']).toBe('Second')
      expect(rows[1]['name']).toBe('First')
    })
  })

  describe('queryWithFilter', () => {
    it('filters by field value', async () => {
      await ds.insert('tasks', { name: 'A', status: 'open' })
      await ds.insert('tasks', { name: 'B', status: 'done' })
      await ds.insert('tasks', { name: 'C', status: 'open' })

      const rows = await ds.queryWithFilter('tasks', { status: 'open' })
      expect(rows).toHaveLength(2)
    })
  })

  describe('queryWithOwnership', () => {
    it('filters by owner when enabled', async () => {
      ds.seed('tasks', [
        { name: 'Mine', _owner: 'user1' },
        { name: 'Theirs', _owner: 'user2' },
      ])

      const rows = await ds.queryWithOwnership('tasks', '_owner', 'user1', false, true)
      expect(rows).toHaveLength(1)
      expect(rows[0]['name']).toBe('Mine')
    })

    it('admin sees all when adminOverride is true', async () => {
      ds.seed('tasks', [
        { name: 'Mine', _owner: 'user1' },
        { name: 'Theirs', _owner: 'user2' },
      ])

      const rows = await ds.queryWithOwnership('tasks', '_owner', 'admin', true, true)
      expect(rows).toHaveLength(2)
    })

    it('admin filtered when adminOverride is false', async () => {
      ds.seed('tasks', [
        { name: 'Mine', _owner: 'admin' },
        { name: 'Theirs', _owner: 'user2' },
      ])

      const rows = await ds.queryWithOwnership('tasks', '_owner', 'admin', true, false)
      expect(rows).toHaveLength(1)
    })
  })

  describe('getRowCount', () => {
    it('returns 0 for empty/unknown table', async () => {
      expect(await ds.getRowCount('nothing')).toBe(0)
    })

    it('returns correct count', async () => {
      await ds.insert('tasks', { name: 'A' })
      await ds.insert('tasks', { name: 'B' })
      expect(await ds.getRowCount('tasks')).toBe(2)
    })
  })
})

// ---------------------------------------------------------------------------
// Multi-app isolation via appPrefix
// ---------------------------------------------------------------------------
//
// appPrefix is the keystone of multi-app mode: two apps that both declare a
// `local://tasks` data source must end up on physically separate PocketBase
// collections so "App A's tasks" can never leak into "App B's tasks". These
// tests pin that contract at the DataService boundary.

describe('DataService multi-app isolation (appPrefix)', () => {
  /**
   * Builds a fake PocketBase that keeps rows grouped by collection name.
   * We assert against which collection names were actually hit.
   */
  function makeFakePb() {
    const store: Record<string, Array<Record<string, unknown>>> = {}
    const pb = {
      collection: vi.fn((name: string) => ({
        getList: vi.fn(async () => ({ totalItems: (store[name] ?? []).length })),
        getFullList: vi.fn(async () => [...(store[name] ?? [])]),
        create: vi.fn(async (data: Record<string, unknown>) => {
          const row = { ...data, id: `id_${(store[name]?.length ?? 0) + 1}` }
          store[name] = [...(store[name] ?? []), row]
          return row
        }),
        update: vi.fn(async () => ({})),
        delete: vi.fn(async () => {}),
      })),
    }
    return { pb, store }
  }

  it('collectionName() produces app-specific names from the same logical table', () => {
    const { pb } = makeFakePb()

    const dsA = new DataService(pb as never)
    dsA.initialize('App A')
    const dsB = new DataService(pb as never)
    dsB.initialize('App B')

    expect(dsA.collectionName('tasks')).toBe('app_a_tasks')
    expect(dsB.collectionName('tasks')).toBe('app_b_tasks')
    expect(dsA.collectionName('tasks')).not.toBe(dsB.collectionName('tasks'))
  })

  it('inserting into app A does not surface in app B queries for the same logical table', async () => {
    const { pb, store } = makeFakePb()

    const dsA = new DataService(pb as never)
    dsA.initialize('App A')
    const dsB = new DataService(pb as never)
    dsB.initialize('App B')

    await dsA.insert('tasks', { title: 'A-only' })
    await dsB.insert('tasks', { title: 'B-only' })

    const aRows = await dsA.query('tasks')
    const bRows = await dsB.query('tasks')

    expect(aRows).toHaveLength(1)
    expect(aRows[0]['title']).toBe('A-only')
    expect(bRows).toHaveLength(1)
    expect(bRows[0]['title']).toBe('B-only')

    // The underlying PB store landed in two distinct collections.
    expect(Object.keys(store).sort()).toEqual(['app_a_tasks', 'app_b_tasks'])
  })

  it('re-initializing the same instance with a new app name switches the collection', async () => {
    const { pb, store } = makeFakePb()
    const ds = new DataService(pb as never)

    ds.initialize('App A')
    await ds.insert('tasks', { title: 'A-only' })

    ds.initialize('App B')
    const bRows = await ds.query('tasks')

    expect(bRows).toEqual([])
    expect(store['app_a_tasks']).toHaveLength(1)
    expect(store['app_b_tasks']).toBeUndefined()
  })

  it('sanitizes app names into safe collection prefixes', () => {
    const { pb } = makeFakePb()
    const ds = new DataService(pb as never)

    ds.initialize('My App 2.0!')
    expect(ds.collectionName('tasks')).toBe('my_app_2_0__tasks')
  })
})
