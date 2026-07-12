// ---------------------------------------------------------------------------
// Multi-turn chat prompt builder + response parser (ADR-0003 phase 4) — Dart
// mirror of Frameworks/react-web/src/engine/ai-chat-prompt.ts.
//
// The chat protocol uses `<spec>...</spec>` tags so the AI can reply with
// prose, with a complete spec proposal, or both. The screen renders the
// prose as a chat bubble and any proposed spec as a diff card with
// Apply / Discard buttons.
//
// Why tags, not function-calling: Anthropic and OpenAI tool-use shapes
// differ; this stays provider-neutral. The directive is in the system
// prompt; the parser is forgiving (tag-only, prose-only, mixed all
// supported) and tests pin the cases. Keep the wording in sync with the
// React side — the Build Helper assets feed both implementations.
// ---------------------------------------------------------------------------

library;

const _chatProtocolDirective = '''
PROTOCOL FOR THIS CONVERSATION
==============================
You are helping the user iteratively edit an ODS spec across multiple
turns. The user can apply or discard each spec change you propose.

When you propose a complete spec change, wrap the FULL updated JSON in
`<spec>` tags, like this:

  <spec>
  {"appName":"…","startPage":"…","pages":{…},"dataSources":{…}}
  </spec>

Rules:
- The wrapped JSON must be the complete spec, not a partial patch.
- Preserve every field the user did not ask you to change.
- Outside the tags, write normal conversational text — explain what
  you changed, ask clarifying questions, etc. The user reads that.
- Do NOT use markdown code fences for the spec; only the `<spec>` tags.
- One `<spec>` block per turn. If you want to offer alternatives,
  describe them in prose and let the user pick.

If you have a question or are just chatting, reply with prose only and
no `<spec>` tags.''';

/// The result of splitting an AI response into conversational prose and
/// an optional proposed spec.
class ProposedSpec {
  /// Everything outside the `<spec>` tags.
  final String prose;

  /// The JSON inside the first complete tag block, or `null` if there
  /// isn't one.
  final String? spec;
  const ProposedSpec({required this.prose, required this.spec});
}

/// Build the system prompt for a multi-turn chat. [baseSystem] is the
/// canonical `build-helper-prompt.txt` (or any future replacement); the
/// protocol directive + the current spec are appended automatically so
/// the AI always has working context for this turn.
String buildChatSystemPrompt(String baseSystem, String currentSpec) {
  final trimmedBase = baseSystem.trim();
  final head = trimmedBase.isEmpty
      ? _chatProtocolDirective
      : '$trimmedBase\n\n$_chatProtocolDirective';
  return '$head\n\nCURRENT SPEC\n============\n$currentSpec';
}

/// Split an AI response into prose (everything outside `<spec>` tags) and
/// the proposed spec (the JSON inside the first complete tag block, or
/// `null` if there isn't one).
///
///  - Tag-only responses → prose is the empty string.
///  - Prose-only responses → spec is null.
///  - Multiple tag blocks → first one wins (matches the system-prompt
///    "one per turn" rule; later ones become normal prose).
///  - Malformed (opening tag without close) → spec is null and the prose
///    keeps the raw text so the user sees what happened.
ProposedSpec extractProposedSpec(String response) {
  final match = RegExp(
    r'<spec>([\s\S]*?)<\/spec>',
    caseSensitive: false,
  ).firstMatch(response);
  if (match == null) return ProposedSpec(prose: response, spec: null);
  final spec = match.group(1)!.trim();
  final prose =
      (response.substring(0, match.start) + response.substring(match.end))
          .trim();
  return ProposedSpec(prose: prose, spec: spec);
}
