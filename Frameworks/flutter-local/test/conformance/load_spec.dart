/// Loads a named spec from the shared `Frameworks/conformance/specs/`
/// directory. Mirrors `loadSpec` in
/// `Frameworks/conformance/src/load-spec.ts` — both sides read the same
/// JSON bytes, which is how we avoid spec divergence between drivers.
library;

import 'dart:convert';
import 'dart:io';

import 'contract.dart';

/// Path from the Flutter package root (CWD when `flutter test` runs) to the
/// shared specs directory.
const _specsDir = '../conformance/specs';

/// Load a named spec. Each call returns a fresh object (no caching) so
/// scenarios can't leak state between runs.
OdsSpec loadSpec(String name) {
  final file = File('$_specsDir/$name.json');
  if (!file.existsSync()) {
    throw StateError(
      'loadSpec: no spec file at ${file.path} '
      '(did you forget to create Frameworks/conformance/specs/$name.json?)',
    );
  }
  final content = file.readAsStringSync();
  return jsonDecode(content) as OdsSpec;
}
