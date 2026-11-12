# Formata design notes

## Scope

One Mix library and one Hex package (`formata`, namespace `Formata`) with no
runtime dependencies. It composes backends that are maintained forks of
existing packages (see "Forked backends"); it adds no processes, caches,
umbrella, schema AST, schema inference, or schema conversion.

| Module | Responsibility |
| --- | --- |
| `Formata` | Public entry points: `decode/3`, `encode/3`, `convert/4`, `validate/3`, `cast/3` |
| `Formata.Codec` | Codec behaviour, format lookup, shared value-domain checks |
| `Formata.Codec.JSON` / `.TOML` / `.YAML` | Format adapters |
| `Formata.Codec.TOML.Encoder` | Focused TOML 1.0.0 encoder |
| `Formata.Schema` | `compile/3`, `check/3`, compiled-schema struct |
| `Formata.Schema.Native` | `Formata.Backplane.Schema` adapter, pure-validation preflight, casting |
| `Formata.Schema.JSONSchema` | `Formata.Backplane.JsonSchema` adapter |
| `Formata.Transform` | Explicit data transformations |
| `Formata.Error` | Structured errors |

## Contracts

* Argument order is data first: `decode(input, format, opts)`,
  `encode(data, format, opts)`, `convert(input, from, to, opts)`,
  `validate(data, schema, opts)`, `cast(data, schema, opts)`,
  `Schema.compile(kind, definition, opts)`.
* Producing operations return `{:ok, result}`; `validate/3` and
  `Schema.check/3` return `:ok`.
* Expected failures return `{:error, [%Formata.Error{}, ...]}` (non-empty).
  Error kinds: `:parse`, `:encode`, `:schema`, `:validation`, `:transform`,
  `:unsupported`. Programming errors (wrong argument types, unknown compile
  options) raise.
* `location` is set only from backend data (`Formata.Jason` byte offsets, `Formata.Toml`
  line/column in messages, yamerl line/column).
* `validate/3` requires a compiled schema; compiling is never repeated per call.

## Forked backends

The backends were published packages; they are now forked into this
repository, renamed into the `Formata` namespace (so a consumer can still use
the originals side by side), and maintained here. Upstream test suites are
ported under `test/formata/vendor/`. Provenance, licenses, and the common
fork-time modifications are in `NOTICE.md`.

| Upstream | Version | Fork | Use |
| --- | --- | --- | --- |
| `jason` | 1.4.5 | `Formata.Jason` | JSON decode (`objects: :ordered_objects` for duplicate detection) and encode |
| `gsmlg_toml` | 1.0.0 | `Formata.Toml` | TOML decode |
| `yaml_elixir` | 2.12.2 | `Formata.YamlElixir` | YAML decode (`read_all_from_string/2`) |
| `yamerl` | 0.10.0 | `formata_yamerl*` (Erlang) | Detailed node tree for duplicate keys, merge keys, null roots |
| `ymlr` | 5.1.6 | `Formata.Ymlr` | YAML encode |
| `backplane_schema` | 1.10.76 | `Formata.Backplane.Schema` | Native schemas (public vocabulary) |
| `backplane_json_schema` | 1.10.76 | `Formata.Backplane.JsonSchema` | JSON Schema compile/validate |
| `ex_json_pointer` | 0.9.0 | `Formata.ExJSONPointer` | JSON Pointer for the JSON Schema backend |

Fork rules: no compile-time optional integrations (their presence would depend
on the consumer's dependency tree), no application environment, no processes.
The minimum Elixir is 1.18 (built-in `JSON`, used by the JSON Schema fork);
CI tests Elixir 1.18 and 1.20.

## Audit findings and decisions

### `Formata.Backplane.Schema.validate/3` transforms

It applies defaults, coercions and transforms, and in strict mode drops
undeclared fields and re-keys output by schema keys; permissive mode leaves
the input keys and writes updated values under the data's own key (fork fix
for gsmlg-opt/backplane#171, which duplicated them under atom keys). There is
no pure mode and no reject-unknown mode.

Decision: pure validation uses a *plan*, a rewritten definition that only
adds checks:

* A preflight walks the definition and every reachable `{:ref, {Mod, name}}`
  target and rejects `default`, `transform`, `encode`, `coerce`, and
  `{:dependent, callback}` with `:unsupported` errors and schema paths.
* `{:custom, v}` validators are wrapped so a result other than `:ok`/error is
  a `:non_pure_custom` error. Without this, the native engine accepts
  `{:enum, choices, type: {:custom, fn -> {:ok, changed} end}}` by checking the
  changed value.
* References become lazily expanded `{:dependent, fun}` nodes so the wrapping
  also applies inside referenced (including recursive) definitions.
* `unknown: :reject` wraps each map schema as
  `{:schema, map, {:additional_keys, {:custom, reject}}}`, keeping the check in
  the native engine; Formata expands the resulting error to one
  `:unknown_field` error per undeclared key.
* The plan runs in permissive mode; its output is discarded.

`cast/3` runs the original definition (strict mode for `:strip`, the reject
plan in strict mode for `:reject`, permissive mode for `:allow`, keeping the
input keys; a field added by a default uses the schema key). Coercion to `:atom!`
is refused because it calls `String.to_atom/1` on input.

### JSON Schema

Documents go straight to `Formata.Backplane.JsonSchema.compile/2`; the native
`from_json_schema` importer (which turns `oneOf` into a first-match union) is
not used, nor is native export (which omits unsupported constraints). No
schema export is offered: the fork's native `to_json_schema/2`
and `from_json_schema/2` functions are `@doc false` (kept only for the ported upstream
tests) and are not part of the public API.

* Dialects: Draft 7 and 2020-12 via `$schema` or `dialect:`; conflicts are
  backend `:draft_conflict` errors (`:dialect_conflict`). An unrecognized
  `$schema` without `dialect:` or `:loader` is rejected, because its
  vocabularies cannot be known.
* `format`: annotation by default, including without `$schema` (fork fix for
  gsmlg-opt/backplane#170: the default vocabularies are the standard 2020-12
  set, without format-assertion). Values that need the IDNA2008 tables
  (A-labels, non-ASCII labels in `hostname`/`email`/`idn-*`) stop validation
  with `:indeterminate_format`, reported as `:unsupported` /
  `:unsupported_format`; it cannot be inverted by `not`/`anyOf`/`oneOf`/`if`.
* `multipleOf` uses exact decimal arithmetic on integers (no `Decimal`, no
  float quotient); it never raises on data.
* References: local only unless a `:loader` is passed. Unresolvable refs are
  backend validation errors that Formata reports as `:schema` /
  `:unresolved_ref`.
* `validate/3` accepts no options, so nothing can override
  `additionalProperties` / `unevaluatedProperties`.
* Data must be in the JSON data model; other terms are `:non_json_value`.
* Error messages: `format_error/1` is called without the path because
  `Formata.Error` renders it (the backend's path rendering, #172, is fixed in
  the fork).
* Opaque base URIs (`urn:...`) resolve relative references per RFC 3986 on
  every supported Elixir version (Elixir < 1.20's `URI.merge/2` requires a
  host).

### Codecs

* JSON: `Formata.Jason` silently keeps the last duplicate key; Formata decodes ordered
  objects and rejects duplicates.
* TOML: `gsmlg_toml` had no encoder, so Formata ships its own. The forked
  decoder had four bugs found by toml-test (gsmlg-dev/gsmlg_umbrella#13 offset
  sign, #14 empty array-of-tables elements, #15 `true`/`false` keys, #16 local
  date-time in arrays) plus many more exposed by the invalid suite (lexer
  escapes, table redefinition rules, inline tables, crashes on invalid UTF-8);
  all are fixed. The decoder passes the full toml-test 1.0.0 suite (208 valid,
  509 invalid); encoder output is also checked with Python's `tomllib`.
* YAML: `Formata.YamlElixir.read_from_string/2` silently returns the last document,
  keeps the first duplicate key, renames `<<` keys, and maps a null root to
  `%{}`. Formata uses `read_all_from_string/2` and inspects yamerl's detailed
  node tree. `Formata.Ymlr` leaves some strings unquoted that read back as numbers
  (for example `".5"`), so YAML output is decoded and compared before it is
  returned.
* Special floats use the atoms produced by `Formata.Toml`
  (`:infinity`, `:negative_infinity`, `:nan`); YAML's `:"+inf"`/`:"-inf"` are
  normalized to them and converted back for `Formata.Ymlr`.
