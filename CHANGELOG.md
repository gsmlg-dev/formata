# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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
