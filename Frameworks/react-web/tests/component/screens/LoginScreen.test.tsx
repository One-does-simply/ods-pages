import { describe, it, expect, beforeEach, vi } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { LoginScreen } from '../../../src/screens/LoginScreen.tsx'
import { useAppStore } from '../../../src/engine/app-store.ts'
import type { OdsApp } from '../../../src/models/ods-app.ts'
import type { AuthService } from '../../../src/engine/auth-service.ts'

// ---------------------------------------------------------------------------
// LoginScreen component tests
//
// Pins a regression Batch 8 caught: when a user signs up while
// needsAdminSetup is true, both gates (needsLogin + needsAdminSetup) must
// clear — otherwise the user lands on an infinite admin-setup loop despite
// being authenticated. See LoginScreen.tsx:119.
// ---------------------------------------------------------------------------

// The pocketbase singleton is imported at module load for `pb.authStore.record`
// access. We only need it to behave as if no superadmin is signed in.
vi.mock('../../../src/lib/pocketbase.ts', () => ({
  default: {
    authStore: { isValid: false, record: null },
  },
}))

function makeApp(): OdsApp {
  return {
    appName: 'TestApp',
    appDescription: '',
    appIcon: '',
    auth: {
      multiUser: true,
      multiUserOnly: false,
      customRoles: [],
      defaultRole: 'user',
      selfRegistration: true,
    },
    pages: {},
    menu: [],
    dataSources: {},
    startPage: 'home',
    startPageByRole: {},
    settings: [],
    help: null,
    tour: [],
    theme: null,
  } as unknown as OdsApp
}

function makeAuthService(overrides: {
  registerUser?: (params: unknown) => Promise<string | null>
  login?: (email: string, password: string) => Promise<boolean>
} = {}): AuthService {
  return {
    registerUser: overrides.registerUser ?? (async () => 'new-user-id'),
    login: overrides.login ?? (async () => true),
    isAdminSetUp: false,
    oauthProviders: [],
    // Methods/getters that may be read during render but aren't exercised.
    setSuperAdmin: () => {},
    setupAdmin: async () => true,
    startOAuth2Redirect: async () => {},
  } as unknown as AuthService
}

describe('LoginScreen — admin setup + signup interaction', () => {
  beforeEach(() => {
    // Reset to a known starting state: multi-user app, no admin exists yet,
    // so the user is on the login screen with needsAdminSetup=true.
    useAppStore.setState({
      app: makeApp(),
      authService: makeAuthService(),
      dataService: null,
      needsAdminSetup: true,
      needsLogin: true,
    } as never)
  })

  it('clears BOTH needsLogin and needsAdminSetup when a user self-registers during admin setup', async () => {
    render(<LoginScreen />)

    // Open sign-up form.
    fireEvent.click(screen.getByRole('button', { name: /Don't have an account\? Sign Up/i }))

    // Fill the sign-up form.
    fireEvent.change(screen.getByLabelText('Email'), {
      target: { value: 'new@example.com' },
    })
    fireEvent.change(screen.getByLabelText('Password'), {
      target: { value: 'password123' },
    })
    fireEvent.change(screen.getByLabelText('Confirm Password'), {
      target: { value: 'password123' },
    })

    fireEvent.click(screen.getByRole('button', { name: /Create Account/i }))

    await waitFor(() => {
      expect(useAppStore.getState().needsLogin).toBe(false)
    })
    expect(useAppStore.getState().needsAdminSetup).toBe(false)
  })

  it('leaves gates unchanged when registerUser fails', async () => {
    useAppStore.setState({
      authService: makeAuthService({ registerUser: async () => null }),
    } as never)

    render(<LoginScreen />)
    fireEvent.click(screen.getByRole('button', { name: /Don't have an account\? Sign Up/i }))
    fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'new@example.com' } })
    fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'password123' } })
    fireEvent.change(screen.getByLabelText('Confirm Password'), { target: { value: 'password123' } })

    fireEvent.click(screen.getByRole('button', { name: /Create Account/i }))

    await waitFor(() => {
      expect(screen.getByText(/Failed to create account/i)).toBeTruthy()
    })
    expect(useAppStore.getState().needsLogin).toBe(true)
    expect(useAppStore.getState().needsAdminSetup).toBe(true)
  })
})
