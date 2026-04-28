// ---------------------------------------------------------------------------
// One-shot edit prompt builder + response parser (ADR-0003 phase 3).
//
// Pure functions so the screen stays focused on UI state. The prompt
// strategy is straightforward: take the canonical "ODS Build Helper"
// system prompt as-is, append a directive that pins JSON-only output for
// this turn, and frame the user message with the current spec + the
// requested change.
//
// `extractJsonSpec` is a small response cleaner: most LLMs honor the
// directive, but some still wrap the answer in markdown fences. Strip
// fences and surrounding chatter so the parser sees pure JSON.
// ---------------------------------------------------------------------------

const ONE_SHOT_DIRECTIVE = `
IMPORTANT for this conversation: the user is editing an existing ODS spec.
Reply with ONLY the complete updated JSON spec — no commentary, no
explanation, no markdown code fences. The first character of your reply
must be \`{\` and the last must be \`}\`. Preserve every field the user
did not ask you to change.
`.trim()

export interface EditPrompt {
  /** Sent as the system prompt to the provider. */
  system: string
  /** Sent as the user message. */
  user: string
}

/**
 * Build the one-shot edit prompt. `baseSystem` is the canonical
 * `build-helper-prompt.txt` asset (or any future replacement); the
 * one-shot directive is appended automatically.
 */
export function buildEditPrompt(
  currentSpec: string,
  instruction: string,
  baseSystem: string,
): EditPrompt {
  const system = baseSystem.trim()
    ? `${baseSystem.trim()}\n\n${ONE_SHOT_DIRECTIVE}`
    : ONE_SHOT_DIRECTIVE
  const user = `Current spec:\n\n${currentSpec}\n\nMake this change:\n${instruction}`
  return { system, user }
}

/**
 * Strip markdown fences and surrounding commentary from the AI's
 * response, returning what we hope is pure JSON. Caller still has to
 * pass the result through `parseSpec` to validate.
 *
 *  - Matches a ```json (or bare ```) fence anywhere in the response and
 *    returns the contents.
 *  - Otherwise trims surrounding whitespace and returns as-is.
 */
export function extractJsonSpec(response: string): string {
  const fence = /```(?:json)?\s*\n([\s\S]*?)\n```/i.exec(response)
  if (fence) return fence[1].trim()
  return response.trim()
}
