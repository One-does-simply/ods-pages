import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./tests/setup.ts'],
    include: ['tests/**/*.test.{ts,tsx}'],
    coverage: {
      provider: 'v8',
      include: ['src/**/*.{ts,tsx}'],
      exclude: ['src/main.tsx', 'src/vite-env.d.ts', 'src/components/ui/**'],
      // Per-folder thresholds: lock in high coverage where it exists
      // (models, parser) and block regression on the engine. Screens,
      // renderer components, and lib (PocketBase wiring) are deliberately
      // unthresholded — they're driven by E2E + manual UI testing, not
      // unit tests, so a low threshold there is meaningful and a high
      // one would constantly false-fail. See docs/testing.md for the
      // layered-test rationale.
      thresholds: {
        'src/models/**': {
          statements: 90,
          branches: 90,
          functions: 90,
          lines: 90,
        },
        'src/parser/**': {
          statements: 90,
          branches: 85,
          functions: 90,
          lines: 90,
        },
        'src/engine/**': {
          statements: 50,
          branches: 55,
          functions: 50,
          lines: 50,
        },
      },
    },
  },
})
