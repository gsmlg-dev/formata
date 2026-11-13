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
| `Formata.Codec.JSON` / `.JSON5` / `.TOML` / `.YAML` | Format adapters |
| `Formata.Codec.JSON.Stream` | Incremental single-document JSON parser (events) |
| `Formata.Codec.JSON5` parser (internal `JSON5.Parser`) | JSON5 1.0.0 parser |
| `Formata.Codec.TOML.Encoder` | Focused TOML 1.0.0 encoder |
| `Formata.Schema` | `compile/3`, `check/3`, compiled-schema struct |
| `Formata.Schema.Native` | `Formata.Backplane.Schema` adapter, pure-validation preflight, casting |
| `Formata.Schema.JSONSchema` | `Formata.Backplane.JsonSchema` adapter |
| `Formata.JSON` | Phoenix/Plug JSON library module (strict decode, `JSON` encode) |
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
* JSON decode options (`comments`, `trailing_commas`): see "JSON extensions"
  below.
* Special floats use the atoms produced by `Formata.Toml`
  (`:infinity`, `:negative_infinity`, `:nan`); YAML's `:"+inf"`/`:"-inf"` are
  normalized to them and converted back for `Formata.Ymlr`.

### JSON extensions (comments, trailing commas)

* The extensions live in the `Formata.Jason` decoder, not in a pre-pass. A
  `/` clause was added to every bytecase position that accepts whitespace
  (`value`, `array`, `object`, `key`, `terminate`); it consumes a `//` or
  `/* */` comment when `comments` is set and is an error otherwise. Comments
  therefore cannot appear inside strings, numbers, or literals, and byte
  offsets in errors stay those of the original input. Comment text must be
  valid UTF-8; block comments do not nest.
* Trailing commas reuse the decoder's stacks: after a comma the array/object
  accumulator is non-empty, so `]`/`}` in value/key position closes the
  container only when the accumulator is non-empty and `trailing_commas` is
  set. Empty slots never reach that state and stay errors.
* With both options `false` (the default) the decoder takes exactly the
  previous paths; the new clauses only replace the generic error clause for
  `/`.
* The `:json` codec's `decode/2` used to ignore its options. It now validates
  them (`:unsupported` / `:invalid_option`), so callers that passed unknown
  options (also through `convert/4`'s `:decode`) get an error.
* There is no `:jsonc` codec: JSONC is a parsing mode of `:json`, and
  encoding is always strict JSON.

### Incremental JSON parser

`Formata.Codec.JSON.Stream` is a separate state machine
(the internal `Stream.Machine` module). The one-shot `Formata.Jason` decoder
was not reused: it is a recursive parse over one binary with no resumable
state, and making it resumable would slow the common path. Agreement is
enforced by differential tests instead (every two-way split, byte-by-byte
and random chunkings, strict and extended inputs).

* State: an immutable struct holding the options, the absolute
  offset/line/column of the next byte, the carried bytes, and a small record
  with the container stack (`{:array, index, path}`,
  `{:object, seen_keys, key_path, path}`), the grammar mode (expect
  value/key/colon/after-value/done), the depth, and the token in progress
  (string, number, or comment, with its pieces).
* Each `feed/2` scans `carry <> chunk` once. Indivisible units that are cut
  by the chunk end are not consumed but carried: a partial UTF-8 character
  (≤ 3 bytes), a `\uXXXX` escape or surrogate pair (≤ 11 bytes), a literal
  prefix (≤ 4 bytes), `/`, or the `*` of `*/`. Strings and numbers keep their
  pieces in the token; at the end of the feed, pieces that reference the
  chunk are copied (`:binary.copy/1`) so the state never keeps a chunk alive.
  On OTP 28+, slices of up to 64 bytes (including the carry) are already
  standalone binaries and are not copied again.
* Valid prefixes wait, invalid prefixes fail immediately: `tru`, `1e+`,
  `"\u00`, or a UTF-8 lead byte wait, while `trx`, `{"a" 1`, or an overlong
  UTF-8 lead (`E0 80`) fail at once. Numbers are emitted only when a byte
  that cannot continue them arrives, or at `finish/1`.
* Events are paths plus values, never partial values; `string_deltas`
  adds preview fragments for string values that contain only complete
  characters and escapes.
* Duplicate keys are detected per object from the set of keys seen so far,
  so memory grows with the number of keys of open objects as well as the
  depth.
* Limits (`max_depth` 1024, `max_document_bytes` 64 MiB, `max_token_bytes`
  8 MiB) return `:parse` / `:limit_exceeded` errors. The 1024-digit integer
  limit of `Formata.Jason` also applies.
* Error codes: `:syntax`, `:incomplete` (input ended early; reported by
  `finish/1`), `:duplicate_key`, `:limit_exceeded`. Acceptance always
  matches `Formata.decode/3`; codes and some offsets can differ because the
  stream reports the first problem in input order (for example a duplicate
  key before a later syntax error).
* `decode_stream/2` is a `Stream.resource/3` that pulls one chunk at a time
  through a suspended `Enumerable.reduce/3`, so the upstream is read only on
  demand and is halted after an error or when the consumer stops.

#### Performance

Profiled with `:tprof` (call time, call memory), process reductions, and GC
statistics; reproduced with `MIX_ENV=test mix run bench/json_stream.exs`.
The cost model is: one scan per byte, a fixed cost per `feed/2` call, and
the events themselves (each event carries its own path list).

Bottlenecks found in 0.2.0 and what changed in 0.2.1:

* **Position tracking (largest cost).** Every `feed/2` re-traversed the
  consumed bytes with a binary comprehension to count code points: 32% of
  the time and 45% of all allocated words at 4 KiB chunks. Positions are now
  advanced by a loop over 7-byte words (and 4-byte words for short chunks)
  using SWAR bit tricks on BEAM small integers: one mask for "all ASCII", the
  exact zero-byte test for "no newline", and a mask plus shift-and-add
  popcount for UTF-8 continuation bytes. Only words containing a newline are
  handled byte by byte, once. Columns still count code points.
* **A quadratic copy per number.** On each number terminator the scanner
  rebuilt `<<b, rest::bits>>`, which copies the rest of the chunk, so cost
  grew with chunk size times the number of numbers (1.19 µs per number in a
  396 KiB chunk versus 0.10 µs in 256-byte chunks). It now resumes through a
  sub-binary of the chunk. This is why large chunks were slower than 256-byte
  chunks.
* **Sub-binary allocation per token.** `dispatch` passed the remaining input
  under two names to a function that first matched on the grammar mode, so
  the compiler could not reuse the binary match context
  (`ERL_COMPILER_OPTIONS=bin_opt_info` reported "BINARY CREATED"). Each mode
  now has its own function whose first argument is the input.
* **State copies.** Each grammar transition copied the 15-field parser
  struct. Per-token state (mode, stack, depth, token) now lives in a 4-field
  record inside the struct, which is updated once per feed; string pieces
  and the decoded size are loop arguments, so escapes no longer rebuild the
  token.
* **Paths.** Event paths were rebuilt by walking the stack. Each frame now
  caches its container path, and a member's key path is shared by its `:key`
  and `:value` events.
* **Strings.** Unescaped ASCII is scanned eight bytes per step; a string
  made of a single run is detached without `iolist_to_binary/1`.
* Not bottlenecks: `settle` (≤ 3%) and the `decode_stream/2` adapter (≤ 10%
  over a manual `feed/2` loop at 1-byte chunks, about 0 for larger chunks).

Before (0.2.0) and after (0.2.1) on Elixir 1.20.4 / OTP 28, Apple M1 Max.
Median of 5–15 runs, each in a fresh process. `reductions` counts BEAM
reductions of the parsing process; `alloc (kw)` is the thousands of heap
words reclaimed by GC during the run (a proxy for allocation).

| workload | chunking | mode | chunks | before ms | after ms | speedup | before reductions | after reductions | before alloc (kw) | after alloc (kw) |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| structured (396 KiB) | whole document | events | 1 | 41.37 | 23.75 | 1.74x | 2399757 | 833024 | 8330 | 1886 |
| structured (396 KiB) | 65536-byte chunks | events | 7 | 50.73 | 16.00 | 3.17x | 2044166 | 832863 | 8900 | 2291 |
| structured (396 KiB) | 4096-byte chunks | events | 100 | 50.87 | 13.67 | 3.72x | 2851350 | 911517 | 8935 | 2310 |
| structured (396 KiB) | random 1-256 B chunks | events | 3216 | 22.33 | 10.54 | 2.12x | 1601358 | 839041 | 9637 | 2610 |
| structured (396 KiB) | random 1-16 B chunks | events | 47767 | 42.70 | 23.03 | 1.85x | 2842471 | 2120045 | 13814 | 5958 |
| structured (396 KiB) | 1-byte chunks | events | 406052 | 172.80 | 86.54 | 2.00x | 12967277 | 11777054 | 56546 | 34000 |
| pretty (143 KiB) | whole document | events | 1 | 6.97 | 4.08 | 1.71x | 429845 | 298037 | 1067 | 933 |
| pretty (143 KiB) | 4096-byte chunks | events | 36 | 6.70 | 4.90 | 1.37x | 420123 | 330781 | 1262 | 1056 |
| pretty (143 KiB) | random 1-16 B chunks | events | 17227 | 13.19 | 7.27 | 1.81x | 890695 | 716014 | 3928 | 2058 |
| llm_tool (7 KiB) | whole document | events | 1 | 0.26 | 0.13 | 2.00x | 19772 | 10683 | 98 | 16 |
| llm_tool (7 KiB) | whole document | events + string_deltas | 1 | 0.28 | 0.13 | 2.15x | 20507 | 10781 | 96 | 15 |
| llm_tool (7 KiB) | whole document | decode_stream | 1 | 0.27 | 0.13 | 2.08x | 20444 | 11459 | 99 | 16 |
| llm_tool (7 KiB) | random 1-256 B chunks | events | 51 | 0.38 | 0.17 | 2.24x | 21667 | 11913 | 114 | 25 |
| llm_tool (7 KiB) | random 1-256 B chunks | events + string_deltas | 51 | 0.38 | 0.18 | 2.11x | 22477 | 12175 | 114 | 24 |
| llm_tool (7 KiB) | random 1-256 B chunks | decode_stream | 51 | 0.37 | 0.16 | 2.31x | 22986 | 13217 | 113 | 26 |
| llm_tool (7 KiB) | random 1-16 B chunks | events | 860 | 0.79 | 0.48 | 1.65x | 46297 | 37220 | 199 | 90 |
| llm_tool (7 KiB) | random 1-16 B chunks | events + string_deltas | 860 | 0.81 | 0.45 | 1.80x | 50923 | 38949 | 209 | 92 |
| llm_tool (7 KiB) | random 1-16 B chunks | decode_stream | 860 | 0.84 | 0.49 | 1.71x | 54788 | 45851 | 214 | 106 |
| llm_tool (7 KiB) | 1-byte chunks | events | 7342 | 3.48 | 1.74 | 2.00x | 246833 | 223910 | 995 | 589 |
| llm_tool (7 KiB) | 1-byte chunks | events + string_deltas | 7342 | 3.61 | 1.71 | 2.11x | 278101 | 235873 | 1055 | 613 |
| llm_tool (7 KiB) | 1-byte chunks | decode_stream | 7342 | 3.71 | 1.82 | 2.04x | 313528 | 289800 | 1107 | 724 |
| long_string (332 KiB) | whole document | events | 1 | 11.65 | 4.46 | 2.61x | 927015 | 434182 | 4295 | 720 |
| long_string (332 KiB) | whole document | events + string_deltas | 1 | 12.74 | 4.33 | 2.94x | 981922 | 433392 | 4295 | 720 |
| long_string (332 KiB) | 4096-byte chunks | events | 84 | 11.21 | 3.96 | 2.83x | 990693 | 432461 | 4312 | 728 |
| long_string (332 KiB) | 4096-byte chunks | events + string_deltas | 84 | 11.18 | 3.95 | 2.83x | 992283 | 432418 | 4313 | 728 |
| long_string (332 KiB) | random 1-16 B chunks | events | 39982 | 31.20 | 15.41 | 2.02x | 2051745 | 1664263 | 8815 | 3946 |
| long_string (332 KiB) | random 1-16 B chunks | events + string_deltas | 39982 | 29.57 | 15.61 | 1.89x | 2214939 | 1734170 | 9106 | 4188 |
| escaped_unicode (89 KiB) | whole document | events | 1 | 3.02 | 1.31 | 2.31x | 395522 | 306685 | 1622 | 381 |
| escaped_unicode (89 KiB) | random 1-16 B chunks | events | 10877 | 9.43 | 5.12 | 1.84x | 746557 | 672068 | 2754 | 1406 |
| deep (3 KiB) | whole document | events | 1 | 9.10 | 3.13 | 2.91x | 863541 | 44979 | 96 | 23 |
| deep (3 KiB) | random 1-16 B chunks | events | 426 | 4.17 | 3.21 | 1.30x | 914253 | 52194 | 1739 | 54 |

Reference rows, same document, complete value without events (after):

| workload | chunking | decoder | ms |
| --- | --- | --- | ---: |
| structured (396 KiB) | whole document | `Formata.decode/3` | 6.4 |
| structured (396 KiB) | whole document | `:json.decode/1` | 3.1 |
| structured (396 KiB) | random 1-256 B chunks | `:json.decode_start/3` + `decode_continue/2` | 4.3 |
| llm_tool (7 KiB) | random 1-16 B chunks | `:json.decode_start/3` + `decode_continue/2` | 6.1 |
| llm_tool (7 KiB) | 1-byte chunks | `:json.decode_start/3` + `decode_continue/2` | 50.4 |
| llm_tool (7 KiB) | random 1-16 B chunks | re-decode the buffer after each chunk | 57.9 |
| long_string (332 KiB) | whole document | `Formata.decode/3` | 2.0 |
| long_string (332 KiB) | 4096-byte chunks | `:json.decode_start/3` + `decode_continue/2` | 48.4 |

Interpretation:

* Large and medium chunks (4–64 KiB, 1–256-byte token deltas) of compact
  JSON improved 2.1–3.7×, long strings 2.6–2.9×, 1-byte chunks 2.0×, and
  reductions fell up to 19× (deep nesting).
* Small token deltas (1–16 bytes) improved 1.65–2.0×. The remaining cost is
  a fixed ~0.3–0.4 µs per `feed/2` (one machine call, one struct update,
  position, settling the token); fewer, larger chunks are cheaper.
* Pretty-printed JSON improved less (1.4–1.8×): its cost is mostly
  whitespace, scanned byte by byte, and newlines, which take the per-byte
  path of position tracking.
* A whole document in a single `feed/2` is dominated by garbage collection
  of the event list returned at once (about 40,000 events for the 396 KiB
  document): with a pre-sized heap (`min_heap_size: 2_000_000`) the same run
  takes about 11 ms instead of 22 ms. Feeding chunks keeps the live event
  list small.
* Event paths are forward lists, so each nested container needs its own
  copy of its path: memory for events is O(depth) per event and O(depth²)
  for a document nested `depth` levels deep (the `deep` workload, 400
  levels: 2,001 events holding 652k words). Its time is dominated by heap
  growth for those paths, not by parsing (reductions fell 17–19×, time
  1.3–2.9×). `:max_depth` bounds it.
* The one-shot decoders remain faster when the whole document is available;
  the stream exists for input that arrives incrementally.

#### OTP `:json` as a backend

`:json.decode_start/3` and `:json.decode_continue/2` (OTP 27+) were evaluated
as a replacement and rejected:

* A pending token is re-parsed from its start on every continuation, so a
  long string streamed in small chunks is quadratic: a 256 KB string takes
  1.5 s in 16-byte chunks versus 0.2 ms whole, and the 332 KiB `long_string`
  document takes 48 ms in 4 KiB chunks.
* It emits nothing until a value completes (there is no key callback), so it
  cannot produce the current `:key`/`:start_*` events as input arrives.
* It keeps duplicate keys (`{"a":1,"a":2}` decodes to `%{"a" => 1}`),
  reports errors as exceptions such as `{:invalid_byte, 93}` without a
  position, and supports neither comments nor trailing commas.

It is much faster for complete input, which is what `Formata.decode/3` is
for; a hybrid would add a second parser without serving the streaming case.

### Phoenix JSON library

Phoenix requires `decode!/1`, `encode!/1`, and `encode_to_iodata!/1` of its
`:json_library` (the raising functions of Elixir's `JSON`); Plug's JSON parser
calls `decode!/1`, or `decode!/2` through an MFA tuple. `Formata.JSON`
implements them:

* Decoding is `Formata.decode/3` with `:json`, so request bodies and socket
  messages get the same guarantees as other Formata input: RFC 8259, string
  keys, and duplicate keys rejected. The first `Formata.Error` is raised.
* Encoding delegates to Elixir's `JSON` rather than Formata's strict encoder.
  Phoenix and LiveView pass atom keys and values and application structs;
  the strict portable domain rejects those by design. Structs use the
  standard `JSON.Encoder` protocol, so existing `@derive JSON.Encoder`
  declarations keep working; the internal `Formata.Jason` fork and its
  protocol stay private.
* Checked end to end with Phoenix 1.8.16 and Plug 1.20.3 (`Plug.Parsers`,
  `Phoenix.Controller.json/2`, `Phoenix.Socket.V2.JSONSerializer`).

### JSON5

* `Formata.Codec.JSON5` has its own recursive-descent parser. The JSON
  decoder was not extended with JSON5 switches, so JSON5 semantics (quotes,
  identifiers, hexadecimal, `Infinity`/`NaN`) cannot leak into `:json`. No
  regular-expression rewriting into JSON is used; the only regular
  expressions classify a single non-ASCII code point by Unicode general
  category for `IdentifierName`.
* Special values map to `:infinity`, `:negative_infinity`, and `:nan`, the
  atoms already used by TOML and YAML. The encoder accepts them in addition
  to the JSON domain and writes `Infinity`, `-Infinity`, `NaN`.
* Converting to `:json` keeps the JSON encoder's rule: non-finite numbers are
  `:unrepresentable` at their path unless a transform (for example
  `:special_floats_to_strings`) is requested. JSON Schema validation rejects
  them as `:non_json_value`.
* `:json5` takes no decode options; `comments`/`trailing_commas` are
  rejected because JSON5 always allows both.
* Finite literals outside the float range are errors, not `Infinity`;
  underflow to `0.0` follows `:erlang.binary_to_float/1`, as in `:json`.
