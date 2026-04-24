/**
 * Minimal in-memory stand-in for PocketBase, sized for conformance tests.
 *
 * Real AuthService talks to PocketBase via `pb.authStore.*` and
 * `pb.collection('users').*`. This fake implements the subset needed
 * to drive login / registerUser / logout / currentUser through the
 * REAL AuthService — we don't want a parallel auth implementation.
 *
 * Intentionally missing:
 *   - PB filter DSL (getFullList ignores `filter`; AuthService falls
 *     back to manual role scanning when the filter 400s, which is the
 *     path we exercise here)
 *   - Real password hashing (we just compare plaintext)
 *   - OAuth2 (listAuthMethods returns no providers)
 *   - Any collection other than `users`
 */
export class FakePocketBase {
  private users = new Map<string, UserRecord>()
  private nextId = 1
  private _authStore: FakeAuthStore

  constructor() {
    this._authStore = new FakeAuthStore()
  }

  get authStore(): FakeAuthStore {
    return this._authStore
  }

  collection(name: string): FakeCollection {
    if (name === 'users') {
      return new FakeUsersCollection(this.users, () => this._nextId(), this._authStore)
    }
    // Any non-users collection access — return a collection that 404s
    // on every read. Real PB behaves similarly for missing collections.
    return new FakeMissingCollection(name)
  }

  /** `pb.collections.create(...)` — called by AuthService.ensureUsersCollection. */
  collections = {
    create: async (_schema: Record<string, unknown>): Promise<void> => {
      // No-op: users collection is implicitly always present in this fake.
    },
    delete: async (_name: string): Promise<void> => {
      // No-op.
    },
  }

  private _nextId(): string {
    return `u_${this.nextId++}`
  }
}

// ---------------------------------------------------------------------------
// authStore
// ---------------------------------------------------------------------------

export interface UserRecord {
  id: string
  collectionName: string
  email: string
  username: string
  displayName: string
  roles: string[]
  password: string
  [key: string]: unknown
}

class FakeAuthStore {
  private _record: UserRecord | null = null

  get isValid(): boolean {
    return this._record !== null
  }

  get record(): UserRecord | null {
    return this._record
  }

  clear(): void {
    this._record = null
  }

  save(_token: string, model: UserRecord): void {
    this._record = model
  }
}

// ---------------------------------------------------------------------------
// collection('users')
// ---------------------------------------------------------------------------

interface FakeCollection {
  create(data: Record<string, unknown>): Promise<UserRecord>
  authWithPassword(
    email: string,
    password: string,
  ): Promise<{ record: UserRecord; token: string }>
  getFullList(opts?: Record<string, unknown>): Promise<UserRecord[]>
  getList(
    page: number,
    perPage: number,
    opts?: Record<string, unknown>,
  ): Promise<{ items: UserRecord[]; totalItems: number }>
  listAuthMethods(
    opts?: Record<string, unknown>,
  ): Promise<{ oauth2: { providers: unknown[] } }>
  update(id: string, data: Record<string, unknown>): Promise<UserRecord>
  delete(id: string): Promise<void>
  getOne(id: string): Promise<UserRecord>
  authRefresh(): Promise<{ record: UserRecord; token: string }>
}

class FakeUsersCollection implements FakeCollection {
  constructor(
    private users: Map<string, UserRecord>,
    private mint: () => string,
    private authStore: FakeAuthStore,
  ) {}

  async create(data: Record<string, unknown>): Promise<UserRecord> {
    const email = String(data['email'] ?? '')
    if (!email) throw new Error('email required')
    for (const existing of this.users.values()) {
      if (existing.email.toLowerCase() === email.toLowerCase()) {
        throw new Error(`user with email ${email} already exists`)
      }
    }

    const id = this.mint()
    const rolesRaw = data['roles']
    const roles = Array.isArray(rolesRaw)
      ? (rolesRaw as string[])
      : typeof rolesRaw === 'string'
        ? this.tryParseJsonArray(rolesRaw)
        : []

    const record: UserRecord = {
      id,
      collectionName: 'users',
      email,
      username: String(data['username'] ?? email),
      displayName: String(data['displayName'] ?? email.split('@')[0]),
      roles,
      password: String(data['password'] ?? ''),
    }
    this.users.set(id, record)
    return record
  }

  async authWithPassword(
    email: string,
    password: string,
  ): Promise<{ record: UserRecord; token: string }> {
    const user = [...this.users.values()].find(
      (u) => u.email.toLowerCase() === email.toLowerCase(),
    )
    if (!user) throw new Error('auth failed: no such user')
    if (user.password !== password) throw new Error('auth failed: bad password')

    this.authStore.save('fake-token', user)
    return { record: user, token: 'fake-token' }
  }

  async getFullList(_opts?: Record<string, unknown>): Promise<UserRecord[]> {
    // We don't implement the filter DSL. AuthService's admin-detect code
    // catches a 400 and falls back to manual scanning, which is fine for
    // our scenarios.
    return [...this.users.values()]
  }

  async getList(
    page: number,
    perPage: number,
    _opts?: Record<string, unknown>,
  ): Promise<{ items: UserRecord[]; totalItems: number }> {
    const all = [...this.users.values()]
    const start = (page - 1) * perPage
    return { items: all.slice(start, start + perPage), totalItems: all.length }
  }

  async listAuthMethods(
    _opts?: Record<string, unknown>,
  ): Promise<{ oauth2: { providers: unknown[] } }> {
    return { oauth2: { providers: [] } }
  }

  async update(id: string, data: Record<string, unknown>): Promise<UserRecord> {
    const user = this.users.get(id)
    if (!user) throw new Error(`user ${id} not found`)
    Object.assign(user, data)
    return user
  }

  async delete(id: string): Promise<void> {
    this.users.delete(id)
  }

  async getOne(id: string): Promise<UserRecord> {
    const user = this.users.get(id)
    if (!user) throw new Error(`user ${id} not found`)
    return user
  }

  async authRefresh(): Promise<{ record: UserRecord; token: string }> {
    if (!this.authStore.record) throw new Error('not authenticated')
    return { record: this.authStore.record, token: 'fake-token' }
  }

  private tryParseJsonArray(s: string): string[] {
    try {
      const parsed = JSON.parse(s)
      return Array.isArray(parsed) ? (parsed as string[]) : []
    } catch {
      return []
    }
  }
}

class FakeMissingCollection implements FakeCollection {
  constructor(private name: string) {}
  private notFound(): never {
    throw Object.assign(new Error(`collection "${this.name}" not found`), {
      status: 404,
    })
  }
  async create() { return this.notFound() }
  async authWithPassword() { return this.notFound() }
  async getFullList() { return this.notFound() }
  async getList() { return this.notFound() }
  async listAuthMethods() { return this.notFound() }
  async update() { return this.notFound() }
  async delete() { return this.notFound() }
  async getOne() { return this.notFound() }
  async authRefresh() { return this.notFound() }
}
