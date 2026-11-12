# Formata design notes

## Scope

One Mix library and one Hex package (`formata`, namespace `Formata`). It
composes existing backends; it adds no processes, caches, umbrella, schema
AST, schema inference, or schema conversion.

| Module | Responsibility |
| --- | --- |
| `Formata` | Public entry points: `decode/3`, `encode/3`, `convert/4`, `validate/3`, `cast/3` |
| `Formata.Codec` | Codec behaviour, format lookup, shared value-domain checks |
| `Formata.Codec.JSON` / `.TOML` / `.YAML` | Format adapters |
| `Formata.Codec.TOML.Encoder` | Focused TOML 1.0.0 encoder |
| `Formata.Schema` | `compile/3`, `check/3`, compiled-schema struct |
| `Formata.Schema.Native` | `Backplane.Schema` adapter, pure-validation preflight, casting |
| `Formata.Schema.JSONSchema` | `Backplane.JsonSchema` adapter |
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
* `location` is set only from backend data (Jason byte offsets, gsmlg_toml
  line/column in messages, yamerl line/column).
* `validate/3` requires a compiled schema; compiling is never repeated per call.

## Dependencies (verified versions)

| Package | Version audited | Use |
| --- | --- | --- |
| `jason` | 1.4.5 | JSON decode (`objects: :ordered_objects` for duplicate detection) and encode |
| `gsmlg_toml` | 1.0.0 | TOML decode (no encoder exists) |
| `yaml_elixir` | 2.12.2 | YAML decode (`read_all_from_string/2`) |
| `yamerl` | 0.10.0 | Detailed node tree for duplicate keys, merge keys, null roots |
| `ymlr` | 5.1.6 | YAML encode |
| `backplane_schema` | 1.10.76 | Native schemas |
| `backplane_json_schema` | 1.10.76 | JSON Schema compile/validate |

`backplane_*` require Elixir ~> 1.18, which sets Formata's minimum (OTP 25+ as
required by Elixir 1.18). Tested on Elixir 1.18.4 and 1.20.4 with OTP 28.

## Audit findings and decisions

### `Backplane.Schema.validate/3` transforms

It applies defaults, coercions and transforms, and in strict mode drops
undeclared fields and re-keys output by schema keys; permissive mode leaves
the input keys but (bug) duplicates transformed fields under atom keys
(gsmlg-opt/backplane#171). There is no pure mode and no reject-unknown mode.

Decision: pure validation uses a *plan*, a rewritten definition that only
adds checks:

* A preflight walks the definition and every reachable `{:ref, {Mod, name}}`
  target and rejects `default`, `transform`, `encode`, `coerce`, and
  `{:dependent, callback}` with `:unsupported` errors and schema paths.
* `{:custom, v}` validators are wrapped so a result other than `:ok`/error is
  a `:non_pure_custom` error. Without this, `Backplane.Schema` accepts
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
plan in strict mode for `:reject`, permissive mode for `:allow`, refused for
atom-keyed schemas over string data until #171 is fixed). Coercion to `:atom!`
is refused because it calls `String.to_atom/1` on input.

### JSON Schema

Documents go straight to `Backplane.JsonSchema.compile/2`; the native
`from_json_schema` importer (which turns `oneOf` into a first-match union) is
not used, nor is native export (which omits unsupported constraints). No
schema export is offered.

* Dialects: Draft 7 and 2020-12 via `$schema` or `dialect:`; conflicts are
  backend `:draft_conflict` errors (`:dialect_conflict`). An unrecognized
  `$schema` without `dialect:` or `:loader` is rejected, because its
  vocabularies cannot be known.
* `format`: annotation by default. The backend enables the 2020-12
  format-assertion vocabulary when `$schema` is absent
  (gsmlg-opt/backplane#170); Formata declares the standard 2020-12 meta-schema
  in that case, which is the spec default.
* References: local only unless a `:loader` is passed. Unresolvable refs are
  backend validation errors that Formata reports as `:schema` /
  `:unresolved_ref`.
* `validate/3` accepts no options, so nothing can override
  `additionalProperties` / `unevaluatedProperties`.
* Data must be in the JSON data model; other terms are `:non_json_value`.
* Error messages: `format_error/1` mis-renders integer path segments
  (gsmlg-opt/backplane#172); Formata formats messages without the path.

### Codecs

* JSON: Jason silently keeps the last duplicate key; Formata decodes ordered
  objects and rejects duplicates.
* TOML: `gsmlg_toml` has no encoder (gsmlg-dev/gsmlg_umbrella#12), so Formata
  ships one. The toml-test 1.0.0 valid suite (208 cases) found no encoder bug
  and four decoder bugs (#13 offset sign, #14 empty array-of-tables elements,
  #15 `true`/`false` keys, #16 local date-time in arrays). #13 and #14 lose data
  silently, have no safe local workaround, and block a release.
* YAML: `YamlElixir.read_from_string/2` silently returns the last document,
  keeps the first duplicate key, renames `<<` keys, and maps a null root to
  `%{}`. Formata uses `read_all_from_string/2` and inspects yamerl's detailed
  node tree. `Ymlr` leaves some strings unquoted that read back as numbers
  (for example `".5"`), so YAML output is decoded and compared before it is
  returned.
* Special floats use the atoms produced by `gsmlg_toml`
  (`:infinity`, `:negative_infinity`, `:nan`); YAML's `:"+inf"`/`:"-inf"` are
  normalized to them and converted back for `Ymlr`.
