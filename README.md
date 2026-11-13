# Formata

Composable data codecs, schemas, and validation for Elixir.

Formata decodes and encodes **JSON** (with opt-in comments and trailing
commas, and an incremental parser for streamed output), **JSON5**, **TOML**,
and **YAML**, validates data
against **native schemas** (`Formata.Backplane.Schema`) or **JSON Schema** documents
(Draft 7 and Draft 2020-12, via `Formata.Backplane.JsonSchema`), and keeps every
lossy step explicit.

It is a plain functional library: no processes, no global state, no caches.

## Installation

```elixir
def deps do
  [
    {:formata, "~> 0.2.0"}
  ]
end
```

Requires Elixir 1.18 or later (the forked schema backends use Elixir 1.18's
built-in `JSON` module) and Erlang/OTP 28 or later. CI covers the minimum
(Elixir 1.18 on OTP 28) and Elixir 1.20 on OTP 28.

Formata has **no runtime dependencies**. Its backends are maintained forks,
renamed into the `Formata` namespace so they never clash with the original
packages in your project: `Formata.Jason` (from `jason`), `Formata.Toml`
(`gsmlg_toml`), `Formata.YamlElixir` and `formata_yamerl` (`yaml_elixir`,
`yamerl`), `Formata.Ymlr` (`ymlr`), `Formata.Backplane.Schema`
(`backplane_schema`), `Formata.Backplane.JsonSchema` (`backplane_json_schema`),
and `Formata.ExJSONPointer` (`ex_json_pointer`). Only `Formata.Backplane.Schema`
is public API (the native schema vocabulary); the other forks are internal.
Versions, licenses, and modifications are listed in [NOTICE.md](NOTICE.md).

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

`format` is `:json`, `:json5`, `:toml`, `:yaml`, or a module implementing
`Formata.Codec`. `kind` is `:native` or `:json_schema`
(`Formata.Schema.native/2` and `Formata.Schema.json_schema/2` are shortcuts).

Every expected failure is `{:error, errors}` with a non-empty list of
`%Formata.Error{}`.

## Schemas

Formata keeps the two schema systems separate. A JSON Schema document is
always validated by `Formata.Backplane.JsonSchema` itself, never converted into a
native schema; native schemas are never exported to JSON Schema in order to
validate data. Formata does not offer schema export or general schema
conversion.

A compiled `%Formata.Schema{}` records its `kind`, `dialect` (JSON Schema
only), `backend`, and the backend's `compiled` representation. Compile once and
reuse it.

### Native schemas

Native definitions are `Formata.Backplane.Schema` data: maps of field names to types
such as `:string`, `{:integer, gte: 0}`, `{:required, t}`, `{:list, t}`,
`{:enum, values}`, `{:either, {a, b}}`, `{:custom, fun}`, and nested maps. Atom
schema keys match string data keys. Reusable and recursive definitions use
`Formata.Backplane.Schema.defschema/3` with `{:ref, {Module, name}}`; definitions are
data, so they can also be composed with `Formata.Schema.Native.merge/2`,
`select/2`, and `except/2`.

```elixir
iex> defmodule MyApp.Schemas do
...>   import Formata.Backplane.Schema
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
subset of `Formata.Backplane.Schema`. Defaults, coercions, transforms, encoders, and
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

## JSON, JSONC-style options, JSON5, and streaming

`:json` is strict RFC 8259 by default. Two independent decode options accept
the common extensions of configuration files ("JSONC"); there is no separate
JSONC codec:

```elixir
iex> Formata.decode(~s({"a": [1, 2,],}), :json)
...> |> then(fn {:error, [error]} -> error.code end)
:syntax
iex> Formata.decode(~s({"a": [1, 2,],}), :json, trailing_commas: true)
{:ok, %{"a" => [1, 2]}}
iex> Formata.decode("// settings\n{\"url\": \"https://x.dev//a\" /* note */}", :json, comments: true)
{:ok, %{"url" => "https://x.dev//a"}}
```

`comments: true` accepts `//` and `/* */` comments where whitespace is
allowed; `trailing_commas: true` accepts one comma after the last element.
Neither implies the other, and empty slots (`[1,,2]`, `{,}`) are always
errors. Encoding to `:json` always produces strict JSON. Unknown or invalid
options are `:invalid_option` errors. For a `.jsonc` file, pass
`comments: true, trailing_commas: true` (or only what the file format allows).

`:json5` is a separate codec for [JSON5 1.0.0](https://spec.json5.org/):

```elixir
iex> Formata.decode("{name: 'Ada', id: 0x2A, ratio: .5, max: Infinity,}", :json5)
{:ok, %{"name" => "Ada", "id" => 42, "ratio" => 0.5, "max" => :infinity}}
iex> Formata.encode(%{"max" => :infinity}, :json5)
{:ok, ~s({"max":Infinity})}
iex> {:error, [%Formata.Error{kind: :encode, code: :unrepresentable, path: ["max"]}]} =
...>   Formata.convert("{max: Infinity}", :json5, :json)
```

`Formata.Codec.JSON.Stream` parses **one** JSON document that arrives in
chunks cut at arbitrary bytes, for example an LLM's streamed tool arguments.
It emits structure, key, and complete scalar events as soon as they are
known, and it never re-parses earlier input:

```elixir
iex> alias Formata.Codec.JSON.Stream, as: JSONStream
iex> {:ok, parser} = JSONStream.new()
iex> {:ok, events, parser} = JSONStream.feed(parser, ~s({"city": "Par))
iex> events
[{:start_object, []}, {:key, ["city"], "city"}]
iex> {:ok, events, parser} = JSONStream.feed(parser, ~s(is", "days": 3))
iex> events
[{:value, ["city"], "Paris"}, {:key, ["days"], "days"}]
iex> {:error, [%Formata.Error{code: :incomplete}]} = JSONStream.finish(parser)
iex> {:ok, events, parser} = JSONStream.feed(parser, "}")
iex> events
[{:value, ["days"], 3}, {:end_object, []}]
iex> JSONStream.finish(parser)
{:ok, []}
```

Events are provisional: only a successful `finish/1` means the document is
complete and valid. Do not run side effects (such as a tool call) from
partial events; wait for `finish/1`, then validate the data. `decode_stream/2`
wraps the parser as a lazy stream of `{:ok, event}` items that ends with
`{:error, errors}` on failure. See `Formata.Codec.JSON.Stream` for options
(`string_deltas`, resource limits) and the memory model.

JSON Lines (NDJSON) are a sequence of independent documents, not one document
in chunks. Formata has no JSON Lines codec; decode each line:

```elixir
File.stream!("events.jsonl")
|> Stream.map(&String.trim_trailing(&1, "\n"))
|> Stream.map(&String.trim_trailing(&1, "\r"))
|> Stream.reject(&(&1 == ""))
|> Stream.map(&Formata.decode(&1, :json))
```

Whether blank lines are allowed and how line numbers are reported is up to
the caller (`Stream.with_index/2`).

## Codecs and value domains

Decoded data uses ordinary Elixir terms. Document keys stay strings and
Formata never creates atoms from document content. An absent field is absent
from the map; an explicit null is `nil`.

| Value | Elixir | JSON | JSON5 | TOML | YAML |
| --- | --- | --- | --- | --- | --- |
| null | `nil` | yes | yes | no (rejected) | yes |
| boolean, integer, string | as is | yes | yes | yes (64-bit integers) | yes |
| finite float | float | yes | yes | yes | yes |
| ±infinity, NaN | `:infinity`, `:negative_infinity`, `:nan` | no | yes | yes | yes |
| list | list | yes | yes | yes (arrays, arrays of tables) | yes |
| map | string keys | yes | yes | yes (tables) | yes (also integer/boolean keys) |
| date / time / local date-time / offset date-time | `Date`, `Time`, `NaiveDateTime`, `DateTime` | no | no | yes | no (decode as strings) |
| scalar root | | yes | yes | no (root must be a table) | yes |

Policies:

* **Duplicate keys** are rejected by every decoder, compared after unescaping
  (`:duplicate_key`, or the TOML decoder's syntax error).
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

TOML is decoded by `Formata.Toml` and encoded by `Formata.Codec.TOML.Encoder`
(TOML 1.0.0). Both are checked against the TOML 1.0.0 cases of the official
`toml-test` suite: the decoder accepts all 208 valid documents with the
expected values and rejects all 509 invalid ones, and every value from the
valid cases is encoded and parsed again by `Formata.Toml` and by Python's
`tomllib` as an independent parser.

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

* TOML offset date-times are normalized to UTC `DateTime` values; the
  original offset is not kept.
* Native schemas treat an explicit `nil` like an absent field.
* Native `{:oneof, ...}` is "first matching branch"; JSON Schema `oneOf` is
  exclusive.
* Unknown-field rejection is not available for native keyword-list schemas.
* YAML timestamps decode as strings; YAML encoding rejects date/time values.
* JSON5: the sign of `NaN` is not kept, and the integer `-0` decodes as `0`
  (`-0.0` stays a negative-zero float). Unpaired `\u` surrogate escapes are
  rejected because Elixir strings are UTF-8. Identifier characters are
  classified with the Unicode tables of the runtime's PCRE library.
* `Formata.Codec.JSON.Stream` handles one JSON document (no JSON5, no JSON
  Lines). Its error columns count Unicode code points, while `Formata.decode/3`
  counts graphemes; byte offsets are the same. On complete input it is
  about 2–4× slower than `Formata.decode/3`; use it for input that arrives
  incrementally (measurements in `docs/design.md`).
* With `format_assertion: true`, `hostname`, `email`, `idn-hostname`, and
  `idn-email` values that contain an A-label (`xn--...`) or a non-ASCII label
  cannot be checked without the IDNA2008 tables. Validation returns a single
  `:unsupported` / `:unsupported_format` error for them (never a pass or a
  `:format` failure, and not invertible by `not`/`anyOf`/`oneOf`/`if`). Plain
  ASCII names are fully checked.
* Format assertion has known gaps outside the required JSON Schema test suite:
  some edge cases of `email` (quoted local parts, `ipv6:` literals) and
  `uri-template` (malformed `%` escapes, spaces, DEL) are judged incorrectly.

## Documentation

* [Design notes](docs/design.md): contracts, forked backends, and decisions.
* [Release procedure](docs/release.md).
* [Changelog](CHANGELOG.md), [third-party notices](NOTICE.md).

## License

Formata's own code is MIT (see [LICENSE](LICENSE)). The forked backends keep
their original licenses (MIT, Apache-2.0, BSD-2-Clause); see
[NOTICE.md](NOTICE.md) and [LICENSES/](https://github.com/gsmlg-dev/formata/tree/main/LICENSES).
