# Formata

Composable data codecs, schemas, and validation for Elixir.

Formata decodes and encodes **JSON**, **TOML**, and **YAML**, validates data
against **native schemas** (`Backplane.Schema`) or **JSON Schema** documents
(Draft 7 and Draft 2020-12, via `Backplane.JsonSchema`), and keeps every
lossy step explicit.

It is a plain functional library: no processes, no global state, no caches.

## Installation

```elixir
def deps do
  [
    {:formata, "~> 0.1.0"}
  ]
end
```

Requires Elixir 1.18 or later (the minimum of `backplane_schema` and
`backplane_json_schema`) and Erlang/OTP 25 or later (the minimum of Elixir
1.18). CI covers Elixir 1.18 and 1.20 on OTP 27/28.

All backends are regular dependencies: `jason`, `gsmlg_toml`, `yaml_elixir`
(with `yamerl`), `ymlr`, `backplane_schema`, `backplane_json_schema`.

## The workflow

Create a schema, decode a document, validate it, inspect errors, and encode or
convert the data:

```elixir
iex> {:ok, schema} =
...>   Formata.Schema.native(%{
...>     name: {:required, {:string, min: 1}},
...>     port: {:required, {:integer, range: {1, 65_535}}},
...>     tags: {:list, :string}
...>   })
iex> {:ok, config} = Formata.decode(~s({"name": "api", "port": 8080, "tags": ["web"]}), :json)
iex> Formata.validate(config, schema)
:ok
iex> Formata.encode(config, :toml)
{:ok, "name = \"api\"\nport = 8080\ntags = [\"web\"]\n"}
iex> {:error, [error]} = Formata.validate(%{config | "port" => 0}, schema)
iex> {error.kind, error.code, error.path}
{:validation, :range, ["port"]}
```

The same with a JSON Schema document:

```elixir
iex> {:ok, schema} =
...>   Formata.Schema.json_schema(%{
...>     "type" => "object",
...>     "required" => ["port"],
...>     "properties" => %{"port" => %{"type" => "integer", "minimum" => 1}},
...>     "additionalProperties" => false
...>   })
iex> schema.dialect
:draft2020_12
iex> {:ok, config} = Formata.decode("port: 8080\n", :yaml)
iex> Formata.validate(config, schema)
:ok
iex> {:error, [%Formata.Error{kind: :validation, path: ["extra"]}]} =
...>   Formata.validate(Map.put(config, "extra", true), schema)
```

Converting between formats, with an explicit transformation for a value the
target cannot represent:

```elixir
iex> Formata.convert(~s({"name": "api", "debug": null}), :json, :yaml)
{:ok, "---\ndebug:\nname: api\n"}
iex> {:error, [%Formata.Error{kind: :encode, code: :unrepresentable, path: ["debug"]}]} =
...>   Formata.convert(~s({"name": "api", "debug": null}), :json, :toml)
iex> Formata.convert(~s({"name": "api", "debug": null}), :json, :toml, transforms: [:drop_nils])
{:ok, "name = \"api\"\n"}
```

## Public API

| Function | Result |
| --- | --- |
| `Formata.decode(input, format, opts \\ [])` | `{:ok, data}` |
| `Formata.encode(data, format, opts \\ [])` | `{:ok, binary}` |
| `Formata.convert(input, from, to, opts \\ [])` | `{:ok, binary}` |
| `Formata.Schema.compile(kind, definition, opts \\ [])` | `{:ok, %Formata.Schema{}}` |
| `Formata.Schema.check(kind, definition, opts \\ [])` | `:ok` |
| `Formata.validate(data, schema, opts \\ [])` | `:ok` |
| `Formata.cast(data, schema, opts \\ [])` | `{:ok, data}` |
| `Formata.Transform.*` | `{:ok, data}` |

`format` is `:json`, `:toml`, `:yaml`, or a module implementing
`Formata.Codec`. `kind` is `:native` or `:json_schema`
(`Formata.Schema.native/2` and `Formata.Schema.json_schema/2` are shortcuts).

Every expected failure is `{:error, errors}` with a non-empty list of
`%Formata.Error{}`.

## Schemas

Formata keeps the two schema systems separate. A JSON Schema document is
always validated by `Backplane.JsonSchema` itself, never converted into a
native schema; native schemas are never exported to JSON Schema in order to
validate data. Formata does not offer schema export or general schema
conversion.

A compiled `%Formata.Schema{}` records its `kind`, `dialect` (JSON Schema
only), `backend`, and the backend's `compiled` representation. Compile once and
reuse it.

### Native schemas

Native definitions are `Backplane.Schema` data: maps of field names to types
such as `:string`, `{:integer, gte: 0}`, `{:required, t}`, `{:list, t}`,
`{:enum, values}`, `{:either, {a, b}}`, `{:custom, fun}`, and nested maps. Atom
schema keys match string data keys. Reusable and recursive definitions use
`Backplane.Schema.defschema/3` with `{:ref, {Module, name}}`; definitions are
data, so they can also be composed with `Formata.Schema.Native.merge/2`,
`select/2`, and `except/2`.

```elixir
iex> defmodule MyApp.Schemas do
...>   import Backplane.Schema
...>   defschema :node, %{name: {:required, :string}, children: {:list, {:ref, :node}}}
...> end
iex> {:ok, tree} = Formata.Schema.native({:ref, {MyApp.Schemas, :node}})
iex> Formata.validate(%{"name" => "root", "children" => [%{"name" => "leaf"}]}, tree)
:ok
iex> {:error, [%Formata.Error{code: :required, path: ["children", 0, "name"]}]} =
...>   Formata.validate(%{"name" => "root", "children" => [%{}]}, tree)
```

### JSON Schema

Documents are JSON-compatible maps or `true`/`false`. The dialect comes from a
recognized `$schema`, from `dialect: :draft7 | :draft2020_12`, or defaults to
Draft 2020-12; conflicts are errors. `format` is an annotation unless
`format_assertion: true`. Local references resolve without I/O; remote
references require an explicit `:loader` function. Formata never accesses the
network. See `Formata.Schema.JSONSchema`.

## Pure validation versus casting

`Formata.validate/3` checks data exactly as given and returns `:ok` or errors.
It never coerces, inserts defaults, or removes fields, and it never validates a
modified copy of the data.

```elixir
iex> {:ok, strict} = Formata.Schema.native(%{"n" => :integer})
iex> {:error, [%Formata.Error{code: :type}]} = Formata.validate(%{"n" => "42"}, strict)
iex> {:ok, coercing} = Formata.Schema.native(%{"n" => {:coerce, :integer}})
iex> Formata.cast(%{"n" => "42"}, coercing)
{:ok, %{"n" => 42}}
iex> {:error, [%Formata.Error{kind: :unsupported, code: :pure_validation_unsupported}]} =
...>   Formata.validate(%{"n" => "42"}, coercing)
```

For native schemas, pure validation supports a documented non-transforming
subset of `Backplane.Schema`. Defaults, coercions, transforms, encoders, and
run-time-computed schemas are rejected *before anything runs*, with the schema
path of the construct. Custom validators run in the native engine and must
return `:ok` or an error; one that returns a new value is reported as
`:non_pure_custom`.

`Formata.cast/3` runs the full native engine: defaults, coercion, constraint
checks, then transforms (see `Formata.Schema.Native` for the exact order).
JSON Schema annotations such as `default` are never applied; `cast/3` with a
JSON Schema returns `:unsupported`.

### Unknown fields (native schemas)

| | `validate/3` | `cast/3` |
| --- | --- | --- |
| `unknown: :allow` | default | kept |
| `unknown: :reject` | `:unknown_field` errors | `:unknown_field` errors |
| `unknown: :strip` | not accepted | default |

JSON Schema documents control their own additional properties; there is no
facade option to override `additionalProperties` or `unevaluatedProperties`.

## Codecs and value domains

Decoded data uses ordinary Elixir terms. Document keys stay strings and
Formata never creates atoms from document content. An absent field is absent
from the map; an explicit null is `nil`.

| Value | Elixir | JSON | TOML | YAML |
| --- | --- | --- | --- | --- |
| null | `nil` | yes | no (rejected) | yes |
| boolean, integer, string | as is | yes | yes (64-bit integers) | yes |
| finite float | float | yes | yes | yes |
| ±infinity, NaN | `:infinity`, `:negative_infinity`, `:nan` | no | yes | yes |
| list | list | yes | yes (arrays, arrays of tables) | yes |
| map | string keys | yes | yes (tables) | yes (also integer/boolean keys) |
| date / time / local date-time / offset date-time | `Date`, `Time`, `NaiveDateTime`, `DateTime` | no | yes | no (decode as strings) |
| scalar root | | yes | no (root must be a table) | yes |

Policies:

* **Duplicate keys** are rejected by all three decoders (`:duplicate_key`, or
  the TOML decoder's syntax error).
* **YAML** is single-document: multiple documents are rejected
  (`:multiple_documents`); an empty stream decodes to `nil`. Merge keys (`<<`)
  are rejected. Anchors/aliases are expanded. Comments, formatting, anchors,
  and key order are not preserved by any codec.
* **Encoding** rejects every value outside the target's domain with an
  `:encode` error and its path (`:unrepresentable`, `:invalid_key`,
  `:invalid_root`, `:out_of_range`). Nothing is dropped, stringified, replaced,
  or rounded implicitly. YAML output is decoded again and compared; a mismatch
  is `:roundtrip_mismatch`.
* **Explicit transformations** in `Formata.Transform`: `drop_nils/1`,
  `replace_nils/2`, `temporal_to_iso8601/1`, `special_floats_to_strings/1`,
  `stringify_keys/1`, and `apply_all/2` (used by `convert/4`'s `:transforms`).
* **Conversion** goes straight from decoded Elixir values to the target
  encoder; JSON is not used as an intermediate format. To validate native
  date/time values with JSON Schema, convert them explicitly first
  (`temporal_to_iso8601/1`); otherwise validation reports `:non_json_value`.

TOML is decoded by `gsmlg_toml`; `gsmlg_toml` has no encoder, so Formata
includes `Formata.Codec.TOML.Encoder` (TOML 1.0.0). It is checked against the
208 TOML 1.0.0 valid cases of the official `toml-test` suite: every encoded
document is parsed by Python's `tomllib` as an independent parser and by
`gsmlg_toml`.

## Errors

`%Formata.Error{}` fields: `kind` (`:parse`, `:encode`, `:schema`,
`:validation`, `:transform`, `:unsupported`), a stable `code`, `message`,
`backend`, `format`, `path` (data path), `schema_path`, `location` (only when
the backend reports line/column/offset), `details`, and the original `cause`.
`Exception.message/1` prefixes the path:

```elixir
iex> {:error, [error]} = Formata.decode(~s({"a": 1, "a": 2}), :json)
iex> Exception.message(error)
"duplicate object key \"a\""
iex> {:error, [error]} = Formata.encode(%{"a" => %{"b" => nil}}, :toml)
iex> Exception.message(error)
"at /a/b: null values cannot be represented"
```

## Known limitations

These are dependency issues tracked upstream. Tests covering them are tagged
`:upstream_blocked`, excluded from the default run, and must pass before a
release (`mix test --include upstream_blocked`).

* TOML offset date-times with a non-zero offset decode to the wrong instant
  (`gsmlg_toml` inverts the offset sign):
  [gsmlg-dev/gsmlg_umbrella#13](https://github.com/gsmlg-dev/gsmlg_umbrella/issues/13).
  Offsets are also normalized to UTC by the decoder.
* TOML arrays of tables lose empty elements and their subtables when decoded:
  [gsmlg-dev/gsmlg_umbrella#14](https://github.com/gsmlg-dev/gsmlg_umbrella/issues/14).
* TOML bare keys `true`/`false` are rejected by the decoder:
  [gsmlg-dev/gsmlg_umbrella#15](https://github.com/gsmlg-dev/gsmlg_umbrella/issues/15).
* TOML arrays with a local date-time followed by `,` fail to decode:
  [gsmlg-dev/gsmlg_umbrella#16](https://github.com/gsmlg-dev/gsmlg_umbrella/issues/16).

Other limitations, by design or by backend:

* `cast/3` with `unknown: :allow` is unsupported for atom-keyed native schemas
  over string-keyed data (the native engine's permissive mode duplicates such
  fields: [gsmlg-opt/backplane#171](https://github.com/gsmlg-opt/backplane/issues/171)).
  Use `:strip`, `:reject`, or string-keyed schemas.
* Native schemas treat an explicit `nil` like an absent field.
* Native `{:oneof, ...}` is "first matching branch"; JSON Schema `oneOf` is
  exclusive.
* Unknown-field rejection is not available for native keyword-list schemas.
* YAML timestamps decode as strings; YAML encoding rejects date/time values.
* Formata works around two more upstream issues
  ([gsmlg-opt/backplane#170](https://github.com/gsmlg-opt/backplane/issues/170):
  `format` asserted by default;
  [gsmlg-opt/backplane#172](https://github.com/gsmlg-opt/backplane/issues/172):
  error-message paths); the workarounds are marked `WORKAROUND(upstream)` in
  the source.

## Documentation

* [Design notes](docs/design.md): contracts, dependency audit, and decisions.
* [Release procedure](docs/release.md).
* [Changelog](CHANGELOG.md), [third-party notices](NOTICE.md).

## License

MIT. See [LICENSE](LICENSE).
