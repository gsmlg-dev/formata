# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.3.4] - 2026-11-18

### Added

- Application JSON APIs for internal request #1: `Formata.JSON.decode/2`
  returns structured errors and accepts exact float-token callbacks (such as
  `floats: &Decimal.new/1`) and `objects: :ordered_objects`. Both decode
  variants preserve strict duplicate-key rejection; the portable codecs
  retain their existing value domain and options.
- Public `Formata.JSON.OrderedObject` with `Access`, `Enumerable`, and
  `JSON.Encoder` support for order-preserving configuration edits. Encoding
  rejects duplicate encoded keys.
- `pretty: true` on `Formata.JSON.encode!/2` and `encode_to_iodata!/2`,
  including atom keys/values, standard temporal values, derived structs,
  and nested ordered objects.

### Changed

- Remove the imported backend namespaces without compatibility aliases.
  Native schema definitions now use `Formata.NativeSchema` (including its
  `Error` and `Walker` modules); `Formata.Schema.Native` remains the adapter
  for compilation, pure validation, and casting. Recompile existing schemas
  to replace backend module references in compiled structs.
- Rename internal backends to `Formata.JSON.Backend`, `Formata.TOML`,
  `Formata.YAML.Reader`, `Formata.YAML.Writer`, `Formata.JSONSchema`, and
  `Formata.JSONPointer`. Erlang YAML modules, records, and headers use
  `formata_yaml` names. Error metadata reflects the new backend modules;
  serialized YAML tag URIs and upstream license attribution are preserved.
- Align test files, helper modules, and fixture directories with the current
  backend namespaces. Ported suites now live alongside the corresponding
  module tests, without a separate vendor test namespace.

## [0.3.3] - 2026-11-14

### Fixed

- Replace three deprecated Erlang catch expressions in the YAML binary
  constructor and constructor-module probe. Invalid Base64 still returns
  `not_a_binary` with its token and location, including missing padding;
  module probing still attempts loading before checking exports.

### Added

- Clean Erlang compilation gates in CI and Release with warnings treated
  as errors and `warn_deprecated_catch` explicitly enabled on OTP 28.
- Regression coverage for Base64 constructor modes and constructor-module
  probing, including available but unloaded modules.

## [0.3.2] - 2026-11-14

### Fixed

- YAML 1.2 implicit incomplete integers (`+`, `0x`, `0o`) remain strings;
  invalid explicitly tagged integers return syntax errors. Explicit YAML
  1.1 documents retain their separate resolution rules.
- YAML decoding validates mapping keys and values before map construction.
  Null scalar keys work, duplicate normalized keys are rejected, and complex
  sequence/mapping keys return an explicit unsupported-key error instead of
  losing entries or exposing parser records. Encoder key types are unchanged.
- Quoted `"<<"` and explicitly tagged `!!str <<` remain literal string keys;
  only the plain implicit merge convention remains unsupported.
- YAML encoding preserves root `nil`, numeric-looking strings such as `.5`,
  leading-space multiline strings, CRLF, controls and U+FEFF. Unsafe block
  values use complete YAML double-quoted escaping. The round-trip guard stays
  enabled, and the previously skipped leading-space emitter test is enabled.
- Anchors before flow collections attach to the collection rather than a
  child or subsequent mapping key.
- Malformed escapes, raw control characters in flow scalars, and unfinished
  flow collections return structured syntax errors with source locations.

### Added

- Per-call YAML `max_depth` (default 128) and `max_nodes` (default 100,000)
  limits, including mapping keys and repeated alias expansions. Decoding
  uses one detailed parse and bounded validation/conversion. Encoding checks
  its input and round-trip verification with the same limits.
- Scoped fixtures from the tagged official YAML Test Suite and independent
  YAML 1.2 typed-node emission checks using test-only `ruamel.yaml==0.18.16`.
  See [the YAML review](docs/yaml-correctness-review.md) for compatibility
  decisions, resource accounting and validation evidence.

## [0.3.1] - 2026-11-13

### Fixed

- TOML assignments reject comments before a value, including inside inline
  tables, while retaining comments in arrays and valid multiline values.
  Missing values at CRLF boundaries now return syntax errors with locations
  instead of an internal error-formatting failure.
- TOML numeric underscores require digits on both sides, including after
  exponent signs; incomplete fractions and exponents return syntax errors.
- TOML date-time separators accept only `T`, `t`, or one ASCII space;
  standalone dates still allow trailing whitespace.
- Encoding rejects invalid UTF-8 map keys with structured `:invalid_key`
  errors before rendering, including nested and inline TOML tables. The
  shared check also protects JSON, JSON5, and YAML encoders.

### Added

- Deterministic TOML grammar-boundary regressions and independent `tomllib`
  decoder comparisons, retaining all 208 valid and 509 invalid pinned
  conformance inputs. See [the correctness review](docs/toml-correctness-review.md).

## [0.3.0] - 2026-11-13

### Added

- `Formata.JSON`, a Phoenix/Plug JSON library module
  (`config :phoenix, :json_library, Formata.JSON`) with `decode!/1,2`,
  `encode!/1`, and `encode_to_iodata!/1`. Decoding is Formata's strict JSON
  decoder (duplicate keys rejected, raising `Formata.Error`); encoding
  delegates to Elixir's `JSON` (`JSON.Encoder` for structs).

## [0.2.1] - 2026-11-13

### Changed

- `Formata.Codec.JSON.Stream` is faster, with the same API, events, and
  errors. Measured on Elixir 1.20 / OTP 28 (method and full results in
  `docs/design.md`): 2.0–3.7× on compact documents fed in 1-byte, 1–256-byte,
  4 KiB, or 64 KiB chunks and on long strings; 1.65–2.0× on 1–16-byte token
  deltas; 1.4–1.8× on pretty-printed documents; 1.7× for a whole document in
  a single chunk; 1.7–6× less allocation. Position tracking no longer
  re-scans every chunk with a per-byte loop; the scanner reuses binary match
  contexts, keeps per-token state in a small record, caches container paths,
  and scans unescaped ASCII eight bytes at a time.
- `bench/json_stream.exs` covers token deltas, network chunks, long and
  escaped strings, deep nesting, pretty-printed documents, `string_deltas`,
  `decode_stream/2`, and OTP's `:json` incremental decoder for comparison.
- Supported versions are documented as Elixir 1.18+ on Erlang/OTP 28+
  (previously OTP 25+), and CI now tests the minimum combination, Elixir 1.18
  on OTP 28, instead of OTP 27.

### Fixed

- `Formata.Codec.JSON.Stream` copied the rest of the chunk for every number
  it finished, making large chunks with many numbers quadratic.

## [0.2.0] - 2026-11-13

### Added

- `:json` decode options `comments: true` (`//` and `/* */` comments where
  whitespace is allowed) and `trailing_commas: true` (one comma after the
  last element of an array or object). They are independent and default to
  `false`; `:json` stays strict RFC 8259 and encoding always produces strict
  JSON. There is no separate JSONC codec.
- `Formata.Codec.JSON.Stream`: an incremental, purely functional parser for a
  single JSON document received in arbitrary byte chunks (for example LLM
  output), with `new/1`, `feed/2`, `finish/1`, and the lazy
  `decode_stream/2`. It emits structure, key, and complete scalar events (and
  optional string deltas), checks completeness at `finish/1`, rejects
  duplicate keys, reports positions across chunks, and enforces depth,
  document, and token size limits.
- `:json5` codec (`Formata.Codec.JSON5`) for JSON5 1.0.0, with special
  numbers mapped to `:infinity`, `:negative_infinity`, and `:nan`.
- `bench/json_stream.exs` measures the stream parser by chunk size.

### Changed

- `Formata.decode(input, :json, opts)` now rejects unknown options and
  invalid option values with `:unsupported` / `:invalid_option` errors;
  previously all options were ignored.
- `Formata.Jason` decoder (fork): opt-in `comments` and `trailing_commas`
  options.

## [0.1.0]

### Added

- JSON, TOML (TOML 1.0.0), and single-document YAML codecs with a documented
  portable value domain, duplicate-key rejection, and strict encoding that
  rejects unrepresentable values.
- `Formata.convert/4` with explicit transformations (`Formata.Transform`).
- Native schemas (`Formata.Backplane.Schema`) with pure validation
  (`validate/3`) over a checked non-transforming subset, unknown-field
  allow/reject, and full casting (`cast/3`) with defaults, coercion,
  transforms, and stripping.
- JSON Schema Draft 7 and Draft 2020-12 with dialect selection, local
  references, explicit remote loaders, and configurable format assertion.
- Structured `Formata.Error` values for parse, encode, schema, validation,
  transform, and unsupported-operation failures.
- No runtime dependencies: the backends are maintained forks of `jason`
  1.4.5, `gsmlg_toml` 1.0.0, `yaml_elixir` 2.12.2, `yamerl` 0.10.0, `ymlr`
  5.1.6, `backplane_schema` 1.10.76, `backplane_json_schema` 1.10.76, and
  `ex_json_pointer` 0.9.0, renamed into the `Formata` namespace (see
  `NOTICE.md`), with their upstream test suites ported.
- Conformance suites in the test run: toml-test 1.0.0 (208 valid, 509
  invalid) and the required JSON-Schema-Test-Suite cases for Draft 7 and
  Draft 2020-12.

### Changed in the forked backends (relative to the upstream releases)

- TOML decoder: offset date-times decode to the correct instant
  (gsmlg-dev/gsmlg_umbrella#13); empty array-of-tables elements and their
  subtables are kept (#14); `true`/`false` are valid bare keys (#15); local
  date-times may be followed by `,` (#16). It now passes the full toml-test
  1.0.0 suite, including TOML 1.0 table-redefinition and inline-table rules,
  string escapes and line-ending backslashes, and lowercase `t`/`z` in
  date-times. Invalid UTF-8 and malformed `\U` escapes return parse errors
  instead of crashing the caller; `-nan` decodes to `:nan`.
- JSON Schema: `format` is an annotation by default when `$schema` is absent
  (gsmlg-opt/backplane#170); error paths render integer segments and escape
  `~`/`/` (#172); `multipleOf` is exact and never raises; IDN-dependent
  `hostname`/`email` checks report `:unsupported_format` instead of raising;
  opaque base URIs (`urn:`) resolve references on Elixir 1.18.
- Native schemas: permissive mode no longer duplicates fields under atom keys
  (gsmlg-opt/backplane#171), so `cast(..., unknown: :allow)` works for
  atom-keyed schemas over string-keyed data.
- Optional `Decimal`/`:idna` integrations, application environment, and
  yamerl's application/supervisor are removed.
