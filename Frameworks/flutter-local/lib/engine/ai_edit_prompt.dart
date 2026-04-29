// ---------------------------------------------------------------------------
// One-shot edit prompt builder + response parser (ADR-0003 phase 6) — Dart
// mirror of Frameworks/react-web/src/engine/ai-edit-prompt.ts.
//
// Pure functions so the screen stays focused on UI state. Keep the wording
// in this file in sync with the React side — the Build Helper assets feed
// both implementations and the conformance contract pins the wire shape.
// ---------------------------------------------------------------------------

library;

const _oneShotDirective = '''
IMPORTANT for this conversation: the user is editing an existing ODS spec.
Reply with ONLY the complete updated JSON spec — no commentary, no
explanation, no markdown code fences. The first character of your reply
must be `{` and the last must be `}`. Preserve every field the user did
not ask you to change.''';

class EditPrompt {
  final String system;
  final String user;
  const EditPrompt({required this.system, required this.user});
}

/// Build the one-shot edit prompt. `baseSystem` is the canonical
/// `build-helper-prompt.txt` asset (or any future replacement); the
/// one-shot directive is appended automatically.
EditPrompt buildEditPrompt(
  String currentSpec,
  String instruction,
  String baseSystem,
) {
  final trimmedBase = baseSystem.trim();
  final system = trimmedBase.isEmpty
      ? _oneShotDirective
      : '$trimmedBase\n\n$_oneShotDirective';
  final user =
      'Current spec:\n\n$currentSpec\n\nMake this change:\n$instruction';
  return EditPrompt(system: system, user: user);
}

/// Strip markdown fences and surrounding commentary from the AI's
/// response, returning what we hope is pure JSON. Caller still has to
/// pass the result through the spec parser to validate.
///
///  - Matches a ```json (or bare ```) fence anywhere in the response and
///    returns the contents.
///  - Otherwise trims surrounding whitespace and returns as-is.
String extractJsonSpec(String response) {
  final fence = RegExp(
    r'```(?:json)?\s*\n([\s\S]*?)\n```',
    caseSensitive: false,
  ).firstMatch(response);
  if (fence != null) return fence.group(1)!.trim();
  return response.trim();
}
