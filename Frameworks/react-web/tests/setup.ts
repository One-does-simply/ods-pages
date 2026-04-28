import '@testing-library/jest-dom/vitest'

// jsdom in this vitest version exposes a `localStorage` object that's
// missing the standard methods (`removeItem`, etc.) — so any module
// that calls them at test time blows up. Replace it with a minimal
// in-memory shim that satisfies the Web Storage API contract. Real
// browsers + production code paths are unaffected.
if (typeof localStorage === 'undefined' || typeof localStorage.removeItem !== 'function') {
  const store: Record<string, string> = {}
  const shim: Storage = {
    get length() { return Object.keys(store).length },
    clear: () => { for (const k of Object.keys(store)) delete store[k] },
    getItem: (k) => Object.prototype.hasOwnProperty.call(store, k) ? store[k] : null,
    setItem: (k, v) => { store[k] = String(v) },
    removeItem: (k) => { delete store[k] },
    key: (i) => Object.keys(store)[i] ?? null,
  }
  Object.defineProperty(globalThis, 'localStorage', {
    value: shim,
    configurable: true,
    writable: true,
  })
}
