import { useState, useEffect, useRef, useMemo } from 'react'
import { useNavigate, Link } from 'react-router'
import { AppRegistry } from '@/engine/app-registry.ts'
import { parseSpec, isOk } from '@/parser/spec-parser.ts'
import { getAiSettings, isAiConfigured } from '@/engine/ai-settings.ts'
import { extractJsonSpec } from '@/engine/ai-edit-prompt.ts'
import {
  AnthropicProvider,
  OpenAiProvider,
  AiProviderError,
  type AiProvider,
} from '@/engine/ai-provider.ts'
import pb from '@/lib/pocketbase.ts'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { toast } from 'sonner'
import {
  ArrowLeft,
  ClipboardCheck,
  Check,
  Loader2,
  MessageSquare,
  Sparkles,
  RotateCcw,
  X,
} from 'lucide-react'

// ---------------------------------------------------------------------------
// BuildWithAiScreen — create a brand-new app with AI help (ADR-0003 phase 3).
// Mirrors EditWithAiScreen's two-mode shape:
//
//   Configured: textarea "describe your app" → AI call → preview the
//               generated JSON → Save / Regenerate / Discard.
//
//   Not configured: 3-step copy/paste flow:
//                     1. Copy the Build Helper Prompt
//                     2. Use a chatbot to draft the spec
//                     3. Paste the result back, validate, save
//
// Same fallback prompt + same `extractJsonSpec` cleanup as the
// edit-flow so an AI that wraps its reply in fences still works.
// ---------------------------------------------------------------------------

const BUILD_HELPER_URL =
  'https://one-does-simply.github.io/ods-pages/Specification/build-helper-prompt.txt'

const FALLBACK_SYSTEM_PROMPT =
  'You are the ODS Build Helper. ODS apps are simple, data-driven applications described as a single JSON spec. Help the user build a new spec.'

const NEW_APP_DIRECTIVE = `
IMPORTANT for this conversation: the user is creating a brand-new ODS spec
from scratch. Reply with ONLY the complete JSON spec — no commentary, no
explanation, no markdown code fences. The first character of your reply
must be \`{\` and the last must be \`}\`.
`.trim()

export function BuildWithAiScreen() {
  const navigate = useNavigate()
  const registry = useRef(new AppRegistry(pb)).current

  const [buildHelperPrompt, setBuildHelperPrompt] = useState<string | null>(null)
  const [aiSettings] = useState(getAiSettings)
  const aiOn = isAiConfigured(aiSettings)

  useEffect(() => {
    async function fetchPrompt() {
      try {
        const resp = await fetch(BUILD_HELPER_URL)
        if (resp.ok) setBuildHelperPrompt(await resp.text())
      } catch {
        // Fallback used inline below.
      }
    }
    fetchPrompt()
  }, [])

  return (
    <div className="flex min-h-screen flex-col bg-background">
      <header className="sticky top-0 z-40 flex h-14 items-center gap-3 border-b bg-background/95 px-4 supports-backdrop-filter:backdrop-blur-sm">
        <Button variant="ghost" size="icon-sm" onClick={() => navigate('/admin')}>
          <ArrowLeft className="size-5" />
        </Button>
        <h1 className="flex-1 truncate text-base font-semibold">Build with AI</h1>
      </header>

      {aiOn ? (
        <OneShotBuildFlow
          registry={registry}
          systemPrompt={buildHelperPrompt ?? FALLBACK_SYSTEM_PROMPT}
          aiSettings={aiSettings}
        />
      ) : (
        <CopyPasteBuildFlow registry={registry} buildHelperPrompt={buildHelperPrompt} />
      )}
    </div>
  )
}

// ---------------------------------------------------------------------------
// One-shot AI flow (key configured)
// ---------------------------------------------------------------------------

interface OneShotProps {
  registry: AppRegistry
  systemPrompt: string
  aiSettings: ReturnType<typeof getAiSettings>
}

function OneShotBuildFlow({ registry, systemPrompt, aiSettings }: OneShotProps) {
  const navigate = useNavigate()
  const [description, setDescription] = useState('')
  const [generating, setGenerating] = useState(false)
  const [genError, setGenError] = useState<string | null>(null)
  const [proposed, setProposed] = useState<string | null>(null)
  const [validationError, setValidationError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const provider: AiProvider = useMemo(
    () => (aiSettings.provider === 'anthropic' ? new AnthropicProvider() : new OpenAiProvider()),
    [aiSettings.provider],
  )

  async function handleGenerate() {
    if (!description.trim()) return
    setGenerating(true)
    setGenError(null)
    setProposed(null)
    setValidationError(null)
    try {
      const system = systemPrompt.trim()
        ? `${systemPrompt.trim()}\n\n${NEW_APP_DIRECTIVE}`
        : NEW_APP_DIRECTIVE
      const user = `Build an ODS app with these requirements:\n\n${description}`
      const res = await provider.sendMessage(system, [], user, {
        model: aiSettings.model,
        apiKey: aiSettings.apiKey,
      })
      const json = extractJsonSpec(res.text)
      let pretty: string
      try {
        pretty = JSON.stringify(JSON.parse(json), null, 2)
      } catch {
        pretty = json
      }
      setProposed(pretty)
    } catch (e) {
      const msg = e instanceof AiProviderError
        ? `${e.provider} ${e.status ?? ''}: ${e.message}`.trim()
        : e instanceof Error
          ? e.message
          : String(e)
      setGenError(msg)
    } finally {
      setGenerating(false)
    }
  }

  async function handleSave() {
    if (!proposed) return
    setValidationError(null)
    setSaving(true)
    const result = parseSpec(proposed)
    if (result.parseError) {
      setValidationError(result.parseError)
      setSaving(false)
      return
    }
    if (!isOk(result)) {
      const errors = result.validation.messages
        .filter((m) => m.level === 'error')
        .map((m) => m.message)
        .join('\n')
      setValidationError(errors || 'Validation failed')
      setSaving(false)
      return
    }
    const appName = result.app!.appName
    const desc = result.app!.help?.overview ?? ''
    try {
      const saved = await registry.saveApp(appName, proposed, desc)
      setSaving(false)
      if (saved) {
        toast.success(`App "${appName}" saved`)
        navigate(`/${saved.slug}`)
      } else {
        setValidationError('Failed to save app to PocketBase')
      }
    } catch (e) {
      setSaving(false)
      setValidationError(e instanceof Error ? e.message : String(e))
    }
  }

  function handleDiscard() {
    setProposed(null)
    setValidationError(null)
  }

  // Pre-generation phase.
  if (proposed === null) {
    return (
      <div className="mx-auto max-w-2xl space-y-4 p-6">
        <div className="rounded-lg border bg-muted/30 p-3 text-xs text-muted-foreground">
          Using <span className="font-medium text-foreground">{aiSettings.provider}</span> ·{' '}
          <span className="font-medium text-foreground">{aiSettings.model}</span>.{' '}
          <Link to="/admin/settings" className="text-primary hover:underline">
            Change in Settings
          </Link>
        </div>

        <div>
          <label className="mb-1 block text-sm font-medium">Describe the app you want</label>
          <Textarea
            placeholder='e.g., "a habit tracker with daily check-ins, a streak counter, and a chart of completion over the last 30 days" — be specific about pages, fields, and what users should be able to do.'
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={6}
            disabled={generating}
            className="text-sm"
          />
          <p className="mt-1 text-xs text-muted-foreground">
            The more specific you are about pages, fields, and actions, the closer the
            first generation will be to what you want. You can iterate after.
          </p>
        </div>

        {genError && (
          <div className="rounded-lg border border-destructive/50 bg-destructive/10 px-4 py-3 text-sm text-destructive whitespace-pre-wrap">
            {genError}
          </div>
        )}

        <div className="flex gap-2">
          <Button onClick={handleGenerate} disabled={generating || !description.trim()}>
            {generating ? (
              <>
                <Loader2 className="mr-2 size-4 animate-spin" />
                Generating…
              </>
            ) : (
              <>
                <Sparkles className="mr-2 size-4" />
                Generate
              </>
            )}
          </Button>
        </div>
      </div>
    )
  }

  // Preview phase.
  return (
    <div className="mx-auto max-w-3xl space-y-4 p-6">
      <div className="rounded-lg border bg-muted/30 p-3 text-xs text-muted-foreground">
        AI generated this spec. Review below, then Save (which validates first) or
        Regenerate to try again.
      </div>

      {validationError && (
        <div className="rounded-lg border border-destructive/50 bg-destructive/10 px-4 py-3 text-sm text-destructive whitespace-pre-wrap">
          <div className="mb-1 font-semibold">Validation failed — not saved:</div>
          {validationError}
        </div>
      )}

      <div className="overflow-hidden rounded-lg border">
        <div className="border-b bg-muted/40 px-3 py-2 text-xs font-semibold">
          Generated spec
        </div>
        <pre className="max-h-[60vh] overflow-auto bg-background p-3 text-xs leading-relaxed whitespace-pre">
          {proposed}
        </pre>
      </div>

      <div className="flex gap-2">
        <Button onClick={handleSave} disabled={saving}>
          {saving ? <Loader2 className="mr-2 size-4 animate-spin" /> : <Check className="mr-2 size-4" />}
          Save
        </Button>
        <Button variant="outline" onClick={handleGenerate} disabled={saving || generating}>
          <RotateCcw className="mr-2 size-4" />
          Regenerate
        </Button>
        <Button variant="ghost" onClick={handleDiscard} disabled={saving}>
          <X className="mr-2 size-4" />
          Discard
        </Button>
      </div>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Copy/paste fallback (no key configured) — the path that was missing
// before this commit. Three steps: get the prompt, work in a chatbot,
// paste the result back.
// ---------------------------------------------------------------------------

interface FallbackProps {
  registry: AppRegistry
  buildHelperPrompt: string | null
}

function CopyPasteBuildFlow({ registry, buildHelperPrompt }: FallbackProps) {
  const navigate = useNavigate()
  const [promptCopied, setPromptCopied] = useState(false)
  const [pasteText, setPasteText] = useState('')
  const [importError, setImportError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  async function handleCopyPrompt() {
    const text = buildHelperPrompt ?? FALLBACK_SYSTEM_PROMPT
    try {
      await navigator.clipboard.writeText(text)
      setPromptCopied(true)
      toast.success('Build Helper prompt copied to clipboard')
    } catch {
      toast.error('Failed to copy — try manually selecting the text')
    }
  }

  async function handleSave() {
    if (!pasteText.trim()) return
    setImportError(null)
    setSaving(true)
    const result = parseSpec(pasteText)
    if (result.parseError) {
      setImportError(result.parseError)
      setSaving(false)
      return
    }
    if (!isOk(result)) {
      const errors = result.validation.messages
        .filter((m) => m.level === 'error')
        .map((m) => m.message)
        .join('\n')
      setImportError(errors)
      setSaving(false)
      return
    }
    const appName = result.app!.appName
    const desc = result.app!.help?.overview ?? ''
    try {
      const saved = await registry.saveApp(appName, pasteText, desc)
      setSaving(false)
      if (saved) {
        toast.success(`App "${appName}" saved`)
        navigate(`/${saved.slug}`)
      } else {
        setImportError('Failed to save app to PocketBase')
      }
    } catch (e) {
      setSaving(false)
      setImportError(e instanceof Error ? e.message : String(e))
    }
  }

  return (
    <div className="mx-auto max-w-2xl space-y-6 p-6">
      <div className="rounded-lg border border-primary/40 bg-primary/5 p-4 text-sm">
        <div className="mb-1 flex items-center gap-2 font-semibold">
          <Sparkles className="size-4 text-primary" />
          Have an API key?
        </div>
        <p className="text-muted-foreground">
          Set one up in{' '}
          <Link to="/admin/settings" className="text-primary hover:underline">
            Settings → AI Build Helper
          </Link>{' '}
          to draft a new app in one click — no copy/paste, no chatbot tab.
        </p>
      </div>

      <p className="text-sm text-muted-foreground">
        Use an AI chatbot (ChatGPT, Claude, etc.) to draft your new app. Follow the three steps below.
      </p>

      {/* Step 1 */}
      <div className="rounded-lg border p-4">
        <div className="mb-2 flex items-center gap-2">
          <span className="flex size-6 items-center justify-center rounded-full bg-primary text-xs font-bold text-primary-foreground">
            1
          </span>
          <h2 className="font-semibold">Copy the Build Helper Prompt</h2>
        </div>
        <p className="mb-3 text-sm text-muted-foreground">
          This tells the AI how ODS specs work. Paste it as your first message in a new chat.
        </p>
        <Button onClick={handleCopyPrompt} variant={promptCopied ? 'secondary' : 'default'}>
          {promptCopied ? (
            <>
              <ClipboardCheck className="mr-2 size-4" />
              Copied!
            </>
          ) : (
            <>
              <MessageSquare className="mr-2 size-4" />
              Copy Build Helper Prompt
            </>
          )}
        </Button>
      </div>

      {/* Step 2 */}
      <div className="rounded-lg border p-4">
        <div className="mb-2 flex items-center gap-2">
          <span className="flex size-6 items-center justify-center rounded-full bg-primary text-xs font-bold text-primary-foreground">
            2
          </span>
          <h2 className="font-semibold">Describe your app to the chatbot</h2>
        </div>
        <p className="text-sm text-muted-foreground">
          Open ChatGPT, Claude, or another assistant. Paste the prompt from step 1, then
          describe the app you want — pages, fields, what users should be able to do.
          The chatbot will reply with a JSON spec.
        </p>
      </div>

      {/* Step 3 */}
      <div className="rounded-lg border p-4">
        <div className="mb-2 flex items-center gap-2">
          <span className="flex size-6 items-center justify-center rounded-full bg-primary text-xs font-bold text-primary-foreground">
            3
          </span>
          <h2 className="font-semibold">Paste the spec back</h2>
        </div>
        <p className="mb-3 text-sm text-muted-foreground">
          Copy the JSON the chatbot generated and paste it below. We'll validate and save.
        </p>

        {importError && (
          <div className="mb-3 rounded-lg border border-destructive/50 bg-destructive/10 px-4 py-3 text-sm text-destructive whitespace-pre-wrap">
            {importError}
          </div>
        )}

        <Textarea
          placeholder='Paste the new app spec JSON here…'
          value={pasteText}
          onChange={(e) => setPasteText(e.target.value)}
          rows={10}
          className="mb-3 font-mono text-xs"
        />

        <Button onClick={handleSave} disabled={saving || !pasteText.trim()}>
          {saving ? <Loader2 className="mr-2 size-4 animate-spin" /> : <Check className="mr-2 size-4" />}
          Validate & Save
        </Button>
      </div>
    </div>
  )
}
