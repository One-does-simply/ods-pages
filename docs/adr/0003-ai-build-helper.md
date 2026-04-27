# ADR-0003 — In-app AI Build Helper (BYO API key)

**Status:** draft
**Date:** 2026-04-27
**Tracked in:** [TODO.md](../../TODO.md) — *AI Build Helper (BYO API key)*

---

## 1. Context

ODS Pages has had an AI workflow since day one, but it lives entirely
outside the framework: builders copy a system prompt and their current
spec into ChatGPT or Claude, work back and forth, and paste the result
back. The asset bundle ships as
[`Specification/build-helper-prompt.txt`](../../Specification/build-helper-prompt.txt)
with provider-specific variants under
[`BuildHelpers/Claude/`](../../BuildHelpers/Claude/) and
[`BuildHelpers/ChatGPT/`](../../BuildHelpers/ChatGPT/), and the React
framework wraps the copy/paste UX as a 3-step screen
([`EditWithAiScreen.tsx`](../../Frameworks/react-web/src/screens/EditWithAiScreen.tsx)).
Flutter has no AI surface at all today.

This split has accumulated friction now that more builders have their
own API keys:

### 1.1 Same dance whether you have a key or not

A user with an Anthropic key still has to: open the AI screen, copy
the system prompt, switch to claude.ai, paste, switch back to ODS,
copy the spec, switch back to claude.ai, paste, wait, copy the
result, switch back to ODS, paste, save. That's 8+ context switches
for a one-line change. Having a key buys nothing.

### 1.2 Iteration starts fresh every time

Each "Edit with AI" round-trip is a brand-new conversation. *"Now
make the priority field default to medium"* requires re-pasting the
prompt, the spec (which may have been updated since the last round),
and the new instruction. There's no continuity for non-trivial edits.

### 1.3 No safety net

Today the user pastes the AI's output back into a textarea and hits
Save. If the AI hallucinated an `OdsBrandng` field or dropped a
matchField, the validator catches it on load — but the user has
already lost their previous spec and has to undo by hand. There's no
diff-review step where they can see what changed before committing.

### 1.4 Flutter parity gap

The whole "Edit with AI" surface is React-only. Flutter Quick Build
exists, but nothing equivalent to "edit an existing app via AI."

### 1.5 Provider asymmetry would creep in

We currently maintain two prompt files (Claude and ChatGPT) but the
framework only wires the prompt asset for one path. If the in-app
integration locks to a single provider, builders on the other side
become second-class.

## 2. Decision

Add an in-app **AI Build Helper** that activates when the builder has
provided an API key. Two interaction modes share one provider layer:

**One-shot edit.** User types *"add a priority field with low/med/high
options"*; framework sends current spec + instruction + system prompt
to the configured provider; receives a proposed new spec; renders a
side-by-side diff; user accepts or discards. Same as today's
copy/paste loop, just collapsed into one button + one diff.

**Multi-turn chat.** User opens a chat panel, has an ongoing
conversation. Each AI message that proposes a spec change renders as
a diff card with its own Apply / Discard buttons. Conversation
history (in-memory for v1) gives the AI context for *"now make the
default 'medium'"* without re-pasting the spec.

Both modes go through one **`AiProvider`** abstraction with
**Anthropic** and **OpenAI** implementations from day one. The
builder picks a provider + model in the framework settings; key is
stored in `SettingsStore` (Flutter) / localStorage (React) for v1,
with OS-keychain integration noted as a follow-up.

The existing 3-step copy/paste flow stays as the **no-key fallback**:
clicking "Edit with AI" without a configured key still works as it
does today, plus a one-liner *"have an API key? Set it once in
Settings → AI to skip the copy/paste."*

## 3. Consequences

**Good:**

- A configured user goes from 8+ context switches to: type → review
  diff → accept. Target: 5 seconds for a one-line change.
- The diff-review gate keeps the user in control. The AI never
  silently rewrites their spec.
- Provider abstraction means OpenAI users aren't second-class —
  same UI, same modes, same behavior.
- The system prompt loaded by the in-app helper is always the version
  shipped with the framework — no chance of an out-of-date copy
  pasted into a chat session.
- Multi-turn chat unlocks iterative refinement (*"and now…"*) without
  losing context.
- Flutter gets parity for the first time on this surface.

**Bad:**

- Outbound HTTP to `api.anthropic.com` / `api.openai.com` is new for
  the framework — both renderers' only HTTP today is to the local
  PocketBase / SQLite. Adds one egress dependency.
- Token spend is on the builder's wallet. A bad prompt is an
  expensive call. Mitigation: show estimated input/output token
  counts before each call; allow cancel mid-flight.
- API keys in `localStorage` / `SettingsStore` are less secure than
  OS keychain. Mitigation: clearly mark v1 as "best-effort, see
  Settings → AI for what's stored where"; mask in UI; never log.
- Multi-turn chat is a non-trivial UI build (~500 LOC each side).
- Provider drift: when a new model lands, our curated dropdown is
  stale until we ship an update. Mitigation: dropdown allows
  "Custom…" model id as an escape hatch (mirrors the FontPicker
  pattern from ADR-0002).

**Neutral:**

- The shared system prompt becomes more important — both interaction
  modes pull from it. Quality of that file matters more.
- We now own a provider-API contract test — model providers do break
  things in dot releases. The conformance suite catches it.

## 4. Alternatives considered

- **Mandate one provider.** Simpler. Rejected because the BuildHelpers
  folder already maintains both, and forcing users to pick the "wrong"
  one is friction we can't justify.
- **Server-side AI (we hold the key).** Eliminates the BYOK story but
  turns the framework into a metered service we run, which contradicts
  the local-first / self-hosted ethos. Also a billing system to
  maintain.
- **One-shot only, skip chat.** Half the build for 80% of the value.
  Reasonable v1 scope; rejected because the user explicitly asked for
  "more interactive" which strongly implies turn-by-turn.
- **Auto-apply, no diff gate.** Faster but loses user trust on the
  first wrong edit. Rejected.
- **Inline suggestions in the JSON editor (IDE-style ghost text).**
  Powerful but a much larger build (CodeMirror ghost-text bindings,
  partial-spec validation, etc.). Possible v3.
- **Tool use / function calling** (the AI calls `apply_patch(pointer,
  value)` directly rather than returning a full spec). Cleaner for
  large specs but adds plumbing on top of v1. Open question, see §5.

## 5. Open questions

- **Streaming.** Stream tokens for responsiveness, or wait for the
  full response? Streaming is nicer UX but adds chunk handling and
  cancellation logic. Default-no for v1 unless we hear otherwise.
- **Cost ceiling.** Hard limit per session, or just a warning when
  estimated cost exceeds a configurable threshold? Default warning-only.
- **Conversation persistence.** In-memory only (closes with the chat
  panel) for v1. Per-app history would be nicer but raises a storage
  + privacy question. Tracked.
- **Tool use vs. full-spec response.** Function-calling is the modern
  way; both providers support it. Adds round-trip count but reduces
  token spend on big specs. Defer to phase-by-phase decision.
- **PII redaction.** Should we redact obvious user data (emails,
  names) from rows in the spec before sending? Most spec content is
  schema, not data — but `seedData` could carry real names. Default
  off; document in the AI Settings panel.
- **Flutter feature parity for chat mode.** Definitely yes long-term;
  v1 question is whether to ship one-shot first on Flutter and chat
  second, or both at once. Lean toward one-shot first.

## 6. Implementation sketch

Phased so the provider layer + settings land first (small, well-tested),
then the UI surfaces in order of impact.

### Phase 1 — Provider layer (React + Flutter, in parallel)

- New module: `src/engine/ai-provider.ts` (TS) and
  `lib/engine/ai_provider.dart` (Dart).
- Interface (TS, Dart mirror):

  ```ts
  interface AiProvider {
    name: 'anthropic' | 'openai'
    models: Array<{ id: string; label: string }>
    estimateCost(systemPrompt: string, history: Message[], user: string):
      { inputTokens: number; estimatedCostUsd: number }
    sendMessage(
      systemPrompt: string,
      history: Message[],
      user: string,
      opts: { model: string; apiKey: string; signal?: AbortSignal },
    ): Promise<{ text: string; usage: { in: number; out: number } }>
  }
  ```

- Implementations: `AnthropicProvider` (Messages API),
  `OpenAiProvider` (Chat Completions API).
- Pure HTTP — `fetch` (TS) / `package:http` (Dart). No SDK deps.
- Unit tests on each: feed a fake transport, assert request shape
  (URL, headers, body).
- Property-based test on the request builder: any valid system +
  history + user input → well-formed request body.

### Phase 2 — Framework AI Settings (React + Flutter)

- React: new "AI" section in `SettingsDialog`. Flutter: equivalent
  in framework settings (not per-app — the key is a user-level
  concern).
- Fields: provider radio (Anthropic / OpenAI / None), API key
  (masked input, paste-to-confirm), model dropdown populated per
  provider, "Test connection" button (1-token ping).
- Storage: `ods_ai_settings` JSON in localStorage / `SettingsStore`.
  v1 plaintext; OS-keychain tracked as follow-up ADR.
- Mask key on display; never log it.

### Phase 3 — One-shot edit mode (React first)

- Replace or augment `EditWithAiScreen`: textarea for instruction +
  "Generate" button (disabled if no key configured).
- On submit: build prompt (system from
  `Specification/build-helper-prompt.txt` + user wraps current spec
  + instruction) → estimateCost → if over warning threshold confirm
  → call provider → receive proposed spec → render side-by-side diff
  using a small diff library (or hand-roll line-based; this isn't
  prose so character-level diff is overkill).
- On Apply: route through the existing parser + validator. A
  hallucinated bad spec is caught before save; user gets the
  validation error and can re-prompt.

### Phase 4 — Multi-turn chat panel (React first)

- Slide-in panel from the right of `EditWithAiScreen` (and possibly
  also the AdminDashboard? — defer).
- Standard chat UI: message bubbles, user input at bottom, AI typing
  indicator, Stop button.
- Each AI response that proposes a patch renders as a diff card with
  per-message Apply / Discard buttons.
- History in component state for v1; clears on close.

### Phase 5 — Conformance + tests

- New conformance scenario `s27_ai_provider_request_shape`: for the
  same `(systemPrompt, history, userInput)`, both providers must
  produce a request body that includes the system prompt, the user
  message, and the configured model. Fake transport, no real
  network. Same red→green→both-drivers-pass discipline as ADR-0002
  scenarios.
- Mutation tests on the provider modules — small modules, high
  coverage, perfect Stryker target.

### Phase 6 — Flutter mirror

- `AiSettingsSection` in Flutter framework settings.
- One-shot edit screen mirroring React's. Chat panel deferred to a
  follow-up unless v1 timeline allows.

### Out of scope for v1

- OS-keychain storage (separate ADR / TODO item).
- Streaming token UI (open question; non-streaming v1).
- Inline JSON-editor suggestions (possible v3).
- Tool use / function calling (open question; if we adopt, separate
  phase).
- Cross-session conversation persistence.
- Cost-ceiling hard limits (warnings only in v1).

---

## Phasing summary

| Phase | Lands | Surface | Frameworks |
|-------|-------|---------|------------|
| 1 | Provider layer + tests | none (engine) | React + Flutter parallel |
| 2 | AI Settings panel | Settings | React + Flutter |
| 3 | One-shot edit | EditWithAi screen | React |
| 4 | Multi-turn chat | EditWithAi panel | React |
| 5 | Conformance + mutation | tests | both |
| 6 | Flutter mirror | EditWithAi screen | Flutter |

Estimated 4–6 sessions across both frameworks, similar to ADR-0002.
