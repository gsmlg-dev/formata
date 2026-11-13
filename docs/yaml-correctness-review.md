# YAML correctness and resource-limit review

Execution started on 2026-11-13 from clean `main` at
`45e5b697f1e019eb0d2342ad00b4ee4b7148c358` (0.3.1), after the supplied
static-review baseline `735ae8db1f089ab0e7532470cce044cd3a2dcc9f` (0.3.0).
The intervening TOML changes were retained. This remains one Mix library
with no runtime dependencies, and the existing vendored YAML implementation
is the maintenance baseline. No upstream repository or issue was changed.

## Findings

| Finding | Public API reproduction at starting HEAD | Fix and regression |
| --- | --- | --- |
| A: incomplete integers | Default-core `+`, `0x`, `0o` became zero | Require a first digit and the complete core integer grammar. Signs apply only to decimal integers. Unrecognized implicit scalars fall back to strings; invalid `!!int` is a syntax error. Quoted, valid and signed-prefix controls retain their declared types. |
| B: key subtrees | A sequence key containing duplicate mapping entries was accepted after loss; null keys failed; mapping keys exposed internal records | Detailed entries are validated before ordinary maps are constructed. Null scalar keys now work; sequence/mapping keys return `:unsupported` / `:unsupported_key` before lossy conversion. Normalized scalar-key duplicates are rejected. |
| C: literal `<<` | Quoted and explicitly string-tagged keys were rejected; the internal mapper also rewrote them | Preserve scalar style and source tag. Only the plain implicit convention is a merge key. Quoted/`!!str` keys retain the literal string; encoding quotes it. |
| D: root null | `encode(nil, :yaml)` returned `:roundtrip_mismatch` because `nil` emitted as the string `nil` | Emit `null`; preserve the distinct string `"nil"`. Root, map and sequence tests cover null, empty strings/collections and scalar roots. |
| E: strings | Leading-space multiline values produced unreadable YAML or changed spaces; CRLF became LF, and the guard returned errors | Preserve safe block formatting/chomping; use complete YAML double-quoted escapes when blocks cannot preserve content, including multiline keys. `.5` remains a string, and the skipped leading-space vendor test is now enabled. |

One review premise was disproved: `"a\n\u0000"` did **not** fail the public
round-trip guard at the starting HEAD. The emitter wrote raw NUL and the
decoder accepted it, so internal agreement hid invalid YAML. It now emits
escaped LF/NUL, checked by an independent parser. A minimized U+FEFF case
also revealed content being consumed as a BOM; the emitter now escapes it.
The final round-trip guard remains enabled.

The small alias ladder additionally reproduced incorrect values: an anchor
before a flow collection attached to a child or subsequent mapping key.
The parser now attaches that anchor to the collection. No production denial
of service was measured, and no unbounded stress test was run.

The scoped official fixtures also exposed invalid escapes being treated as
warnings, document markers inside quoted scalars being accepted, a crash for
an implicit empty key, and a folded tab-indented line losing its line break.
Their regressions remain enabled. Escape validation checks each hex digit
and Unicode scalar/range boundaries rather than relying on host conversion
or a broad exception rescue.

## Schema and key contract

Absent a version directive, and for `%YAML 1.2`, the vendored constructor
uses the YAML 1.2 core schema. Plain timestamps remain strings; special
floats use `:infinity`, `:negative_infinity`, and `:nan`. Explicit `%YAML 1.1`
retains its separate vendored resolution: `yes` is boolean, `012` is octal,
and legacy integer/float forms resolve under that schema. The patch does
not reinterpret every version as 1.2, and does not add timestamp structs.
The existing parser's version compatibility policy is retained: legacy 1.0
also uses the 1.1 schema; later 1.x minor directives are parsed with the
core schema and a backend warning, while unsupported major versions fail.

Decoded keys may be scalar strings, integers, booleans, null (`nil`), finite
floats, or the special-float atoms. They retain type identity: integer `1`
differs from string `"1"`, and boolean `true` differs from string `"true"`.
Duplicate detection happens after normalization, so different spellings of
the same scalar cannot silently collide. Sequence/mapping keys are an
intentional compatibility restriction: previous partial sequence-key support
could discard entries, and mapping keys were not ordinary mapped values.
Such valid YAML is explicitly unsupported, not called a syntax error.

The encoder domain is unchanged: only string, integer and boolean keys.
Null/float/complex keys and temporal structs remain outside that domain.
No input creates atoms. The plain implicit `<<` convention is rejected as
a compatibility policy, not asserted to be part of mandatory YAML 1.2 core.
Quoted `"<<"` and explicitly string-tagged `!!str <<` are ordinary strings.

## Bounded pipeline

The public decoder performs one detailed parse, retaining duplicate pairs
and scalar source metadata. It then validates, normalizes and converts in
one traversal. Ordinary maps are only built after their entries pass checks.

Both public operations validate these per-call options:

| Option | Default | Accounting |
| --- | --- | --- |
| `max_depth` | 128 | Non-negative integer; root depth is zero, and keys/values and sequence items descend one level. |
| `max_nodes` | 100,000 | Positive integer; cumulative expanded logical nodes, including container nodes, keys, values and every alias occurrence. |

The parser bounds pending collection/key state before constructor callbacks
can run. The constructor tracks each anchor's subtree size and height while
constructing it. An alias charges that cached size and height before
attachment, without recursively traversing the referenced subtree to count
it. Keys are included. This prevents exponential validation/conversion work
from a compact alias graph. Budgets are local to the call.

The fused conversion pass checks the same expanded-node/depth ceilings;
validation and normalization do not perform additional unbounded walks.
Encoding checks its input before domain validation/emission and uses the
same caller limits for verification. The node ceiling bounds structural
work rather than bytes: it is not an input-byte, scalar-length, wall-clock,
or numeric-digit limit. A caller accepting untrusted large scalar payloads
should separately bound input size.

Limits return `:parse` or `:encode` / `:limit_exceeded`, with the limit name,
maximum and observed count, and available location/path. Invalid options
return `:unsupported` / `:invalid_option`. Multiple documents remain rejected
before map conversion; empty streams/documents are `nil`, and `{}` is `%{}`.

## Validation and provenance

Focused regressions cover the public facade and lower-level constructors,
mapper/emitter behavior, exact budget boundaries, repeated aliases, keys,
invalid options and call isolation. The original vendored suites remain
enabled. Two old core integer expectations were corrected from signed
octal/hex integers to strings according to YAML 1.2.2 section 10.3.2;
the separate YAML 1.1 expectations are retained.

The scoped official YAML Test Suite selection contains 21 leaf inputs from
the tagged **`data-2022-01-17`** release at
`6e6c296ae9c9d2d5c4134b4b64d01b29ac19ff6f`, including numbered subtests.
Files are unmodified, tests use the leaf `error` marker before `in.json`,
and intentional profile rejections have explicit error assertions rather
than skips. See the
[fixture provenance](https://github.com/gsmlg-dev/formata/blob/main/test/fixtures/yaml-test-suite/PROVENANCE.md).
This scoped selection does not claim complete YAML specification coverage.

Independent emission checks use test-only **ruamel.yaml 0.18.16**, explicitly
configured for YAML 1.2 with non-core merge/timestamp implicit resolvers
removed. Typed node pairs preserve boolean/integer key distinctions instead
of constructing host dictionaries that can collapse them. Values and scalar
types are compared, not formatting. CI and Release install the pinned tool;
ordinary test execution never downloads fixtures.

Local runtimes: Elixir **1.20.4** and **1.18.4** / Erlang OTP **28**
(ERTS **16.4.0.1**), Python **3.15.2**, ruamel.yaml **0.18.16**. There is no
repository Nix/devenv setup.

Final local validation on 2026-11-14:

- `mix deps.get` and `mix format --check-formatted` passed.
- `MIX_ENV=test mix compile --warnings-as-errors --force` passed on both
  supported Elixir versions.
- `FORMATA_YAML_REFERENCE_PYTHON=/tmp/formata-yaml-reference/bin/python3 mix test`
  passed **3,624 tests** (145 doctests, 3,479 tests) on both Elixir versions,
  including all vendored suites, JSON/TOML/schema coverage, pinned YAML
  fixtures and both independent encoder references. The 1.18.4 run used
  its installed `bin` directory on `PATH` and isolated
  `MIX_BUILD_PATH=/tmp/formata-yaml-elixir118`. Existing vendored test-only
  protocol-consolidation warnings remain; source compilation is warning-free.
- `mix docs --warnings-as-errors` and `mix hex.build` passed.
- `mix hex.build --unpack -o /tmp/formata-yaml-consumer.zSjW8N/package`,
  followed by `mix deps.get` and `mix run smoke.exs` in an isolated consumer,
  passed. The consumer fetched no runtime dependencies and exercised numeric
  resolution, null/literal keys, all four supplied string examples, malformed
  inputs, alias budget boundaries, JSON and TOML. The pre-release artifact
  carries 0.3.1 because release automation owns the version bump.
- `git diff --check` passed outside byte-exact official fixtures; fixture
  whitespace is intentionally retained unchanged.

Integrated testing exposed two additional exceptions previously hidden by
an old broad wrapper catch: raw C0 controls in flow scalars and unfinished
flow collections such as `a: [`. Both now produce structured syntax errors
at the parser boundary, with regression coverage for locations and valid
controls. No broad exception rescue was introduced. The independent oracle
also required resolver customization at document-resolver construction time;
its final typed-value comparison passes without relaxing expectations.

The release workflow owns the 0.3.2 bump/tag and repeats its gates before
publication. Remote CI and publication outcomes are reported separately from
these local checks.

## References

- [YAML 1.2.2 specification](https://yaml.org/spec/1.2.2/), scalar styles,
  mapping key equality, and core resolution in section 10.3.2.
- [Official YAML Test Suite](https://github.com/yaml/yaml-test-suite).
- [Release procedure](release.md).
