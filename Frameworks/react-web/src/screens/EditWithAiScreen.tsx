import { useState, useEffect, useRef, useMemo } from 'react'
import { useParams, useNavigate, Link } from 'react-router'
import { diffLines } from 'diff'
import { AppRegistry, type AppRecord } from '@/engine/app-registry.ts'
import { parseSpec, isOk } from '@/parser/spec-parser.ts'
import { getAiSettings, isAiConfigured } from '@/engine/ai-settings.ts'
import { buildEditPrompt, extractJsonSpec } from '@/engine/ai-edit-prompt.ts'
import { buildChatSystemPrompt, extractProposedSpec } from '@/engine/ai-chat-prompt.ts'
import {
  AnthropicProvider,
  OpenAiProvider,
  AiProviderError,
  type AiProvider,
  type Message,
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
  MessageCircle,
  FileJson,
  Sparkles,
  RotateCcw,
  Send,
  Square,
  X,
} from 'lucide-react'

// ---------------------------------------------------------------------------
// EditWithAiScreen — two flows depending on whether the user has
// configured an API key (ADR-0003 phase 3):
//
//   Configured: textarea instruction → AI call → side-by-side diff →
//               Apply / Regenerate / Discard. The win — no copy/paste.
//
//   Not configured: the original 3-step copy/paste flow, plus a callout
//                   pointing the user to Settings → AI to set up a key.
// ---------------------------------------------------------------------------

const BUILD_HELPER_URL =
  'https://one-does-simply.github.io/ods-pages/Specification/build-helper-prompt.txt'

const FALLBACK_SYSTEM_PROMPT =
  'You are the ODS Build Helper. ODS apps are simple, data-driven applications described as a single JSON spec. Help the user edit their spec.'

export function EditWithAiScreen() {
  const { appId } = useParams<{ appId: string }>()
  const navigate = useNavigate()
  const registry = useRef(new AppRegistry(pb)).current

  const [app, setApp] = useState<AppRecord | null>(null)
  const [loading, setLoading] = useState(true)
  const [buildHelperPrompt, setBuildHelperPrompt] = useState<string | null>(null)

  // AI settings are read once on mount; if the user changes them in the
  // other tab, they need to navigate away and back (acceptable for v1).
  const [aiSettings] = useState(getAiSettings)
  const aiOn = isAiConfigured(aiSettings)

  useEffect(() => {
    async function load() {
      if (!appId) return
      setLoading(true)
      try {
        const record = await pb.collection('_ods_apps').getOne(appId, { requestKey: null })
        setApp({
          id: record.id,
          name: record['name'] as string,
          slug: record['slug'] as string,
          specJson:
            typeof record['specJson'] === 'string'
              ? record['specJson']
              : JSON.stringify(record['specJson']),
          status: (record['status'] as string) === 'archived' ? 'archived' : 'active',
          description: (record['description'] as string) ?? '',
          created: record.created,
          updated: record.updated,
        })
      } catch {
        toast.error('App not found')
        navigate('/admin')
      }
      setLoading(false)
    }
    load()
  }, [appId, navigate])

  // Fetch the canonical build-helper system prompt. Falls back to a
  // minimal inline string if the asset isn't reachable so the AI flow
  // still works offline-ish.
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

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background">
        <Loader2 className="size-5 animate-spin text-muted-foreground" />
      </div>
    )
  }
  if (!app) return null

  return (
    <div className="flex min-h-screen flex-col bg-background">
      <header className="sticky top-0 z-40 flex h-14 items-center gap-3 border-b bg-background/95 px-4 supports-backdrop-filter:backdrop-blur-sm">
        <Button variant="ghost" size="icon-sm" onClick={() => navigate('/admin')}>
          <ArrowLeft className="size-5" />
        </Button>
        <h1 className="flex-1 truncate text-base font-semibold">
          Edit with AI: {app.name}
        </h1>
      </header>

      {aiOn ? (
        <AiEditFlows
          app={app}
          registry={registry}
          systemPrompt={buildHelperPrompt ?? FALLBACK_SYSTEM_PROMPT}
          aiSettings={aiSettings}
        />
      ) : (
        <CopyPasteFallbackFlow app={app} registry={registry} buildHelperPrompt={buildHelperPrompt} />
      )}
    </div>
  )
}

// ---------------------------------------------------------------------------
// AiEditFlows — mode toggle + body. The toggle lives at the top so the
// user can pick between a single-shot edit and a multi-turn chat. State
// is per-flow (lost when toggling) — fine for v1; persistence is an
// open question in ADR-0003.
// ---------------------------------------------------------------------------

interface AiFlowsProps {
  app: AppRecord
  registry: AppRegistry
  systemPrompt: string
  aiSettings: ReturnType<typeof getAiSettings>
}

function AiEditFlows(props: AiFlowsProps) {
  const [mode, setMode] = useState<'one-shot' | 'chat'>('one-shot')
  return (
    <div className="flex-1">
      <div className="mx-auto flex max-w-5xl items-center gap-2 px-6 pt-6">
        <div className="flex gap-1 rounded-lg border p-0.5">
          <button
            type="button"
            onClick={() => setMode('one-shot')}
            className={`flex items-center gap-1.5 rounded-md px-3 py-1 text-xs font-medium transition-colors ${
              mode === 'one-shot'
                ? 'bg-primary text-primary-foreground'
                : 'text-muted-foreground hover:text-foreground'
            }`}
          >
            <Sparkles className="size-3.5" />
            One-shot edit
          </button>
          <button
            type="button"
            onClick={() => setMode('chat')}
            className={`flex items-center gap-1.5 rounded-md px-3 py-1 text-xs font-medium transition-colors ${
              mode === 'chat'
                ? 'bg-primary text-primary-foreground'
                : 'text-muted-foreground hover:text-foreground'
            }`}
          >
            <MessageCircle className="size-3.5" />
            Chat
          </button>
        </div>
      </div>
      {mode === 'one-shot' ? <OneShotEditFlow {...props} /> : <ChatEditFlow {...props} />}
    </div>
  )
}

// ---------------------------------------------------------------------------
// One-shot AI flow — the new path
// ---------------------------------------------------------------------------

interface OneShotProps {
  app: AppRecord
  registry: AppRegistry
  systemPrompt: string
  aiSettings: ReturnType<typeof getAiSettings>
}

function OneShotEditFlow({ app, registry, systemPrompt, aiSettings }: OneShotProps) {
  const navigate = useNavigate()
  const [instruction, setInstruction] = useState('')
  const [generating, setGenerating] = useState(false)
  const [genError, setGenError] = useState<string | null>(null)
  const [proposed, setProposed] = useState<string | null>(null)
  const [validationError, setValidationError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  const provider: AiProvider = useMemo(
    () => (aiSettings.provider === 'anthropic' ? new AnthropicProvider() : new OpenAiProvider()),
    [aiSettings.provider],
  )

  const prettyCurrentSpec = useMemo(() => {
    try {
      return JSON.stringify(JSON.parse(app.specJson), null, 2)
    } catch {
      return app.specJson
    }
  }, [app.specJson])

  async function handleGenerate() {
    if (!instruction.trim()) return
    setGenerating(true)
    setGenError(null)
    setProposed(null)
    setValidationError(null)
    try {
      const { system, user } = buildEditPrompt(prettyCurrentSpec, instruction, systemPrompt)
      const res = await provider.sendMessage(system, [], user, {
        model: aiSettings.model,
        apiKey: aiSettings.apiKey,
      })
      const json = extractJsonSpec(res.text)
      // Pretty-print so the diff is line-aligned with the current spec.
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

  async function handleApply() {
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
    const ok = await registry.updateApp(app.id, proposed)
    setSaving(false)
    if (ok) {
      toast.success('App updated successfully!')
      navigate('/admin')
    } else {
      setValidationError('Failed to save the updated spec')
    }
  }

  function handleDiscard() {
    setProposed(null)
    setValidationError(null)
  }

  // Pre-diff phase: show instruction textarea + Generate button.
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
          <label className="mb-1 block text-sm font-medium">What change do you want?</label>
          <Textarea
            placeholder='e.g., "add a priority field with low/medium/high options" or "rename the title field to headline"'
            value={instruction}
            onChange={(e) => setInstruction(e.target.value)}
            rows={5}
            disabled={generating}
            className="text-sm"
          />
        </div>

        {genError && (
          <div className="rounded-lg border border-destructive/50 bg-destructive/10 px-4 py-3 text-sm text-destructive whitespace-pre-wrap">
            {genError}
          </div>
        )}

        <div className="flex gap-2">
          <Button onClick={handleGenerate} disabled={generating || !instruction.trim()}>
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

  // Diff-review phase.
  const diffParts = diffLines(prettyCurrentSpec, proposed)

  return (
    <div className="mx-auto max-w-5xl space-y-4 p-6">
      <div className="rounded-lg border bg-muted/30 p-3 text-xs text-muted-foreground">
        AI proposed the following changes. Review the diff below, then Apply
        (which validates the spec before saving) or Discard.
      </div>

      {validationError && (
        <div className="rounded-lg border border-destructive/50 bg-destructive/10 px-4 py-3 text-sm text-destructive whitespace-pre-wrap">
          <div className="mb-1 font-semibold">Validation failed — not saved:</div>
          {validationError}
        </div>
      )}

      <div className="overflow-hidden rounded-lg border">
        <div className="border-b bg-muted/40 px-3 py-2 text-xs font-semibold">
          Diff (current → proposed)
        </div>
        <pre className="max-h-[60vh] overflow-auto bg-background p-3 text-xs leading-relaxed">
          {diffParts.map((part, i) => {
            const cls = part.added
              ? 'block bg-green-500/10 text-green-700 dark:text-green-400'
              : part.removed
                ? 'block bg-red-500/10 text-red-700 dark:text-red-400'
                : 'block text-muted-foreground'
            const sign = part.added ? '+ ' : part.removed ? '- ' : '  '
            return (
              <span key={i} className={cls}>
                {part.value
                  .split('\n')
                  .filter((_, idx, arr) => !(idx === arr.length - 1 && arr[idx] === ''))
                  .map((line, j) => (
                    <span key={j} className="block whitespace-pre">
                      {sign}
                      {line}
                    </span>
                  ))}
              </span>
            )
          })}
        </pre>
      </div>

      <div className="flex gap-2">
        <Button onClick={handleApply} disabled={saving}>
          {saving ? (
            <Loader2 className="mr-2 size-4 animate-spin" />
          ) : (
            <Check className="mr-2 size-4" />
          )}
          Apply
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
// ChatEditFlow — multi-turn chat where the AI proposes spec changes
// inline. Each turn that wraps a spec in `<spec>` tags renders as a
// chat bubble PLUS a diff card with per-message Apply / Discard buttons.
// Conversation history lives in component state (clears on mode toggle
// or page leave — v1 scope; persistence is an ADR open question).
// ---------------------------------------------------------------------------

interface ChatTurn {
  role: 'user' | 'assistant'
  /** Raw provider response. For assistant turns, the prose has the
   *  `<spec>` block stripped; for user turns this is just the input. */
  prose: string
  /** Pretty-printed proposed spec for assistant turns that included a
   *  `<spec>` block. null = chat-only message. */
  proposedSpec: string | null
  /** Whether the user has applied this turn's proposed spec. Apply
   *  closes the diff card; Discard does the same without saving. */
  applied: boolean
  discarded: boolean
}

interface ChatProps {
  app: AppRecord
  registry: AppRegistry
  systemPrompt: string
  aiSettings: ReturnType<typeof getAiSettings>
}

function ChatEditFlow({ app, registry, systemPrompt, aiSettings }: ChatProps) {
  const navigate = useNavigate()

  // The chat operates on the live current spec — when the user applies
  // a patch, this state moves forward so subsequent turns build on it.
  const [currentSpec, setCurrentSpec] = useState(() => {
    try {
      return JSON.stringify(JSON.parse(app.specJson), null, 2)
    } catch {
      return app.specJson
    }
  })
  const [turns, setTurns] = useState<ChatTurn[]>([])
  const [input, setInput] = useState('')
  const [generating, setGenerating] = useState(false)
  const [genError, setGenError] = useState<string | null>(null)
  const [savingTurnIndex, setSavingTurnIndex] = useState<number | null>(null)
  const abortRef = useRef<AbortController | null>(null)
  const scrollerRef = useRef<HTMLDivElement | null>(null)

  const provider: AiProvider = useMemo(
    () => (aiSettings.provider === 'anthropic' ? new AnthropicProvider() : new OpenAiProvider()),
    [aiSettings.provider],
  )

  // Auto-scroll to the bottom whenever the conversation grows.
  useEffect(() => {
    const el = scrollerRef.current
    if (el) el.scrollTop = el.scrollHeight
  }, [turns, generating])

  async function handleSend() {
    if (!input.trim() || generating) return
    const userText = input.trim()
    setInput('')
    setGenError(null)

    const newUserTurn: ChatTurn = {
      role: 'user',
      prose: userText,
      proposedSpec: null,
      applied: false,
      discarded: false,
    }
    const nextTurns = [...turns, newUserTurn]
    setTurns(nextTurns)

    setGenerating(true)
    const ac = new AbortController()
    abortRef.current = ac
    try {
      // Build the conversation history the provider sees: every prior
      // user turn + every prior assistant prose. Skip the proposedSpec
      // payload — the system prompt already contains the latest spec.
      const history: Message[] = nextTurns.slice(0, -1).map((t) => ({
        role: t.role,
        content: t.role === 'assistant' && t.proposedSpec != null
          ? `${t.prose}\n\n<spec>${t.proposedSpec}</spec>`
          : t.prose,
      }))
      const system = buildChatSystemPrompt(systemPrompt, currentSpec)
      const res = await provider.sendMessage(system, history, userText, {
        model: aiSettings.model,
        apiKey: aiSettings.apiKey,
        signal: ac.signal,
      })
      const { prose, spec } = extractProposedSpec(res.text)
      let prettySpec: string | null = null
      if (spec != null) {
        try {
          prettySpec = JSON.stringify(JSON.parse(spec), null, 2)
        } catch {
          prettySpec = spec
        }
      }
      const assistantTurn: ChatTurn = {
        role: 'assistant',
        prose,
        proposedSpec: prettySpec,
        applied: false,
        discarded: false,
      }
      setTurns([...nextTurns, assistantTurn])
    } catch (e) {
      if (ac.signal.aborted) {
        // User hit Stop — show a friendly note in chat instead of an error.
        setTurns([
          ...nextTurns,
          { role: 'assistant', prose: '_(stopped)_', proposedSpec: null, applied: false, discarded: true },
        ])
      } else {
        const msg = e instanceof AiProviderError
          ? `${e.provider} ${e.status ?? ''}: ${e.message}`.trim()
          : e instanceof Error
            ? e.message
            : String(e)
        setGenError(msg)
      }
    } finally {
      setGenerating(false)
      abortRef.current = null
    }
  }

  function handleStop() {
    abortRef.current?.abort()
  }

  async function handleApplyTurn(index: number) {
    const turn = turns[index]
    if (!turn || turn.proposedSpec == null) return
    setSavingTurnIndex(index)
    const result = parseSpec(turn.proposedSpec)
    if (result.parseError || !isOk(result)) {
      const errors = result.parseError
        ?? result.validation.messages.filter((m) => m.level === 'error').map((m) => m.message).join('\n')
      toast.error(`Validation failed: ${errors}`)
      setSavingTurnIndex(null)
      return
    }
    const ok = await registry.updateApp(app.id, turn.proposedSpec)
    setSavingTurnIndex(null)
    if (!ok) {
      toast.error('Failed to save')
      return
    }
    toast.success('Applied — current spec updated')
    setCurrentSpec(turn.proposedSpec)
    setTurns((ts) =>
      ts.map((t, i) => (i === index ? { ...t, applied: true } : t)),
    )
  }

  function handleDiscardTurn(index: number) {
    setTurns((ts) =>
      ts.map((t, i) => (i === index ? { ...t, discarded: true } : t)),
    )
  }

  return (
    <div className="mx-auto flex h-[calc(100vh-12rem)] max-w-5xl flex-col gap-3 p-6">
      <div className="rounded-lg border bg-muted/30 p-3 text-xs text-muted-foreground">
        Chat with <span className="font-medium text-foreground">{aiSettings.provider}</span> ·{' '}
        <span className="font-medium text-foreground">{aiSettings.model}</span>. The AI sees
        the current spec on every turn and may propose changes inline. You apply or discard
        each proposal independently.{' '}
        <Link to="/admin/settings" className="text-primary hover:underline">
          Change in Settings
        </Link>
      </div>

      <div ref={scrollerRef} className="flex-1 overflow-y-auto rounded-lg border bg-background p-3 space-y-3">
        {turns.length === 0 && !generating && (
          <div className="flex h-full flex-col items-center justify-center gap-2 text-center text-sm text-muted-foreground">
            <MessageCircle className="size-6" />
            Ask anything — *"add a priority field"*, *"why isn't my form submitting?"*,
            *"what would a kanban view of this look like?"*
          </div>
        )}

        {turns.map((turn, i) => (
          <ChatTurnView
            key={i}
            turn={turn}
            currentSpec={currentSpec}
            saving={savingTurnIndex === i}
            onApply={() => handleApplyTurn(i)}
            onDiscard={() => handleDiscardTurn(i)}
            onAfterApplyNavigate={() => navigate('/admin')}
          />
        ))}

        {generating && (
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <Loader2 className="size-4 animate-spin" />
            Thinking…
          </div>
        )}
      </div>

      {genError && (
        <div className="rounded-lg border border-destructive/50 bg-destructive/10 px-4 py-3 text-sm text-destructive whitespace-pre-wrap">
          {genError}
        </div>
      )}

      <div className="flex gap-2">
        <Textarea
          placeholder="Ask the AI to make a change, or just ask a question…"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
              e.preventDefault()
              handleSend()
            }
          }}
          rows={2}
          className="text-sm"
          disabled={generating}
        />
        {generating ? (
          <Button variant="outline" onClick={handleStop} title="Cancel the in-flight request">
            <Square className="mr-2 size-4" />
            Stop
          </Button>
        ) : (
          <Button onClick={handleSend} disabled={!input.trim()}>
            <Send className="mr-2 size-4" />
            Send
          </Button>
        )}
      </div>
      <p className="-mt-1 text-[11px] text-muted-foreground">
        Ctrl/⌘ + Enter to send.
      </p>
    </div>
  )
}

interface ChatTurnViewProps {
  turn: ChatTurn
  currentSpec: string
  saving: boolean
  onApply: () => void
  onDiscard: () => void
  onAfterApplyNavigate: () => void
}

function ChatTurnView({ turn, currentSpec, saving, onApply, onDiscard }: ChatTurnViewProps) {
  const isUser = turn.role === 'user'
  const showDiff = !!turn.proposedSpec && !turn.applied && !turn.discarded

  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}>
      <div className={`max-w-[85%] space-y-2 ${isUser ? 'items-end' : 'items-start'} flex flex-col`}>
        {turn.prose.trim().length > 0 && (
          <div
            className={`whitespace-pre-wrap rounded-lg px-3 py-2 text-sm ${
              isUser
                ? 'bg-primary text-primary-foreground'
                : 'border bg-muted/40'
            }`}
          >
            {turn.prose}
          </div>
        )}

        {turn.proposedSpec != null && turn.applied && (
          <div className="text-xs text-muted-foreground italic">
            ✓ Spec change applied.
          </div>
        )}
        {turn.proposedSpec != null && turn.discarded && (
          <div className="text-xs text-muted-foreground italic">
            Spec change discarded.
          </div>
        )}

        {showDiff && (
          <DiffCard
            currentSpec={currentSpec}
            proposedSpec={turn.proposedSpec!}
            saving={saving}
            onApply={onApply}
            onDiscard={onDiscard}
          />
        )}
      </div>
    </div>
  )
}

interface DiffCardProps {
  currentSpec: string
  proposedSpec: string
  saving: boolean
  onApply: () => void
  onDiscard: () => void
}

function DiffCard({ currentSpec, proposedSpec, saving, onApply, onDiscard }: DiffCardProps) {
  const parts = useMemo(() => diffLines(currentSpec, proposedSpec), [currentSpec, proposedSpec])

  return (
    <div className="w-full overflow-hidden rounded-lg border">
      <div className="flex items-center gap-2 border-b bg-muted/40 px-3 py-2 text-xs font-semibold">
        <Sparkles className="size-3.5" />
        Proposed spec change
      </div>
      <pre className="max-h-72 overflow-auto bg-background p-3 text-[11px] leading-relaxed">
        {parts.map((part, i) => {
          const cls = part.added
            ? 'block bg-green-500/10 text-green-700 dark:text-green-400'
            : part.removed
              ? 'block bg-red-500/10 text-red-700 dark:text-red-400'
              : 'block text-muted-foreground'
          const sign = part.added ? '+ ' : part.removed ? '- ' : '  '
          return (
            <span key={i} className={cls}>
              {part.value
                .split('\n')
                .filter((_, idx, arr) => !(idx === arr.length - 1 && arr[idx] === ''))
                .map((line, j) => (
                  <span key={j} className="block whitespace-pre">
                    {sign}
                    {line}
                  </span>
                ))}
            </span>
          )
        })}
      </pre>
      <div className="flex gap-2 border-t bg-muted/20 px-3 py-2">
        <Button size="sm" onClick={onApply} disabled={saving}>
          {saving ? (
            <Loader2 className="mr-1.5 size-3.5 animate-spin" />
          ) : (
            <Check className="mr-1.5 size-3.5" />
          )}
          Apply
        </Button>
        <Button size="sm" variant="ghost" onClick={onDiscard} disabled={saving}>
          <X className="mr-1.5 size-3.5" />
          Discard
        </Button>
      </div>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Copy/paste fallback flow — the original 3-step UI, used when AI is not
// configured. Includes a callout pointing the user at Settings → AI.
// ---------------------------------------------------------------------------

interface FallbackProps {
  app: AppRecord
  registry: AppRegistry
  buildHelperPrompt: string | null
}

function CopyPasteFallbackFlow({ app, registry, buildHelperPrompt }: FallbackProps) {
  const navigate = useNavigate()
  const [promptCopied, setPromptCopied] = useState(false)
  const [specCopied, setSpecCopied] = useState(false)
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

  async function handleCopySpec() {
    try {
      let pretty: string
      try {
        pretty = JSON.stringify(JSON.parse(app.specJson), null, 2)
      } catch {
        pretty = app.specJson
      }
      await navigator.clipboard.writeText(pretty)
      setSpecCopied(true)
      toast.success('App spec copied to clipboard')
    } catch {
      toast.error('Failed to copy — try manually selecting the text')
    }
  }

  async function handleImport() {
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
    const success = await registry.updateApp(app.id, pasteText)
    setSaving(false)
    if (success) {
      toast.success('App updated successfully!')
      navigate('/admin')
    } else {
      setImportError('Failed to save the updated spec')
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
          to skip the copy/paste loop and edit your app in one click.
        </p>
      </div>

      <p className="text-sm text-muted-foreground">
        Use an AI chatbot (ChatGPT, Claude, etc.) to modify your app. Follow the three steps below.
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
          <h2 className="font-semibold">Copy Your Current App Spec</h2>
        </div>
        <p className="mb-3 text-sm text-muted-foreground">
          Paste this into the AI chat as your second message. Tell the AI what changes you want.
        </p>
        <Button onClick={handleCopySpec} variant={specCopied ? 'secondary' : 'default'}>
          {specCopied ? (
            <>
              <ClipboardCheck className="mr-2 size-4" />
              Copied!
            </>
          ) : (
            <>
              <FileJson className="mr-2 size-4" />
              Copy App Spec
            </>
          )}
        </Button>
      </div>

      {/* Step 3 */}
      <div className="rounded-lg border p-4">
        <div className="mb-2 flex items-center gap-2">
          <span className="flex size-6 items-center justify-center rounded-full bg-primary text-xs font-bold text-primary-foreground">
            3
          </span>
          <h2 className="font-semibold">Paste the Updated Spec</h2>
        </div>
        <p className="mb-3 text-sm text-muted-foreground">
          Copy the AI's updated JSON and paste it below. We'll validate and save it.
        </p>

        {importError && (
          <div className="mb-3 rounded-lg border border-destructive/50 bg-destructive/10 px-4 py-3 text-sm text-destructive whitespace-pre-wrap">
            {importError}
          </div>
        )}

        <Textarea
          placeholder='Paste updated JSON here...'
          value={pasteText}
          onChange={(e) => setPasteText(e.target.value)}
          rows={10}
          className="mb-3 font-mono text-xs"
        />

        <Button onClick={handleImport} disabled={saving || !pasteText.trim()}>
          {saving ? (
            <Loader2 className="mr-2 size-4 animate-spin" />
          ) : (
            <Check className="mr-2 size-4" />
          )}
          Validate & Save
        </Button>
      </div>
    </div>
  )
}
